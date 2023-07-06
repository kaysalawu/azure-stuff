
# TODO: rename resources to match vnet${each.key}

locals {
  prefix = var.prefix == "" ? "" : join("-", [var.prefix, ""])
  subnets = flatten([
    for k, v in var.vnet_config : [
      for subnet_key, subnet in v.subnets : [
        {
          vnet_key                 = k
          subnet_key               = subnet_key
          subnet                   = subnet
          delegate                 = try(subnet.value.delegate, [])
          dns_zone_linked_rulesets = try(subnet.value.dns_zone_linked_rulesets, [])
        }
      ]
    ]
  ])
  subnets_with_nat = {
    for x in local.subnets : x.vnet_key => azurerm_subnet.this[x.subnet_key].id
    if contains(var.vnet_config[x.vnet_key].subnets_nat_gateway, x.subnet_key)
  }
  dns_rulesets = flatten([
    for k, v in var.vnet_config : [
      for ruleset_key, ruleset_value in var.dns_zone_linked_rulesets : [
        {
          vnet_key    = k
          ruleset_key = ruleset_key
          ruleset_id  = ruleset_value
        }
      ]
    ]
  ])
}

# vnet
#----------------------------

resource "azurerm_virtual_network" "this" {
  for_each            = { for k, v in var.vnet_config : k => v }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}"
  name          = "${local.prefix}vnet"
  address_space = each.value.address_space
  location      = var.location
}

# subnets
#----------------------------

resource "azurerm_subnet" "this" {
  for_each             = { for x in local.subnets : x.subnet_key => x }
  resource_group_name  = var.resource_group
  name                 = each.value.subnet_key
  virtual_network_name = azurerm_virtual_network.this[each.value.vnet_key].name
  address_prefixes     = each.value.subnet.address_prefixes

  dynamic "delegation" {
    iterator = delegation
    for_each = contains(try(each.value.subnet.delegate, []), "dns") ? [1] : []
    content {
      name = "Microsoft.Network.dnsResolvers"
      service_delegation {
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
        name    = "Microsoft.Network/dnsResolvers"
      }
    }
  }
  private_endpoint_network_policies_enabled     = length(regexall("pls", each.key)) > 0 ? false : true
  private_link_service_network_policies_enabled = length(regexall("pls", each.key)) > 0 ? false : true
}

# nsg
#----------------------------

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = var.nsg_config
  subnet_id                 = [for k, v in azurerm_subnet.this : v.id if length(regexall("${each.key}", k)) > 0][0]
  network_security_group_id = each.value
  timeouts {
    create = "60m"
  }
}

# dns
#----------------------------

resource "azurerm_private_dns_zone" "this" {
  count               = var.private_dns_zone == null ? 0 : 1
  resource_group_name = var.resource_group
  name                = var.private_dns_zone
  timeouts {
    create = "60m"
  }
}

# vnet link (local vnet)

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = { for k, v in var.vnet_config : k => azurerm_virtual_network.this[k] if var.private_dns_zone != null }
  resource_group_name   = var.resource_group
  name                  = each.value.name
  private_dns_zone_name = azurerm_private_dns_zone.this[0].name
  virtual_network_id    = each.value.id
  registration_enabled  = true
  timeouts {
    create = "60m"
  }
}

# vnet link (external vnets)

resource "azurerm_private_dns_zone_virtual_network_link" "external" {
  for_each              = { for k, v in var.dns_zone_linked_vnets : k => v if var.private_dns_zone != null }
  resource_group_name   = var.resource_group
  name                  = "${local.prefix}${each.key}-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.this[0].name
  virtual_network_id    = each.value.vnet
  registration_enabled  = each.value.registration_enabled
  timeouts {
    create = "60m"
  }
}

# dns resolver

