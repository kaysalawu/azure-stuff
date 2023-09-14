####################################################
# Lab
####################################################

locals {
  prefix       = "Hs12"
  my_public_ip = chomp(data.http.my_public_ip.response_body)
}

####################################################
# providers
####################################################

provider "azurerm" {
  skip_provider_registration = true
  features {}
}

terraform {
  required_providers {
    megaport = {
      source  = "megaport/megaport"
      version = "0.1.9"
    }
  }
}

####################################################
# network features
####################################################

locals {
  regions = {
    region1 = local.region1
    region2 = local.region2
  }
  udr_destinations = concat(
    local.udr_azure_destinations_region1,
    local.udr_onprem_destinations_region1,
    local.udr_azure_destinations_region2,
    local.udr_onprem_destinations_region2,
  )

  firewall_sku = "Basic"

  hub1_features = {
    enable_private_dns_resolver = true
    enable_ars                  = false
    enable_vpn_gateway          = true
    enable_er_gateway           = false

    enable_firewall    = true
    firewall_sku       = local.firewall_sku
    firewall_policy_id = azurerm_firewall_policy.firewall_policy["region1"].id
  }

  hub2_features = {
    enable_private_dns_resolver = true
    enable_ars                  = false
    enable_vpn_gateway          = true
    enable_er_gateway           = false

    enable_firewall    = true
    firewall_sku       = local.firewall_sku
    firewall_policy_id = azurerm_firewall_policy.firewall_policy["region2"].id
  }
}

# resource group

resource "azurerm_resource_group" "rg" {
  name     = "${local.prefix}RG"
  location = local.default_region
}

# my public ip

data "http" "my_public_ip" {
  url = "http://ipv4.icanhazip.com"
}

####################################################
# common resources
####################################################

module "common" {
  source         = "../../modules/common"
  resource_group = azurerm_resource_group.rg.name
  prefix         = local.prefix
  firewall_sku   = local.firewall_sku
  regions        = local.regions
}

# vm startup scripts
#----------------------------

locals {
  hub1_nva_asn   = "65000"
  hub1_vpngw_asn = "65515"
  hub1_ergw_asn  = "65515"
  hub1_ars_asn   = "65515"

  hub2_nva_asn   = "65000"
  hub2_vpngw_asn = "65515"
  hub2_ergw_asn  = "65515"
  hub2_ars_asn   = "65515"
  #mypip         = chomp(data.http.mypip.response_body)

  vm_script_targets_region1 = [
    { name = "branch1", dns = local.branch1_vm_dns, ip = local.branch1_vm_addr },
    { name = "hub1   ", dns = local.hub1_vm_dns, ip = local.hub1_vm_addr },
    { name = "hub1-pe", dns = local.hub1_pep_dns, ping = false },
    { name = "spoke1 ", dns = local.spoke1_vm_dns, ip = local.spoke1_vm_addr },
    { name = "spoke2 ", dns = local.spoke2_vm_dns, ip = local.spoke2_vm_addr },
    { name = "spoke3 ", dns = local.spoke3_vm_dns, ip = local.spoke3_vm_addr, ping = false },
  ]
  vm_script_targets_region2 = [
    { name = "branch3", dns = local.branch3_vm_dns, ip = local.branch3_vm_addr },
    { name = "hub2   ", dns = local.hub2_vm_dns, ip = local.hub2_vm_addr },
    { name = "hub2-pe", dns = local.hub2_pep_dns, ping = false },
    { name = "spoke4 ", dns = local.spoke4_vm_dns, ip = local.spoke4_vm_addr },
    { name = "spoke5 ", dns = local.spoke5_vm_dns, ip = local.spoke5_vm_addr },
    { name = "spoke6 ", dns = local.spoke6_vm_dns, ip = local.spoke6_vm_addr, ping = false },
  ]
  vm_script_targets_misc = [
    { name = "internet", dns = "icanhazip.com", ip = "icanhazip.com" },
  ]
  vm_script_targets = concat(
    local.vm_script_targets_region1,
    local.vm_script_targets_region2,
    local.vm_script_targets_misc,
  )
  vm_startup = templatefile("../../scripts/server.sh", {
    TARGETS = local.vm_script_targets
  })
  branch_unbound_config = templatefile("../../scripts/unbound.sh", {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    FORWARD_ZONES        = local.onprem_forward_zones
    TARGETS              = local.vm_script_targets_region1
  })
  branch_unbound_vars = {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    FORWARD_ZONES        = local.onprem_forward_zones
    TARGETS              = local.vm_script_targets_region1
  }
  onprem_local_records = [
    { name = (local.branch1_vm_dns), record = local.branch1_vm_addr },
    { name = (local.branch2_vm_dns), record = local.branch2_vm_addr },
    { name = (local.branch3_vm_dns), record = local.branch3_vm_addr },
  ]
  onprem_forward_zones = [
    { zone = "${local.cloud_domain}.", targets = [local.hub1_dns_in_addr, local.hub2_dns_in_addr], },
    { zone = ".", targets = [local.azuredns, ] },
  ]
  onprem_redirected_hosts = []
}

