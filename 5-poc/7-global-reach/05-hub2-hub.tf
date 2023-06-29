
####################################################
# base
####################################################

module "hub2" {
  source         = "../../modules/base"
  resource_group = azurerm_resource_group.rg.name
  prefix         = trimsuffix(local.hub2_prefix, "-")
  location       = local.hub2_location
  #storage_account = azurerm_storage_account.region2

  private_dns_zone         = local.hub2_dns_zone
  dns_zone_linked_vnets    = {}
  dns_zone_linked_rulesets = {}

  nsg_config = {
    "${local.hub2_prefix}main" = azurerm_network_security_group.nsg_region2_main.id
    "${local.hub2_prefix}nva"  = azurerm_network_security_group.nsg_region2_nva.id
    "${local.hub2_prefix}ilb"  = azurerm_network_security_group.nsg_region2_default.id
  }

  vnet_config = [
    {
      address_space               = local.hub2_address_space
      subnets                     = local.hub2_subnets
      enable_private_dns_resolver = false
      enable_ergw                 = true
      enable_vpngw                = false
      enable_ars                  = false
      enable_firewall             = false

      vpngw_config = [
        {
          sku = "VpnGw2AZ"
          asn = local.hub2_vpngw_asn
        }
      ]
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

