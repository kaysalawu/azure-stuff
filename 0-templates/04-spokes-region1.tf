
locals {
  #spoke3_vm_public_ip = module.spoke3.vm_public_ip[local.spoke3_vm_name]
}

####################################################
# spoke1
####################################################

# base

module "spoke1" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.spoke1_prefix, "-")
  location        = local.spoke1_location
  storage_account = module.common.storage_accounts["region1"]

  private_dns_zone_name = azurerm_private_dns_zone.global.name
  private_dns_prefix    = local.spoke1_dns_zone

  nsg_subnet_map = {
    "${local.spoke1_prefix}main"  = module.common.nsg_main["region1"].id
    "${local.spoke1_prefix}appgw" = module.common.nsg_appgw["region1"].id
    "${local.spoke1_prefix}ilb"   = module.common.nsg_default["region1"].id
  }

  vnet_config = [
    {
      address_space = local.spoke1_address_space
      subnets       = local.spoke1_subnets
      #subnets_nat_gateway = ["${local.spoke1_prefix}main", ]
    }
  ]

  vm_config = [
    {
      name         = "vm"
      dns_host     = local.spoke1_vm_dns_host
      subnet       = "${local.spoke1_prefix}main"
      private_ip   = local.spoke1_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
    }
  ]
  depends_on = [
    module.common,
  ]
}

####################################################
# spoke2
####################################################

# base

module "spoke2" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.spoke2_prefix, "-")
  location        = local.spoke2_location
  storage_account = module.common.storage_accounts["region1"]

  private_dns_zone_name = azurerm_private_dns_zone.global.name
  private_dns_prefix    = local.spoke2_dns_zone

  nsg_subnet_map = {
    "${local.spoke2_prefix}main"  = module.common.nsg_main["region1"].id
    "${local.spoke2_prefix}appgw" = module.common.nsg_appgw["region1"].id
    "${local.spoke2_prefix}ilb"   = module.common.nsg_default["region1"].id
  }

  vnet_config = [
    {
      address_space = local.spoke2_address_space
      subnets       = local.spoke2_subnets
    }
  ]

  vm_config = [
    {
      name         = "vm"
      dns_host     = local.spoke2_vm_dns_host
      subnet       = "${local.spoke2_prefix}main"
      private_ip   = local.spoke2_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
    }
  ]
  depends_on = [
    module.common,
  ]
}

####################################################
# spoke3
####################################################

# base

module "spoke3" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.spoke3_prefix, "-")
  location        = local.spoke3_location
  storage_account = module.common.storage_accounts["region1"]

  private_dns_zone_name = azurerm_private_dns_zone.global.name
  private_dns_prefix    = local.spoke3_dns_zone

  nsg_subnet_map = {
    "${local.spoke3_prefix}main"  = module.common.nsg_main["region1"].id
    "${local.spoke3_prefix}appgw" = module.common.nsg_appgw["region1"].id
    "${local.spoke3_prefix}ilb"   = module.common.nsg_default["region1"].id
  }

  vnet_config = [
    {
      address_space = local.spoke3_address_space
      subnets       = local.spoke3_subnets
      #subnets_nat_gateway = ["${local.spoke3_prefix}main", ]
    }
  ]

  vm_config = [
    {
      name             = "vm"
      dns_host         = local.spoke3_vm_dns_host
      subnet           = "${local.spoke3_prefix}main"
      private_ip       = local.spoke3_vm_addr
      enable_public_ip = true
      custom_data      = base64encode(local.vm_startup)
      source_image     = "ubuntu"
    }
  ]
  depends_on = [
    module.common,
  ]
}
/*
# ilb
#----------------------------

# internal load balancer

module "spoke3_lb" {
  source                                 = "../../modules/azlb"
  resource_group_name                    = azurerm_resource_group.rg.name
  location                               = local.spoke3_location
  prefix                                 = trimsuffix(local.spoke3_prefix, "-")
  type                                   = "private"
  private_dns_zone                       = local.spoke3_dns_zone
  dns_host                               = local.spoke3_ilb_dns_host
  frontend_subnet_id                     = module.spoke3.subnets["${local.spoke3_prefix}ilb"].id
  frontend_private_ip_address_allocation = "Static"
  frontend_private_ip_address            = local.spoke3_ilb_addr
  lb_sku                                 = "Standard"

  remote_port = { ssh = ["Tcp", "80"] }
  lb_port     = { http = ["80", "Tcp", "80"] }
  lb_probe    = { http = ["Tcp", "80", ""] }

  backends = [
    {
      name                  = module.spoke3.vm[local.spoke3_vm_dns_host].name
      ip_configuration_name = module.spoke3.vm_interface[local.spoke3_vm_dns_host].ip_configuration[0].name
      network_interface_id  = module.spoke3.vm_interface[local.spoke3_vm_dns_host].id
    }
  ]
}

# private link service

module "spoke3_pls" {
  source           = "../../modules/privatelink"
  resource_group   = azurerm_resource_group.rg.name
  location         = local.spoke3_location
  prefix           = trimsuffix(local.spoke3_prefix, "-")
  private_dns_zone = local.spoke3_dns_zone
  dns_host         = local.spoke3_ilb_dns_host

  nat_ip_config = [
    {
      name            = "pls-nat-ip-config"
      primary         = true
      subnet_id       = module.spoke3.subnets["${local.spoke3_prefix}pls"].id
      lb_frontend_ids = [module.spoke3_lb.frontend_ip_configuration[0].id, ]
    }
  ]
}*/
