
locals {
  vhub1_vpngw_pip0          = tolist(azurerm_vpn_gateway.vhub1.bgp_settings[0].instance_0_bgp_peering_address[0].tunnel_ips)[1]
  vhub1_vpngw_pip1          = tolist(azurerm_vpn_gateway.vhub1.bgp_settings[0].instance_1_bgp_peering_address[0].tunnel_ips)[1]
  vhub1_vpngw_bgp0          = tolist(azurerm_vpn_gateway.vhub1.bgp_settings[0].instance_0_bgp_peering_address[0].default_ips)[0]
  vhub1_vpngw_bgp1          = tolist(azurerm_vpn_gateway.vhub1.bgp_settings[0].instance_1_bgp_peering_address[0].default_ips)[0]
  vhub1_router_bgp0         = azurerm_virtual_hub.vhub1.virtual_router_ips[1]
  vhub1_router_bgp1         = azurerm_virtual_hub.vhub1.virtual_router_ips[0]
  vhub1_firewall_private_ip = azurerm_firewall.vhub1.virtual_hub[0].private_ip_address
}

# hub
#----------------------------

resource "azurerm_virtual_hub" "vhub1" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.vhub1_prefix}hub"
  location            = local.vhub1_location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = local.vhub1_address_prefix
}

# vpngw
#----------------------------

# s2s

resource "azurerm_vpn_gateway" "vhub1" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.vhub1_prefix}vpngw"
  location            = local.vhub1_location
  virtual_hub_id      = azurerm_virtual_hub.vhub1.id
  bgp_settings {
    asn         = local.vhub1_bgp_asn
    peer_weight = 0
    instance_0_bgp_peering_address {
      custom_ips = [local.vhub1_vpngw_bgp_apipa_0]
    }
    instance_1_bgp_peering_address {
      custom_ips = [local.vhub1_vpngw_bgp_apipa_1]
    }
  }
}

# vpn-site
#----------------------------

# branch1

resource "azurerm_vpn_site" "vhub1_site_branch1" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.vhub1_prefix}site-branch1"
  location            = local.vhub1_location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  device_model        = "Azure"
  device_vendor       = "Microsoft"
  link {
    name          = "${local.vhub1_prefix}site-branch1-link-0"
    provider_name = "Microsoft"
    ip_address    = azurerm_public_ip.branch1_nva_pip.ip_address
    speed_in_mbps = 50
    bgp {
      asn             = local.branch1_nva_asn
      peering_address = local.branch1_nva_loopback0
    }
  }
}

# firewall
#----------------------------

resource "azurerm_firewall" "vhub1" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.vhub1_prefix}azfw"
  location            = local.vhub1_location
  sku_tier            = "Standard"
  sku_name            = "AZFW_Hub"
  firewall_policy_id  = azurerm_firewall_policy.firewall_policy_region1.id
  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.vhub1.id
    public_ip_count = 1
  }
}

# diagnostic setting

resource "azurerm_monitor_diagnostic_setting" "vhub1_firewall_diagnostic" {
  name                       = "${local.vhub1_prefix}azfw-diagnostic"
  target_resource_id         = azurerm_firewall.vhub1.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.analytics_ws_region1.id
  storage_account_id         = azurerm_storage_account.region1.id

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
