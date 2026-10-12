# Organisation profile

GitHub displays [profile/README.md](profile/README.md) on the public
[organisation overview](https://github.com/ai-platform-portfolio).

The introduction is maintained by hand. Repository catalogue automation owns only
the block between `repositories:start` and `repositories:end`.

## Bulk repository settings

`scripts/repository_settings.py` uses Python 3 and an authenticated GitHub CLI
(`gh`) to apply supported boolean repository settings across an organisation.
Automatic deletion after PR merge is a **repository setting**, rather than an
organisation setting. Enabling it requires organisation-owner access.

### Settings scope

| Setting | GitHub scope | Script behaviour |
| --- | --- | --- |
| `delete_branch_on_merge` | Per repository | Enables/disables branch deletion after merge in each selected repository |
| `allow_auto_merge` | Per repository | Enables/disables PR auto-merge availability |
| `allow_merge_commit`, `allow_squash_merge`, `allow_rebase_merge` | Per repository | Enables/disables each PR merge method |
| `has_issues`, `has_projects`, `has_wiki`, `has_discussions` | Per repository | Enables/disables repository features |
| Organisation-level settings | Organisation | Not supported by this script; no organisation settings are changed |

`--org` selects the repositories to process; it does **not** make these settings
organisation-wide defaults or policies. New repositories must be included in a
later run. When adding settings, record their GitHub scope here. Organisation
settings should have a separate command and section, rather than being passed
to this repository-settings script.

Preview, then apply:

```sh
python3 scripts/repository_settings.py --set delete_branch_on_merge=true
python3 scripts/repository_settings.py --set delete_branch_on_merge=true --apply
```

Use `--org NAME` for another organisation and repeat `--repo NAME` to restrict
the scope. Repeat `--set KEY=true|false` to change multiple supported settings;
`--help` shows usage and invalid settings print the supported keys. The script
discovers all repositories with pagination, skips archived repositories, changes
only settings that differ, and verifies each update. Errors produce a nonzero
exit status; earlier successful updates remain applied and reruns are safe.

This enables deletion after future merges; it does not clean up branches from
PRs already merged. Branch protections and repository rules can prevent deletion.

## Delivery acceptance

- [ ] Public organisation profile is visible.
- [ ] A GitHub App repository webhook updates the catalogue automatically.
- [ ] A real repository metadata change is reflected without a manual sync.

The webhook integration requires an installed GitHub App and an approved Azure
Function deployment. Until those are verified, automatic sync is not operational.
The selected hosting design is Azure Functions Flex Consumption with VNet
integration and a public endpoint for signed GitHub webhooks. Deployment belongs
in the central `ci` Terraform root; credentials belong in managed secrets.
