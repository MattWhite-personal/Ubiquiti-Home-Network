mock_provider "unifi" {}
mock_provider "azurerm" {}

variables {
  ipv4_supernet        = "10.140.0.0/16"
  ipv6_supernet        = "2001:db8:1234::/48"
  pihole_ipv4          = "192.0.2.1"
  pihole_ipv6          = "2001:db8::1"
  kea_ipv4             = "192.0.2.2"
  wifi_guest_psk       = "test-password"
  wifi_iot_psk         = "test-password"
  radius_matt_work     = "test-password"
  radius_jen_work      = "test-password"
  radius_matt_personal = "test-password"
  radius_jen_personal  = "test-password"
}

run "return_traffic_policy" {
  command = plan

  plan_options {
    target = [unifi_firewall_policy.flow]
  }

  assert {
    condition     = unifi_firewall_policy.flow["permit-pihole-to-internet-0"].create_allow_respond == false
    error_message = "External-bound DNS policy must not request an automatic return rule."
  }

  assert {
    condition     = unifi_firewall_policy.flow["matt-work-to-iot-0"].create_allow_respond == true
    error_message = "Internal allow policies must retain automatic return rules."
  }

  assert {
    condition     = unifi_firewall_policy.flow["work-intra-zone-deny-0"].create_allow_respond == false
    error_message = "Block policies must not request an automatic return rule."
  }
}
