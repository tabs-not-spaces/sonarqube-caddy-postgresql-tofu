output "public_ip_address" {
  description = "Public IP address of the container instance"
  value       = azurerm_container_group.main.ip_address
}

output "fqdn" {
  description = "Fully qualified domain name of the container instance"
  value       = azurerm_container_group.main.fqdn
}

output "sonarqube_url" {
  description = "URL to access SonarQube (via public IP)"
  value       = "http://${azurerm_container_group.main.ip_address}"
}

output "caddy_https_url" {
  description = "HTTPS URL if using custom domain with Caddy"
  value       = "https://${var.public_domain}"
}

output "postgresql_server_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgresql_connection_string" {
  description = "PostgreSQL connection string for SonarQube"
  value       = "jdbc:postgresql://${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.postgresql_database_name}?sslmode=require"
  sensitive   = false
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "resource_group_name" {
  description = "Name of the resource group"
  value       = data.azurerm_resource_group.main.name
}

output "container_group_name" {
  description = "Name of the container group"
  value       = azurerm_container_group.main.name
}