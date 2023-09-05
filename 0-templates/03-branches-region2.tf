
####################################################
# branch3
####################################################

# env
#----------------------------

module "branch3" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.branch3_prefix, "-")
  location        = local.branch3_location
  storage_account = module.common.storage_accounts["region2"]

  nsg_config = {
    #"${local.branch3_prefix}main" = module.common.nsg_main["region2"].id
    #"${local.branch3_prefix}int"  = module.common.nsg_main["region2"].id
    #"${local.branch3_prefix}ext"  = module.common.nsg_nva["region2"].id
  }

  vnet_config = [
    {
      address_space = local.branch3_address_space
      subnets       = local.branch3_subnets
    }
  ]

  vm_config = [
    {
      name             = "vm1"
      subnet           = "${local.branch3_prefix}main"
      private_ip       = local.branch3_vm_addr
      custom_data      = base64encode(local.vm_startup)
      source_image     = "ubuntu"
      dns_servers      = [local.branch3_dns_addr, ]
      use_vm_extension = false
      #delay_creation   = "60s"
    },
    {
      name             = "dns"
      subnet           = "${local.branch3_prefix}main"
      private_ip       = local.branch3_dns_addr
      custom_data      = base64encode(local.branch_unbound_config)
      source_image     = "debian"
      use_vm_extension = true
    }
  ]
}
