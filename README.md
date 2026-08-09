# Ubiquiti-Home-Network

Terraform-managed UniFi network configuration for the White family home network.

This repository manages UniFi configuration for a UDR7-based home network, including VLANs, WLANs, firewall rules, and RADIUS-enabled wireless authentication. Terraform state is stored in Azure Blob Storage and changes are applied through GitHub Actions on a self-hosted homelab runner.

## What this repo manages

- UniFi Dream Router 7 (UDR7) configuration
- VLAN definitions and IP addressing
- Wireless network profiles and PSK/RADIUS settings
- Zone-based firewall rules
- UniFi object tagging and device configuration

## What this repo does not manage

- NUC-hosted DHCP/DNS services (Kea + Pi-hole)
- Physical switch inventory or port profile configuration yet
- Local UniFi controller installation

## Architecture

- Router / gateway: UniFi Dream Router 7 (UDR7)
- Access point: U7 Pro adopted into the UDR7
- Terraform backend: Azure Storage blob in `rg-whitefam-terraform`, container `tfstate`, key `unifi-homelab.tfstate`
- CI/CD: GitHub Actions on a self-hosted runner tagged `[self-hosted, homelab, ubiquiti]`
- Providers:
  - `ubiquiti-community/unifi` `0.55.0`
  - `hashicorp/azurerm` `~> 4.0`
- Terraform required version: `~> 1.9`

## Repository layout

```plaintext
.
├── .github/workflows/
│   ├── tf-plan-apply.yml
│   ├── tf-drift.yml
│   ├── tf-import.yml
│   ├── tf-unit-tests.yml
│   └── runner-smoketest.yml
├── LICENSE
├── README.md
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── output.tf
    ├── networks.tf
    ├── wlan.tf
    ├── firewall.tf
    ├── radius.tf
    ├── devices.tf
    ├── locals_network.tf
    ├── locals_wifi.tf
    ├── data.tf
    └── .terraform.lock.hcl
```

- `terraform/main.tf` configures the backend, required providers, and root module.
- `terraform/variables.tf` declares the shared network inputs and sensitive values.
- `terraform/output.tf` exposes computed network facts.
- `terraform/networks.tf`, `wlan.tf`, `firewall.tf`, and `radius.tf` define the UniFi-managed network objects.

## Workflow

- Pull requests to `main` run `terraform plan`.
- Merges to `main` run `terraform apply`.
- The workflow uses GitHub Actions, a self-hosted runner, and 1Password to inject secrets at runtime.

### Secrets and authentication

- Azure backend authentication is done via OIDC and GitHub secrets:
  - `AZURE_CLIENT_ID`
  - `AZURE_SUBSCRIPTION_ID`
  - `AZURE_TENANT_ID`
- 1Password service account token is stored in `OP_SERVICE_ACCOUNT_TOKEN`.
- The workflow loads UniFi and Terraform values from 1Password:
  - `UNIFI_API`
  - `UNIFI_API_KEY`
  - `TF_VAR_*` values for IP addressing and Wi-Fi credentials
- No long-lived UniFi API credentials are stored in the repo.

## Local development

Local `terraform apply` is not the intended workflow. Prefer the GitHub Actions path for all changes.

If you need to inspect or plan locally:

1. Log in to Azure and verify access to the storage backend.
2. Populate a local `terraform.tfvars` with secrets from 1Password.
3. Set `UNIFI_API_URL` and `UNIFI_API_KEY` locally.
4. In `terraform/`, run:
   - `terraform init`
   - `terraform fmt -check`
   - `terraform plan`

Avoid running `terraform apply` locally against the shared backend unless you fully understand the state coordination risks.

## Notes

- The backend is configured in `terraform/main.tf` with Azure storage account `stwhitefamterraform`.
- The UniFi provider is configured with `allow_insecure = true` to support self-signed or locally trusted controller certificates.
- Network addressing is derived from the `ipv4_supernet` and `ipv6_supernet` inputs.

## Runbook

- Rotate UniFi API key: regenerate in UDR7, update 1Password, and let the workflow pick up the new key.
- Rotate 1Password service account token: update `OP_SERVICE_ACCOUNT_TOKEN` in GitHub secrets.
- Recover corrupted state: use Azure Storage versioning to restore the blob if needed.

## References

- Ubiquiti Terraform provider: `ubiquiti-community/unifi`
- Azure Terraform provider: `hashicorp/azurerm`
- Self-hosted runner and 1Password secrets injection pattern

## Changelog

- 2026-07-11 — initial scaffold; UDR7 baseline imported from UI wizard.
