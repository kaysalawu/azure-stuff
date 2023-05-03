
####################################################
# spoke4
####################################################

# udr
#----------------------------

/*module "spoke4_udr_main" {
  source                 = "../../modules/udr"
  resource_group         = azurerm_resource_group.rg.name
  prefix                 = "${local.spoke4_prefix}main"
  location               = local.spoke4_location
  subnet_id              = module.spoke4.subnets["${local.spoke4_prefix}main"].id
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.hub2_nva_ilb_addr
  destinations = concat(
    local.udr_destinations_region1,
    local.udr_destinations_region2
  )
}*/

####################################################
# spoke5
####################################################

# vnet peering
#----------------------------

# spoke5-to-hub2

resource "azurerm_virtual_network_peering" "spoke5_to_hub2_peering" {
  resource_group_name          = azurerm_resource_group.rg.name
  name                         = "${local.prefix}-spoke5-to-hub2-peering"
  virtual_network_name         = module.spoke5.vnet.name
  remote_virtual_network_id    = module.hub2.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  #use_remote_gateways          = true
}

# hub2-to-spoke5

resource "azurerm_virtual_network_peering" "hub2_to_spoke5_peering" {
  resource_group_name          = azurerm_resource_group.rg.name
  name                         = "${local.prefix}-hub2-to-spoke5-peering"
  virtual_network_name         = module.hub2.vnet.name
  remote_virtual_network_id    = module.spoke5.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  #allow_gateway_transit        = true
}

# udr
#----------------------------

module "spoke5_udr_main" {
  source                 = "../../modules/udr"
  resource_group         = azurerm_resource_group.rg.name
  prefix                 = "${local.spoke5_prefix}main"
  location               = local.spoke5_location
  subnet_id              = module.spoke5.subnets["${local.spoke5_prefix}main"].id
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.hub2_nva_ilb_addr
  destinations = concat(
    local.udr_destinations_region1,
    local.udr_destinations_region2
  )
}

####################################################
# hub2
####################################################

# nva

locals {
  hub2_router_route_map_name_nh = "NEXT-HOP"
  hub2_router_init = templatefile("../../scripts/nva-hub.sh", {
    LOCAL_ASN = local.hub2_nva_asn
    LOOPBACK0 = local.hub2_nva_loopback0
    LOOPBACKS = {
      Loopback1 = local.hub2_nva_ilb_addr
    }
    INT_ADDR = local.hub2_nva_addr
    VPN_PSK  = local.psk

    ROUTE_MAPS = []
    TUNNELS    = []

    STATIC_ROUTES = [
      { network = "0.0.0.0", mask = "0.0.0.0", next_hop = local.hub2_default_gw_nva },
      { network = local.vhub2_router_bgp0, mask = "255.255.255.255", next_hop = local.hub2_default_gw_nva },
      { network = local.vhub2_router_bgp1, mask = "255.255.255.255", next_hop = local.hub2_default_gw_nva },
      {
        network  = cidrhost(local.spoke5_address_space[0], 0),
        mask     = cidrnetmask(local.spoke5_address_space[0])
        next_hop = local.hub2_default_gw_nva
      },
    ]

    BGP_SESSIONS = [
      {
        peer_asn      = local.vhub2_bgp_asn
        peer_ip       = local.vhub2_router_bgp0
        ebgp_multihop = true
        route_map     = {}
      },
      {
        peer_asn      = local.vhub2_bgp_asn
        peer_ip       = local.vhub2_router_bgp1
        ebgp_multihop = true
        route_map     = {}
      },
    ]
    BGP_ADVERTISED_NETWORKS = [
      {
        network = cidrhost(local.spoke5_address_space[0], 0)
        mask    = cidrnetmask(local.spoke5_address_space[0])
      },
    ]
  })
}

module "hub2_nva" {
  source               = "../../modules/csr-hub"
  resource_group       = azurerm_resource_group.rg.name
  name                 = "${local.hub2_prefix}nva"
  location             = local.hub2_location
  enable_ip_forwarding = true
  enable_public_ip     = true
  subnet               = module.hub2.subnets["${local.hub2_prefix}nva"].id
  private_ip           = local.hub2_nva_addr
  storage_account      = azurerm_storage_account.region2
  admin_username       = local.username
  admin_password       = local.password
  custom_data          = base64encode(local.hub2_router_init)
}

# udr

module "hub2_udr_main" {
  source                 = "../../modules/udr"
  resource_group         = azurerm_resource_group.rg.name
  prefix                 = "${local.hub2_prefix}main"
  location               = local.hub2_location
  subnet_id              = module.hub2.subnets["${local.hub2_prefix}main"].id
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.hub2_nva_ilb_addr
  destinations = concat(
    local.udr_destinations_region1,
    local.udr_destinations_region2
  )
}

####################################################
# vpn-site connection
####################################################

# branch3

resource "azurerm_vpn_gateway_connection" "vhub2_site_branch3_conn" {
  name                      = "${local.vhub2_prefix}site-branch3-conn"
  vpn_gateway_id            = azurerm_vpn_gateway.vhub2.id
  remote_vpn_site_id        = azurerm_vpn_site.vhub2_site_branch3.id
  internet_security_enabled = false

  vpn_link {
    name             = "${local.vhub2_prefix}site-branch3-conn-vpn-link-0"
    bgp_enabled      = true
    shared_key       = local.psk
    vpn_site_link_id = azurerm_vpn_site.vhub2_site_branch3.link[0].id
  }

  routing {
    associated_route_table = azurerm_virtual_hub.vhub2.default_route_table_id
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

# spoke4

resource "azurerm_virtual_hub_connection" "spoke4_vnet_conn" {
  name                      = "${local.vhub2_prefix}spoke4-vnet-conn"
  virtual_hub_id            = azurerm_virtual_hub.vhub2.id
  remote_virtual_network_id = module.spoke4.vnet.id

  routing {
    associated_route_table_id = azurerm_virtual_hub.vhub2.default_route_table_id
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

# hub2

locals {
  vhub2_hub2_vnet_conn_routes = []
}

resource "azurerm_virtual_hub_connection" "hub2_vnet_conn" {
  name                      = "${local.vhub2_prefix}hub2-vnet-conn"
  virtual_hub_id            = azurerm_virtual_hub.vhub2.id
  remote_virtual_network_id = module.hub2.vnet.id

  routing {
    associated_route_table_id = azurerm_virtual_hub.vhub2.default_route_table_id
    propagated_route_table {
      labels = [
        "default",
      ]
      route_table_ids = [
        azurerm_virtual_hub.vhub1.default_route_table_id,
      ]
    }
    dynamic "static_vnet_route" {
      for_each = local.vhub2_hub2_vnet_conn_routes
      content {
        name                = static_vnet_route.value.name
        address_prefixes    = static_vnet_route.value.address_prefixes
        next_hop_ip_address = static_vnet_route.value.next_hop_ip_address
      }
    }
  }
}

####################################################
# bgp connections
####################################################

# hub2

resource "azurerm_virtual_hub_bgp_connection" "vhub2_hub2_bgp_conn" {
  name           = "${local.vhub2_prefix}hub2-bgp-conn"
  virtual_hub_id = azurerm_virtual_hub.vhub2.id
  peer_asn       = local.hub2_nva_asn
  peer_ip        = local.hub2_nva_addr

  virtual_network_connection_id = azurerm_virtual_hub_connection.hub2_vnet_conn.id
}
