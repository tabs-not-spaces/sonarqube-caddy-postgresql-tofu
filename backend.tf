terraform {
  backend "azurerm" {
    subscription_id      = "7e53aadb-8bf2-4e2d-a7cb-5c26586323cc"
    resource_group_name  = "sonarqube-test"
    storage_account_name = "opentofuconfig"
    container_name       = "opentofuconfig"
    key                  = "sonarqube.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = "7e53aadb-8bf2-4e2d-a7cb-5c26586323cc"
}