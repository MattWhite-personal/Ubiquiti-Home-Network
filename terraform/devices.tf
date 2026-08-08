import {
  for_each = local.devices
  to       = unifi_device.device[each.key]
  id       = each.value.mac
}

resource "unifi_device" "device" {
  for_each = local.devices
  mac      = each.value.mac
  name     = each.value.name
  dynamic "port_override" {
    for_each = each.value.ports
    content {
      index           = port_override.key
      port_profile_id = unifi_port_profile.port_profile[port_override.value].id
    }
  }
}
