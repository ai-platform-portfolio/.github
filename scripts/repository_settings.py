#!/usr/bin/env python3
"""Preview/apply per-repository settings; no organization-level settings are changed."""

import argparse
import json
import re
import subprocess
import sys


SETTINGS = {
    "delete_branch_on_merge", "allow_auto_merge", "allow_merge_commit",
    "allow_squash_merge", "allow_rebase_merge", "has_issues",
    "has_projects", "has_wiki", "has_discussions",
}


def setting(value):
    key, separator, raw = value.partition("=")
    if not separator or key not in SETTINGS or raw not in {"true", "false"}:
        raise argparse.ArgumentTypeError(
            "Use SUPPORTED_SETTING=true|false; supported: " + ", ".join(sorted(SETTINGS))
        )
    return key, raw == "true"


def api(endpoint, payload=None, paginate=False):
    command = ["gh", "api", "--hostname", "github.com", endpoint]
    if paginate:
        command += ["--paginate", "--slurp"]
    if payload is not None:
        command += ["--method", "PATCH", "--input", "-"]
    result = subprocess.run(
        command, input=json.dumps(payload) if payload is not None else None,
        capture_output=True, text=True, check=True,
    )
    return json.loads(result.stdout)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--org", default="ai-platform-portfolio", help="Select repositories in this organization; does not change organization settings")
    parser.add_argument("--set", dest="settings", type=setting, action="append", required=True)
    parser.add_argument("--repo", action="append", help="Limit to named repositories; repeatable")
    parser.add_argument("--apply", action="store_true", help="Apply changes; default is preview only")
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9-]+", args.org):
        parser.error("Invalid organization name")
    desired = dict(args.settings)
    if len(desired) != len(args.settings):
        parser.error("Specify each setting only once")
    try:
        print(f"Scope: PER REPOSITORY | organization: {args.org} | mode: {'apply' if args.apply else 'preview'}")
        pages = api(f"orgs/{args.org}/repos?per_page=100", paginate=True)
        repos = sorted((repo for page in pages for repo in page), key=lambda r: r["name"])
        selected = set(args.repo or [])
        missing = selected - {repo["name"] for repo in repos}
        if missing:
            parser.error("Repositories not found: " + ", ".join(sorted(missing)))
        failures = 0
        for repo in repos:
            if selected and repo["name"] not in selected:
                continue
            name = repo["full_name"]
            if repo["archived"]:
                print(f"SKIP {name}: archived")
                continue
            try:
                current = api(f"repos/{name}")
                changes = {key: value for key, value in desired.items() if current.get(key) != value}
                if not changes:
                    print(f"OK {name}: settings already match")
                    continue
                detail = ", ".join(
                    f"{key}: {json.dumps(current.get(key))} -> {json.dumps(value)}"
                    for key, value in changes.items()
                )
                if not args.apply:
                    print(f"PREVIEW {name}: {detail}")
                    continue
                api(f"repos/{name}", payload=changes)
                verified = api(f"repos/{name}")
                if any(verified.get(key) != value for key, value in desired.items()):
                    raise ValueError("Settings did not match after update")
                print(f"UPDATED {name}: {detail} (verified)")
            except (subprocess.CalledProcessError, ValueError) as error:
                failures += 1
                message = error.stderr.strip() if isinstance(error, subprocess.CalledProcessError) else str(error)
                print(f"ERROR {name}: {message}", file=sys.stderr)
        return 1 if failures else 0
    except subprocess.CalledProcessError as error:
        print(error.stderr.strip(), file=sys.stderr)
        return 1
    except FileNotFoundError:
        print("GitHub CLI (gh) must be installed and authenticated.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
