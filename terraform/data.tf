data "unifi_network" "lan_network" {
  name = "Default"
}
data "unifi_ap_group" "default" {
  name = "Default"
}

data "unifi_client_qos_rate" "default" {
  name = "Default"
}
