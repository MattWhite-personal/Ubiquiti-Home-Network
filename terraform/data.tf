data "unifi_network" "lan_network" {
  name = "Default"
}
data "unifi_ap_group" "default" {
  name = "All APs"
}

data "unifi_client_qos_rate" "default" {
  name = "Default"
}

data "unifi_radius_profile" "udr7" {
  name = "Default"
}