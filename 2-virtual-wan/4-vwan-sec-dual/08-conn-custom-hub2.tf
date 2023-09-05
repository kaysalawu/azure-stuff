
locals {
  vhub2_router_bgp_ip0   = module.vhub2.router_bgp_ip0
  vhub2_router_bgp_ip1   = module.vhub2.router_bgp_ip1
  vhub2_vpngw_public_ip0 = module.vhub2.vpn_gateway_public_ip0
  vhub2_vpngw_public_ip1 = module.vhub2.vpn_gateway_public_ip1
  vhub2_vpngw_bgp_ip0    = module.vhub2.vpn_gateway_bgp_ip0
  vhub2_vpngw_bgp_ip1    = module.vhub2.vpn_gateway_bgp_ip1
}

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

module "spoke5_udr_main" {
  source                 = "../../modules/udr"
  resource_group         = azurerm_resource_group.rg.name
  prefix                 = "${local.spoke5_prefix}main"
  location               = local.spoke5_location
  subnet_id              = module.spoke5.subnets["${local.spoke5_prefix}main"].id
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.hub1_nva_ilb_addr
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
  hub2_nva_init = templatefile("../../scripts/nva-hub.sh", {
    LOCAL_ASN = local.hub2_nva_asn
    LOOPBACK0 = local.hub2_nva_loopback0
    LOOPBACKS = {
      Loopback1 = local.hub2_nva_ilb_addr
    }
    INT_ADDR = local.hub2_nva_addr
    VPN_PSK  = local.psk

    MASQUERADE = []
    ROUTE_MAPS = [
      {
        name   = local.hub2_router_route_map_name_nh
        action = "permit"
        rule   = 100
        commands = [
          "match ip address prefix-list all",
          "set ip next-hop ${local.hub2_nva_ilb_addr}"
        ]
      }
    ]
    TUNNELS = []

    STATIC_ROUTES = [
      { network = "0.0.0.0", mask = "0.0.0.0", next_hop = local.hub2_default_gw_nva },
    ]

    BGP_SESSIONS            = []
    BGP_ADVERTISED_NETWORKS = []
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
  storage_account      = module.common.storage_accounts["region2"]
  admin_username       = local.username
  admin_password       = local.password
  custom_data          = base64encode(local.hub2_nva_init)
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
    local.udr_destinations_region2,
    local.udr_destinations_region2
  )
}

####################################################
# vpn-site connection
####################################################

# branch3
#----------------------------

# branch3

resource "azurerm_vpn_site" "vhub2_site_branch3" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.vhub2_prefix}site-branch3"
  location            = azurerm_virtual_wan.vwan.location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  device_model        = "Azure"
  device_vendor       = "Microsoft"
  link {
    name          = "${local.vhub2_prefix}site-branch3-link-0"
    provider_name = "Microsoft"
    ip_address    = azurerm_public_ip.branch3_nva_pip.ip_address
    speed_in_mbps = 50
    bgp {
      asn             = local.branch3_nva_asn
      peering_address = local.branch3_nva_loopback0
    }
  }
}

resource "azurerm_vpn_gateway_connection" "vhub2_site_branch3_conn" {
  name                      = "${local.vhub2_prefix}site-branch3-conn"
  vpn_gateway_id            = module.vhub2.vpn_gateway.id
  remote_vpn_site_id        = azurerm_vpn_site.vhub2_site_branch3.id
  internet_security_enabled = false

  vpn_link {
    name             = "${local.vhub2_prefix}site-branch3-conn-vpn-link-0"
    bgp_enabled      = true
    shared_key       = local.psk
    vpn_site_link_id = azurerm_vpn_site.vhub2_site_branch3.link[0].id
  }

  routing {
    associated_route_table = module.vhub2.virtual_hub.default_route_table_id
    propagated_route_table {
      labels = [
        "default",
      ]
      route_table_ids = [
        module.vhub2.virtual_hub.default_route_table_id,
      ]
    }
  }
}

####################################################
# vnet connections
####################################################

locals {
  vhub2_spoke4_vnet_conn_routes = []
  vhub2_hub2_vnet_conn_routes = [
    {
      name                = "spoke5"
      address_prefixes    = local.spoke5_address_space
      next_hop_ip_address = local.hub2_nva_ilb_addr
    }
  ]
}

# spoke4

resource "azurerm_virtual_hub_connection" "spoke4_vnet_conn" {
  name                      = "${local.vhub2_prefix}spoke4-vnet-conn"
  virtual_hub_id            = module.vhub2.virtual_hub.id
  remote_virtual_network_id = module.spoke4.vnet.id

  routing {
    associated_route_table_id = module.vhub2.virtual_hub.default_route_table_id
    propagated_route_table {
      labels = [
        "default",
      ]
      route_table_ids = [
        module.vhub2.virtual_hub.default_route_table_id,
      ]
    }
    dynamic "static_vnet_route" {
      for_each = local.vhub2_spoke4_vnet_conn_routes
      content {
        name                = static_vnet_route.value.name
        address_prefixes    = static_vnet_route.value.address_prefixes
        next_hop_ip_address = static_vnet_route.value.next_hop_ip_address
      }
    }
  }
}

# hub2

resource "azurerm_virtual_hub_connection" "hub2_vnet_conn" {
  name                      = "${local.vhub2_prefix}hub2-vnet-conn"
  virtual_hub_id            = module.vhub2.virtual_hub.id
  remote_virtual_network_id = module.hub2.vnet.id

  routing {
    associated_route_table_id = module.vhub2.virtual_hub.default_route_table_id
    propagated_route_table {
      labels = [
        "default",
      ]
      route_table_ids = [
        module.vhub2.virtual_hub.default_route_table_id,
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
# output files
####################################################

locals {
  hub2_files = {
    "output/hub2-nva.sh" = local.hub2_nva_init
  }
}

resource "local_file" "hub2_files" {
  for_each = local.hub2_files
  filename = each.key
  content  = each.value
}


