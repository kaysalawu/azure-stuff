

# nsg
#----------------------------

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each                  = var.nsg_config
  subnet_id                 = [for k, v in azurerm_subnet.this : v.id if length(regexall("${each.key}", k)) > 0][0]
  network_security_group_id = each.value
  timeouts {
    create = "60m"
  }
}
