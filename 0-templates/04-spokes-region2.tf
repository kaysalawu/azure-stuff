
####################################################
# spoke4
####################################################

# base

module "spoke4" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.spoke4_prefix, "-")
  location        = local.spoke4_location
  storage_account = module.common.storage_accounts["region2"]

  private_dns_zone = local.spoke4_dns_zone
  dns_zone_linked_vnets = {
    "hub2" = { vnet = module.hub2.vnet.id, registration_enabled = false }
  }
  dns_zone_linked_rulesets = {
    #"hub2" = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub2_onprem.id
  }

  nsg_subnet_map = {
    "${local.spoke4_prefix}main"  = azurerm_network_security_group.nsg_region2_main.id
    "${local.spoke4_prefix}appgw" = azurerm_network_security_group.nsg_region2_appgw.id
    "${local.spoke4_prefix}ilb"   = azurerm_network_security_group.nsg_region2_default.id
  }

  vnet_config = [
    {
      address_space = local.spoke4_address_space
      subnets       = local.spoke4_subnets
      #subnets_nat_gateway = ["${local.spoke4_prefix}main", ]
    }
  ]

  vm_config = [
    {
      name         = local.spoke4_vm_dns_host
      subnet       = "${local.spoke4_prefix}main"
      private_ip   = local.spoke4_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
      #dns_servers      = [local.hub2_dns_in_ip, ]
      use_vm_extension = true
      delay_creation   = "60s"
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
  storage_account = module.common.storage_accounts["region2"]

  private_dns_zone = local.spoke5_dns_zone
  dns_zone_linked_vnets = {
    "hub2" = { vnet = module.hub2.vnet.id, registration_enabled = false }
  }
  dns_zone_linked_rulesets = {
    #"hub2" = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub2_onprem.id
  }

  nsg_subnet_map = {
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
      #dns_servers      = [local.hub2_dns_in_ip, ]
      use_vm_extension = true
      #delay_creation = "60s"
    }
  ]
  depends_on = [module.hub2, ]
}

####################################################
# spoke6
####################################################

# base

module "spoke6" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.spoke6_prefix, "-")
  location        = local.spoke6_location
  storage_account = module.common.storage_accounts["region2"]

  private_dns_zone         = local.spoke6_dns_zone
  dns_zone_linked_vnets    = {}
  dns_zone_linked_rulesets = {}

  nsg_subnet_map = {
    "main"  = azurerm_network_security_group.nsg_region2_main.id
    "ilb"   = azurerm_network_security_group.nsg_region2_default.id
    "appgw" = azurerm_network_security_group.nsg_region2_appgw.id
  }

  vnet_config = [
    {
      address_space = local.spoke6_address_space
      subnets       = local.spoke6_subnets
      #subnets_nat_gateway = ["${local.spoke6_prefix}main", ]
    }
  ]

  vm_config = [
    {
      name         = local.spoke6_vm_dns_host
      subnet       = "${local.spoke6_prefix}main"
      private_ip   = local.spoke6_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
      #dns_servers      = [local.hub2_dns_in_ip, ]
      use_vm_extension = true
      #delay_creation   = "60s"
    }
  ]
}

# ilb
#----------------------------
/*
# internal load balancer

module "spoke6_lb" {
  source                                 = "../../modules/azlb"
  resource_group_name                    = azurerm_resource_group.rg.name
  location                               = local.spoke6_location
  prefix                                 = trimsuffix(local.spoke6_prefix, "-")
  type                                   = "private"
  private_dns_zone                       = local.spoke6_dns_zone
  dns_host                               = local.spoke6_ilb_dns_host
  frontend_subnet_id                     = module.spoke6.subnets["${local.spoke6_prefix}ilb"].id
  frontend_private_ip_address_allocation = "Static"
  frontend_private_ip_address            = local.spoke6_ilb_addr
  lb_sku                                 = "Standard"

  remote_port = { ssh = ["Tcp", "80"] }
  lb_port     = { http = ["80", "Tcp", "80"] }
  lb_probe    = { http = ["Tcp", "80", ""] }

  backends = [
    {
      name                  = module.spoke6.vm[local.spoke6_vm_dns_host].name
      ip_configuration_name = module.spoke6.interface[local.spoke6_vm_dns_host].ip_configuration[0].name
      network_interface_id  = module.spoke6.interface[local.spoke6_vm_dns_host].id
    }
  ]
}

# private link service

module "spoke6_pls" {
  source           = "../../modules/privatelink"
  resource_group   = azurerm_resource_group.rg.name
  location         = local.spoke6_location
  prefix           = trimsuffix(local.spoke6_prefix, "-")
  private_dns_zone = local.spoke6_dns_zone
  dns_host         = local.spoke6_ilb_dns_host

  nat_ip_config = [
    {
      name            = "pls-nat-ip-config"
      primary         = true
      subnet_id       = module.spoke6.subnets["${local.spoke6_prefix}pls"].id
      lb_frontend_ids = [module.spoke6_lb.frontend_ip_configuration[0].id, ]
    }
  ]
}*/
