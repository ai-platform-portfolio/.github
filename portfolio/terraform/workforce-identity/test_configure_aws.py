import configparser
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from configure_aws import install


GENERATED = '''[profile example]
sso_session = example
sso_account_id = 123456789012
sso_role_name = Bootstrap
region = eu-west-3

[sso-session example]
sso_start_url = https://example.awsapps.com/start
sso_region = eu-west-2
sso_registration_scopes = sso:account:access
'''


class ConfigurationTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.config = Path(directory.name) / 'aws' / 'config'

    def test_replaces_obsolete_profile_preserves_others_and_repeats_safely(self):
        self.config.parent.mkdir()
        unrelated = '# unrelated operator\n[profile other]\nregion = eu-west-1\ncredential_process = existing-helper\n'
        self.config.write_text(unrelated + '\n[profile example]\nlogin_session = old-root-session\n')
        install(GENERATED, self.config)
        first = self.config.read_text()
        self.assertTrue(first.startswith(unrelated))
        self.assertNotIn('login_session', first)
        install(GENERATED, self.config)
        self.assertEqual(self.config.read_text(), first)
        self.assertEqual(stat.S_IMODE(self.config.stat().st_mode), 0o600)

    def test_new_destination_and_nonliteral_profile_name(self):
        install(GENERATED.replace('example', 'second'), self.config)
        config = configparser.RawConfigParser()
        config.read(self.config)
        self.assertEqual(set(config.sections()), {'profile second', 'sso-session second'})

    def test_invalid_or_ambiguous_input_preserves_existing_file(self):
        self.config.parent.mkdir()
        for generated in ['', GENERATED.replace('sso_session = example', 'login_session = example'),
                          GENERATED + '\n[profile example]\nregion = eu-west-1\n',
                          GENERATED.replace('https://', 'http://'),
                          GENERATED.replace('sso_region = eu-west-2', 'aws_secret_access_key = forbidden')]:
            with self.subTest(generated=generated):
                self.config.write_text('[profile other]\nregion = eu-west-1\n')
                before = self.config.read_bytes()
                with self.assertRaises((ValueError, configparser.Error)):
                    install(generated, self.config)
                self.assertEqual(self.config.read_bytes(), before)
        self.config.write_text('[profile other]\n[profile other]\n')
        with self.assertRaises(configparser.Error):
            install(GENERATED, self.config)

    def test_failed_atomic_replace_preserves_file_and_removes_temporary(self):
        self.config.parent.mkdir()
        self.config.write_text('# original\n')
        with patch('configure_aws.os.replace', side_effect=OSError('unavailable')):
            with self.assertRaises(OSError):
                install(GENERATED, self.config)
        self.assertEqual(self.config.read_text(), '# original\n')
        self.assertEqual(list(self.config.parent.iterdir()), [self.config])

    def test_command_reads_output_from_stdin_without_starting_login(self):
        result = subprocess.run([sys.executable, str(Path(__file__).with_name('configure_aws.py')),
                                 '--config', str(self.config)], input=GENERATED,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('123456789012', result.stdout + result.stderr)
        self.assertIn('No login started', result.stdout)


if __name__ == '__main__':
    unittest.main()
