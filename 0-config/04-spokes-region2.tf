
####################################################
# spoke4
####################################################

# base

module "spoke4" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.spoke4_prefix, "-")
  location        = local.spoke4_location
  storage_account = azurerm_storage_account.region2

  private_dns_zone = local.spoke4_dns_zone
  dns_zone_linked_vnets = {
    "hub2" = { vnet = module.hub2.vnet.id, registration_enabled = false }
  }
  dns_zone_linked_rulesets = {
    "hub2" = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub2_onprem.id
  }

  nsg_config = {
    "${local.spoke4_prefix}main"  = azurerm_network_security_group.nsg_region2_main.id
    "${local.spoke4_prefix}appgw" = azurerm_network_security_group.nsg_region2_appgw.id
    "${local.spoke4_prefix}ilb"   = azurerm_network_security_group.nsg_region2_default.id
  }

  vnet_config = [
    {
      address_space       = local.spoke4_address_space
      subnets             = local.spoke4_subnets
      subnets_nat_gateway = ["${local.spoke4_prefix}main", ]
    }
  ]

  vm_config = [
    {
      name         = local.spoke4_vm_dns_host
      subnet       = "${local.spoke4_prefix}main"
      private_ip   = local.spoke4_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
    }
  ]
}

####################################################
# spoke5
####################################################

# base

module "spoke5" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.spoke5_prefix, "-")
  location        = local.spoke5_location
  storage_account = azurerm_storage_account.region2

  private_dns_zone = local.spoke5_dns_zone
  dns_zone_linked_vnets = {
    "hub2" = { vnet = module.hub2.vnet.id, registration_enabled = false }
  }
  dns_zone_linked_rulesets = {
    "hub2" = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub2_onprem.id
  }

  nsg_config = {
    "main"  = azurerm_network_security_group.nsg_region2_main.id
    "appgw" = azurerm_network_security_group.nsg_region2_appgw.id
    "ilb"   = azurerm_network_security_group.nsg_region2_default.id
  }

  vnet_config = [
    {
      address_space = local.spoke5_address_space
      subnets       = local.spoke5_subnets
    }
  ]

  vm_config = [
    {
      name         = local.spoke5_vm_dns_host
      subnet       = "${local.spoke5_prefix}main"
      private_ip   = local.spoke5_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
    }
  ]
}
