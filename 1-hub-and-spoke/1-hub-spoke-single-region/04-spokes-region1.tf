
####################################################
# spoke1
####################################################

# env
#----------------------------

module "spoke1" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.spoke1_prefix, "-")
  location        = local.spoke1_location
  storage_account = azurerm_storage_account.region1

  private_dns_zone = local.spoke1_dns_zone
  dns_zone_linked_vnets = {
    "hub1" = { vnet = module.hub1.vnet.0.id, registration_enabled = false }
  }
  dns_zone_linked_rulesets = {
    "hub1" = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub1_onprem.id
  }

  nsg_config = {
    "${local.spoke1_prefix}main"  = azurerm_network_security_group.nsg_region1_main.id
    "${local.spoke1_prefix}appgw" = azurerm_network_security_group.nsg_region1_appgw.id
    "${local.spoke1_prefix}ilb"   = azurerm_network_security_group.nsg_region1_default.id
  }

  vnet_config = [
    {
      address_space       = local.spoke1_address_space
      subnets             = local.spoke1_subnets
      subnets_nat_gateway = ["${local.spoke2_prefix}main", ]
    }
  ]

  vm_config = [
    {
      name         = local.spoke1_vm_dns_host
      subnet       = "${local.spoke1_prefix}main"
      private_ip   = local.spoke1_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
    }
  ]
}

####################################################
# spoke2
####################################################

# env
#----------------------------

module "spoke2" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.spoke2_prefix, "-")
  location        = local.spoke2_location
  storage_account = azurerm_storage_account.region1

  private_dns_zone = local.spoke2_dns_zone
  dns_zone_linked_vnets = {
    "hub1" = { vnet = module.hub1.vnet.0.id, registration_enabled = false }
  }
  dns_zone_linked_rulesets = {
    "hub1" = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub1_onprem.id
  }

  nsg_config = {
    "main"  = azurerm_network_security_group.nsg_region1_main.id
    "appgw" = azurerm_network_security_group.nsg_region1_appgw.id
    "ilb"   = azurerm_network_security_group.nsg_region1_default.id
  }

  vnet_config = [
    {
      address_space = local.spoke2_address_space
      subnets       = local.spoke2_subnets
    }
  ]

  vm_config = [
    {
      name         = local.spoke2_vm_dns_host
      subnet       = "${local.spoke2_prefix}main"
      private_ip   = local.spoke2_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
    }
  ]
}
