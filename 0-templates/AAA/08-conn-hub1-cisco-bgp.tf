
locals {
  vhub1_router_bgp_ip0   = module.vhub1.router_bgp_ip0
  vhub1_router_bgp_ip1   = module.vhub1.router_bgp_ip1
  vhub1_vpngw_public_ip0 = module.vhub1.vpn_gateway_public_ip0
  vhub1_vpngw_public_ip1 = module.vhub1.vpn_gateway_public_ip1
  vhub1_vpngw_bgp_ip0    = module.vhub1.vpn_gateway_bgp_ip0
  vhub1_vpngw_bgp_ip1    = module.vhub1.vpn_gateway_bgp_ip1
}

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
  use_remote_gateways          = false
}

# hub1-to-spoke2

resource "azurerm_virtual_network_peering" "hub1_to_spoke2_peering" {
  resource_group_name          = azurerm_resource_group.rg.name
  name                         = "${local.prefix}-hub1-to-spoke2-peering"
  virtual_network_name         = module.hub1.vnet.name
  remote_virtual_network_id    = module.spoke2.vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

# udr

module "spoke2_udr_main" {
  source                 = "../../modules/udr"
  resource_group         = azurerm_resource_group.rg.name
  prefix                 = "${local.spoke2_prefix}main"
  location               = local.spoke2_location
  subnet_id              = module.spoke2.subnets["${local.spoke2_prefix}main"].id
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = local.hub1_nva_ilb_addr
  destinations = concat(
    ["0.0.0.0/0"],
    local.udr_destinations_region1,
  )
}

####################################################
# hub1
####################################################

# nva

locals {
  hub1_router_route_map_name_nh = "NEXT-HOP"
  hub1_nva_vars = {
    LOCAL_ASN = local.hub1_nva_asn
    LOOPBACK0 = local.hub1_nva_loopback0
    LOOPBACKS = {
      Loopback1 = local.hub1_nva_ilb_addr
    }
    INT_ADDR = local.hub1_nva_addr
    VPN_PSK  = local.psk
  }
  hub1_cisco_nva_init = templatefile("../../scripts/nva-hub.sh", merge(
    local.hub1_nva_vars,
    {
      MASQUERADE = []
      ROUTE_MAPS = [
        {
          name   = local.hub1_router_route_map_name_nh
          action = "permit"
          rule   = 100
          commands = [
            "match ip address prefix-list all",
            "set ip next-hop ${local.hub1_nva_ilb_addr}"
          ]
        }
      ]
      TUNNELS = []
      STATIC_ROUTES = [
        { network = "0.0.0.0", mask = "0.0.0.0", next_hop = local.hub1_default_gw_nva },
        { network = local.vhub1_router_bgp_ip0, mask = "255.255.255.255", next_hop = local.hub1_default_gw_nva },
        { network = local.vhub1_router_bgp_ip1, mask = "255.255.255.255", next_hop = local.hub1_default_gw_nva },
        {
          network  = split("/", local.spoke2_address_space[0])[0]
          mask     = cidrnetmask(local.spoke2_address_space[0])
          next_hop = local.hub1_default_gw_nva
        },
      ]
      BGP_SESSIONS = [
        {
          peer_asn      = local.vhub1_bgp_asn
          peer_ip       = local.vhub1_router_bgp_ip0
          ebgp_multihop = true
          route_map = {
            #name      = local.hub1_router_route_map_name_nh
            #direction = "out"
          }
        },
        {
          peer_asn      = local.vhub1_bgp_asn
          peer_ip       = local.vhub1_router_bgp_ip1
          ebgp_multihop = true
          route_map = {
            #name      = local.hub1_router_route_map_name_nh
            #direction = "out"
          }
        },
      ]
      BGP_ADVERTISED_NETWORKS = [
        {
          network = split("/", local.spoke2_address_space[0])[0]
          mask    = cidrnetmask(local.spoke2_address_space[0])
        }
      ]
    }
  ))
  hub1_linux_nva_init = templatefile("../../scripts/linux-nva.sh", merge(local.hub1_nva_vars, {
    TARGETS = local.vm_script_targets_region1
    IPTABLES_RULES = [
      "iptables -t nat -A POSTROUTING -d 10.0.0.0/8 -j ACCEPT",
      "iptables -t nat -A POSTROUTING -d 172.16.0.0/12 -j ACCEPT",
      "iptables -t nat -A POSTROUTING -d 192.168.0.0/16 -j ACCEPT",
      "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
    ]
    ROUTE_MAPS = [
      {
        name   = local.hub1_router_route_map_name_nh
        action = "permit"
        rule   = 100
        commands = [
          "match ip address prefix-list all",
          "set ip next-hop ${local.hub1_nva_ilb_addr}"
        ]
      }
    ]
    TUNNELS = []
    QUAGGA_ZEBRA_CONF = templatefile("../../scripts/quagga/zebra.conf", merge(
      local.hub1_nva_vars,
      {
        INTERFACE = "eth0"
        STATIC_ROUTES = [
          { prefix = "0.0.0.0/0", next_hop = local.hub1_default_gw_nva },
          { prefix = "${local.vhub1_router_bgp_ip0}/32", next_hop = local.hub1_default_gw_nva },
          { prefix = local.spoke2_address_space[0], next_hop = local.hub1_default_gw_nva },
        ]
      }
    ))
    QUAGGA_BGPD_CONF = templatefile("../../scripts/quagga/bgpd.conf", merge(
      local.hub1_nva_vars,
      {
        BGP_SESSIONS = [
          {
            peer_asn      = local.vhub1_bgp_asn
            peer_ip       = local.vhub1_router_bgp_ip0
            ebgp_multihop = true
            route_map = {
              #name      = local.hub1_router_route_map_name_nh
              #direction = "out"
            }
          },
          {
            peer_asn      = local.vhub1_bgp_asn
            peer_ip       = local.vhub1_router_bgp_ip1
            ebgp_multihop = true
            route_map = {
              #name      = local.hub1_router_route_map_name_nh
              #direction = "out"
            }
          },
        ]
        BGP_ADVERTISED_PREFIXES = [
          local.spoke2_address_space[0]
        ]
      }
    ))
    }
  ))
}
/*
module "hub1_nva" {
  source               = "../../modules/csr-hub"
  resource_group       = azurerm_resource_group.rg.name
  name                 = "${local.hub1_prefix}nva"
  location             = local.hub1_location
  enable_ip_forwarding = true
  enable_public_ip     = true
  subnet               = module.hub1.subnets["${local.hub1_prefix}nva"].id
  private_ip           = local.hub1_nva_addr
  storage_account      = module.common.storage_accounts["region1"]
  admin_username       = local.username
  admin_password       = local.password
  custom_data          = base64encode(local.hub1_cisco_nva_init)
}*/

module "hub1_nva" {
  source               = "../../modules/linux"
  resource_group       = azurerm_resource_group.rg.name
  prefix               = ""
  name                 = "${local.hub1_prefix}nva"
  location             = local.hub1_location
  subnet               = module.hub1.subnets["${local.hub1_prefix}nva"].id
  private_ip           = local.hub1_nva_addr
  enable_ip_forwarding = true
  enable_public_ip     = true
  source_image         = "ubuntu"
  storage_account      = module.common.storage_accounts["region1"]
  admin_username       = local.username
  admin_password       = local.password
  custom_data          = base64encode(local.hub1_linux_nva_init)
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
    ["0.0.0.0/0"],
    local.udr_destinations_region1
  )
}

