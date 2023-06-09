
####################################################
# spoke2
####################################################

# vnet peering
#----------------------------

# spoke2-to-hub1

resource "azurerm_virtual_network_peering" "spoke2_to_hub1_peering" {
  resource_group_name          = azurerm_resource_group.rg.name
  name                         = "${local.prefix}-spoke2-to-hub1-peering"
  virtual_network_name         = module.spoke2.vnet.name
  remote_virtual_network_id    = module.hub1.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  #use_remote_gateways          = true
}

# hub1-to-spoke2

resource "azurerm_virtual_network_peering" "hub1_to_spoke2_peering" {
  resource_group_name          = azurerm_resource_group.rg.name
  name                         = "${local.prefix}-hub1-to-spoke2-peering"
  virtual_network_name         = module.hub1.vnet.name
  remote_virtual_network_id    = module.spoke2.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  #allow_gateway_transit        = true
}

####################################################
# hub1
####################################################

# nva

locals {
  hub1_router_route_map_name_nh = "NEXT-HOP"
  hub1_router_init = templatefile("../../scripts/nva-hub.sh", {
    LOCAL_ASN = local.hub1_nva_asn
    LOOPBACK0 = local.hub1_nva_loopback0
    LOOPBACKS = {
      Loopback1 = local.hub1_nva_ilb_addr
    }
    INT_ADDR = local.hub1_nva_addr
    VPN_PSK  = local.psk

    ROUTE_MAPS = []
    TUNNELS    = []

    STATIC_ROUTES = [
      { network = "0.0.0.0", mask = "0.0.0.0", next_hop = local.hub1_default_gw_nva },
    ]

    BGP_SESSIONS            = []
    BGP_ADVERTISED_NETWORKS = []
  })
}

module "hub1_nva" {
  source               = "../../modules/csr-hub"
  resource_group       = azurerm_resource_group.rg.name
  name                 = "${local.hub1_prefix}nva"
  location             = local.hub1_location
  enable_ip_forwarding = true
  enable_public_ip     = true
  subnet               = module.hub1.subnets["${local.hub1_prefix}nva"].id
  private_ip           = local.hub1_nva_addr
  storage_account      = azurerm_storage_account.region1
  admin_username       = local.username
  admin_password       = local.password
  custom_data          = base64encode(local.hub1_router_init)
}

# udr

module "hub1_udr_main" {
  source                 = "../../modules/udr"
  resource_group         = azurerm_resource_group.rg.name
  prefix                 = "${local.hub1_prefix}main"
  location               = local.hub1_location
  subnet_id              = module.hub1.subnets["${local.hub1_prefix}main"].id
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.hub1_nva_ilb_addr
  destinations = concat(
    local.udr_destinations_region1,
    local.udr_destinations_region2
  )
}

####################################################
# vpn-site connection
####################################################

# branch1

resource "azurerm_vpn_gateway_connection" "vhub1_site_branch1_conn" {
  name                      = "${local.vhub1_prefix}site-branch1-conn"
  vpn_gateway_id            = azurerm_vpn_gateway.vhub1.id
  remote_vpn_site_id        = azurerm_vpn_site.vhub1_site_branch1.id
  internet_security_enabled = false

  vpn_link {
    name             = "${local.vhub1_prefix}site-branch1-conn-vpn-link-0"
    bgp_enabled      = true
    shared_key       = local.psk
    vpn_site_link_id = azurerm_vpn_site.vhub1_site_branch1.link[0].id
  }

  routing {
    associated_route_table = azurerm_virtual_hub.vhub1.default_route_table_id
    propagated_route_table {
      labels = [
        "default",
      ]
      route_table_ids = [
        azurerm_virtual_hub.vhub1.default_route_table_id,
      ]
    }
  }
}

####################################################
# vnet connections
####################################################

# spoke1

resource "azurerm_virtual_hub_connection" "spoke1_vnet_conn" {
  name                      = "${local.vhub1_prefix}spoke1-vnet-conn"
  virtual_hub_id            = azurerm_virtual_hub.vhub1.id
  remote_virtual_network_id = module.spoke1.vnet.id

  routing {
    associated_route_table_id = azurerm_virtual_hub.vhub1.default_route_table_id
    propagated_route_table {
      labels = [
        "default",
      ]
      route_table_ids = [
        azurerm_virtual_hub.vhub1.default_route_table_id,
      ]
    }
  }
}

# hub1

locals {
  vhub1_hub1_vnet_conn_routes = []
}

resource "azurerm_virtual_hub_connection" "hub1_vnet_conn" {
  name                      = "${local.vhub1_prefix}hub1-vnet-conn"
  virtual_hub_id            = azurerm_virtual_hub.vhub1.id
  remote_virtual_network_id = module.hub1.vnet.id

  routing {
    associated_route_table_id = azurerm_virtual_hub.vhub1.default_route_table_id
    propagated_route_table {
      labels = [
        "default",
      ]
      route_table_ids = [
        azurerm_virtual_hub.vhub1.default_route_table_id,
      ]
    }
    dynamic "static_vnet_route" {
      for_each = local.vhub1_hub1_vnet_conn_routes
      content {
        name                = static_vnet_route.value.name
        address_prefixes    = static_vnet_route.value.address_prefixes
        next_hop_ip_address = static_vnet_route.value.next_hop_ip_address
      }
    }
  }
}