####################################################
# nsg
####################################################

# region1
#----------------------------

# nsg

resource "azurerm_network_security_group" "nsg_region1_main" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.prefix}-nsg-${local.region1}-main"
  location            = local.region1
}

resource "azurerm_network_security_group" "nsg_region1_nva" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.prefix}-nsg-${local.region1}-nva"
  location            = local.region1
}

resource "azurerm_network_security_group" "nsg_region1_appgw" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.prefix}-nsg-${local.region1}-appgw"
  location            = local.region1
}

resource "azurerm_network_security_group" "nsg_region1_default" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.prefix}-nsg-${local.region1}-default"
  location            = local.region1
}

# rules

locals {
  nsg_region1_main_rules = {
    "allow-public-web"  = { priority = 100, direction = "Inbound", src = ["0.0.0.0/0", ], protocol = "Tcp", destination_port = "80" }
    "allow-public-icmp" = { priority = 110, direction = "Inbound", src = ["0.0.0.0/0", ], protocol = "Icmp" }
  }
}

resource "azurerm_network_security_rule" "nsg_region1_main" {
  for_each                    = local.nsg_region1_main_rules
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg_region1_main.name
  name                        = each.key
  direction                   = each.value.direction
  access                      = "Allow"
  priority                    = each.value.priority
  source_address_prefixes     = each.value.src
  source_port_range           = "*"
  destination_address_prefix  = "*"
  destination_port_range      = try(each.value.destination_port, "*")
  protocol                    = each.value.protocol
  description                 = each.key
}

# region2
#----------------------------

resource "azurerm_network_security_group" "nsg_region2_main" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.prefix}-nsg-${local.region2}-main"
  location            = local.region2
}

resource "azurerm_network_security_group" "nsg_region2_nva" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.prefix}-nsg-${local.region2}-nva"
  location            = local.region2
}

resource "azurerm_network_security_group" "nsg_region2_appgw" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.prefix}-nsg-${local.region2}-appgw"
  location            = local.region2
}

resource "azurerm_network_security_group" "nsg_region2_default" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.prefix}-nsg-${local.region2}-default"
  location            = local.region2
}

####################################################
# addresses
####################################################

resource "azurerm_public_ip" "branch1_nva_pip" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.branch1_prefix}nva-pip"
  location            = local.branch1_location
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "branch3_nva_pip" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.branch3_prefix}nva-pip"
  location            = local.branch3_location
  sku                 = "Standard"
  allocation_method   = "Static"
}

####################################################
# firewall policy
####################################################

# policy

resource "azurerm_firewall_policy" "firewall_policy" {
  for_each                 = local.regions
  resource_group_name      = azurerm_resource_group.rg.name
  name                     = "${local.prefix}-fw-policy-${each.key}"
  location                 = each.value
  threat_intelligence_mode = "Alert"
  sku                      = local.firewall_sku

  private_ip_ranges = concat(
    local.private_prefixes,
    [
      "${local.spoke3_vm_public_ip}/32",
      "${local.spoke6_vm_public_ip}/32",
    ]
  )

  #dns {
  #  proxy_enabled = true
  #}
}

# collection

module "fw_policy_rule_collection_group" {
  for_each           = local.regions
  source             = "../../modules/fw-policy"
  prefix             = local.prefix
  firewall_policy_id = azurerm_firewall_policy.firewall_policy[each.key].id

  network_rule_collection = [
    {
      name     = "network-rc"
      priority = 100
      action   = "Allow"
      rule = [
        {
          name                  = "network-rc-any-to-any"
          source_addresses      = ["*"]
          destination_addresses = ["*"]
          protocols             = ["Any"]
          destination_ports     = ["*"]
        }
      ]
    }
  ]
  application_rule_collection = []
  nat_rule_collection         = []
}
