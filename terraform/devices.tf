import {
  for_each = local.devices
  to       = unifi_device.device[each.key]
  id       = each.value.mac
}

resource "unifi_device" "device" {
  for_each = local.devices
  mac      = each.value.mac
  name     = each.value.name
  # NO port_override yet — PR2 is import-only.
  # Because port_override is a MERGE, omitting it leaves all existing
  # controller-side port config untouched. Safe.
}