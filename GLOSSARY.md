# Home network recovery

Terms for recovering the UniFi-managed home network.

## Language

**UniFi system configuration backup**:
A backup of the UniFi console's operating-system, application, and device configuration.
_Avoid_: Terraform state, Network application backup

**Terraform state**:
Terraform's record of the resources it manages, separate from a UniFi system configuration backup.
_Avoid_: UniFi backup
