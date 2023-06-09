
locals {
  vhub2_vpngw_pip0          = tolist(azurerm_vpn_gateway.vhub2.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]
  vhub2_vpngw_pip1          = tolist(azurerm_vpn_gateway.vhub2.bgp_settings[0].instance_1_bgp_peering_address[0].tunnel_ips)[1]
  vhub2_vpngw_bgp0          = tolist(azurerm_vpn_gateway.vhub2.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0]
  vhub2_vpngw_bgp1          = tolist(azurerm_vpn_gateway.vhub2.bgp_settings[0].instance_1_bgp_peering_address[0].default_ips)[0]
  vhub2_router_bgp0         = azurerm_virtual_hub.vhub2.virtual_router_ips[1]
  vhub2_router_bgp1         = azurerm_virtual_hub.vhub2.virtual_router_ips[0]
  vhub2_firewall_private_ip = azurerm_firewall.vhub2.virtual_hub[0].private_ip_address
}

# hub
#----------------------------

resource "azurerm_virtual_hub" "vhub2" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.vhub2_prefix}hub"
  location            = local.vhub2_location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = local.vhub2_address_prefix
}

# vpngw
#----------------------------

# s2s

resource "azurerm_vpn_gateway" "vhub2" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.vhub2_prefix}vpngw"
  location            = local.vhub2_location
  virtual_hub_id      = azurerm_virtual_hub.vhub2.id
  bgp_settings {
    asn         = local.vhub2_bgp_asn
    peer_weight = 0
    instance_0_bgp_peering_address {
      custom_ips = [local.vhub2_vpngw_bgp_apipa_0]
    }
    instance_1_bgp_peering_address {
      custom_ips = [local.vhub2_vpngw_bgp_apipa_1]
    }
  }
}

# vpn-site
#----------------------------

# branch3

resource "azurerm_vpn_site" "vhub2_site_branch3" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.vhub2_prefix}site-branch3"
  location            = local.vhub2_location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  device_model        = "Azure"
  device_vendor       = "Microsoft"
  link {
    name          = "${local.vhub2_prefix}site-branch3-link-0"
    provider_name = "Microsoft"
    ip_address    = azurerm_public_ip.branch3_nva_pip.ip_address
    speed_in_mbps = 50
    bgp {
      asn             = local.branch3_nva_asn
      peering_address = local.branch3_nva_loopback0
    }
  }
}

# firewall
#----------------------------

resource "azurerm_firewall" "vhub2" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.vhub2_prefix}azfw"
  location            = local.vhub2_location
  sku_tier            = "Standard"
  sku_name            = "AZFW_Hub"
  firewall_policy_id  = azurerm_firewall_policy.firewall_policy_region2.id
  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.vhub2.id
    public_ip_count = 1
  }
}

# diagnostic setting

resource "azurerm_monitor_diagnostic_setting" "vhub2_firewall_diagnostic" {
  name                       = "${local.vhub2_prefix}azfw-diagnostic"
  target_resource_id         = azurerm_firewall.vhub2.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.analytics_ws_region2.id
  storage_account_id         = azurerm_storage_account.region2.id

  dynamic "metric" {
    for_each = local.firewall_categories_metric
    content {
      category = metric.value
      enabled  = true
    }
  }
  dynamic "enabled_log" {
    for_each = local.firewall_categories_log
    content {
      category = enabled_log.value
    }
  }
}
