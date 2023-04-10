
# env
#----------------------------

module "hub1" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.hub1_prefix, "-")
  location        = local.hub1_location
  storage_account = azurerm_storage_account.region1

  private_dns_zone = local.hub1_dns_zone
  dns_zone_linked_vnets = {
    "spoke1" = { vnet = module.spoke1.vnet.0.id, registration_enabled = false }
    "spoke2" = { vnet = module.spoke2.vnet.0.id, registration_enabled = false }
  }
  dns_zone_linked_rulesets = {
    "hub1" = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub1_onprem.id
  }

  nsg_config = {
    "${local.hub1_prefix}main" = azurerm_network_security_group.nsg_region1_main.id
    "${local.hub1_prefix}nva"  = azurerm_network_security_group.nsg_region1_nva.id
    "${local.hub1_prefix}ilb"  = azurerm_network_security_group.nsg_region1_default.id
  }

  vnet_config = [
    {
      address_space               = local.hub1_address_space
      subnets                     = local.hub1_subnets
      enable_private_dns_resolver = true
      enable_ergw                 = false
      enable_vpngw                = true
      enable_ars                  = true

      vpngw_config = [
        {
          asn = local.hub1_vpngw_asn
        }
      ]
    }
  ]

  vm_config = [
    {
      name         = local.hub1_vm_dns_host
      subnet       = "${local.hub1_prefix}main"
      private_ip   = local.hub1_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
    }
  ]
}
/*
# udr
#----------------------------

# route table

resource "azurerm_route_table" "hub1_vpngw_rt" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.hub1_prefix}vpngw-rt"
  location            = local.region1

  disable_bgp_route_propagation = false
}

# routes

locals {
  hub1_vpngw_routes = {
    spoke2 = local.spoke2_address_space[0],
    spoke3 = local.spoke3_address_space[0],
  }
}

resource "azurerm_route" "hub1_vpngw_rt_routes" {
  for_each               = local.hub1_vpngw_routes
  resource_group_name    = azurerm_resource_group.rg.name
  name                   = "${local.hub1_prefix}vpngw-rt-${each.key}-route"
  route_table_name       = azurerm_route_table.hub1_vpngw_rt.name
  address_prefix         = each.value
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.hub1_nva_ilb_addr
}

# association

resource "azurerm_subnet_route_table_association" "hub1_vpngw_rt_spoke_route" {
  subnet_id      = module.hub1.subnets["GatewaySubnet"].id
  route_table_id = azurerm_route_table.hub1_vpngw_rt.id
}

# internal lb
#----------------------------

resource "azurerm_lb" "hub1_nva_lb" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.hub1_prefix}nva-lb"
  location            = local.hub1_location
  sku                 = "Standard"
  frontend_ip_configuration {
    name                          = "${local.hub1_prefix}nva-lb-feip"
    subnet_id                     = module.hub1.subnets["${local.hub1_prefix}ilb"].id
    private_ip_address            = local.hub1_nva_ilb_addr
    private_ip_address_allocation = "Static"
  }

  lifecycle {
    ignore_changes = [frontend_ip_configuration, ]
  }
}

# backend

resource "azurerm_lb_backend_address_pool" "hub1_nva" {
  name            = "${local.hub1_prefix}nva-beap"
  loadbalancer_id = azurerm_lb.hub1_nva_lb.id
}

resource "azurerm_lb_backend_address_pool_address" "hub1_nva" {
  name                    = "${local.hub1_prefix}nva-beap-addr"
  backend_address_pool_id = azurerm_lb_backend_address_pool.hub1_nva.id
  virtual_network_id      = module.hub1.vnet.id
  ip_address              = local.hub1_nva_addr
}

# probe

resource "azurerm_lb_probe" "hub1_nva1_lb_probe" {
  name                = "${local.hub1_prefix}nva-probe"
  interval_in_seconds = 5
  number_of_probes    = 2
  loadbalancer_id     = azurerm_lb.hub1_nva_lb.id
  port                = 22
  protocol            = "Tcp"
}

# rule

resource "azurerm_lb_rule" "hub1_nva" {
  name     = "${local.hub1_prefix}nva-rule"
  protocol = "All"
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.hub1_nva.id
  ]
  loadbalancer_id                = azurerm_lb.hub1_nva_lb.id
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "${local.hub1_prefix}nva-lb-feip"
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 30
  load_distribution              = "Default"
  probe_id                       = azurerm_lb_probe.hub1_nva1_lb_probe.id
}*/

# dns resolver ruleset
#----------------------------

# onprem

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "hub1_onprem" {
  resource_group_name                        = azurerm_resource_group.rg.name
  name                                       = "${local.hub1_prefix}onprem"
  location                                   = local.hub1_location
  private_dns_resolver_outbound_endpoint_ids = [module.hub1.private_dns_outbound_ep.0.id]
}

resource "azurerm_private_dns_resolver_forwarding_rule" "hub1_onprem" {
  name                      = "${local.hub1_prefix}onprem"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub1_onprem.id
  domain_name               = "${local.onprem_domain}."
  enabled                   = true
  target_dns_servers {
    ip_address = local.branch1_dns_addr
    port       = 53
  }
  target_dns_servers {
    ip_address = local.branch2_dns_addr
    port       = 53
  }
}

