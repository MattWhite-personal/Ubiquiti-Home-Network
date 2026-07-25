resource "unifi_firewall_zone" "hotspot" {
  name         = "Hotspot"
  default_zone = true
  network_ids = [
    unifi_network.network["guest"].id
  ]
}

resource "unifi_firewall_zone" "mjw-test" {
  name = "MJW Test"
}
