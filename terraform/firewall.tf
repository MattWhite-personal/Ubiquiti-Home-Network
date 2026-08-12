resource "unifi_firewall_zone" "hotspot" {
  name = "Hotspot"
  #default_zone = true

}

resource "unifi_firewall_zone" "zone" {
  for_each    = local.zone_membership
  name        = title(each.key) # "Trusted", "Iot", "Guest"
  network_ids = [for slug in each.value : unifi_network.network[slug].id]
}

resource "unifi_firewall_policy" "flow" {
  for_each = local.expanded_flows

  name        = "TF-${each.key}"
  action      = each.value.action
  protocol    = each.value.protocol
  description = each.value.description
  logging     = true

  source = {
    zone_id         = local.all_zone_ids[each.value.source_zone]
    matching_target = length(each.value.source.ips) > 0 ? "IP" : length(each.value.source.networks) > 0 ? "NETWORK" : "ANY"
    network_ids     = length(each.value.source.networks) > 0 ? [for slug in each.value.source.networks : local.network_id[slug]] : null
    ips             = length(each.value.source.ips) > 0 ? each.value.source.ips : null
  }

  destination = {
    zone_id             = local.all_zone_ids[each.value.destination_zone]
    matching_target     = length(each.value.destination.ips) > 0 ? "IP" : length(each.value.destination.networks) > 0 ? "NETWORK" : "ANY"
    network_ids         = length(each.value.destination.networks) > 0 ? [for slug in each.value.destination.networks : local.network_id[slug]] : null
    ips                 = length(each.value.destination.ips) > 0 ? each.value.destination.ips : null
    port                = each.value.port
    port_matching_type  = each.value.port != null ? "SPECIFIC" : "ANY"
  }
}