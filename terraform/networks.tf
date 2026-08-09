resource "unifi_network" "network" {
  for_each = local.networks

  name               = each.value.name
  purpose            = "corporate" #all networks corporate - guest handled in WLAN config
  vlan               = each.value.vlan_id
  auto_scale         = false
  setting_preference = each.value.setting_preference

  # IPv4 — gateway-in-CIDR form (UniFi expects the gateway here, not the network address)
  subnet = local.network_facts[each.key].ipv4_gateway

  # IPv6 — static /64, gateway ::1, clients SLAAC
  ipv6_interface_type            = "static"
  ipv6_static_subnet             = local.network_facts[each.key].ipv6_gateway
  ipv6_client_address_assignment = "slaac"
  ipv6_ra                        = true

  # DHCP relay to Kea
  dhcp_relay = each.value.dhcp_mode == "relay" ? {
    enabled = true
    servers = [var.kea_ipv4]
  } : null
}

###############################################################################
# KNOWN-ISSUE: unifi_port_profile tagged_networkconf_ids not persisted
# -----------------------------------------------------------------------------
# The provider's inclusion field `tagged_networkconf_ids` is NOT wired to the
# go-unifi backend, so `forward = "customize"` + a tagged include-list fails at
# apply ("Provider produced inconsistent result after apply"): forward reverts
# to "all" and the tagged set reads back null, leaving resources tainted and
# unable to converge.
#
# WORKAROUND (used below): exclusion model instead of inclusion.
#   - trunks -> tagged_vlan_mgmt = "custom" + excluded_networkconf_ids
#   - access -> tagged_vlan_mgmt = "block_all" + forward = "native"
#
# Revert to the cleaner tagged_networkconf_ids include-list once fixed upstream.
#
# Our issue:    https://github.com/MattWhite-personal/Ubiquiti-Home-Network/issues/50
# Upstream ref: https://github.com/ubiquiti-community/terraform-provider-unifi/issues/245
# Provider:     ubiquiti-community/unifi v0.55.0
#######################################################
resource "unifi_port_profile" "port_profile" {
  for_each = local.port_profiles

  name        = each.key
  full_duplex = true

  forward = (
    each.value.state == "disabled" ? "disabled" :
    length(each.value.tagged_network) == 0 ? "native" : "customize"
  )

  native_networkconf_id = local.network_id[each.value.native_network]

  tagged_vlan_mgmt = length(each.value.tagged_network) == 0 ? "block_all" : "custom"

  excluded_networkconf_ids = length(each.value.tagged_network) == 0 ? null : [
    for slug in local.all_taggable_slugs :
    local.network_id[slug]
    if !contains(each.value.tagged_network, slug) && slug != each.value.native_network
  ]

  poe_mode = each.value.poe_mode
}

# Rename from the previous refactor's address to the flat slug-keyed address
moved {
  from = unifi_network.vlan["mgmt"]
  to   = unifi_network.network["mgmt"]
}
moved {
  from = unifi_network.vlan["iot"]
  to   = unifi_network.network["iot"]
}
