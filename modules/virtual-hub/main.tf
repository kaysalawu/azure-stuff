
locals {
  firewall_categories_metric = ["AllMetrics"]
  firewall_categories_log = [
    "AzureFirewallApplicationRule",
    "AzureFirewallNetworkRule",
    "AzureFirewallDnsProxy"
  ]
}

# hub
#----------------------------

resource "azurerm_virtual_hub" "this" {
  resource_group_name = var.resource_group
  name                = "${var.prefix}hub"
  location            = var.location
  virtual_wan_id      = var.virtual_wan_id
  address_prefix      = var.address_prefix
  timeouts {
    create = "60m"
  }
}

# vpngw
#----------------------------

# s2s

resource "azurerm_vpn_gateway" "this" {
  count               = var.enable_s2s_vpn_gateway ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${var.prefix}vpngw"
  location            = var.location
  virtual_hub_id      = azurerm_virtual_hub.this.id

  bgp_settings {
    asn         = var.bgp_config[0].asn
    peer_weight = var.bgp_config[0].peer_weight
    instance_0_bgp_peering_address {
      custom_ips = var.bgp_config[0].instance_0_custom_ips
    }
    instance_1_bgp_peering_address {
      custom_ips = var.bgp_config[0].instance_1_custom_ips
    }
  }
  timeouts {
    create = "60m"
  }
}

# firewall
#----------------------------

resource "random_id" "azfw" {
  byte_length = 2
}

resource "azurerm_firewall" "this" {
  count               = var.security_config[0].enable_firewall ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${var.prefix}azfw-${random_id.azfw.hex}"
  location            = var.location
  sku_tier            = "Standard"
  sku_name            = "AZFW_Hub"
  firewall_policy_id  = var.security_config[0].firewall_policy_id
  virtual_hub {
    virtual_hub_id  = azurerm_virtual_hub.this.id
    public_ip_count = 1
  }
  timeouts {
    create = "60m"
  }
}

# diagnostic setting

resource "azurerm_monitor_diagnostic_setting" "this" {
  count                      = var.security_config[0].enable_firewall ? 1 : 0
  name                       = "${var.prefix}azfw-diag"
  target_resource_id         = azurerm_firewall.this[0].id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  storage_account_id         = var.storage_account_id

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
  timeouts {
    create = "60m"
  }
}
