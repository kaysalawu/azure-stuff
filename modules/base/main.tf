
locals {
  prefix = var.prefix == "" ? "" : join("-", [var.prefix, ""])
  subnets_with_nat = [
    for x in var.vnet_config[0].subnets : azurerm_subnet.this[x].id
    if contains(var.vnet_config[0].subnets_nat_gateway, x)
  ]
}

# vnet
#----------------------------

resource "azurerm_virtual_network" "this" {
  resource_group_name = var.resource_group
  name                = "${local.prefix}vnet"
  address_space       = var.vnet_config[0].address_space
  location            = var.location
}

# subnets
#----------------------------

resource "azurerm_subnet" "this" {
  for_each             = var.vnet_config[0].subnets
  resource_group_name  = var.resource_group
  virtual_network_name = azurerm_virtual_network.this.name
  name                 = each.key
  address_prefixes     = each.value.address_prefixes

  dynamic "delegation" {
    iterator = delegation
    for_each = contains(try(each.value.delegate, []), "dns") ? [1] : []
    content {
      name = "Microsoft.Network.dnsResolvers"
      service_delegation {
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
        name    = "Microsoft.Network/dnsResolvers"
      }
    }
  }
  private_endpoint_network_policies_enabled     = length(regexall("pls", each.key)) > 0 ? false : true #TODO: replace regex with subnet_key
  private_link_service_network_policies_enabled = length(regexall("pls", each.key)) > 0 ? false : true #TODO: replace regex with subnet_key
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

# zones

resource "azurerm_private_dns_zone" "this" {
  count               = var.private_dns_zone == null ? 0 : 1
  resource_group_name = var.resource_group
  name                = var.private_dns_zone
  timeouts {
    create = "60m"
  }
}

# zone links

resource "azurerm_private_dns_zone_virtual_network_link" "internal" {
  count                 = var.private_dns_zone == null ? 0 : 1
  resource_group_name   = var.resource_group
  name                  = "${local.prefix}vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.this[0].name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = true
  timeouts {
    create = "60m"
  }
}

# dns resolver

resource "azurerm_private_dns_resolver" "this" {
  count               = var.vnet_config[0].enable_private_dns_resolver ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}dns-resolver"
  location            = var.location
  virtual_network_id  = azurerm_virtual_network.this.id
  timeouts {
    create = "60m"
  }
}

resource "azurerm_private_dns_resolver_inbound_endpoint" "this" {
  count                   = var.vnet_config[0].enable_private_dns_resolver ? 1 : 0
  name                    = "${local.prefix}dns-in"
  private_dns_resolver_id = azurerm_private_dns_resolver.this[0].id
  location                = var.location
  ip_configurations {
    private_ip_allocation_method = "Dynamic"
    subnet_id                    = [for k, v in azurerm_subnet.this : v.id if length(regexall("dns-in", k)) > 0][0] # TODO: replace regex with subnet_key
  }
  timeouts {
    create = "60m"
  }
}

resource "azurerm_private_dns_resolver_outbound_endpoint" "this" {
  count                   = var.vnet_config[0].enable_private_dns_resolver ? 1 : 0
  name                    = "${local.prefix}dns-out"
  private_dns_resolver_id = azurerm_private_dns_resolver.this[0].id
  location                = var.location
  subnet_id               = [for k, v in azurerm_subnet.this : v.id if length(regexall("dns-out", k)) > 0][0] # TODO: replace regex with subnet_key
  timeouts {
    create = "60m"
  }
}

# nat
#----------------------------

resource "azurerm_public_ip" "nat" {
  count               = length(var.vnet_config[0].subnets_nat_gateway) > 0 ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}natgw"
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  timeouts {
    create = "60m"
  }
}

resource "azurerm_nat_gateway" "nat" {
  count               = length(var.vnet_config[0].subnets_nat_gateway) > 0 ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}natgw"
  location            = var.location
  sku_name            = "Standard"
  timeouts {
    create = "60m"
  }
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  count                = length(var.vnet_config[0].subnets_nat_gateway) > 0 ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.nat[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
  timeouts {
    create = "60m"
  }
}

resource "azurerm_subnet_nat_gateway_association" "nat" {
  for_each       = toset(local.subnets_with_nat)
  nat_gateway_id = azurerm_nat_gateway.nat[each.key].id
  subnet_id      = each.value
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
  depends_on = [
    azurerm_public_ip.nat,
    azurerm_nat_gateway.nat,
    azurerm_nat_gateway_public_ip_association.nat,
    azurerm_subnet_nat_gateway_association.nat,
  ]
}

