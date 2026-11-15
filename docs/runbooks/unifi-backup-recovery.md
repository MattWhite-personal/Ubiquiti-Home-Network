# UniFi Backup and Physical Recovery Runbook

## Scope and current verification status

This runbook covers the UDR7 UniFi console and its managed network configuration. It is separate from Terraform state recovery: a UniFi backup does not replace Terraform state, and Terraform state does not contain a restorable console backup.

**Backup status: not verified.** No controller access, backup file, or restore test was available while preparing this runbook. Do not treat the existence of this document, a configured cloud backup option, or a downloaded file as proof that a backup can be restored. Complete the verification checklist below from the console before relying on a backup.

## Before a planned network change

1. Schedule the change for a time when an outage is acceptable. Keep the owner available to authorize a restore or other disruptive action.
2. Confirm local physical access to the UDR7, its power source, WAN connection, and downstream network cabling. Have a charged wired computer and working Ethernet cable available; do not depend on Wi-Fi for recovery.
3. Confirm the owner can sign in to the UniFi console and to the approved encrypted storage location for backups.
4. Create and verify a current console backup using the procedure below.
5. Review the Terraform plan before merge. Changes to `main` can trigger the repository's Terraform apply workflow; do not run a separate local apply against the shared backend.

## Create and non-destructively verify a console backup

Use the console's supported backup controls. Ubiquiti's current backup and migration guidance describes system configuration backups under **Settings > Control Plane > Backups**. Labels may differ by UniFi OS version; follow the current on-screen instructions and the linked Ubiquiti guide.

1. Sign in to the UDR7 as an owner/admin and open **Settings > Control Plane > Backups**.
2. Check that automatic cloud backups are enabled in the console's backup settings; enable them if needed. Ubiquiti says that, when enabled, cloud backups are generated weekly and before major updates. Check the backup history and most recent timestamp; enabling the setting alone does not establish that a backup exists.
3. Before the change, create a new system configuration backup using the console controls and use **Download** to save a local copy. Do not substitute a Network-only application export when a full console/system configuration backup is intended.
4. Save the downloaded file to the owner's approved encrypted storage, outside this repository. Restrict access to people who need it. Do not commit it, attach it to a pull request, or put it in an unencrypted/shared location.
5. From the storage location, confirm that the expected file is present and can be read/downloaded by the owner. Record its generation time, console/UniFi OS version, file name, size, and SHA-256 hash in the owner's protected operational record. A hash can identify later file changes; it does not prove that the backup contents are valid or restorable.
6. Record whether an automatic cloud backup is enabled and its most recent timestamp. Treat it as an additional copy, not the only copy.

The current Terraform provider does not expose the console backup setting, and no supported API to initiate and confirm a cloud backup before apply was found. The apply workflow does **not** create or verify a backup; the owner must complete these checks before merging a network change. See [backup automation research](../research/udr7-backup-automation.md).

These checks establish only that the console reported a backup and that a file was downloaded and can be retrieved. They do **not** verify the file's contents or successful restoration. Do not upload the backup to an unapproved service or attempt to unpack/edit it. A restoration test requires a compatible spare/replacement console and explicit owner authorization; it is not part of this runbook's non-destructive verification and has not been performed.

### Verification record

Keep the completed record in approved protected storage, not in Git:

| Item | Record |
| --- | --- |
| Console model and UniFi OS version | |
| Backup generation date/time | |
| Local file name and size | |
| SHA-256 hash | |
| Encrypted storage location (name only) | |
| Download/read-back checked by and date | |
| Restore test | Not performed unless separately authorized and recorded |

## Physical recovery

### Expected impact

The UDR7 is the gateway and UniFi console. Rebooting or restoring it can interrupt Internet access, wired routing, Wi-Fi, VLAN connectivity, and management of adopted devices. Network services hosted elsewhere may also become unreachable if their VLAN or route depends on the gateway. A console restore or factory reset can require downstream devices to reconnect or be adopted again. Allow for a complete network outage until the gateway and required services are confirmed healthy.

### Recovery sequence

