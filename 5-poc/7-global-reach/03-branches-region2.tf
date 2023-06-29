
####################################################
# branch3
####################################################

# env
#----------------------------

module "branch3" {
  source         = "../../modules/base"
  resource_group = azurerm_resource_group.rg.name
  prefix         = trimsuffix(local.branch3_prefix, "-")
  location       = local.branch3_location
  #storage_account = azurerm_storage_account.region2

  nsg_config = {
    "${local.branch3_prefix}main" = azurerm_network_security_group.nsg_region2_main.id
    "${local.branch3_prefix}int"  = azurerm_network_security_group.nsg_region2_main.id
    "${local.branch3_prefix}ext"  = azurerm_network_security_group.nsg_region2_nva.id
  }

  vnet_config = [
    {
      address_space = local.branch3_address_space
      subnets       = local.branch3_subnets
      enable_ergw   = true
    }
  ]

  vm_config = [
    {
      name           = "vm1"
      subnet         = "${local.branch3_prefix}main"
      private_ip     = local.branch3_vm_addr
      custom_data    = base64encode(local.vm_startup)
      source_image   = "ubuntu"
      dns_servers    = [local.branch3_dns_addr, ]
      delay_creation = "60s"
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
