
####################################################
# base
####################################################

module "hub1" {
  source         = "../../modules/base"
  resource_group = azurerm_resource_group.rg.name
  prefix         = trimsuffix(local.hub1_prefix, "-")
  location       = local.hub1_location
  #storage_account = azurerm_storage_account.region1

  private_dns_zone         = local.hub1_dns_zone
  dns_zone_linked_vnets    = {}
  dns_zone_linked_rulesets = {}

  nsg_config = {
    "${local.hub1_prefix}main" = azurerm_network_security_group.nsg_region1_main.id
    "${local.hub1_prefix}nva"  = azurerm_network_security_group.nsg_region1_nva.id
    "${local.hub1_prefix}ilb"  = azurerm_network_security_group.nsg_region1_default.id
  }

  vnet_config = [
    {
      address_space               = local.hub1_address_space
      subnets                     = local.hub1_subnets
      enable_private_dns_resolver = false
      enable_ergw                 = true
      enable_vpngw                = false
      enable_ars                  = false
      enable_firewall             = false

      vpngw_config = [
        {
          sku = "VpnGw2AZ"
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
