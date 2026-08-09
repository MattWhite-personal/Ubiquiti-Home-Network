import {
  for_each = local.devices
  to       = unifi_device.device[each.key]
  id       = each.value.mac
}

resource "unifi_device" "device" {
  for_each        = local.devices
  mac             = each.value.mac
  name            = each.value.name
  mgmt_network_id = each.value.mgmt_network != null ? local.network_id[each.value.mgmt_network] : null
  #stp_priority    = each.value.stp_priority
  #stp_version     = each.value.stp_version
  config_network = each.value.mgmt_ip != null ? {
    type      = "static"
    ip        = "10.140.254.${each.value.mgmt_ip}"
    netmask   = "255.255.255.0"
    gateway   = "10.140.254.1"
    dns1      = "192.168.178.11"
    dnssuffix = "gilbert.road"
  } : null
  #dynamic "port_override" {
  #  for_each = each.value.ports != null ? each.value.ports : {}
  #  content {
  #    index           = port_override.key
  #    port_profile_id = unifi_port_profile.port_profile[port_override.value].id
  #  }
  #}
}
