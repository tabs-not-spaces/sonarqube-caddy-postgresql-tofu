variable "resource_group_name" {
  description = "Name of the existing resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "East US"
}

variable "container_registry_name" {
  description = "Name of the existing Azure Container Registry"
  type        = string
}

variable "managed_identity_name" {
  description = "Name of the existing managed identity with ACR pull permissions"
  type        = string
}

variable "postgresql_admin_username" {
  description = "Administrator username for PostgreSQL server"
  type        = string
  default     = "sqladmin"
}

variable "postgresql_admin_password" {
  description = "Administrator password for PostgreSQL server"
  type        = string
  sensitive   = true
}

variable "postgresql_database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "sonarqube"
}

variable "public_domain" {
  description = "Public domain for Caddy reverse proxy"
  type        = string
  default     = "sonarqube.local"
}

variable "environment" {
  description = "Environment name for resource naming"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "sonarqube"
}

variable "sonarqube_cpu" {
  description = "CPU allocation for SonarQube container"
  type        = number
  default     = 2
}

variable "sonarqube_memory" {
  description = "Memory allocation for SonarQube container in GB"
  type        = number
  default     = 4
}

variable "caddy_cpu" {
  description = "CPU allocation for Caddy container"
  type        = number
  default     = 0.5
}

variable "caddy_memory" {
  description = "Memory allocation for Caddy container in GB"
  type        = number
  default     = 1
}

variable "log_analytics_retention_days" {
  description = "Log Analytics workspace retention in days"
  type        = number
  default     = 30
}