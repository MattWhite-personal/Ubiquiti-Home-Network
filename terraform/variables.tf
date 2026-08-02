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

variable "kea_ipv4" {
  description = "IPv4 of the Kea DHCP server that VLANs relay to."
  type        = string
  sensitive   = true
}

variable "networks" {
  description = "Map of managed VLANs. Key = resource address; vlan_id drives all addressing."
  type = map(object({
    vlan_id   = number
    name      = string
    purpose   = string # "corporate" | "guest"
    dhcp_mode = string # "relay" (to Kea) | "server" (UDR7 built-in) | "none"
  }))
  default = {
    mgmt = {
      vlan_id   = 999
      name      = "Management"
      purpose   = "corporate"
      dhcp_mode = "relay"
    }
    iot = {
      vlan_id   = 30
      name      = "IoT"
      purpose   = "corporate"
      dhcp_mode = "relay"
    }
  }
}

variable "wifi_guest_psk" {
  type      = string
  sensitive = true
}
variable "wifi_iot_psk" {
  type      = string
  sensitive = true
}
variable "radius_matt_work" {
  type      = string
  sensitive = true
}
variable "radius_jen_work" {
  type      = string
  sensitive = true
}
variable "radius_matt_personal" {
  type      = string
  sensitive = true
}
variable "radius_jen_personal" {
  type      = string
  sensitive = true
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
