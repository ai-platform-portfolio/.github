# AI platform portfolio

Platform engineering work focused on reusable infrastructure, reliable delivery,
and practical controls for AI-assisted development.

## Repositories

<!-- repositories:start -->
| Repository | Purpose |
| --- | --- |
| [engineering-standards](https://github.com/ai-platform-portfolio/engineering-standards) | Agent-independent working standards and executable Terraform, Python and TypeScript quality policies. |
| [engineering-acceptance](https://github.com/ai-platform-portfolio/engineering-acceptance) | Deliberately flawed and passing examples that test whether the engineering policies catch real problems. |
| [terraform-modules](https://github.com/ai-platform-portfolio/terraform-modules) | Reusable infrastructure modules, with a central deployment root for the portfolio's shared infrastructure. |
| [ops-shared](https://github.com/ai-platform-portfolio/ops-shared) | Shared CI workflows for quality checks, governance, Terraform plans and deployments, and container builds. |
| [.github](https://github.com/ai-platform-portfolio/.github) | This organisation overview and its repository catalogue automation. |
<!-- repositories:end -->

Start with **engineering-standards** for the rules, **engineering-acceptance** for
evidence of what they detect, and **terraform-modules** for the infrastructure.

Implementation and verification status belong in each repository's documentation
and pull requests; this overview does not imply that every component is deployed.
