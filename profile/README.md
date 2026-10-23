# AI platform portfolio

An Azure AKS platform portfolio focused on reusable infrastructure, federated
GitOps and independent cluster reconciliation. Terraform provisions infrastructure
and installs Argo CD; shared Helm charts define the platform packages reconciled
by each cluster. Reusable GitHub Actions workflows support validation and issue
traceability across the implementation repositories.

Start with [GitOps](https://github.com/ai-platform-portfolio/gitops) for the platform
architecture and lifecycle, or the
[Terraform library](https://github.com/ai-platform-portfolio/terraform) for reusable
Azure modules. The configuration is validated offline; live deployment and
multi-cluster failure testing remain outstanding.

<!-- repositories:start -->
| Repository | Purpose |
| --- | --- |
| [.github](https://github.com/ai-platform-portfolio/.github) | Organisation overview and repository catalogue for the AI platform portfolio |
| [gitops](https://github.com/ai-platform-portfolio/gitops) | Federated Argo CD platform configuration for Azure AKS, with reusable Helm charts, Terraform bootstrap and independent cluster reconciliation. |
| [kiro](https://github.com/ai-platform-portfolio/kiro) | Kiro AI session context for the ai-platform-portfolio org — architecture decisions, conventions, network topology, and build spec |
| [ops-shared](https://github.com/ai-platform-portfolio/ops-shared) | Reusable GitHub Actions workflow templates |
| [terraform](https://github.com/ai-platform-portfolio/terraform) | Reusable Terraform modules organised by provider |
<!-- repositories:end -->
