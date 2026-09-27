# Organisation profile

GitHub displays [profile/README.md](profile/README.md) on the public
[organisation overview](https://github.com/ai-platform-portfolio).

The introduction is maintained by hand. [catalogue.yml](.github/workflows/catalogue.yml)
owns only the block between `repositories:start` and `repositories:end`, rebuilding
it from each public repository's name and description.

It runs hourly, on `workflow_dispatch`, and on a `repository-changed`
`repository_dispatch` for an immediate update. A repository is added or renamed by
changing it in GitHub, not by editing this file; a repository's one-line purpose is
its GitHub description.

## Delivery acceptance

- [ ] Public organisation profile is visible.
- [ ] A repository metadata change is reflected without a manual edit.

Pushing to `main` needs a bypass actor on this repository's ruleset, since the
catalogue commit is generated rather than reviewed.
