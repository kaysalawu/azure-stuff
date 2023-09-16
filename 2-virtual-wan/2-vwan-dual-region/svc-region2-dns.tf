
####################################################
# dns resolver ruleset
####################################################

# ruleset
#---------------------------

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

# links
#---------------------------

locals {
  dns_zone_linked_rulesets_hub2_onprem = {
    "hub2"   = module.hub2.vnet.id
    "spoke4" = module.spoke4.vnet.id
    "spoke5" = module.spoke5.vnet.id
  }
}

resource "azurerm_private_dns_resolver_virtual_network_link" "hub2" {
  for_each                  = local.dns_zone_linked_rulesets_hub2_onprem
  name                      = "${local.prefix}${each.key}-vnet-link"
  dns_forwarding_ruleset_id = azurerm_private_dns_resolver_dns_forwarding_ruleset.hub2_onprem.id
  virtual_network_id        = each.value
}

