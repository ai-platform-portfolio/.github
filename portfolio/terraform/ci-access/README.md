# Persistent CI access

Owns all CI publisher grants formerly managed by disposable GitOps bootstrap:
Foundry Project Manager at subscription scope and Storage Blob Data Contributor
on the existing Terraform backend account. They use the same existing principal,
built-in roles and scopes; no registration, federation, backend or cluster is
created. Other externally supplied roles retain their existing ownership.

This Azure-only root uses `ci-access.tfstate` in the existing persistent backend.
It is independent of `portfolio-hosting.tfstate`, `workforce-identity.tfstate` and
disposable GitOps state. Neither Container App nor GitOps teardown touches it.
The infra caller includes it as a separate matrix row with a unique plan artifact
and no AWS inputs. Changes to this root do not trigger the Container App image flow.

## Bootstrap and ownership

An authorised local Azure operator establishes the grants using this root before
the CI identity can manage its own persistent state. Missing grants are created
and tracked directly by Terraform; already-existing grants must be imported.
Do not create a duplicate assignment or let GitOps reconcile the same grant.

For this transfer, disposable GitOps state was verified empty and the source
grant definitions removed. If transferring a grant still in another state, first
relinquish it there without destroying it, then import it here. No manual backend
storage deletion, access key or AWS authentication is required.

From this directory, supply ignored `backend.local.hcl` with the existing account,
resource group and container metadata. Its final key must be `ci-access.tfstate`:

```sh
tofu init -backend-config=backend.local.hcl -backend-config=key=ci-access.tfstate
tofu plan -out=ci-access.tfplan
tofu apply ci-access.tfplan
tofu plan
```

Keep identifiers and native command output containing subscription context out
of public logs; no subscription/tenant outputs are defined. Actual principal and
storage resource metadata live in tracked `terraform.tfvars`; credentials and
backend configuration remain ignored. After apply or import, require a no-change plan
and rerun the failed Container App CI plan to verify effective backend access.
The pipeline uses the existing organisation Azure OIDC identity and secrets.
