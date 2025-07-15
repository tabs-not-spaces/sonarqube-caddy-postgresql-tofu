# Data sources for existing resources
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_container_registry" "main" {
  name                = var.container_registry_name
  resource_group_name = data.azurerm_resource_group.main.name
}

data "azurerm_user_assigned_identity" "main" {
  name                = var.managed_identity_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# Random password for PostgreSQL if not provided
resource "random_password" "postgresql_password" {
  count   = var.postgresql_admin_password == "" ? 1 : 0
  length  = 16
  special = true
}

locals {
  postgresql_password = var.postgresql_admin_password != "" ? var.postgresql_admin_password : random_password.postgresql_password[0].result
}

# Log Analytics Workspace for monitoring
resource "azurerm_log_analytics_workspace" "main" {
  name                = "${var.project_name}-${var.environment}-logs"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = "${var.project_name}-${var.environment}-psql-${random_id.postgresql_suffix.hex}"
  resource_group_name    = data.azurerm_resource_group.main.name
  location               = data.azurerm_resource_group.main.location
  version                = "13"
  zone                   = 1
  administrator_login    = var.postgresql_admin_username
  administrator_password = local.postgresql_password

  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false

  public_network_access_enabled = true

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# PostgreSQL database
resource "azurerm_postgresql_flexible_server_database" "sonarqube" {
  name      = var.postgresql_database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# Firewall rule to allow Azure services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Storage Account for SonarQube and Caddy
resource "azurerm_storage_account" "sonarqube" {
  name                     = "${substr(var.project_name, 0, 11)}${var.environment}sa${random_id.storage_suffix.hex}"
  resource_group_name      = data.azurerm_resource_group.main.name
  location                 = data.azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# SonarQube storage shares
resource "azurerm_storage_share" "sonarqube_conf" {
  name               = "conf"
  storage_account_id = azurerm_storage_account.sonarqube.id
  quota              = 5 # 5GB for configuration
}

resource "azurerm_storage_share" "sonarqube_data" {
  name               = "data"
  storage_account_id = azurerm_storage_account.sonarqube.id
  quota              = 50 # 50GB for data
}

resource "azurerm_storage_share" "sonarqube_logs" {
  name               = "logs"
  storage_account_id = azurerm_storage_account.sonarqube.id
  quota              = 10 # 10GB for logs
}

resource "azurerm_storage_share" "sonarqube_extensions" {
  name               = "extensions"
  storage_account_id = azurerm_storage_account.sonarqube.id
  quota              = 5 # 5GB for extensions/plugins
}

# Caddy storage shares
resource "azurerm_storage_share" "caddy_config" {
  name               = "caddy-config"
  storage_account_id = azurerm_storage_account.sonarqube.id
  quota              = 5 # 5GB for Caddy configuration
}

resource "azurerm_storage_share" "caddy_data" {
  name               = "caddy-data"
  storage_account_id = azurerm_storage_account.sonarqube.id
  quota              = 5 # 5GB for Caddy data (certificates, etc.)
}

# Upload sonar.properties file to the conf share
resource "azurerm_storage_share_file" "sonar_properties" {
  name                 = "sonar.properties"
  storage_share_id     = azurerm_storage_share.sonarqube_conf.url
  source               = "${path.module}/sonar.properties"

  depends_on = [azurerm_storage_share.sonarqube_conf]
}

# Upload Caddyfile to the Caddy config share
resource "azurerm_storage_share_file" "caddyfile" {
  name                 = "Caddyfile"
  storage_share_id     = azurerm_storage_share.caddy_config.url
  source               = "${path.module}/Caddyfile"

  depends_on = [azurerm_storage_share.caddy_config]
}

# Random suffix for storage account naming
resource "random_id" "storage_suffix" {
  byte_length = 4
}

# Container Instance Group
resource "azurerm_container_group" "main" {
  name                = "${var.project_name}-${var.environment}-aci"
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  ip_address_type     = "Public"
  dns_name_label      = "${var.project_name}-${var.environment}-${random_password.dns_suffix.result}"
  os_type             = "Linux"
  restart_policy      = "Never"

  # SonarQube container
  container {
    name   = "sonarqube"
    image  = "${data.azurerm_container_registry.main.login_server}/sonarqube:community"
    cpu    = var.sonarqube_cpu
    memory = var.sonarqube_memory

    ports {
      port     = 9000
      protocol = "TCP"
    }

    environment_variables = {
      SONAR_JDBC_URL                  = "jdbc:postgresql://${azurerm_postgresql_flexible_server.main.fqdn}:5432/${var.postgresql_database_name}?sslmode=require"
      SONAR_JDBC_USERNAME             = var.postgresql_admin_username
      SONAR_WEB_HOST                  = "0.0.0.0"
      SONAR_WEB_PORT                  = "9000"
      SONAR_SEARCH_JAVAADDITIONALOPTS = "-Dnode.store.allow_mmap=false"
      SONAR_LOG_LEVEL                 = "INFO"
      SONAR_LOG_JSONOUTPUT            = "true"
    }

    secure_environment_variables = {
      SONAR_JDBC_PASSWORD = local.postgresql_password
    }

    volume {
      name                 = "sonarqube-conf"
      mount_path           = "/opt/sonarqube/conf"
      read_only            = false
      storage_account_name = azurerm_storage_account.sonarqube.name
      storage_account_key  = azurerm_storage_account.sonarqube.primary_access_key
      share_name           = azurerm_storage_share.sonarqube_conf.name
    }

    volume {
      name                 = "sonarqube-data"
      mount_path           = "/opt/sonarqube/data"
      read_only            = false
      storage_account_name = azurerm_storage_account.sonarqube.name
      storage_account_key  = azurerm_storage_account.sonarqube.primary_access_key
      share_name           = azurerm_storage_share.sonarqube_data.name
    }

    volume {
      name                 = "sonarqube-logs"
      mount_path           = "/opt/sonarqube/logs"
      read_only            = false
      storage_account_name = azurerm_storage_account.sonarqube.name
      storage_account_key  = azurerm_storage_account.sonarqube.primary_access_key
      share_name           = azurerm_storage_share.sonarqube_logs.name
    }

    volume {
      name                 = "sonarqube-extensions"
      mount_path           = "/opt/sonarqube/extensions"
      read_only            = false
      storage_account_name = azurerm_storage_account.sonarqube.name
      storage_account_key  = azurerm_storage_account.sonarqube.primary_access_key
      share_name           = azurerm_storage_share.sonarqube_extensions.name
    }
  }

  # Caddy container
  container {
    name   = "caddy"
    image  = "${data.azurerm_container_registry.main.login_server}/caddy:latest"
    cpu    = var.caddy_cpu
    memory = var.caddy_memory

    ports {
      port     = 80
      protocol = "TCP"
    }

    ports {
      port     = 443
      protocol = "TCP"
    }

    environment_variables = {
      PUBLIC_DOMAIN   = var.public_domain
      CADDY_LOG_LEVEL = "INFO"
    }

    volume {
      name                 = "caddy-config"
      mount_path           = "/etc/caddy"
      read_only            = false
      storage_account_name = azurerm_storage_account.sonarqube.name
      storage_account_key  = azurerm_storage_account.sonarqube.primary_access_key
      share_name           = azurerm_storage_share.caddy_config.name
    }

    volume {
      name                 = "caddy-data"
      mount_path           = "/data"
      read_only            = false
      storage_account_name = azurerm_storage_account.sonarqube.name
      storage_account_key  = azurerm_storage_account.sonarqube.primary_access_key
      share_name           = azurerm_storage_share.caddy_data.name
    }
  }

  # Use managed identity for ACR authentication
  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.main.id]
  }

  image_registry_credential {
    server                    = data.azurerm_container_registry.main.login_server
    user_assigned_identity_id = data.azurerm_user_assigned_identity.main.id
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Random suffixes for unique naming
resource "random_password" "dns_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_id" "postgresql_suffix" {
  byte_length = 4
}

# Diagnostic setting for container group logs
resource "azurerm_monitor_diagnostic_setting" "container_group" {
  name                       = "${azurerm_container_group.main.name}-diagnostics"
  target_resource_id         = azurerm_container_group.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "ContainerInstanceLog"
  }

  enabled_log {
    category = "ContainerEvent"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
