
####################################################
# branch1
####################################################

# env
#----------------------------

module "branch1" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.branch1_prefix, "-")
  location        = local.branch1_location
  storage_account = module.common.storage_accounts["region1"]

  nsg_config = {
    "${local.branch1_prefix}main" = azurerm_network_security_group.nsg_region1_main.id
    "${local.branch1_prefix}int"  = azurerm_network_security_group.nsg_region1_main.id
    "${local.branch1_prefix}ext"  = azurerm_network_security_group.nsg_region1_nva.id
  }

  vnet_config = [
    {
      address_space = local.branch1_address_space
      subnets       = local.branch1_subnets
    }
  ]

  vm_config = [
    {
      name         = "vm1"
      subnet       = "${local.branch1_prefix}main"
      private_ip   = local.branch1_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
      dns_servers  = [local.branch1_dns_addr, ]
    },
    {
      name             = "dns"
      subnet           = "${local.branch1_prefix}main"
      private_ip       = local.branch1_dns_addr
      custom_data      = base64encode(local.branch_unbound_config)
      source_image     = "debian"
      use_vm_extension = true
    }
  ]
}

####################################################
# branch2
####################################################

# env
#----------------------------

module "branch2" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.branch2_prefix, "-")
  location        = local.branch2_location
  storage_account = module.common.storage_accounts["region1"]

  nsg_config = {
    "${local.branch2_prefix}main" = azurerm_network_security_group.nsg_region1_main.id
    "${local.branch2_prefix}int"  = azurerm_network_security_group.nsg_region1_main.id
    "${local.branch2_prefix}ext"  = azurerm_network_security_group.nsg_region1_nva.id
  }

  vnet_config = [
    {
      address_space = local.branch2_address_space
      subnets       = local.branch2_subnets
    }
  ]

  vm_config = [
    {
      name         = "vm1"
      subnet       = "${local.branch2_prefix}main"
      private_ip   = local.branch2_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
      dns_servers  = [local.branch2_dns_addr, ]
    },
    {
      name             = "dns"
      subnet           = "${local.branch2_prefix}main"
      private_ip       = local.branch2_dns_addr
      custom_data      = base64encode(local.branch_unbound_config)
      source_image     = "debian"
      use_vm_extension = true
    }
  ]
}
