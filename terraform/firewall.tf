resource "unifi_firewall_zone" "hotspot" {
  name         = "Hotspot"
  default_zone = true
}

resource "unifi_firewall_zone" "mjw-test" {
  name = "MJW Test"
}
