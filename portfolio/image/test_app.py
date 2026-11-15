"""Meaningful status boundaries: deletion, auth failure, cache and power vs health."""

import json
import os
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

from azure.core.exceptions import ClientAuthenticationError

import app


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
