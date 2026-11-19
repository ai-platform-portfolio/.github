# Persistent workforce identity

Entra-backed AWS operator access for local GitOps bootstrap, independent of AKS
and the portfolio Container App. This root owns a new gallery SAML application,
its signing certificate/Entra assignments, explicitly provisioned Identity Store
users and one scoped AWS permission set/account assignment. It uses reusable
modules from the Terraform library. It creates no IAM user, access key, SCIM
provisioning token, credential helper or deployment runner.

| Root | State key | Lifecycle |
| --- | --- | --- |
| `portfolio/terraform/container-app` | `portfolio-hosting.tfstate` | Container App hosting |
| `portfolio/terraform/ci-access` | `ci-access.tfstate` | Persistent Azure CI grants |
| `portfolio/terraform/workforce-identity` | `workforce-identity.tfstate` | Persistent operator authentication |
| GitOps `bootstrap` | Existing bootstrap key | Disposable platform |

Use the existing persistent Azure backend account/container with a separate key.
Neither `gitops make down` nor a hosting-root destroy traverses this root. Do not
destroy this foundation as part of application teardown. No existing account,
Identity Center instance or registration is adopted by this code. It owns two
GitHub OIDC CI roles and reuses the existing GitHub OIDC provider.

## Initial setup

An existing authorised AWS administrator is needed once to establish account
access, and again for foundation maintenance; the scoped role created here
cannot administer Identity Center. Use an appropriately authorised Entra directory
operator too. This setup cannot authenticate itself from an expired AWS session.
No login is invoked automatically by this repository.

1. Locate or enable an **account-access-capable** IAM Identity Center instance in
   its chosen home region. Check the existing instance and account/Organizations
   setup first; an application-only instance is insufficient. Do not replace an
   existing identity source without reviewing its users and ownership.
2. In Identity Center, select the external SAML identity-source setup and obtain
   the service-provider entity ID and ACS URL. Copy `terraform.tfvars.example` to
   `terraform.tfvars`, replace all example metadata with the actual instance,
   endpoints, explicit target AWS account and Entra operator UPNs, and retain these non-secret deployment
   choices in Git. Verify the exact gallery template and its `User` role name.
   Ensure each Entra user has given name, surname and email configured. The target
   account is explicit; it is not inferred from the Identity Center administrator's
   account, which may be a different delegated administration account.
3. Create ignored `backend.local.hcl` containing the existing Azure backend's
   `resource_group_name`, `storage_account_name` and `container_name` only. Do not
   copy a hosting/bootstrap `key` or credentials into it. Authenticate to Azure
   using the existing supported backend authentication and to AWS using the
   existing administrative context, then run from this directory:

   ```sh
   tofu init -backend-config=backend.local.hcl -backend-config=key=workforce-identity.tfstate
   tofu plan -out=workforce.tfplan
   tofu apply workforce.tfplan
   ```

   Review only the intended new identity/access resources. No cluster or hosting
   resource should appear. Keep plans/state out of Git; do not publish raw plans.
4. Open the resulting Entra enterprise application. Verify that the generated
   signing certificate thumbprint matches `tofu output -raw
   signing_certificate_thumbprint` and activate it if needed. Verify the gallery
   NameID uses `user.userprincipalname`, matching the provisioned AWS `user_name`.
   Download its Federation Metadata XML and complete AWS's external identity-source
   configuration with that metadata. This exchange is an AWS console prerequisite,
   not an automated Terraform resource.
5. In **Identity Center → Settings → Authentication → Session duration**, set
   **user interactive sessions to 90 days (129600 minutes)**. This setting is
   console-only with the supported provider/API. It is distinct from this root's
   one-hour AWS role credentials, which refresh automatically. Check whether
   Entra includes SAML `SessionNotOnOrAfter`: that can shorten the effective
   session. Apply the setting before the initial CLI sign-in.
6. Install the generated native profile from this initialized Terraform root:

   ```sh
   tofu output -raw aws_config | python3 configure_aws.py
   ```

   The installer replaces only the generated profile and its named SSO session,
   removing the obsolete `login_session` entry. Other profiles and their comments
   are preserved. It validates input before an atomic mode-0600 replacement and
   is safe to rerun after foundation updates or on a new workstation. No account,
   role, portal URL or region is copied into the installer; Terraform output owns
   those choices. It respects `AWS_CONFIG_FILE` or `--config /path/to/config`.
   Python uses only its standard library; the native `aws configure set` command
   cannot atomically replace these two sections and remove the obsolete entry.
   No credentials or tokens are installed, and no login command is run.

