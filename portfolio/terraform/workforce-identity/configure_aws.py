#!/usr/bin/env python3
"""Install the aws_config Terraform output without starting an authentication flow."""
import argparse
import configparser
import os
from pathlib import Path
import re
import sys
import tempfile
from urllib.parse import urlsplit


def install(generated, destination):
    config = configparser.RawConfigParser()
    config.read_string(generated)
    profiles = [name for name in config.sections() if name.startswith('profile ')]
    if len(profiles) != 1 or config.defaults():
        raise ValueError('Expected one generated profile and its SSO session')
    profile = profiles[0]
    values = config[profile]
    if set(values) != {'sso_session', 'sso_account_id', 'sso_role_name', 'region'}:
        raise ValueError('Expected only native SSO profile settings')
    session = 'sso-session ' + values['sso_session']
    if (set(config.sections()) != {profile, session}
            or not re.fullmatch(r'[A-Za-z0-9_-]+', profile.removeprefix('profile '))
            or values['sso_session'] != profile.removeprefix('profile ')
            or not re.fullmatch(r'[0-9]{12}', values['sso_account_id'])
            or not values['sso_role_name'] or not values['region']):
        raise ValueError('Invalid generated SSO profile/session')
    settings = config[session]
    if set(settings) != {'sso_start_url', 'sso_region', 'sso_registration_scopes'}:
        raise ValueError('Expected only native SSO session settings')
    url = urlsplit(settings['sso_start_url'])
    if (url.scheme != 'https' or not url.hostname or url.username or url.password
            or not settings['sso_region'] or settings['sso_registration_scopes'] != 'sso:account:access'):
        raise ValueError('Invalid generated SSO session settings')

    original = destination.read_text() if destination.exists() else ''
    existing = configparser.RawConfigParser()
    existing.read_string(original)  # Reject ambiguous/duplicate sections before changing anything.
    headers = list(re.finditer(r'(?m)^[ \t]*\[([^\]\r\n]+)\][^\r\n]*', original))
    retained = original[:headers[0].start()] if headers else original
    for index, header in enumerate(headers):
        end = headers[index + 1].start() if index + 1 < len(headers) else len(original)
        if header[1].strip() not in {profile, session}:
            retained += original[header.start():end]
    updated = retained + ('\n' if retained and not retained.endswith('\n\n') else '') + generated.strip() + '\n'
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=destination.parent, prefix='.aws-config-', delete=False) as output:
            temporary = Path(output.name)  # NamedTemporaryFile creates the file with mode 0600.
            output.write(updated)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, destination)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--config', type=Path,
                        default=Path(os.environ.get('AWS_CONFIG_FILE', '~/.aws/config')).expanduser())
    args = parser.parse_args()
    try:
        install(sys.stdin.read(), args.config.expanduser())
    except (ValueError, OSError, configparser.Error) as error:
        # Parser errors can include input text; never echo configuration values.
        parser.exit(1, f'Cannot install generated AWS SSO configuration ({type(error).__name__}); destination preserved.\n')
    print('Installed native AWS SSO configuration. No login started; unrelated profiles preserved.')


if __name__ == '__main__':
    main()
