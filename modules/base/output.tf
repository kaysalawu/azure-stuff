
output "vnet" {
  value = azurerm_virtual_network.this
}

output "subnets" {
  value = azurerm_subnet.this
}

output "private_dns_zone" {
  value = azurerm_private_dns_zone.this
}

output "vm" {
  value = { for k, v in module.vm : k => v.vm }
}

output "interface" {
  value = { for k, v in module.vm : k => v.interface }
}

output "private_dns_inbound_ep" {
  value = try(azurerm_private_dns_resolver_inbound_endpoint.this, {})
}

output "private_dns_outbound_ep" {
  value = try(azurerm_private_dns_resolver_outbound_endpoint.this, {})
}

output "ars_pip" {
  value = try(azurerm_public_ip.ars_pip, {})
}

output "ergw_pip" {
  value = try(azurerm_public_ip.ergw_pip, {})
}

output "vpngw_pip0" {
  value = try(azurerm_public_ip.vpngw_pip0, {})
}

output "vpngw_pip1" {
  value = try(azurerm_public_ip.vpngw_pip1, {})
}

output "ars" {
  value = try(azurerm_route_server.ars, {})
}

output "ergw" {
  value = try(azurerm_virtual_network_gateway.ergw, {})
}

output "vpngw" {
  value = try(azurerm_virtual_network_gateway.vpngw, {})
}
