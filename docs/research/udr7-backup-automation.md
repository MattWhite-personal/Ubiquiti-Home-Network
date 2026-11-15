# UDR7 automatic cloud backup and on-demand backup via Terraform/API

Researched 2026-11-15. No live controller was queried or changed.

## Question

Can the UDR7's UniFi OS system/cloud automatic backup settings be codified with the `ubiquiti-community/unifi` Terraform provider, and is there a supported local API to force an on-demand cloud/system backup before `terraform apply`?

## Findings

### 1. Two different backup kinds (Ubiquiti, first party)

Source: Ubiquiti Help Center, [Backups and Migration in UniFi](https://help.ui.com/hc/en-us/articles/360008976393-Backups-and-Migration-in-UniFi). Direct fetch returned HTTP 403, so this relies on the article text as returned by search for that URL; re-read it in a browser to confirm the wording.

- **System Config Backup** (console level): "include all OS, application, and device configurations", created and restored in **Settings > Control Plane > Console**; described as the most common form for Cloud Gateways and CloudKeys.
- **Cloud backup**: "If enabled, a cloud backup will be generated automatically each week and prior to each major update. Manual backups and restorations are managed in the Console's Control Plane."
- **Network application backup** (`.unf`): "UniFi Network settings and device configurations"; Ubiquiti says most users will not need these and calls them advanced methods for Gen1 CloudKey or self-hosted servers. The same article places them in **Settings > Control Plane > Backups**.

Not established: the exact current UI path/labels on a UDR7. The article text found gives both "Console" and "Backups" paths. Treat the console/cloud backup and the Network `.unf` backup as separate features.

### 2. Terraform provider: auto/cloud backup settings are NOT exposed

- [Provider v0.65.0 `unifi_setting` schema](https://github.com/ubiquiti-community/terraform-provider-unifi/blob/v0.65.0/docs/resources/setting.md) exposes no backup setting. The [provider registration](https://github.com/ubiquiti-community/terraform-provider-unifi/blob/v0.65.0/unifi/provider.go) lists no backup resource or action.
- Upstream [`go-unifi` generated `super_mgmt` fields](https://github.com/ubiquiti-community/go-unifi/blob/be9b2a2/unifi/settings/super_mgmt.generated.go#L29-L36) include automatic-backup and cloud-related names. The provider does not surface them, and nothing found establishes that they control the UniFi OS console/cloud backup.
- No `cmd/backup` or on-demand backup method found in go-unifi's hand-written (non-generated) top-level `unifi/*.go` files.

Conclusion: the regular console backup setting is not exposed by the provider as published. A provider change would not by itself establish how to manage it; a supported console API and live verification would also be needed.

### 3. On-demand backup API

- **No first-party Ubiquiti documentation was found** for a supported local API that starts an on-demand cloud/system backup. Ubiquiti's help article describes UI-based manual backups only.
- Third-party, unofficial, unsupported evidence only:
  - [brettmiller/unifi-backup](https://github.com/brettmiller/unifi-backup) README: Network backup trigger `POST /proxy/network/api/s/{site}/cmd/backup` (download `GET /proxy/network/dl/backup/{filename}`); system backup `GET /api/backup/download` ("trigger + download", `.unifi` file). Auth claims: an API key works for network backup only ("scoped to the Network application and cannot access OS-level endpoints"); system backup needs username/password login.
  - [corny gist](https://gist.github.com/corny/3cf7af0f6cb7a00adeb3): legacy controller `POST /api/s/default/cmd/backup` with `{"cmd":"backup","days":"-1"}` using a session cookie.
- These are reverse-engineered, not documented by Ubiquiti, and were not validated (no controller access by design). They describe a Network `.unf` backup or a downloaded `.unifi` file, not a confirmed *cloud* backup upload. Confirmation semantics for a cloud backup (job id, completion status, appearance in the UI account's backups) are not documented in any source found.

## Implications

- "Codify regular backup settings in Terraform": not supported by the current provider; keep it a documented manual setting (see `docs/runbooks/unifi-backup-recovery.md`).
- "Force a cloud backup before apply": no supported, documented API was found. The unofficial system download endpoint is not proof of a cloud backup and introduces admin credentials into CI. The runbook retains a manual pre-change backup check before the owner merges; it does not add an apply-approval workflow.

## Gaps

- Ubiquiti article fetch blocked (403). No UDR7-specific backup doc or UniFi OS API documentation from Ubiquiti was found.
- Nothing tested against a console.
