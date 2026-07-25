# resource "unifi_network" "lan_network" {
#  name                           = "Management"
#  purpose                        = "corporate"
#  subnet                         = "10.140.254.1/24"
#  vlan                           = 999
#  ipv6_interface_type            = "static"
#  ipv6_static_subnet             = "2a02:8011:ee07:999::1/64"
#  ipv6_client_address_assignment = "slaac"
#  ipv6_ra                        = true
#  dhcp_relay = {
#    enabled = true
#    servers = ["192.168.178.14"]
#  }
#  #dhcp_guarding = {
#  #  enabled = true
#  #  servers = ["192.168.178.14"]
#  #}
#
# }

resource "unifi_network" "vlan" {
  for_each = local.networks_computed

  name    = each.value.name
  purpose = each.value.purpose

  subnet = each.value.ipv4_gateway
  vlan   = each.value.vlan_id

  # DHCP — relay to Kea, or UDR7 built-in, or off
  dhcp_relay = each.value.dhcp_mode == "relay" ? {
    enabled = true
    servers = [var.kea_ipv4]
  } : null

  dhcp_enabled = each.value.dhcp_mode == "server"

  # IPv6 — SLAAC via RA from the WAN-delegated /48
  ipv6_interface_type            = "static"
  ipv6_static_subnet             = each.value.ipv6_gateway
  ipv6_client_address_assignment = "slaac"
  ipv6_ra_enable                 = true
}

moved {
  from = unifi_network.lan_network
  to   = unifi_network.vlan["mgmt"]
}
