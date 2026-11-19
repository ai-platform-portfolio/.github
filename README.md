# Organisation profile and portfolio

GitHub displays [profile/README.md](profile/README.md) on the public
[organisation overview](https://github.com/ai-platform-portfolio).

The introduction is maintained by hand. The catalogue markers reserve the table
for repository catalogue automation; the proposed GitHub webhook integration is
not operational. This hosting work does not implement that older integration.

## Persistent workforce identity

Persistent operator authentication lives separately in
[`portfolio/terraform/workforce-identity/`](portfolio/terraform/workforce-identity/README.md).
It uses `workforce-identity.tfstate` in the existing Azure backend, independently
of `portfolio-hosting.tfstate` and disposable GitOps bootstrap. Its Entra-backed
AWS access uses native refreshable CLI SSO; initial SAML connection and the 90-day
interactive session setting require the documented one-time console setup.
Both persistent roots live under `portfolio/terraform`, in independent directories
and state files. Moving a root does not change its resource addresses or blob key.

### Infrastructure pipeline

`.github/workflows/infra.yml` validates `portfolio/terraform/*` offline on PRs and
main pushes using the existing ops-shared template. PRs and manual dispatches call its
Terraform plan/apply template once per explicit matrix row. Main dispatches apply
the saved plan; PRs and dispatches on other branches only plan. The caller owns the matrix,
and each row supplies its root, state key and unique plan artifact name.

The deployment matrix contains `portfolio/terraform/ci-access` and
`portfolio/terraform/workforce-identity`. The Azure-only CI access root owns the
existing publisher's persistent Foundry and backend Blob grants in `ci-access.tfstate`.
Add a row for another standalone root when it is ready for deployment. The Container
App remains in `portfolio.yml`: it still builds/scans an image and deploys its exact
digest. Identity-only changes do not trigger that image workflow.

Before dispatching workforce identity, provide its actual tracked
`terraform.tfvars`, set repository variables `AWS_WORKFORCE_PLAN_ROLE_ARN` and
`AWS_WORKFORCE_APPLY_ROLE_ARN` to existing authorised CI role ARNs, and match the
matrix AWS region to Identity Center's home region. These are deployment roles,
separate from the local user's Identity Center role. Verify their GitHub OIDC
trust for this repository's `central-plan` and `central-apply` environments, their
Identity Center/Identity Store permissions, and the existing Azure identity's
backend/Entra Graph permissions. No trust, role or permission is created by the
workflow. Missing AWS inputs fail before backend initialization. The existing
organisation Azure OIDC and backend secrets remain the authentication contract.
No AWS access keys are used. The pipeline is source-only until these prerequisites
and the documented SAML setup are completed and a real plan is reviewed.

## Always-on portfolio

[`portfolio/image/`](portfolio/image/) contains the website and its small Python
API. [`portfolio/terraform/container-app/`](portfolio/terraform/container-app/) owns independent Azure Container
Apps hosting at `https://portfolio.dev.michaelalinks.com`. Production is deployed
independently of AKS.

The site stays available during the disposable AKS lifecycle. It has no dependency
on an in-cluster database, ingress, Argo CD or cluster credentials. Its own resource
group, managed identity and separate backend key are outside `gitops/bootstrap`.
The existing `localacrk8s` registry and DNS zone are persistent prerequisites.

### Delivery

`.github/workflows/portfolio.yml` composes the shared Docker and Azure OpenTofu
workflows. Same-repository PRs publish scanned preview images and plan their actual
digests. Forks run tests, offline OpenTofu validation and build-only image scans.
Main pushes publish a scanned image and automatically invoke **OpenTofu
plan/apply**. Manual runs from `main` also deploy; PRs only plan. Each invocation builds the selected source and deploys its
immutable image digest. No stored registry password or Azure client secret is used.

### PR previews

Same-repository PRs select `build-engine: acr` in the shared Docker workflow.
The checked-out source is uploaded to standard ACR Tasks for the container build;
application tests and the existing Trivy vulnerability gate stay in their current
workflow. GitHub uses Azure OIDC; ACR needs no GitHub PAT or source webhook.
Forks remain validation/build-only. Production retains its existing build and
OpenTofu delivery path.

After a successful scan, the shared native Container Apps action creates or
updates `pv-<repository-id>-pr-<number>` in the existing environment and posts its
generated HTTPS URL. Previews reuse the permanent `portfolio-hosting` managed
identity, including its existing Contributor and AcrPull grants, as explicitly
chosen for this portfolio. Preview code therefore has the same Azure permissions
as production. No preview identities or role assignments are created or deleted.
Previews scale from zero to one replica at0.25vCPU/0.5GiB and share the existing
public environment; initial requests may encounter a cold start.

The same workflow handles unfiltered close-only events without checking out PR
code. It deletes only the owned app. A shared queue and live PR checks prevent
stale builds from replacing a newer head or recreating a closed preview.

An Azure Container Apps job, `portfolio-preview-cleanup`, runs at02:00UTC as a
fallback for missed close events. It uses the same image, environment and managed
identity, starting `python /app/preview_cleanup.py` instead of the web server.
The shared script is included from an immutable source with a verified checksum.
Only apps whose name/tags match a verified closed PR in this organization are
deleted. Open PRs and failed/unknown GitHub lookups remain. The job has no running
replica between executions, a five-minute timeout and one retry. Successful main
delivery updates its image; production delivery remains the existing OpenTofu path.

Published images have independent retention. No preview Terraform root, backend
key, custom DNS, dedicated build pool or GitHub nightly workflow is added.
Merge the shared capability first and adopt its merge SHA before merging this
caller. Close-event automation starts after the caller merges; the Azure fallback
is independent once configured. Source CI and live acceptance are separate.

The OpenTofu shared workflows are pinned to their actual merged revision. Merge
the Container Apps module-library PR first, then adopt its actual merge SHA in
all three module calls before merging the portfolio PR. Before the first manual run:

1. Verify the existing organisation `AZURE_CLIENT_ID`, `AZURE_TENANT_ID` and
   `AZURE_SUBSCRIPTION_ID` secrets and federated trust for this repository and the
   `central-plan` / `central-apply` environments. Protect the apply environment as
   appropriate. The environment name alone does not impose reviewer approval.
2. Verify the existing `TF_BACKEND_RESOURCE_GROUP`, `TF_BACKEND_RESOURCE_NAME` and
   `TF_BACKEND_CONTAINER` secrets reference the persistent backend. The caller uses
   the distinct key `portfolio-hosting.tfstate`; it does not manage backend storage.
3. Verify the CI identity can publish to ACR, access the backend and plan the root.
   Apply also needs resource-group/Container Apps/identity management, the two new
   DNS records, and role-definition/assignment permissions for this root's RBAC.
   Existing secret names alone do not prove effective permissions.
4. Confirm `Microsoft.App`, `Microsoft.ManagedIdentity`, `Microsoft.Network` and
   `Microsoft.Authorization` provider registrations. This root avoids automatically
   registering unrelated Azure providers.

The network change is limited to public HTTPS ingress on the new Container App,
the `portfolio` CNAME and `asuid.portfolio` TXT record in the existing zone.
Azure issues and renews the managed certificate. No AKS firewall, ingress, DNS
record or VNet is changed. Verify public DNS and certificate binding after apply;
Azure's asynchronous issuance and DNS propagation remain live acceptance gates.

The reusable `container-app` module owns hostname registration and the managed
certificate through AzureRM. Its certificate
argument does not accept managed-certificate IDs, so Azure's existing AzAPI
provider binds that certificate through the native API. A destroy-only action
removes the binding before OpenTofu deletes the certificate; an update resource
alone would leave the binding behind on destroy. No CLI provisioner, certificate
private key or additional certificate service is used.

The default is one Consumption replica at 0.25 vCPU / 0.5 GiB, with maximum one
replica. This is a small portfolio host, not a high-availability design. Azure can
restart the replica, and brief interruptions remain possible. No dedicated profile,
gateway, database or Log Analytics workspace is provisioned by this root.

### Cluster status

`GET /api/status` uses a managed identity to read the configured AKS resource from
Azure Resource Manager. The public response contains only a normalized state and
check timestamp. Requests share a 30-second in-process cache. Checks happen on
page load, return to the browser tab and Refresh; an untouched open tab does not
receive continuous updates. There is no timer, background poller or Event Grid
subscription.

The UI distinguishes running, stopped, changing, not provisioned, unsuccessful
operations and unknown status. Only a resource lookup's HTTP 404 means not
provisioned; authorization, throttling and network failures mean unknown. Cluster
power state is separate from application readiness. `/healthz` checks this host
and remains healthy when AKS or Azure's management API is unavailable.

As explicitly requested, the runtime identity now uses built-in Contributor at
subscription scope instead of a custom runtime Contributor role. This permits resource
management across the subscription and is broader than the status API's reads.
The API still queries only its configured cluster and returns normalized status.
AcrPull remains scoped to the existing registry. Contributor does not include IAM
role-assignment management; the deploying identity needs that capability separately
to create the declared runtime grants.

### Local validation

```sh
tofu -chdir=portfolio/terraform/container-app init -backend=false
tofu -chdir=portfolio/terraform/container-app fmt -check
tofu -chdir=portfolio/terraform/container-app validate

python -m venv .venv
.venv/bin/pip install --require-hashes -r portfolio/image/requirements.txt
.venv/bin/python -m unittest discover -s portfolio/image -p 'test_*.py'
.venv/bin/uvicorn app:app --app-dir portfolio/image --port 8080

docker build -t portfolio portfolio/image
```

Without Azure configuration, local status is honestly unavailable. For a read-only
live lookup, set `AZURE_SUBSCRIPTION_ID`, `AKS_RESOURCE_GROUP` and `AKS_NAME` in the
local process and authenticate with a supported `DefaultAzureCredential` identity.
Deployed code uses `ManagedIdentityCredential` with its assigned identity directly.
Keep actual subscription/tenant IDs, backend configuration and credentials out of
Git. Upgrade dependencies with `uv pip compile portfolio/image/requirements.in
--generate-hashes --output-file portfolio/image/requirements.txt` and rerun the image
scan. The Dockerfile pins the official Python Alpine base by digest.

### Reusable module ownership

The root composes `container-app-environment`, the existing `managed-identity`
module and `container-app` from the Terraform library, following `gitops/bootstrap`.
The caller owns the resource group, grouped Azure/environment/application intent,
registry/DNS lookups and the runtime role selection. The identity module owns
its scoped grants; the app module owns sizing/probe defaults and optional managed
HTTPS wiring/cleanup. The caller explicitly selects public ingress and one warm
replica. Modules contain no portfolio domain, cluster name or status permission.
Names and the approved resource set are preserved. No deployment has taken place,
so no resource-address migration blocks are needed.