resource "azurerm_private_dns_resolver" "this" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_private_dns_resolver }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-dns-resolver-${each.key}"
  name               = "${local.prefix}dns-resolver-${each.key}"
  location           = var.location
  virtual_network_id = azurerm_virtual_network.this[each.key].id
  timeouts {
    create = "60m"
  }
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "this" {
  for_each = { for k, v in var.vnet_config : k => v if v.enable_private_dns_resolver }
  #name                    = "${local.prefix}vnet${each.key}-dns-in-${each.key}"
  name                    = "${local.prefix}dns-in-${each.key}"
  private_dns_resolver_id = azurerm_private_dns_resolver.this[each.key].id
  location                = var.location
  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = [for k, v in azurerm_subnet.this : v.id if length(regexall("dns-in", k)) > 0][0]
  } # TODO: replace regex with subnet_key
  timeouts {
    create = "60m"
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "this" {
  for_each = { for k, v in var.vnet_config : k => v if v.enable_private_dns_resolver }
  #name                    = "${local.prefix}vnet${each.key}-dns-out-${each.key}"
  name                    = "${local.prefix}dns-out-${each.key}"
  private_dns_resolver_id = azurerm_private_dns_resolver.this[each.key].id
  location                = var.location
  subnet_id               = [for k, v in azurerm_subnet.this : v.id if length(regexall("dns-out", k)) > 0][0]
  timeouts {
    create = "60m"
  }
} # TODO: replace regex with subnet_key

resource "azurerm_private_dns_resolver_virtual_network_link" "this" {
  for_each                  = { for x in local.dns_rulesets : x.ruleset_key => x }
  name                      = "${local.prefix}${each.key}-vnet${each.value.vnet_key}-link"
  dns_forwarding_ruleset_id = each.value.ruleset_id
  virtual_network_id        = azurerm_virtual_network.this[each.value.vnet_key].id
  timeouts {
    create = "60m"
  }
}

# vm
#----------------------------

module "vm" {
  for_each         = { for x in var.vm_config : x.name => x }
  source           = "../../modules/linux"
  resource_group   = var.resource_group
  prefix           = var.prefix
  name             = each.key
  location         = var.location
  subnet           = azurerm_subnet.this[each.value.subnet].id
  private_ip       = each.value.private_ip
  source_image     = each.value.source_image
  use_vm_extension = each.value.use_vm_extension
  custom_data      = each.value.custom_data
  enable_public_ip = each.value.public_ip == null ? false : true
  dns_servers      = each.value.dns_servers
  storage_account  = var.storage_account
  admin_username   = var.admin_username
  admin_password   = var.admin_password
  private_dns_zone = try(azurerm_private_dns_zone.this[0].name, "")
  delay_creation   = each.value.delay_creation
}

# nat
#----------------------------

resource "azurerm_public_ip" "nat" {
  for_each            = { for k, v in var.vnet_config : k => v if length(v.subnets_nat_gateway) > 0 }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-natgw"
  name              = "${local.prefix}natgw"
  location          = var.location
  allocation_method = "Static"
  sku               = "Standard"
  timeouts {
    create = "60m"
  }
}

resource "azurerm_nat_gateway" "nat" {
  for_each            = { for k, v in var.vnet_config : k => v if length(v.subnets_nat_gateway) > 0 }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-natgw"
  name     = "${local.prefix}natgw"
  location = var.location
  sku_name = "Standard"
  timeouts {
    create = "60m"
  }
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  for_each             = { for k, v in var.vnet_config : k => v if length(v.subnets_nat_gateway) > 0 }
  nat_gateway_id       = azurerm_nat_gateway.nat[each.key].id
  public_ip_address_id = azurerm_public_ip.nat[each.key].id
  timeouts {
    create = "60m"
  }
}

resource "azurerm_subnet_nat_gateway_association" "nat" {
  for_each       = local.subnets_with_nat
  nat_gateway_id = azurerm_nat_gateway.nat[each.key].id
  subnet_id      = each.value
}

# route server
#----------------------------

resource "azurerm_public_ip" "ars_pip" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_ars }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-ars-pip"
  name              = "${local.prefix}ars-pip"
  location          = var.location
  sku               = "Standard"
  allocation_method = "Static"
  timeouts {
    create = "60m"
  }
}

resource "azurerm_route_server" "ars" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_ars }
  resource_group_name = var.resource_group
  #name                             = "${local.prefix}vnet${each.key}-ars"
  name                             = "${local.prefix}ars"
  location                         = var.location
  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.ars_pip[each.key].id
  subnet_id                        = azurerm_subnet.this["RouteServerSubnet"].id
  branch_to_branch_traffic_enabled = true

  lifecycle {
    ignore_changes = [
      subnet_id
    ]
  }
  timeouts {
    create = "60m"
  }
}

# vpngw
#----------------------------

resource "azurerm_public_ip" "vpngw_pip0" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_vpngw }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-vpngw-pip0"
  name              = "${local.prefix}vpngw-pip0"
  location          = var.location
  sku               = "Standard"
  allocation_method = "Static"
  zones             = [1, 2, 3]
  timeouts {
    create = "60m"
  }
}

resource "azurerm_public_ip" "vpngw_pip1" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_vpngw }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-vpngw-pip1"
  name              = "${local.prefix}vpngw-pip1"
  location          = var.location
  sku               = "Standard"
  allocation_method = "Static"
  zones             = [1, 2, 3]
  timeouts {
    create = "60m"
  }
}

resource "azurerm_virtual_network_gateway" "vpngw" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_vpngw }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-vpngw"
  name          = "${local.prefix}vpngw"
  location      = var.location
  type          = "Vpn"
  vpn_type      = "RouteBased"
  sku           = var.vnet_config[each.key].vpngw_config[0].sku
  enable_bgp    = true
  active_active = true

  ip_configuration {
    name                          = "${local.prefix}ip-config0"
    subnet_id                     = azurerm_subnet.this["GatewaySubnet"].id
    public_ip_address_id          = azurerm_public_ip.vpngw_pip0[0].id
    private_ip_address_allocation = "Dynamic"
  }
  ip_configuration {
    name                          = "${local.prefix}ip-config1"
    subnet_id                     = azurerm_subnet.this["GatewaySubnet"].id
    public_ip_address_id          = azurerm_public_ip.vpngw_pip1[0].id
    private_ip_address_allocation = "Dynamic"
  }

  bgp_settings {
    asn = var.vnet_config[each.key].vpngw_config[0].asn
    peering_addresses {
      ip_configuration_name = "${local.prefix}ip-config0"
      apipa_addresses       = try(var.vnet_config[each.key].vpngw_config.ip_config0_apipa_addresses, ["169.254.21.1"])
    }
    peering_addresses {
      ip_configuration_name = "${local.prefix}ip-config1"
      apipa_addresses       = try(var.vnet_config[each.key].vpngw_config.ip_config1_apipa_addresses, ["169.254.21.5"])
    }
  }
  timeouts {
    create = "60m"
  }
}

