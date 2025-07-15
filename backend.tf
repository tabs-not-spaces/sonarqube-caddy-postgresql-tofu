terraform {
  backend "azurerm" {
    # Configure these values in your backend configuration or via environment variables:
    # storage_account_name = "your-terraform-storage"
    # container_name       = "terraform-state"
    # key                  = "sonarqube-stack.tfstate"
    # resource_group_name  = "your-terraform-rg"
  }
}