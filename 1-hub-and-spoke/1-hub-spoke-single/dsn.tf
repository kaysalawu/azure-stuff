
/*
resource "azurerm_private_dns_zone_virtual_network_link" "external" {
  for_each              = { for k, v in var.dns_zone_linked_vnets : k => v if var.private_dns_zone != null }
  resource_group_name   = var.resource_group
  name                  = "${local.prefix}${each.key}-vnet-link"
  private_dns_zone_name = azurerm_private_dns_zone.this[0].name
  virtual_network_id    = each.value
  registration_enabled  = each.value.registration_enabled
  timeouts {
    create = "60m"
  }
}*/

/*ource "azurerm_private_dns_resolver_virtual_network_link" "this" {
  count                     = var.vnet_config[0].enable_private_dns_resolver ? 1 : 0
  name                      = "${local.prefix}vnet-link"
  dns_forwarding_ruleset_id = each.value.ruleset_id
  virtual_network_id        = azurerm_virtual_network.this.id
  timeouts {
    create = "60m"
  }
}*/
