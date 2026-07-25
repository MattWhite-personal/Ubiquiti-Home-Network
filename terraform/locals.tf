locals {

  vlan_octet_overrides = {
    666 = 166 # Guest
    999 = 254 # Management
  }

  networks_computed = {
    for k, cfg in var.networks : k => merge(cfg, {
      # IPv4 subnet — octet from override table or the VLAN ID itself
      ipv4_subnet = cidrsubnet(
        var.ipv4_supernet,
        8,
        lookup(local.vlan_octet_overrides, cfg.vlan_id, cfg.vlan_id)
      )
      ipv4_gateway = "${cidrhost(
        cidrsubnet(var.ipv4_supernet, 8, lookup(local.vlan_octet_overrides, cfg.vlan_id, cfg.vlan_id)),
        1
      )}/24"

      ipv6_subnet = cidrsubnet(
        var.ipv6_supernet,
        16,
        parseint(tostring(cfg.vlan_id), 16)
      )
      ipv6_gateway = format(
        "%s/64",
        cidrhost(
          cidrsubnet(var.ipv6_supernet, 16, parseint(tostring(cfg.vlan_id), 16)),
          1
        )
      )
    })
  }
}
