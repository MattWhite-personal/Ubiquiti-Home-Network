locals {
  # ── WLANs — the SSIDs ──
  wlans = {
    lansolo = {
      name         = "LanSolo"
      auth         = "psk"              # "psk" | "enterprise"
      network_slug = "guest"            # references network_facts key
      psk          = var.wifi_guest_psk # which sensitive var holds the key
      wpa3         = "transition"       # "only" | "transition" | "off"
      bands        = ["2g", "5g", "6g"]
      is_guest     = true
    }
    whitefam_iot = {
      name         = "WhiteFam-IoT"
      auth         = "psk"
      network_slug = "iot"
      psk          = var.wifi_iot_psk
      wpa3         = "transition"
      bands        = ["2g", "5g"]
      is_guest     = false
    }
    whitefam = {
      name           = "WhiteFam"
      auth           = "enterprise" # 802.1X — VLAN comes from RADIUS, not here
      radius_profile = "home"
      wpa3           = "only"
      bands          = ["2g", "5g", "6g"]
      is_guest       = false
      #  # note: no network_slug — dynamic VLAN via RADIUS account attributes
    }
  }

  # ── RADIUS accounts — identity → VLAN (4c) ──
  radius_accounts = {
    matt_devices = {
      network_slug  = "matt-work"
      radius_secret = var.radius_matt
    }
    jen_devices = {
      network_slug  = "jen-work"
      radius_secret = var.radius_jen
    }
    personal = {
      network_slug  = "personal"
      radius_secret = var.radius_personal
    }
  }
}