# ergw
#----------------------------

resource "azurerm_public_ip" "ergw_pip" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_ergw }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-ergw-pip0"
  name              = "${local.prefix}ergw-pip0"
  location          = var.location
  sku               = "Standard"
  allocation_method = "Static"
  timeouts {
    create = "60m"
  }
}

resource "azurerm_virtual_network_gateway" "ergw" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_ergw }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-ergw"
  name          = "${local.prefix}ergw"
  location      = var.location
  type          = "ExpressRoute"
  vpn_type      = "RouteBased"
  sku           = "Standard"
  enable_bgp    = true
  active_active = false
  ip_configuration {
    name                          = "${local.prefix}ip0"
    subnet_id                     = azurerm_subnet.this["GatewaySubnet"].id
    public_ip_address_id          = azurerm_public_ip.ergw_pip[0].id
    private_ip_address_allocation = "Dynamic"
  }
  timeouts {
    create = "60m"
  }
}

# azure firewall
#----------------------------

# workspace

resource "azurerm_log_analytics_workspace" "azfw" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_firewall }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-azfw-ws"
  name     = "${local.prefix}azfw-ws"
  location = var.location
}

# firewall public ip

resource "azurerm_public_ip" "fw_pip" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_firewall }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-azfw-pip0"
  name              = "${local.prefix}azfw-pip0"
  location          = var.location
  sku               = "Standard"
  allocation_method = "Static"
  timeouts {
    create = "60m"
  }
}

# firewall management public ip

resource "azurerm_public_ip" "fw_mgt_pip" {
  for_each            = { for k, v in var.vnet_config : k => v if v.enable_firewall }
  resource_group_name = var.resource_group
  #name                = "${local.prefix}vnet${each.key}-azfw-mgt-pip0"
  name              = "${local.prefix}azfw-mgt-pip0"
  location          = var.location
  sku               = "Standard"
  allocation_method = "Static"
  timeouts {
    create = "60m"
  }
}

# firewall

resource "azurerm_firewall" "azfw" {
  for_each = { for k, v in var.vnet_config : k => v if v.enable_firewall }
  #name                = "${local.prefix}vnet${each.key}-azfw"
  name                = "${local.prefix}azfw"
  resource_group_name = var.resource_group
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = each.value.firewall_config[0].sku_tier
  firewall_policy_id  = each.value.firewall_config[0].firewall_policy_id

  ip_configuration {
    name                 = "${local.prefix}ip-config"
    subnet_id            = azurerm_subnet.this["AzureFirewallSubnet"].id
    public_ip_address_id = azurerm_public_ip.fw_pip[0].id
  }
  management_ip_configuration {
    name                 = "${local.prefix}mgmt-ip-config"
    subnet_id            = azurerm_subnet.this["AzureFirewallManagementSubnet"].id
    public_ip_address_id = azurerm_public_ip.fw_mgt_pip[0].id
  }
  timeouts {
    create = "60m"
  }
  depends_on = [
    azurerm_public_ip.fw_mgt_pip,
    azurerm_public_ip.fw_pip,
    azurerm_subnet.this,
    azurerm_virtual_network_gateway.vpngw,
    azurerm_virtual_network_gateway.ergw,
    azurerm_route_server.ars
  ]
  lifecycle {
    ignore_changes = [
      ip_configuration,
      management_ip_configuration,
    ]
  }
}

# storage account

resource "azurerm_storage_account" "azfw" {
  for_each                 = { for k, v in var.vnet_config : k => v if v.enable_firewall }
  resource_group_name      = var.resource_group
  name                     = lower(replace("${local.prefix}azfw", "-", ""))
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}


# diagnostic setting

resource "azurerm_monitor_diagnostic_setting" "azfw" {
  for_each = { for k, v in var.vnet_config : k => v if v.enable_firewall }
  #name                       = "${local.prefix}vnet${each.key}-azfw-diag"
  name                       = "${local.prefix}azfw-diag"
  target_resource_id         = azurerm_firewall.azfw[each.key].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.azfw[each.key].id
  storage_account_id         = azurerm_storage_account.azfw[each.key].id

  dynamic "metric" {
    for_each = var.metric_categories_firewall
    content {
      category = metric.value
      enabled  = true
    }
  }

  dynamic "enabled_log" {
    for_each = var.log_categories_firewall
    content {
      category = enabled_log.value
    }
  }
  depends_on = [
    azurerm_firewall.azfw,
    azurerm_log_analytics_workspace.azfw,
    azurerm_storage_account.azfw,
    azurerm_subnet.this,
  ]
  timeouts {
    create = "60m"
  }
}
