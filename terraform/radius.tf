resource "unifi_radius_user" "user" {
  for_each = local.radius_accounts

  name     = each.key
  password = each.value.radius_secret
  vlan     = each.value.network_slug != null ? local.network_facts[each.value.network_slug].vlan_id : null
  tunnel = {
    config_type = "802.1x"
    type        = 13 # VLAN
    medium_type = 6  # IEEE-802
  }
}
