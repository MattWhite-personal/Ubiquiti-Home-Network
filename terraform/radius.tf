resource "unifi_radius_profile" "udr" {
  name = "udr-radius"

  use_usg_auth_server = true
  use_usg_acct_server = true
  accounting_enabled  = true

  vlan_enabled   = true
  vlan_wlan_mode = "optional"
}

resource "unifi_radius_user" "user" {
  for_each = local.radius_accounts

  name     = each.key
  password = local.wifi_secrets[each.value.cred_var]

  # 4b deliberately omits vlan / network_id / tunnel_* — that is 4c.
}