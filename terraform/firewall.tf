resource "unifi_firewall_zone" "hotspot" {
  name = "Hotspot"
  #default_zone = true

}

resource "unifi_firewall_zone" "zone" {
  for_each    = local.zone_membership
  name        = title(each.key) # "Trusted", "Iot", "Guest"
  network_ids = [for slug in each.value : unifi_network.network[slug].id]
}
