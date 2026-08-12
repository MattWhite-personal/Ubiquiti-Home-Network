locals {
  firewall_flows = {

    "dns-allow-pihole" = {
      action      = "ALLOW"
      protocol    = "tcp_udp"
      port        = 53
      description = "Permit DNS to Pi-hole (v4/v6) from any LAN zone"
      source      = { zones = ["any"], networks = [], ips = [] }
      destination = { zones = ["infrastructure"], networks = [], ips = [var.pihole_ipv4, var.pihole_ipv6] }
    }

    "work-intra-zone-deny" = {
      action      = "BLOCK"
      protocol    = "all"
      port        = null
      description = "Block matt-work <-> jen-work east-west traffic (intra-zone default is ALLOW, so this exception is required)"
      source      = { zones = ["work"], networks = ["matt-work"], ips = [] }
      destination = { zones = ["work"], networks = ["jen-work"], ips = [] }
    }

    # "matt-work AND server -> IoT" — written as TWO flows instead of one
    # combined rule, per the simplification above.
    "matt-work-to-iot" = {
      action      = "ALLOW"
      protocol    = "tcp_udp"
      port        = null
      description = "Allow matt-work devices to reach IoT devices (cross-zone: work -> infrastructure)"
      source      = { zones = ["work"], networks = ["matt-work"], ips = [] }
      destination = { zones = ["infrastructure"], networks = ["iot"], ips = [] }
    }
    "server-to-iot" = {
      action      = "ALLOW"
      protocol    = "tcp_udp"
      port        = null
      description = "Allow server to reach IoT devices. NOTE: server and iot are both already in the infrastructure zone, so this is currently a no-op under intra-zone default-allow — included for clarity / future-proofing if either network moves zones later."
      source      = { zones = ["infrastructure"], networks = ["server"], ips = [] }
      destination = { zones = ["infrastructure"], networks = ["iot"], ips = [] }
    }

    #"dot-block-egress" = {
    #  action      = "BLOCK"
    #  protocol    = "tcp_udp"
    #  port        = 853
    #  description = "Block DNS-over-TLS egress to the internet from any LAN zone — closes the encrypted DNS-bypass path (plain DNS is redirected to Pi-hole via NAT, see header)"
    #  source      = { zones = ["any"], networks = [], ips = [] }
    #  destination = { zones = ["external"], networks = [], ips = [] }
    #  # ORDER-SENSITIVE if you also have a broad "LAN -> External, ALLOW
    #  # everything" policy for general internet access — the check block
    #  # below will flag that combination; verify order in the Zone Matrix
    #  # UI if so.
    #}

    #"doh-block-known-ips" = {
    #  action      = "BLOCK"
    #  protocol    = "tcp"
    #  port        = 443
    #  description = "Best-effort block of known public DoH provider IPs — refresh var.known_doh_ipv4 periodically; will not catch every provider"
    #  source      = { zones = ["work", "personal", "guest"], networks = [], ips = [] }
    #  destination = { zones = ["external"], networks = [], ips = var.known_doh_ipv4 }
    #}

    # --- add new flows here as your infrastructure changes ---
    # e.g. "personal-to-jen-work-only":
    #   source      = { zones = ["personal"], networks = [], ips = [] }
    #   destination = { zones = ["work"], networks = ["jen-work"], ips = [] }
  }

  expanded_flows = merge([
    for fkey, f in local.firewall_flows : {
      for idx, pair in setproduct(
        contains(f.source.zones, "any") ? local.zone_names : f.source.zones,
        contains(f.destination.zones, "any") ? local.zone_names : f.destination.zones
      ) :
      "${fkey}-${idx}" => merge(f, {
        source_zone      = pair[0]
        destination_zone = pair[1]
        is_broad = (
          length(f.source.networks) == 0 && length(f.source.ips) == 0 &&
          length(f.destination.networks) == 0 && length(f.destination.ips) == 0 &&
          f.port == null
        )
      })
    }
  ]...)
}