1. **Get local and owner access.** Have the owner present or reachable, console credentials available, and a wired computer connected to a LAN port. Record the current cable positions and visible device status before changing connections.
2. **Check without changing configuration.** Verify power, WAN/link cabling, and visible status indicators against the device documentation. Check whether the ISP connection and other network equipment have power. Do not move multiple cables or power-cycle multiple devices at once.
3. **Use a normal reboot only when authorized.** If the console is unresponsive and the owner approves, use the normal documented reboot method and wait for startup to complete before taking another action. Do not press or hold the physical reset button as a reboot method.
4. **Restore only with explicit owner authorization.** Prefer restoring a known-good system configuration backup to a compatible replacement console.
   - Set up the replacement using Ubiquiti's current instructions. Restore the backup when prompted during setup, or afterwards from **Settings > Control Plane > Backups > Restore**.
   - Keep the original console powered off and its configuration untouched until the replacement is confirmed operational. Do not connect two gateways into the same topology unless the owner has planned that cabling.
   - Allow for the replacement to restart, then perform the service checks below. Keep downstream devices connected as before unless the replacement instructions or owner-approved topology require otherwise.
5. **Factory reset is destructive and a last resort.** A factory reset removes local configuration and can increase downtime. Do not reset the live UDR7 unless the owner explicitly authorizes it, accepts the outage, and has confirmed an accessible backup or chosen a deliberate rebuild. Follow the exact instructions for the device and firmware version, then restore the backup during setup if appropriate.
6. **Recovery Mode is the final escalation.** Ubiquiti describes Recovery Mode as a last resort when a normal reboot and factory reset do not resolve an unresponsive device. It requires the correct device firmware and a wired recovery procedure. Confirm the model-specific official instructions before starting; do not improvise firmware, ports, addresses, or button timing.
7. **Validate service before ending the outage.** With the owner, confirm gateway/Internet access, wired connectivity, expected Wi-Fi, DHCP/DNS, and access to required VLANs. Confirm adopted UniFi devices are online. Review Terraform drift before any subsequent apply; a Terraform apply may change manually restored settings to match repository configuration.

### Roll back a managed change

If a Terraform change causes an outage or unexpected behavior, stop queued or concurrent Terraform runs and preserve the plan/apply output. If the console is reachable, prefer a reviewed revert of the offending repository change: merges to `main` can trigger another apply, so inspect its plan and coordinate with the owner before merging. Do not use a console restore as a shortcut for rolling back Terraform; Terraform may reapply the repository configuration. If a console restore is still necessary, get explicit owner authorization, account for the outage described above, and review the resulting Terraform plan before any apply.

If recovery does not proceed as expected, stop before a reset, firmware recovery, or repeated power cycle. Preserve the original hardware, downloaded backup, cabling notes, and error/status information, then consult Ubiquiti support or the owner.

## Terraform state recovery is separate

The Terraform backend configured in `terraform/main.tf` is the Azure Blob `tfstate` container and `unifi-homelab.tfstate` key. The existing README identifies Azure Storage blob versioning as a possible state-recovery mechanism, but this repository does not establish that versioning, retention, and access are currently enabled or tested. Verify those settings in Azure before relying on a prior version.

If Terraform state recovery is needed:

1. Stop other Terraform runs and coordinate a maintenance window so the shared state is not being written.
2. Identify and preserve the current blob and the exact candidate version before changing anything. Treat state and exported state files as sensitive.
3. Have the authorized Azure operator restore the intended blob version using the verified Azure procedure. Do not use a UniFi console backup to replace Terraform state.
4. Initialize Terraform with the configured backend and run a read-only plan. Review the result against the live UniFi configuration before any apply. Do not apply until the owner has reviewed and authorized the plan.

## References

- [Ubiquiti: Backups and Migration in UniFi](https://help.ui.com/hc/en-us/articles/360008976393-Backups-and-Migration-in-UniFi)
- [Ubiquiti: How to Reset UniFi Devices to Factory Defaults](https://help.ui.com/hc/en-us/articles/205143490-How-to-Reset-UniFi-Devices-to-Factory-Defaults)
- [Ubiquiti: UniFi Recovery Mode](https://help.ui.com/hc/en-us/articles/360043360253-UniFi-Recovery-Mode)
- Repository Terraform backend: `terraform/main.tf`
- Existing state recovery note: `README.md`
