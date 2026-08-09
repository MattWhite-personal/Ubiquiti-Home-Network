locals {
  devices = {
    fw01 = {
      name         = "wf-cam-fw01",
      mac          = "a8:9c:6c:10:4b:de",
      mgmt_network = null,
      mgmt_ip      = null,
      stp_priority = 4096,
      stp_version  = "rstp",
      ports        = {}
    }
    sw01 = {
      name         = "wf-cam-sw01",
      mac          = "90:41:b2:e4:c2:5b",
      mgmt_network = "mgmt",
      mgmt_ip      = null,
      stp_priority = 8192,
      stp_version  = "rstp",
      ports = {
        # 1 = "trunk_wifi"
        # 2 = "access_matt_work"
        # 3 = "shutdown"
        # 4 = "shutdown"
        # 5 = "trunk_wired"
      }
    }
    ap01 = {
      name         = "wf-cam-ap01",
      mac          = "58:d6:1f:84:35:0b",
      mgmt_network = "mgmt",
      mgmt_ip      = 3
      stp_priority = 16384,
      stp_version  = "rstp",
      ports        = {}
    }
  }

  # ── DECLARATIVE SURFACE — edit this to add/change networks ──
  # Keyed by a stable slug. The slug never changes even if you
  # rename the network or renumber the VLAN — downstream refs stay valid.
  networks = {
    mgmt = {
      vlan_id   = 999
      name      = "Management"
      purpose   = "corporate"
      dhcp_mode = "relay"
      octet     = 254
      zone      = "management"
    }
    iot = {
      vlan_id   = 30
      name      = "IoT"
      purpose   = "corporate"
      dhcp_mode = "relay"
      octet     = 30
      zone      = "infrastructure"
    }
    guest = {
      vlan_id   = 666
      name      = "Guest"
      purpose   = "corporate"
      dhcp_mode = "relay"
      octet     = 166
      zone      = "guest"
    }
    matt-work = {
      vlan_id   = 21
      name      = "Matt's Work"
      purpose   = "corporate"
      dhcp_mode = "relay"
      octet     = 21
      zone      = "work"
    }
    jen-work = {
      vlan_id   = 22
      name      = "Jen's Work"
      purpose   = "corporate"
      dhcp_mode = "relay"
      octet     = 22
      zone      = "work"
    }
    personal = {
      vlan_id   = 40
      name      = "Personal devices"
      purpose   = "corporate"
      dhcp_mode = "relay"
      octet     = 40
      zone      = "personal"
    }
    server = {
      vlan_id   = 10
      name      = "Server"
      purpose   = "corporate"
      dhcp_mode = "relay"
      octet     = 10
      zone      = "infrastructure"
    }
  }
  zone_names = distinct([for net in local.networks : net.zone])
  zone_membership = {
    for zone in local.zone_names : zone => [
      for slug, net in local.networks : slug if net.zone == zone
    ]
  }

  # ── COMPUTED FACTS — do not edit; derived from definitions ──
  # Referenced by wifi.tf, firewall.tf, ports.tf via local.network_facts[<slug>]
  network_facts = {
    for slug, net in local.networks : slug => {
      vlan_id      = net.vlan_id
      name         = net.name
      ipv4_subnet  = cidrsubnet(var.ipv4_supernet, 8, net.octet)                            # routable prefix e.g. 10.140.254.0/24
      ipv4_gateway = "${cidrhost(cidrsubnet(var.ipv4_supernet, 8, net.octet), 1)}/24"       # gateway CIDR e.g. 10.140.254.1/24
      ipv6_subnet  = cidrsubnet(var.ipv6_supernet, 16, parseint(tostring(net.vlan_id), 16)) # routable prefix e.g. 2a02:8011:ee07:999::/64
      ipv6_gateway = "${cidrhost(cidrsubnet(var.ipv6_supernet, 16, parseint(tostring(net.vlan_id), 16)), 1)}/64"
    }
  }
  network_id = merge(
    { for slug, net in local.networks : slug => unifi_network.network[slug].id },
    { default = data.unifi_network.lan_network.id }
  )
  all_taggable_slugs = keys(local.networks) # temp whilst tf doesnt correctly set tagged vlans

  port_profiles = {
    trunk_wifi = {
      state          = "enabled"
      native_network = "default"
      tagged_network = ["guest", "iot", "matt-work", "jen-work", "personal", "mgmt"]
      poe_mode       = "auto"
    }
    trunk_wired = {
      state          = "enabled"
      native_network = "default"
      tagged_network = ["guest", "iot", "matt-work", "jen-work", "personal", "mgmt"]
      poe_mode       = "auto"
    }
    trunk_nuc = {
      state          = "enabled"
      native_network = "default"
      tagged_network = ["server", "iot"]
      poe_mode       = "auto"
    }
    access_iot = {
      state          = "enabled"
      native_network = "iot"
      tagged_network = []
      poe_mode       = "auto"
    }
    access_matt_work = {
      state          = "enabled"
      native_network = "matt-work"
      tagged_network = []
      poe_mode       = "auto"
    }
  }
}
