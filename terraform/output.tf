output "network_facts" {
  description = "Computed facts per network, keyed by slug. Source of truth for cross-referencing."
  value       = local.network_facts
  sensitive   = true # contains subnet/prefix data derived from sensitive supernets
}

output "disabled_profile_id" {
  value = data.unifi_port_profile.disabled.id
}