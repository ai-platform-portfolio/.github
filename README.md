# Organisation profile and portfolio

GitHub displays [profile/README.md](profile/README.md) on the public
[organisation overview](https://github.com/ai-platform-portfolio).

The introduction is maintained by hand. The catalogue markers reserve the table
for repository catalogue automation; the proposed GitHub webhook integration is
not operational. This hosting work does not implement that older integration.

## Always-on portfolio

[`portfolio/image/`](portfolio/image/) contains the website and its small Python
API. [`portfolio/terraform/`](portfolio/terraform/) owns independent Azure Container
Apps hosting at `https://portfolio.dev.michaelalinks.com`. Initial deployment is
pending; a successful build or plan is not evidence that the site is live.

The site stays available during the disposable AKS lifecycle. It has no dependency
on an in-cluster database, ingress, Argo CD or cluster credentials. Its own resource
group, managed identity and separate backend key are outside `gitops/bootstrap`.
The existing `localacrk8s` registry and DNS zone are persistent prerequisites.

### Delivery

`.github/workflows/portfolio.yml` composes the shared Docker and Azure Terraform
workflows. Same-repository PRs publish scanned preview images and plan their actual
digests. Forks run tests, offline Terraform validation and build-only image scans.
Main pushes publish a scanned image; **only a manual run from `main` invokes
Terraform apply**. Each invocation builds the selected source and deploys its
immutable image digest. No stored registry password or Azure client secret is used.

Merge the shared `ops-shared` workflow first, update this caller to its actual merge
SHA, then merge the portfolio PR. The implementation pin may refer to the reviewed
shared PR commit until that final adoption update. Before the first manual run:

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

The custom runtime role grants **only**
`Microsoft.ContainerService/managedClusters/read` at subscription scope. It can
read metadata for other AKS resources in that subscription, although the application
queries only its configured cluster. This scope is deliberate: assignments attached
to the disposable cluster/resource group disappear on teardown. The role cannot
fetch kubeconfig, access the Kubernetes API or change a cluster. A separate AcrPull
assignment is scoped to the existing registry.

### Local validation

```sh
terraform -chdir=portfolio/terraform init -backend=false
terraform -chdir=portfolio/terraform fmt -check
terraform -chdir=portfolio/terraform validate

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
