
locals {
  #hub2_vpngw_bgp0  = module.hub2.vpngw.bgp_settings[0].peering_addresses[0].default_addresses[0]
  #hub2_vpngw_bgp1  = module.hub2.vpngw.bgp_settings[0].peering_addresses[1].default_addresses[0]
  #hub2_ars_bgp0    = tolist(module.hub2.ars.virtual_router_ips)[0]
  #hub2_ars_bgp1    = tolist(module.hub2.ars.virtual_router_ips)[1]
  #hub2_firewall_ip = module.hub2.firewall.ip_configuration[0].private_ip_address
  #hub2_ars_bgp_asn = module.hub2.ars.virtual_router_asn
  hub2_dns_in_ip = module.hub2.private_dns_inbound_ep.ip_configurations[0].private_ip_address

}

####################################################
# base
####################################################

module "hub2" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.hub2_prefix, "-")
  location        = local.hub2_location
  storage_account = azurerm_storage_account.region2

  private_dns_zone = local.hub2_dns_zone
  dns_zone_linked_vnets = {
    "spoke4" = { vnet = module.spoke4.vnet.id, registration_enabled = false }
    "spoke5" = { vnet = module.spoke5.vnet.id, registration_enabled = false }
  }
  dns_zone_linked_rulesets = {
    "hub2" = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub2_onprem.id
  }

  nsg_config = {
    "${local.hub2_prefix}main" = azurerm_network_security_group.nsg_region2_main.id
    "${local.hub2_prefix}nva"  = azurerm_network_security_group.nsg_region2_nva.id
    "${local.hub2_prefix}ilb"  = azurerm_network_security_group.nsg_region2_default.id
  }

  vnet_config = [
    {
      address_space               = local.hub2_address_space
      subnets                     = local.hub2_subnets
      enable_private_dns_resolver = true
      enable_ergw                 = false
      enable_vpngw                = false
      enable_ars                  = false
      enable_firewall             = false
    }
  ]

  vm_config = [
    {
      name         = local.hub2_vm_dns_host
      subnet       = "${local.hub2_prefix}main"
      private_ip   = local.hub2_vm_addr
      custom_data  = base64encode(local.vm_startup)
      source_image = "ubuntu"
    }
  ]
}

####################################################
# internal lb
####################################################

resource "azurerm_lb" "hub2_nva_lb" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.hub2_prefix}nva-lb"
  location            = local.hub2_location
  sku                 = "Standard"
  frontend_ip_configuration {
    name                          = "${local.hub2_prefix}nva-lb-feip"
    subnet_id                     = module.hub2.subnets["${local.hub2_prefix}ilb"].id
    private_ip_address            = local.hub2_nva_ilb_addr
    private_ip_address_allocation = "Static"
  }

  lifecycle {
    ignore_changes = [frontend_ip_configuration, ]
  }
}

# backend

resource "azurerm_lb_backend_address_pool" "hub2_nva" {
  name            = "${local.hub2_prefix}nva-beap"
  loadbalancer_id = azurerm_lb.hub2_nva_lb.id
}

resource "azurerm_lb_backend_address_pool_address" "hub2_nva" {
  name                    = "${local.hub2_prefix}nva-beap-addr"
  backend_address_pool_id = azurerm_lb_backend_address_pool.hub2_nva.id
  virtual_network_id      = module.hub2.vnet.id
  ip_address              = local.hub2_nva_addr
}

# probe

resource "azurerm_lb_probe" "hub2_nva1_lb_probe" {
  name                = "${local.hub2_prefix}nva-probe"
  interval_in_seconds = 5
  number_of_probes    = 2
  loadbalancer_id     = azurerm_lb.hub2_nva_lb.id
  port                = 22
  protocol            = "Tcp"
}

# rule

resource "azurerm_lb_rule" "hub2_nva" {
  name     = "${local.hub2_prefix}nva-rule"
  protocol = "All"
  backend_address_pool_ids = [
    azurerm_lb_backend_address_pool.hub2_nva.id
  ]
  loadbalancer_id                = azurerm_lb.hub2_nva_lb.id
  frontend_port                  = 0
  backend_port                   = 0
  frontend_ip_configuration_name = "${local.hub2_prefix}nva-lb-feip"
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 30
  load_distribution              = "Default"
  probe_id                       = azurerm_lb_probe.hub2_nva1_lb_probe.id
}

####################################################
# dns resolver ruleset
####################################################

# onprem

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "hub2_onprem" {
  resource_group_name                        = azurerm_resource_group.rg.name
  name                                       = "${local.hub2_prefix}onprem"
  location                                   = local.hub2_location
  private_dns_resolver_outbound_endpoint_ids = [module.hub2.private_dns_outbound_ep.id]
}

resource "azurerm_private_dns_resolver_forwarding_rule" "hub2_onprem" {
  name                      = "${local.hub2_prefix}onprem"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub2_onprem.id
  domain_name               = "${local.onprem_domain}."
  enabled                   = true
  target_dns_servers {
    ip_address = local.branch3_dns_addr
    port       = 53
  }
  target_dns_servers {
    ip_address = local.branch1_dns_addr
    port       = 53
  }
}

# cloud

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "hub2_cloud" {
  resource_group_name                        = azurerm_resource_group.rg.name
  name                                       = "${local.hub2_prefix}cloud"
  location                                   = local.hub2_location
  private_dns_resolver_outbound_endpoint_ids = [module.hub2.private_dns_outbound_ep.id]
}

resource "azurerm_private_dns_resolver_forwarding_rule" "hub2_cloud" {
  name                      = "${local.hub2_prefix}cloud"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub2_cloud.id
  domain_name               = "${local.cloud_domain}."
  enabled                   = true
  target_dns_servers {
    ip_address = local.hub1_dns_in_addr
    port       = 53
  }
}

####################################################
# private endpoint
####################################################

resource "azurerm_private_endpoint" "hub2_spoke6_pe" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.hub2_prefix}spoke6-pe"
  location            = local.hub2_location
  subnet_id           = module.hub2.subnets["${local.hub2_prefix}pep"].id

  private_service_connection {
    name                           = "${local.hub2_prefix}spoke6-pe-psc"
    private_connection_resource_id = module.spoke6_pls.private_link_service_id
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_a_record" "hub2_spoke6_pe" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = local.hub1_pep_dns_host
  zone_name           = local.hub2_dns_zone
  ttl                 = 300
  records             = [azurerm_private_endpoint.hub2_spoke6_pe.private_service_connection[0].private_ip_address, ]
}
