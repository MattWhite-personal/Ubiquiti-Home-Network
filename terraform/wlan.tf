#resource "unifi_ap_group" "all-aps" {
#  name = "all-aps"
#
#  device_macs = [
#    "58:d6:1f:84:35:0b",
#  ]
#}

resource "unifi_wlan" "psk" {
  for_each = { for k, v in local.wlans : k => v if v.auth == "psk" }

  name          = each.value.name
  is_guest      = each.value.is_guest
  security      = "wpapsk"
  passphrase    = local.wifi_secrets[each.value.psk_var]
  network_id    = unifi_network.network[each.value.network_slug].id
  ap_group_ids  = [data.unifi_ap_group.default.id]
  user_group_id = data.unifi_client_qos_rate.default.id

  wpa3_support    = each.value.wpa3 != "off"
  wpa3_transition = each.value.wpa3 == "transition"

  # bands / ap_group / pmf — tune to the provider's actual attribute names
}

# ── Enterprise / 802.1X WLANs (4c — empty until then) ──
# The filtered for_each produces an empty map now, so this resource
# creates nothing until an enterprise entry is added to local.wlans.
#resource "unifi_wlan" "enterprise" {
#  for_each = { for k, v in local.wlans : k => v if v.auth == "enterprise" }
#
#  name              = each.value.name
#  is_guest          = each.value.is_guest
#  security          = "wpaeap"
#  radius_profile_id = unifi_radius_profile.this[each.value.radius_profile].id
#
#  wpa3_support    = each.value.wpa3 != "off"
#  wpa3_transition = each.value.wpa3 == "transition"
#}
