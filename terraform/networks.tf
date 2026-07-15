resource "unifi_network" "lan_network" {
  name    = "Management"
  purpose = "corporate"
  subnet  = "10.140.254.1/24"
  vlan    = 999
  dhcp_relay = {
    enabled = true
    servers = ["192.168.178.14"]
  }
  dhcp_guarding = {
    enabled = true
    servers = ["192.168.178.14"]
  }
  ipv6_interface_type            = "static"
  ipv6_static_subnet             = "2a02:8011:ee07:999::/64"
  ipv6_client_address_assignment = "slaac"
  ipv6_ra                        = true
}
