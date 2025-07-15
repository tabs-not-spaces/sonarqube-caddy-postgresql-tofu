# SonarQube + Caddy + PostgreSQL on Azure with OpenTofu

This OpenTofu configuration deploys a SonarQube stack to Azure using Azure Container Instances, Azure PostgreSQL Flexible Server, and includes monitoring through Log Analytics.

## Architecture

- **Azure Container Instance Group**: Runs SonarQube and Caddy containers
- **Azure PostgreSQL Flexible Server**: Database for SonarQube
- **Log Analytics Workspace**: Monitors container logs and metrics
- **Azure Container Registry**: Existing registry with SonarQube and Caddy images
- **Managed Identity**: For secure ACR image pulling

## Prerequisites

1. **Existing Azure Resources:**
   - Resource Group
   - Azure Container Registry with images:
     - `powershell.azurecr.io/sonarqube:community`
     - `powershell.azurecr.io/caddy:latest`
   - Managed Identity with `AcrPull` role on the Container Registry

2. **OpenTofu/Terraform:**
   - OpenTofu 1.8+ or Terraform 1.5+
   - Azure CLI configured or service principal authentication

## Deployment Steps

1. **Configure Backend** (optional but recommended):
   ```bash
   # Edit backend.tf with your storage account details
   # Or use environment variables:
   export ARM_STORAGE_ACCOUNT_NAME="your-terraform-storage"
   export ARM_CONTAINER_NAME="terraform-state"
   export ARM_KEY="sonarqube-stack.tfstate"
   export ARM_RESOURCE_GROUP_NAME="your-terraform-rg"
   ```

2. **Copy and Configure Variables:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

3. **Initialize and Deploy:**
   ```bash
   tofu init
   tofu plan
   tofu apply
   ```

## Configuration

### Required Variables (terraform.tfvars)

```hcl
resource_group_name     = "your-existing-resource-group"
container_registry_name = "your-existing-acr"
managed_identity_name   = "your-existing-managed-identity"
postgresql_admin_password = "YourSecurePassword123!"
public_domain = "your-domain.com"
```

### Optional Variables

See `variables.tf` for all available options including:
- Resource sizing (CPU/Memory)
- PostgreSQL configuration
- Log Analytics retention
- Environment and project naming

## Outputs

After deployment, you'll get:
- **Public IP**: Direct access to the container instance
- **FQDN**: Azure-generated domain name
- **SonarQube URL**: HTTP access via public IP
- **HTTPS URL**: Custom domain access (requires DNS configuration)

## Post-Deployment

1. **Configure DNS**: Point your domain to the public IP address
2. **Access SonarQube**: Navigate to the provided URL
3. **Initial Setup**: Complete SonarQube initial configuration
4. **Monitor Logs**: Check Log Analytics workspace for container logs

## Container Images

The configuration uses the same container images as the docker-compose setup:
- SonarQube: `powershell.azurecr.io/sonarqube:community`
- Caddy: `powershell.azurecr.io/caddy:latest`

## Monitoring

Container logs and metrics are automatically sent to the Log Analytics workspace. You can create dashboards and alerts in Azure Monitor.

## Security

- PostgreSQL uses SSL/TLS connections
- Container Registry authentication via managed identity
- Firewall rules configured for Azure services

## Troubleshooting

1. **Container fails to start**: Check Log Analytics for container logs
2. **Database connection issues**: Verify PostgreSQL firewall rules
3. **Image pull errors**: Ensure managed identity has ACR pull permissions
4. **Memory issues**: Increase container memory allocation in variables
5. **Container restart loops**: Containers are configured with restart policy "Never" to prevent automatic restarts on failure. Check Log Analytics workspace for detailed logs to diagnose startup issues.

## Cleanup

```bash
tofu destroy
```

This will remove all created resources but preserve the existing resource group, ACR, and managed identity.