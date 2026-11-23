resource "azuread_application_owner" "telemetry_ci_publisher" {
  application_id  = "/applications/${var.telemetry_api_object_id}"
  owner_object_id = var.ci_publisher.principal_id
}

resource "azuread_application_app_role" "telemetry_query" {
  application_id = azuread_application_owner.telemetry_ci_publisher.application_id
  role_id        = "25b3bb97-a1fe-487c-9c52-4ae0d5fa7574"

  allowed_member_types = ["Application"]
  description          = "Call the private telemetry query API."
  display_name         = "Telemetry Query"
  value                = "Telemetry.Query"
}
