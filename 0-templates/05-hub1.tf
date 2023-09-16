
####################################################
# base
####################################################

module "hub1" {
  source          = "../../modules/base"
  resource_group  = azurerm_resource_group.rg.name
  prefix          = trimsuffix(local.hub1_prefix, "-")
  location        = local.hub1_location
  storage_account = module.common.storage_accounts["region1"]

  private_dns_zone = local.hub1_dns_zone
  dns_zone_linked_vnets = {
    #"spoke1" = { vnet = module.spoke1.vnet.id, registration_enabled = false }
    #"spoke2" = { vnet = module.spoke2.vnet.id, registration_enabled = false }
  }
  dns_zone_linked_rulesets = {
    #"hub1" = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub1_onprem.id
  }

  nsg_subnet_map = {
    "${local.hub1_prefix}main" = module.common.nsg_main["region1"].id
    "${local.hub1_prefix}nva"  = module.common.nsg_nva["region1"].id
    "${local.hub1_prefix}ilb"  = module.common.nsg_default["region1"].id
  }

  vnet_config = [
    {
      address_space = local.hub1_address_space
      subnets       = local.hub1_subnets

      private_dns_inbound_subnet_name  = "${local.hub1_prefix}dns-in"
      private_dns_outbound_subnet_name = "${local.hub1_prefix}dns-out"

      enable_private_dns_resolver = local.hub1_features.enable_private_dns_resolver
      enable_ars                  = local.hub1_features.enable_ars
      enable_vpn_gateway          = local.hub1_features.enable_vpn_gateway
      enable_er_gateway           = local.hub1_features.enable_er_gateway

      vpn_gateway_sku = "VpnGw2AZ"
      vpn_gateway_asn = local.hub1_vpngw_asn
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

####################################################
# dns resolver ruleset
####################################################
/*
# onprem

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "hub1_onprem" {
  resource_group_name                        = azurerm_resource_group.rg.name
  name                                       = "${local.hub1_prefix}onprem"
  location                                   = local.hub1_location
  private_dns_resolver_outbound_endpoint_ids = [module.hub1.private_dns_outbound_ep.id]
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
    ip_address = local.branch3_dns_addr
    port       = 53
  }
}

# cloud

resource "azurerm_private_dns_resolver_dns_forwarding_ruleset" "hub1_cloud" {
  resource_group_name                        = azurerm_resource_group.rg.name
  name                                       = "${local.hub1_prefix}cloud"
  location                                   = local.hub1_location
  private_dns_resolver_outbound_endpoint_ids = [module.hub1.private_dns_outbound_ep.id]
}

resource "azurerm_private_dns_resolver_forwarding_rule" "hub1_cloud" {
  name                      = "${local.hub1_prefix}cloud"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub1_cloud.id
  domain_name               = "${local.cloud_domain}."
  enabled                   = true
  target_dns_servers {
    ip_address = local.hub2_dns_in_addr
    port       = 53
  }
}
/*
####################################################
# private endpoint
####################################################

resource "azurerm_private_endpoint" "hub1_spoke3_pe" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.hub1_prefix}spoke3-pe"
  location            = local.hub1_location
  subnet_id           = module.hub1.subnets["${local.hub1_prefix}pep"].id

  private_service_connection {
    name                           = "${local.hub1_prefix}spoke3-pe-psc"
    private_connection_resource_id = module.spoke3_pls.private_link_service_id
    is_manual_connection           = false
  }
}

resource "azurerm_private_dns_a_record" "hub1_spoke3_pe" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = local.hub1_pep_dns_host
  zone_name           = local.hub1_dns_zone
  ttl                 = 300
  records             = [azurerm_private_endpoint.hub1_spoke3_pe.private_service_connection[0].private_ip_address, ]
}*/
