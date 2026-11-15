# AI platform portfolio

A platform engineering portfolio by **Michaela Links**, exploring reusable Azure
infrastructure, GitOps delivery and AI applications.

Start with [GitOps](https://github.com/ai-platform-portfolio/gitops) for the
architecture and disposable AKS lifecycle. Follow the layers through reusable
[Terraform modules](https://github.com/ai-platform-portfolio/terraform),
[application Helm templates](https://github.com/ai-platform-portfolio/application-helm-chart)
and composable [CI workflows](https://github.com/ai-platform-portfolio/ops-shared).
Applications supply code and intent; shared templates own the delivery wiring.

The AKS environment is brought online for development and demonstrations, then
torn down to control costs. Its source remains available for review at any time.
The [portfolio website](https://portfolio.dev.michaelalinks.com) is being prepared
with a live cluster-status view and independent Azure Container Apps hosting;
**its first deployment is pending**. Cluster power state does not imply that
every application is healthy.

<!-- repositories:start -->
| Repository | Purpose |
| --- | --- |
| [.github](https://github.com/ai-platform-portfolio/.github) | Organisation overview and repository catalogue for the AI platform portfolio |
| [gitops](https://github.com/ai-platform-portfolio/gitops) | Federated Argo CD platform configuration for Azure AKS, with reusable Helm charts, Terraform bootstrap and independent cluster reconciliation. |
| [kiro](https://github.com/ai-platform-portfolio/kiro) | Kiro AI session context for the ai-platform-portfolio org — architecture decisions, conventions, network topology, and build spec |
| [ops-shared](https://github.com/ai-platform-portfolio/ops-shared) | Reusable GitHub Actions workflow templates |
| [terraform](https://github.com/ai-platform-portfolio/terraform) | Reusable Terraform modules organised by provider |
<!-- repositories:end -->
