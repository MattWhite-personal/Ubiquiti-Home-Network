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
  #config_network = each.value.mgmt_network != null ? {
  #  type    = "static"
  #  ip      = cidrhost(local.network_facts[each.value.mgmt_network].ipv4_subnet, each.value.mgmt_ip)
  #  netmask = cidrnetmask(local.network_facts[each.value.mgmt_network].ipv4_subnet)
  #  gateway = split("/", local.network_facts[each.value.mgmt_network].ipv4_gateway)[0]
  #  dns1    = var.pihole_ipv4
  #} : null
  dynamic "port_override" {
    for_each = each.value.ports
    content {
      index           = port_override.key
      port_profile_id = unifi_port_profile.port_profile[port_override.value].id
    }
  }
}