####################################################
# vpn-site connection
####################################################

# branch1
#----------------------------

# branch1

resource "azurerm_vpn_site" "vhub1_site_branch1" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.vhub1_prefix}site-branch1"
  location            = azurerm_virtual_wan.vwan.location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  device_model        = "Azure"
  device_vendor       = "Microsoft"
  link {
    name          = "${local.vhub1_prefix}site-branch1-link-0"
    provider_name = "Microsoft"
    ip_address    = azurerm_public_ip.branch1_nva_pip.ip_address
    speed_in_mbps = 50
    bgp {
      asn             = local.branch1_nva_asn
      peering_address = local.branch1_nva_loopback0
    }
  }
}

resource "azurerm_vpn_gateway_connection" "vhub1_site_branch1_conn" {
  name                      = "${local.vhub1_prefix}site-branch1-conn"
  vpn_gateway_id            = module.vhub1.vpn_gateway.id
  remote_vpn_site_id        = azurerm_vpn_site.vhub1_site_branch1.id
  internet_security_enabled = false

  vpn_link {
    name             = "${local.vhub1_prefix}site-branch1-conn-vpn-link-0"
    bgp_enabled      = true
    shared_key       = local.psk
    vpn_site_link_id = azurerm_vpn_site.vhub1_site_branch1.link[0].id
  }

  routing {
    associated_route_table = module.vhub1.virtual_hub.default_route_table_id
    propagated_route_table {
      labels = [
        "default",
      ]
      route_table_ids = [
        module.vhub1.virtual_hub.default_route_table_id,
      ]
    }
  }
}

