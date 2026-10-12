# Organisation profile

GitHub displays [profile/README.md](profile/README.md) on the public
[organisation overview](https://github.com/ai-platform-portfolio).

The introduction is maintained by hand. Repository catalogue automation owns only
the block between `repositories:start` and `repositories:end`.

## Repository defaults

Edit `repository-settings.json` to change the settings applied to each repository:

| Setting | Value | GitHub scope |
| --- | --- | --- |
| `delete_branch_on_merge` | `true` | Per repository |
| `allow_squash_merge` | `true` | Per repository |
| `allow_merge_commit` | `false` | Per repository |
| `allow_rebase_merge` | `false` | Per repository |
| Organisation-level settings | Not managed here | Organisation |

These are bulk **per-repository** updates, not organisation-wide GitHub defaults.
Record the scope in this table when adding settings. Organisation settings need
separate code and documentation.

With Python 3 and an authenticated GitHub CLI (`gh`), preview or apply:

```sh
python3 scripts/repository_settings.py
python3 scripts/repository_settings.py --apply
```

The script reads the saved settings, lists all org repositories, skips archived
repositories, changes settings that differ, and verifies each write. A failed API
request stops the run; rerun after fixing it. New repositories receive the same
configuration when the script runs. Enabling branch deletion affects future
merges, not existing branches from already merged PRs. Branch rules can prevent deletion.

## Delivery acceptance

- [ ] Public organisation profile is visible.
- [ ] A GitHub App repository webhook updates the catalogue automatically.
- [ ] A real repository metadata change is reflected without a manual sync.

The webhook integration requires an installed GitHub App and an approved Azure
Function deployment. Until those are verified, automatic sync is not operational.
The selected hosting design is Azure Functions Flex Consumption with VNet
integration and a public endpoint for signed GitHub webhooks. Deployment belongs
in the central `ci` Terraform root; credentials belong in managed secrets.
