# Ubiquiti-Home-Network

Terraform-managed network configuration for the home lab. UDR7 + AP + future switch, applied via GitHub Actions using a self-hosted runner on the NUC.

## Architecture

- Router / gateway: UniFi Dream Router 7 (UDR7) at 192.168.178.1 during legacy transition
- AP: U7 Pro, adopted to UDR7
- DHCP / DNS: Kea + Pi-hole on the NUC — not managed by this repo
- Firewall: Zone-Based Firewall (ZBF) on UDR7 — managed here

Full network design intent documented in docs/design.md (TODO).

## How this repo runs

All Terraform runs happen in GitHub Actions, applied by the self-hosted runner on wf-cam-nuc01. Local terraform apply is not the intended workflow.

- Plan: opens automatically on every pull request
- Apply: triggers on merge to main

### Authentication

- Azure (state backend): OIDC federation from GitHub Actions to Entra ID service principal to Azure Storage
- UniFi (config target): API key from 1Password, injected via env vars at runtime

No long-lived secrets are stored in this repo or in GitHub repository secrets, beyond the 1Password service account token used to fetch everything else at runtime.

## Layout

``` plaintext
├── main.tf              # Terraform config, backend, provider blocks
├── variables.tf         # Shared input variables (marked sensitive where relevant)
├── terraform.tfvars.example
├── .github/workflows/
│   ├── runner-smoke-test.yml
│   └── terraform.yml    # plan-on-PR + apply-on-main
└── docs/
    └── design.md        # (TODO) IP scheme, VLAN plan, firewall zones
```

Domain-specific resources will land in their own .tf files as the config grows:

- networks.tf — VLAN definitions
- wifi.tf — WLAN networks + PSK references
- firewall.tf — ZBF rules
- port_profiles.tf — switch port config (once the switch arrives)

## Local development

Rarely needed. If you must:

1. az login and confirm you can access the Azure subscription that owns the state backend.
2. cp terraform.tfvars.example terraform.tfvars and fill in real values from 1Password homelab-cicd/unifi-terraform-vars.
3. export UNIFI_API_URL="<https://192.168.178.1>" and export UNIFI_API_KEY="$(op read 'op://homelab-cicd/unifi-network-local-api/credential')".
4. terraform init — resolves providers and connects to Azure Storage.
5. terraform plan — shows intended changes without applying.

Do not terraform apply locally against main's state. Push a branch, open a PR, let the runner do it. This preserves apply-audit-trail in Actions.

## Runbooks

- Rotate UniFi API key: 1Password unifi-network-local-api → regenerate in UDR7 UI → update 1Password → next workflow run picks up the new key automatically.
- Rotate 1Password service account token: covered by homelab-cicd/Runbook — Service account rotation (60-day cadence).
- Recover if state is corrupted: state versioning is enabled on the Azure Storage account; roll back via az storage blob undelete or portal.

## References

- filipowm/unifi provider
- UDR7 firmware: 10.4.57 (as of first import)
- Related repos:
  - homelab-infra — Docker Compose stacks on the NUC (including this runner)

## Change log

- 2026-07-11 — initial scaffold; UDR7 baseline imported from UI wizard.