####################################################
# vnet connections
####################################################

locals {
  vhub1_spoke1_vnet_conn_routes = []
}

# spoke1

resource "azurerm_virtual_hub_connection" "spoke1_vnet_conn" {
  name                      = "${local.vhub1_prefix}spoke1-vnet-conn"
  virtual_hub_id            = module.vhub1.virtual_hub.id
  remote_virtual_network_id = module.spoke1.vnet.id
  internet_security_enabled = true

  routing {
    associated_route_table_id = azurerm_virtual_hub_route_table.vhub1_custom.id
    propagated_route_table {
      labels = [
        "none"
      ]
      route_table_ids = [
        data.azurerm_virtual_hub_route_table.vhub1_none.id
      ]
    }
    dynamic "static_vnet_route" {
      for_each = local.vhub1_spoke1_vnet_conn_routes
      content {
        name                = static_vnet_route.value.name
        address_prefixes    = static_vnet_route.value.address_prefixes
        next_hop_ip_address = static_vnet_route.value.next_hop_ip_address
      }
    }
  }
}

# hub1

locals {
  vhub1_hub1_vnet_conn_routes = [
    /*{
      name                = "zscaler"
      address_prefixes    = ["${local.spoke2_vm_addr}/32"]
      next_hop_ip_address = local.hub1_nva_ilb_addr
    }*/
  ]
}

resource "azurerm_virtual_hub_connection" "hub1_vnet_conn" {
  name                      = "${local.vhub1_prefix}hub1-vnet-conn"
  virtual_hub_id            = module.vhub1.virtual_hub.id
  remote_virtual_network_id = module.hub1.vnet.id

  routing {
    associated_route_table_id = data.azurerm_virtual_hub_route_table.vhub1_default.id
    propagated_route_table {
      labels = [
        "none"
      ]
      route_table_ids = [
        data.azurerm_virtual_hub_route_table.vhub1_none.id
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

####################################################
# vhub static routes
####################################################

locals {
  vhub1_default_rt_static_routes = {
    default = { destinations = ["0.0.0.0/0"], next_hop = module.vhub1.firewall.id }
    rfc1918 = { destinations = local.rfc1918_prefixes, next_hop = module.vhub1.firewall.id }
    #zscaler = { destinations = ["${local.spoke2_vm_addr}/32"], next_hop = azurerm_virtual_hub_connection.hub1_vnet_conn.id }
  }
  vhub1_custom_rt_static_routes = {
    default = { destinations = ["0.0.0.0/0"], next_hop = module.vhub1.firewall.id }
    rfc1918 = { destinations = local.rfc1918_prefixes, next_hop = module.vhub1.firewall.id }
  }
}

resource "azurerm_virtual_hub_route_table_route" "vhub1_default_rt_static_routes" {
  for_each          = local.vhub1_default_rt_static_routes
  route_table_id    = data.azurerm_virtual_hub_route_table.vhub1_default.id
  name              = each.key
  destinations_type = "CIDR"
  destinations      = each.value.destinations
  next_hop_type     = "ResourceId"
  next_hop          = each.value.next_hop
}

resource "azurerm_virtual_hub_route_table_route" "vhub1_custom_rt_static_routes" {
  for_each          = local.vhub1_custom_rt_static_routes
  route_table_id    = azurerm_virtual_hub_route_table.vhub1_custom.id
  name              = each.key
  destinations_type = "CIDR"
  destinations      = each.value.destinations
  next_hop_type     = "ResourceId"
  next_hop          = each.value.next_hop
}

####################################################
# bgp connections
####################################################

# hub1

resource "azurerm_virtual_hub_bgp_connection" "vhub1_hub1_bgp_conn" {
  name           = "${local.vhub1_prefix}hub1-bgp-conn"
  virtual_hub_id = module.vhub1.virtual_hub.id
  peer_asn       = local.hub1_nva_asn
  peer_ip        = local.hub1_nva_addr

  virtual_network_connection_id = azurerm_virtual_hub_connection.hub1_vnet_conn.id
}

####################################################
# output files
####################################################

locals {
  hub1_files = {
    "output/hub1-cisco-nva.sh" = local.hub1_cisco_nva_init
    "output/hub1-linux-nva.sh" = local.hub1_linux_nva_init
  }
}

resource "local_file" "hub1_files" {
  for_each = local.hub1_files
  filename = each.key
  content  = each.value
}

