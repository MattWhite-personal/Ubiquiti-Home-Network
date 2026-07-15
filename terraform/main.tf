# ─────────────────────────────────────────────────────────────
# versions.tf — Terraform and provider version constraints
# ─────────────────────────────────────────────────────────────
# Bumping any version here is a deliberate change. Update via PR,
# review the changelog, and confirm `terraform plan` shows no
# unintended diffs before merging.

terraform {
  required_version = "~> 1.9"

  required_providers {
    unifi = {
      source  = "filipowm/unifi"
      version = "~> 1.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-whitefam-terraform"
    storage_account_name = "stwhitefamterraform"
    container_name       = "tfstate"
    key                  = "unifi-homelab.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}

  use_oidc = true
}

provider "unifi" {
  allow_insecure = true
}
