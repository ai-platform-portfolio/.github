# Persistent workforce identity

Entra-backed AWS operator access for local GitOps bootstrap, independent of AKS
and the portfolio Container App. This root owns a new gallery SAML application,
its signing certificate/Entra assignments, explicitly provisioned Identity Store
users and one scoped AWS permission set/account assignment. It uses reusable
modules from the Terraform library. It creates no IAM user, access key, SCIM
provisioning token, credential helper or deployment runner.

| Root | State key | Lifecycle |
| --- | --- | --- |
| `portfolio/terraform` | `portfolio-hosting.tfstate` | Container App hosting |
| `foundations/workforce-identity` | `workforce-identity.tfstate` | Persistent operator authentication |
| GitOps `bootstrap` | Existing bootstrap key | Disposable platform |

Use the existing persistent Azure backend account/container with a separate key.
Neither `gitops make down` nor a hosting-root destroy traverses this root. Do not
destroy this foundation as part of application teardown. No existing account,
Identity Center instance, registration or CI role is adopted by this code.

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
6. Review `tofu output -raw aws_config` and merge those two sections into
   `~/.aws/config`. Replace the old `model-gateway` profile's `login_session` entry;
   keep unrelated profiles. Do not write credential values into the profile.

   ```sh
   aws sso login --profile model-gateway
   aws sts get-caller-identity --profile model-gateway
   # In the gitops checkout, when startup is separately authorised:
   AWS_PROFILE=model-gateway make aks-plan
   ```

The source currently contains example inputs, not live instance metadata, and is
not deployed. Both shared modules are pinned to the verified merge revision of
[Terraform PR32](https://github.com/ai-platform-portfolio/terraform/pull/32).
Complete and validate the prerequisites before claiming readiness.

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
as removing assignments. No automatic startup, merge or deployment is authorised
by this root or its offline validation workflow.

Sources: [Entra integration](https://learn.microsoft.com/en-us/entra/identity/saas-apps/aws-single-sign-on-tutorial),
[native CLI SSO](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html),
[90-day interactive sessions](https://docs.aws.amazon.com/singlesignon/latest/userguide/user-interactive-sessions.html),
[external IdP duration limits](https://docs.aws.amazon.com/singlesignon/latest/userguide/user-session-duration-prereqs-considerations.html).
