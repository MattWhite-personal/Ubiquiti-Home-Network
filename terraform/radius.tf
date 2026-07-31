resource "unifi_radius_user" "user" {
  for_each = local.radius_accounts

  name               = each.key
  password           = local.wifi_secrets[each.value.cred_var]
  vlan               = local.network_facts[each.value.network_slug].vlan_id
  tunnel_config_type = "802.1x"
  tunnel_type        = 13 # VLAN
  tunnel_medium_type = 6  # IEEE-802
}
