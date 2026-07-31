resource "unifi_radius_user" "user" {
  for_each = local.radius_accounts

  name     = each.key
  password = local.wifi_secrets[each.value.cred_var]

  # 4b deliberately omits vlan / network_id / tunnel_* — that is 4c.
}