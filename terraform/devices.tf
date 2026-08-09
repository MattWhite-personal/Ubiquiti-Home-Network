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
  dynamic "port_override" {
    for_each = each.value.ports != null ? each.value.ports : {}
    content {
      index                 = port_override.key
      name                  = port_override.value.name
      speed                 = port_override.value.speed
      poe_mode              = port_override.value.poe_mode
      forward                = length(port_override.value.tagged_vlans) == 0 ? "native" : "customize"
      native_networkconf_id = local.network_id[port_override.value.native_vlan]
      tagged_networkconf_ids = length(port_override.value.tagged_vlans) == 0 ? null : [
        for slug in local.all_taggable_slugs :
        local.network_id[slug]
        if contains(port_override.value.tagged_vlans, slug)
      ]
    }
  }
}