7. Complete initial authorization explicitly, outside deployment:

   ```sh
   aws sso login --profile model-gateway
   aws sts get-caller-identity --profile model-gateway
   # In the gitops checkout, when startup is separately authorised:
   make aks-plan
   ```

   GitOps defaults to this platform's `model-gateway` profile. Native AWS providers
   refresh cached SSO tokens and short-lived role credentials within the effective
   session lifetime. Missing/expired authorization makes lifecycle preflight stop
   before Terraform init/apply or Kubernetes teardown; it never invokes `aws login`,
   `aws sso login`, or a browser fallback. Use `AWS_PROFILE=other-profile` to select
   another native profile, or `AWS_PROFILE=` for environment/workload credentials.
   Installing profile metadata cannot establish the initial SSO session. The AWS
   console prerequisites above and that first authorization must be completed
   before a plain GitOps `make aks-up` can pass cold-start acceptance.

Tracked inputs contain the actual London instance and the exact service-provider
metadata supplied by AWS. The AWS module uses merged
[Terraform PR32](https://github.com/ai-platform-portfolio/terraform/pull/32); the
SAML module includes the dependency-order repair from Terraform PR33.
Complete and validate the prerequisites before claiming readiness.

## Infrastructure pipeline

The repository's `.github/workflows/infra.yml` validates both Terraform subroots
offline, and plans this root through a caller-owned matrix and the
shared ops-shared Terraform workflow. It passes `workforce-identity.tfstate` and
a unique `workforce-identity-plan` artifact. The Container App's image/deployment
flow stays in `portfolio.yml`, using its own root and unchanged hosting state key.

The Terraform-owned CI roles are referenced by repository variables `AWS_WORKFORCE_PLAN_ROLE_ARN` and
`AWS_WORKFORCE_APPLY_ROLE_ARN`. Match the matrix AWS region to the instance home
region. The roles trust only this repository’s immutable GitHub subjects for
`central-plan` / `central-apply`. Both can read the foundation; only apply can
write this London Identity Center instance and Identity Store. Neither can
change IAM trust or its own permissions. Bootstrap or change these CI roles once
with an existing AWS administrator, using the same root/state. The existing Azure OIDC identity also needs backend access and
Entra Graph read/application-management permissions. The workflow does not create
trust/permissions or reuse the local user's SSO session. Main pushes and manual
main dispatches apply the saved plan; PRs and manual runs on other branches only
plan.
The matrix pins the source-labelled plan revision from
[ops-shared PR31](https://github.com/ai-platform-portfolio/ops-shared/pull/31).
CI's OIDC authentication is separate from local operator SSO and does not prove
local sign-in or credential refresh.

The infrastructure workflow also runs the profile installer's standard-library
tests before any infrastructure job. Locally:

```sh
python3 -m unittest discover -s portfolio/terraform/workforce-identity -p 'test_*.py'
```

## Boundaries and acceptance

The reusable AWS module receives only native IAM actions on one named gateway
role and this account's `*.oic.prod-aks.azure.com/*` OIDC providers. New clusters
get new issuer paths, so this permission survives AKS deletion without trusting
a cluster to authenticate its own creation. The role can change its gateway role's
inline permissions/trust: this is privileged foundation authority, not a runtime
inference identity. It cannot change arbitrary IAM roles, manage Identity Center
or sign in as root. Existing GitHub OIDC/CI roles and gateway runtime ownership
remain unchanged. AWS provider region is the Identity Center home region; the CLI
workload region remains Paris.

Terraform owns the declared Identity Store users for this small portfolio. Do not
also provision them through SCIM. Changing a UPN/assignment or enabling SCIM needs
an explicit ownership/access review; no duplicate Entra users are created.

Before using the profile for startup, verify an assigned Entra user can sign in,
an unassigned user cannot, STS reports the intended assumed permission-set role,
and a read-only GitOps plan can read the required AWS resources. After the initial
role credentials expire, repeat the STS check/plan **without another SSO login** to
prove refresh. Confirm the interactive session remains configured for 90 days and
check Entra's effective SAML limit. Offline tests do not establish these outcomes.

Sign in again with `aws sso login` after the interactive session expires or is
revoked. There is no indefinite session. Before the SAML certificate expires,
rotate it with overlapping trust, update AWS metadata and test sign-in before
retiring the old certificate; automatic certificate/metadata rotation is not
implemented. Removing operator access requires revoking active sessions as well
as removing assignments. No cluster startup is triggered by this foundation.

Sources: [Entra integration](https://learn.microsoft.com/en-us/entra/identity/saas-apps/aws-single-sign-on-tutorial),
[native CLI SSO](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html),
[90-day interactive sessions](https://docs.aws.amazon.com/singlesignon/latest/userguide/user-interactive-sessions.html),
[external IdP duration limits](https://docs.aws.amazon.com/singlesignon/latest/userguide/user-session-duration-prereqs-considerations.html).
