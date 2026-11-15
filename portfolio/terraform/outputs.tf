output "url" {
  description = "Portfolio URL once DNS and the managed certificate are ready."
  value       = "https://${var.hostname}"
}