# route server
#----------------------------

resource "azurerm_public_ip" "ars_pip" {
  count               = var.vnet_config[0].enable_ars ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}ars-pip"
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
  timeouts {
    create = "60m"
  }
}

resource "azurerm_route_server" "ars" {
  count                            = var.vnet_config[0].enable_ars ? 1 : 0
  resource_group_name              = var.resource_group
  name                             = "${local.prefix}ars"
  location                         = var.location
  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.ars_pip[0].id
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
  count               = var.vnet_config[0].enable_vpn_gateway ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}vpngw-pip0"
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = [1, 2, 3]
  timeouts {
    create = "60m"
  }
}

resource "azurerm_public_ip" "vpngw_pip1" {
  count               = var.vnet_config[0].enable_vpn_gateway ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}vpngw-pip1"
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = [1, 2, 3]
  timeouts {
    create = "60m"
  }
}

resource "azurerm_virtual_network_gateway" "vpngw" {
  count               = var.vnet_config[0].enable_vpn_gateway ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}vpngw"
  location            = var.location
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = var.vnet_config[0].vpn_gateway_sku
  enable_bgp          = true
  active_active       = true

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
    asn = var.vnet_config[0].vpn_gateway_asn
    peering_addresses {
      ip_configuration_name = "${local.prefix}ip-config0"
      apipa_addresses       = try(var.vnet_config.ip_config0_apipa_addresses, ["169.254.21.1"])
    }
    peering_addresses {
      ip_configuration_name = "${local.prefix}ip-config1"
      apipa_addresses       = try(var.vnet_config.ip_config1_apipa_addresses, ["169.254.21.5"])
    }
  }
  timeouts {
    create = "60m"
  }
}

# ergw
#----------------------------

resource "azurerm_public_ip" "ergw_pip" {
  count               = var.vnet_config[0].enable_er_gateway ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}ergw-pip0"
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
  timeouts {
    create = "60m"
  }
}

resource "azurerm_virtual_network_gateway" "ergw" {
  count               = var.vnet_config[0].enable_er_gateway ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}ergw"
  location            = var.location
  type                = "ExpressRoute"
  vpn_type            = "RouteBased"
  sku                 = "Standard"
  enable_bgp          = true
  active_active       = false
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
  count               = var.vnet_config[0].enable_firewall ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}azfw-ws"
  location            = var.location
}

# firewall public ip

resource "azurerm_public_ip" "fw_pip" {
  count               = var.vnet_config[0].enable_firewall ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}azfw-pip0"
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
  timeouts {
    create = "60m"
  }
}

# firewall management public ip

resource "azurerm_public_ip" "fw_mgt_pip" {
  count               = var.vnet_config[0].enable_firewall ? 1 : 0
  resource_group_name = var.resource_group
  name                = "${local.prefix}azfw-mgt-pip0"
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
  timeouts {
    create = "60m"
  }
}

# firewall

resource "azurerm_firewall" "azfw" {
  count               = var.vnet_config[0].enable_firewall ? 1 : 0
  name                = "${local.prefix}azfw"
  resource_group_name = var.resource_group
  location            = var.location
  sku_name            = "AZFW_VNet"
  sku_tier            = try(var.vnet_config[0].firewall_config[0].sku_tier, "Basic")
  firewall_policy_id  = try(var.vnet_config[0].firewall_config[0].firewall_policy_id, null)

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

resource "random_id" "azfw" {
  count       = var.vnet_config[0].enable_firewall ? 1 : 0
  byte_length = 4
}

resource "azurerm_storage_account" "azfw" {
  count                    = var.vnet_config[0].enable_firewall ? 1 : 0
  resource_group_name      = var.resource_group
  name                     = lower(replace("${local.prefix}azfw${random_id.azfw[0].hex}", "-", ""))
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# diagnostic setting

resource "azurerm_monitor_diagnostic_setting" "azfw" {
  count                      = var.vnet_config[0].enable_firewall ? 1 : 0
  name                       = "${local.prefix}azfw-diag"
  target_resource_id         = azurerm_firewall.azfw[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.azfw[0].id
  storage_account_id         = azurerm_storage_account.azfw[0].id

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
