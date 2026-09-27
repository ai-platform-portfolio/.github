# Organisation profile

GitHub displays [profile/README.md](profile/README.md) on the public
[organisation overview](https://github.com/ai-platform-portfolio).

The introduction is maintained by hand. Repository catalogue automation owns only
the block between `repositories:start` and `repositories:end`.

## Delivery acceptance

- [ ] Public organisation profile is visible.
- [ ] A GitHub App repository webhook updates the catalogue automatically.
- [ ] A real repository metadata change is reflected without a manual sync.

The webhook integration requires an installed GitHub App and an approved Azure
Function deployment. Until those are verified, automatic sync is not operational.
The selected hosting design is Azure Functions Flex Consumption with VNet
integration and a public endpoint for signed GitHub webhooks. Deployment belongs
in the central `ci` Terraform root; credentials belong in managed secrets.
