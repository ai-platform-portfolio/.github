"""Portfolio homepage asset versioning and cluster status boundaries."""

from hashlib import sha256
import json
import os
from pathlib import Path
from shutil import copyfile
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from azure.core.exceptions import ClientAuthenticationError

import app


class HomepageTests(unittest.TestCase):
    def test_homepage_requires_revalidation_and_references_current_assets(self):
        response = app.index()
        self.assertEqual(response.headers["cache-control"], "no-cache")
        for name in ("style.css", "app.js"):
            version = sha256((app.assets / name).read_bytes()).hexdigest()
            self.assertIn(f'"/static/{name}?v={version}"'.encode(), response.body)

    def test_changing_one_asset_changes_only_its_url(self):
        with TemporaryDirectory() as temp:
            directory = Path(temp)
            for name in ("index.html", "style.css", "app.js"):
                copyfile(app.assets / name, directory / name)

            previous = app.render_homepage(directory)
            old_version = sha256((directory / "style.css").read_bytes()).hexdigest()
            new_css = b"body { color: blue; }"
            (directory / "style.css").write_bytes(new_css)
            current = app.render_homepage(directory)

        old_url = f"/static/style.css?v={old_version}"
        new_url = f"/static/style.css?v={sha256(new_css).hexdigest()}"
        self.assertIn(old_url, previous)
        self.assertEqual(current, previous.replace(old_url, new_url))


class StatusTests(unittest.TestCase):
    def setUp(self):
        app._cached = None
        app._expires = 0

    def test_power_and_transition_states(self):
        for power, provisioning, expected in [
            ("Running", "Succeeded", "running"),
            ("Stopped", "Succeeded", "stopped"),
            ("Running", "Starting", "changing"),
            ("Running", "Updating", "changing"),
            ("Stopped", "Deleting", "changing"),
            ("Running", "Failed", "degraded"),
            ("Running", "", "unknown"),
            ("", "Succeeded", "unknown"),
        ]:
            with self.subTest(power=power, provisioning=provisioning):
                resource = {
                    "properties": {
                        "powerState": {"code": power},
                        "provisioningState": provisioning,
                    }
                }
                self.assertEqual(app.cluster_state(resource), expected)

    @patch.dict(
        os.environ,
        {
            "AZURE_SUBSCRIPTION_ID": "test",
            "AKS_RESOURCE_GROUP": "test",
            "AKS_NAME": "test",
        },
    )
    @patch("app._credential")
    def test_only_not_found_means_absent(self, credential):
        for code, expected in [
            (404, "absent"),
            (403, "unknown"),
            (429, "unknown"),
            (503, "unknown"),
        ]:
            with (
                self.subTest(code=code),
                patch(
                    "app.urlopen", side_effect=HTTPError("url", code, "error", {}, None)
                ),
            ):
                app._cached = None
                result = json.loads(app.status().body)
                self.assertEqual(result["state"], expected)
                self.assertNotIn("test", json.dumps(result))

    @patch("app.read_status")
    def test_cache_coalesces_requests_and_expires(self, read):
        read.return_value = "running"
        first = app.status()
        self.assertEqual(app.status().body, first.body)
        self.assertEqual(read.call_count, 1)

        app._expires = 0
        read.return_value = "absent"
        self.assertEqual(json.loads(app.status().body)["state"], "absent")
        self.assertEqual(read.call_count, 2)

    @patch("app.read_status")
    def test_auth_error_replaces_previous_green_state(self, read):
        read.return_value = "running"
        app.status()
        app._expires = 0
        read.side_effect = ClientAuthenticationError("private error details")

        response = app.status()
        self.assertEqual(json.loads(response.body)["state"], "unknown")
        self.assertNotIn(b"private", response.body)
        self.assertEqual(response.headers["cache-control"], "no-store")
        self.assertEqual(app.health(), {"status": "ok"})


if __name__ == "__main__":
    unittest.main()
