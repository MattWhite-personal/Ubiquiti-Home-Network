resource "unifi_network" "network" {
  for_each = local.networks

  name       = each.value.name
  purpose    = "corporate" #all networks corporate - guest handled in WLAN config
  vlan       = each.value.vlan_id
  auto_scale = false

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

resource "unifi_port_profile" "port_profile" {
  for_each = local.port_profiles

  name = each.key
  forward = (
    each.value.state == "disabled" ? "disabled" :
    length(each.value.tagged_network) == 0 ? "native" : "customize"
  )
  native_networkconf_id = local.network_id[each.value.native_network]
  tagged_networkconf_ids = [
    for slug in each.value.tagged_network : local.network_id[slug]
  ]
  excluded_networkconf_ids = [
    for slug in local.all_taggable_slugs :
    local.network_id[slug]
    if !contains(each.value.tagged_network, slug)
  ]
  tagged_vlan_mgmt = length(each.value.tagged_network) == 0 ? "block_all" : "custom"
  poe_mode         = each.value.poe_mode # now honours your locals (remember: "off", not "none")
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
