# One-time adoption of the existing cleanup job; remove after the first apply.
# This is migration metadata for this host, not a reusable module dependency.
import {
  to = module.application.azurerm_container_app_job.this["preview-cleanup"]
  id = "${azurerm_resource_group.portfolio.id}/providers/Microsoft.App/jobs/${var.application.name}-preview-cleanup"
}
