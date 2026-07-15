resource "unifi_network" "lan_network" {
  name         = "Management"
  purpose      = "corporate"
  subnet       = "10.140.254.0/24"
  vlan_id      = 999
  dhcp_enabled = false
  enabled      = true
  #ipv6_interface_type = "pd"
  #ipv6_pd_interface   = "wan"
  #ipv6_ra_enable      = "true"
}
