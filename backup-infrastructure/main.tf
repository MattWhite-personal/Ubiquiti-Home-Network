terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-whitefam-terraform"
    storage_account_name = "stwhitefamterraform"
    container_name       = "tfstate"
    key                  = "unifi-backup-infrastructure.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
  use_oidc            = true
  storage_use_azuread = true
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique Azure storage account name for UniFi backups."
}

variable "resource_group_name" {
  type        = string
  description = "Existing resource group for the backup account."
}

variable "location" {
  type        = string
  description = "Azure region for the backup account."
}

resource "azurerm_storage_account" "backup" {
  name                            = var.storage_account_name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  default_to_oauth_authentication = true
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"

  blob_properties {
    delete_retention_policy {
      days = 14
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "backup" {
  name                  = "unifi-backups"
  storage_account_id    = azurerm_storage_account.backup.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}
