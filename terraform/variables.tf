# ─────────────────────────────────────────────────────────────
# variables.tf — Shared inputs for the root module
# ─────────────────────────────────────────────────────────────
# Provider auth (UNIFI_API_URL, UNIFI_API_KEY, AZURE_*) is set
# via env vars in the workflow, not here. This file is only for
# variables consumed by the Terraform configuration itself
# (naming conventions, IP schemes, shared toggles).

variable "ipv4_supernet" {
  description = "IPv4 supernet within which all VLAN subnets live."
  type        = string
  sensitive   = true
}

variable "ipv6_supernet" {
  description = "IPv6 supernet delegated by ISP. Used to compute per-VLAN /64s as <prefix>:<vid>::/64."
  type        = string
  sensitive   = true
}

variable "pihole_ipv4" {
  description = "Static IPv4 of Pi-hole on the LAN. Every VLAN's DHCP scope hands this out as primary DNS."
  type        = string
  sensitive   = true
}

variable "pihole_ipv6" {
  description = "Static IPv6 of Pi-hole on VLAN 1. Every VLAN's RA advertises this as RDNSS."
  type        = string
  sensitive   = true
}

variable "common_tags" {
  description = "Tags applied to all UniFi objects that support tagging. UniFi's tag support is limited but growing."
  type        = map(string)
  default = {
    managed_by = "terraform"
    repo       = "Ubiquiti-Home-Network"
    owner      = "matt"
  }
}
