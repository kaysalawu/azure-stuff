
####################################################
# dns resolver ruleset
####################################################

# ruleset
#---------------------------

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

# links
#---------------------------

locals {
  dns_zone_linked_rulesets_hub1_onprem = {
    "hub1"   = module.hub1.vnet.id
    "spoke1" = module.spoke1.vnet.id
    "spoke2" = module.spoke2.vnet.id
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "hub1" {
  for_each                  = local.dns_zone_linked_rulesets_hub1_onprem
  name                      = "${local.prefix}${each.key}-vnet-link"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub1_onprem.id
  virtual_network_id        = each.value
}

