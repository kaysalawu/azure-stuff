
locals {
  rfc1918_prefixes = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

####################################################
# storage accounts (boot diagnostics)
####################################################

resource "random_id" "storage_accounts" {
  byte_length = 5
}

# region 1

resource "azurerm_storage_account" "storage_accounts" {
  for_each                 = var.regions
  resource_group_name      = var.resource_group
  name                     = lower("${var.prefix}${each.key}${random_id.storage_accounts.hex}")
  location                 = each.value
  account_replication_type = "LRS"
  account_tier             = "Standard"
}

####################################################
# log analytics workspace
####################################################

resource "random_id" "analytics_workspaces" {
  byte_length = 5
}

resource "azurerm_log_analytics_workspace" "analytics_workspaces" {
  for_each            = var.regions
  resource_group_name = var.resource_group
  name                = "${var.prefix}-${each.key}-analytics-ws-${random_id.analytics_workspaces.hex}"
  location            = each.value
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

locals {
  firewall_categories_metric = ["AllMetrics"]
  firewall_categories_log = [
    "AzureFirewallApplicationRule",
    "AzureFirewallNetworkRule",
    "AzureFirewallDnsProxy"
  ]
}

# my public ip

/*data "http" "mypip" {
  url = "http://ipv4.icanhazip.com"
}*/

####################################################
# nsg
####################################################

# default
#----------------------------

resource "azurerm_network_security_group" "nsg_default" {
  for_each            = var.regions
  resource_group_name = var.resource_group
  name                = "${var.prefix}-nsg-${each.value}-default"
  location            = each.value
}

# vm
#----------------------------

resource "azurerm_network_security_group" "nsg_main" {
  for_each            = var.regions
  resource_group_name = var.resource_group
  name                = "${var.prefix}-nsg-${each.key}-main"
  location            = each.value
}

resource "azurerm_network_security_rule" "nsg_main_inbound_allow_all" {
  for_each                    = var.regions
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_main[each.key].name
  name                        = "inbound-allow-all"
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 100
  source_address_prefixes     = local.rfc1918_prefixes
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  protocol                    = "*"
  description                 = "Inbound Allow RFC1918"
}

resource "azurerm_network_security_rule" "nsg_main_inbound_allow_web_external" {
  for_each                    = var.regions
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_main[each.key].name
  name                        = "inbound-allow-web-external"
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 110
  source_address_prefix       = "0.0.0.0/0"
  source_port_range           = "*"
  destination_address_prefix  = "VirtualNetwork"
  destination_port_ranges     = ["80", "8080", "443"]
  protocol                    = "Tcp"
  description                 = "Allow inbound web traffic"
}

resource "azurerm_network_security_rule" "nsg_main_outbound_allow_rfc1918" {
  for_each                    = var.regions
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_main[each.key].name
  name                        = "outbound-allow-rfc1918"
  direction                   = "Outbound"
  access                      = "Allow"
  priority                    = 100
  source_address_prefixes     = local.rfc1918_prefixes
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  protocol                    = "*"
  description                 = "Outbound Allow RFC1918"
}

# nva
#----------------------------

resource "azurerm_network_security_group" "nsg_nva" {
  for_each            = var.regions
  resource_group_name = var.resource_group
  name                = "${var.prefix}-nsg-${each.value}-nva"
  location            = each.value
}

resource "azurerm_network_security_rule" "nsg_nva_inbound_allow_rfc1918" {
  for_each                    = var.regions
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_nva[each.key].name
  name                        = "inbound-allow-rfc1918"
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 100
  source_address_prefixes     = local.rfc1918_prefixes
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  protocol                    = "*"
  description                 = "Inbound Allow RFC1918"
}

resource "azurerm_network_security_rule" "nsg_nva_outbound_allow_rfc1918" {
  for_each                     = var.regions
  resource_group_name          = var.resource_group
  network_security_group_name  = azurerm_network_security_group.nsg_nva[each.key].name
  name                         = "outbound-allow-rfc1918"
  direction                    = "Outbound"
  access                       = "Allow"
  priority                     = 100
  source_address_prefix        = "*"
  source_port_range            = "*"
  destination_address_prefixes = local.rfc1918_prefixes
  destination_port_range       = "*"
  protocol                     = "*"
  description                  = "Outbound Allow RFC1918"
}

resource "azurerm_network_security_rule" "nsg_nva_inbound_allow_ipsec" {
  for_each                    = var.regions
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_nva[each.key].name
  name                        = "inbound-allow-ipsec"
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 110
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["500", "4500"]
  protocol                    = "Udp"
  description                 = "Inbound Allow UDP 500, 4500"
}

resource "azurerm_network_security_rule" "nsg_nva_outbound_allow_ipsec" {
  for_each                    = var.regions
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_nva[each.key].name
  name                        = "outbound-allow-ipsec"
  direction                   = "Outbound"
  access                      = "Allow"
  priority                    = 110
  source_address_prefix       = "*"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_ranges     = ["500", "4500"]
  protocol                    = "Udp"
  description                 = "Outbound Allow UDP 500, 4500"
}

# appgw
#----------------------------

resource "azurerm_network_security_group" "nsg_appgw" {
  for_each            = var.regions
  resource_group_name = var.resource_group
  name                = "${var.prefix}-nsg-${each.value}-appgw"
  location            = each.value
}

resource "azurerm_network_security_rule" "nsg_appgw_inbound_allow_appgw_v2sku" {
  for_each                    = var.regions
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_appgw[each.key].name
  name                        = "inbound-allow-appgw-v2sku"
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 100
  source_address_prefix       = "GatewayManager"
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = "65200-65535"
  protocol                    = "*"
  description                 = "Allow Inbound Azure infrastructure communication"
}

resource "azurerm_network_security_rule" "nsg_appgw_inbound_allow_web_external" {
  for_each                    = var.regions
  resource_group_name         = var.resource_group
  network_security_group_name = azurerm_network_security_group.nsg_appgw[each.key].name
  name                        = "inbound-allow-web-external"
  direction                   = "Inbound"
  access                      = "Allow"
  priority                    = 110
  source_address_prefix       = "0.0.0.0/0"
  source_port_range           = "*"
  destination_address_prefix  = "VirtualNetwork"
  destination_port_ranges     = ["80", "8080", "443"]
  protocol                    = "Tcp"
  description                 = "Allow inbound web traffic"
}