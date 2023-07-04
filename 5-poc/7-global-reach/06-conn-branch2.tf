
# locals
#------------------------
locals {
  megaport_prefix           = lower("salawu-${local.prefix}")
  megaport_asn_mcr1         = 65011
  megaport_asn_mcr2         = 65022
  megaport_hub1_er1_vlan    = "110"
  megaport_hub2_er2_vlan    = "210"
  megaport_branch2_er1_vlan = "100"
  megaport_branch3_er2_vlan = "200"
}

####################################################
# common
####################################################

provider "megaport" {
  username              = var.megaport_username
  password              = var.megaport_password
  accept_purchase_terms = true
  delete_ports          = true
  environment           = "production"
}

variable "megaport_username" {
  description = "megaport username"
}

variable "megaport_password" {
  description = "megaport password"
}

data "megaport_location" "location" {
  name    = "Equinix AM1"
  has_mcr = true
}
/*
####################################################
# circuits
####################################################

# hub1
#------------------------

# er1

resource "azurerm_express_route_circuit" "hub1_er1_circuit" {
  resource_group_name   = azurerm_resource_group.rg.name
  name                  = "${local.hub1_prefix}er1-circuit"
  location              = local.hub1_location
  service_provider_name = "Megaport"
  peering_location      = "Amsterdam"
  bandwidth_in_mbps     = 50
  sku {
    tier   = "Premium"
    family = "MeteredData"
  }
}

resource "azurerm_express_route_circuit_authorization" "hub1_er1_circuit" {
  resource_group_name        = azurerm_resource_group.rg.name
  name                       = "${local.hub1_prefix}er1-circuit"
  express_route_circuit_name = azurerm_express_route_circuit.hub1_er1_circuit.name
}

# hub2
#------------------------

# er2

resource "azurerm_express_route_circuit" "hub2_er2_circuit" {
  resource_group_name   = azurerm_resource_group.rg.name
  name                  = "${local.hub2_prefix}er2-circuit"
  location              = local.hub2_location
  service_provider_name = "Megaport"
  peering_location      = "Amsterdam"
  bandwidth_in_mbps     = 50
  sku {
    tier   = "Premium"
    family = "MeteredData"
  }
}

resource "azurerm_express_route_circuit_authorization" "hub2_er2_circuit" {
  resource_group_name        = azurerm_resource_group.rg.name
  name                       = "${local.hub2_prefix}er2-circuit"
  express_route_circuit_name = azurerm_express_route_circuit.hub2_er2_circuit.name
}

# branch2
#------------------------

# er1

resource "azurerm_express_route_circuit" "branch2_er1_circuit" {
  resource_group_name   = azurerm_resource_group.rg.name
  name                  = "${local.branch2_prefix}er1-circuit"
  location              = local.branch2_location
  service_provider_name = "Megaport"
  peering_location      = "Amsterdam"
  bandwidth_in_mbps     = 50
  sku {
    tier   = "Standard"
    family = "MeteredData"
  }
}

resource "azurerm_express_route_circuit_authorization" "branch2_er1_circuit" {
  resource_group_name        = azurerm_resource_group.rg.name
  name                       = "${local.branch2_prefix}er1-circuit"
  express_route_circuit_name = azurerm_express_route_circuit.branch2_er1_circuit.name
}

# branch3
#------------------------

# er2

resource "azurerm_express_route_circuit" "branch3_er2_circuit" {
  resource_group_name   = azurerm_resource_group.rg.name
  name                  = "${local.branch3_prefix}er2-circuit"
  location              = local.branch3_location
  service_provider_name = "Megaport"
  peering_location      = "Amsterdam"
  bandwidth_in_mbps     = 50
  sku {
    tier   = "Standard"
    family = "MeteredData"
  }
}

resource "azurerm_express_route_circuit_authorization" "branch3_er2_circuit" {
  resource_group_name        = azurerm_resource_group.rg.name
  name                       = "${local.branch3_prefix}er2-circuit"
  express_route_circuit_name = azurerm_express_route_circuit.branch3_er2_circuit.name
}

####################################################
# megaport
####################################################

# mcr
#----------------------------

# mcr1

resource "megaport_mcr" "mcr1" {
  mcr_name    = "${local.megaport_prefix}-mcr1"
  location_id = data.megaport_location.location.id
  router {
    port_speed    = 1000
    requested_asn = local.megaport_asn_mcr1
  }
}

# mcr2

resource "megaport_mcr" "mcr2" {
  mcr_name    = "${local.megaport_prefix}-mcr2"
  location_id = data.megaport_location.location.id
  router {
    port_speed    = 1000
    requested_asn = local.megaport_asn_mcr2
  }
}

# connection
#----------------------------

# hub1

resource "megaport_azure_connection" "azure_vcx_hub1_er1" {
  vxc_name   = "${local.megaport_prefix}-azure-vcx-hub1-er1"
  rate_limit = 50
  a_end {
    requested_vlan = local.megaport_hub1_er1_vlan
  }
  csp_settings {
    service_key = azurerm_express_route_circuit.hub1_er1_circuit.service_key
    attached_to = megaport_mcr.mcr1.id
    peerings {
      private_peer   = true
      microsoft_peer = false
    }
  }
}

# hub2

resource "megaport_azure_connection" "azure_vcx_hub2_er2" {
  vxc_name   = "${local.megaport_prefix}-azure-vcx-hub2-er2"
  rate_limit = 50
  a_end {
    requested_vlan = local.megaport_hub2_er2_vlan
  }
  csp_settings {
    service_key = azurerm_express_route_circuit.hub2_er2_circuit.service_key
    attached_to = megaport_mcr.mcr2.id
    peerings {
      private_peer   = true
      microsoft_peer = false
    }
  }
}

# branch2

resource "megaport_azure_connection" "azure_vcx_branch2_er1" {
  vxc_name   = "${local.megaport_prefix}-azure-vcx-branch2-er1"
  rate_limit = 50
  a_end {
    requested_vlan = local.megaport_branch2_er1_vlan
  }
  csp_settings {
    service_key = azurerm_express_route_circuit.branch2_er1_circuit.service_key
    attached_to = megaport_mcr.mcr1.id
    peerings {
      private_peer   = true
      microsoft_peer = false
    }
  }
}

# branch3

resource "megaport_azure_connection" "azure_vcx_branch3_er2" {
  vxc_name   = "${local.megaport_prefix}-azure-vcx-branch3-er2"
  rate_limit = 50
  a_end {
    requested_vlan = local.megaport_branch3_er2_vlan
  }
  csp_settings {
    service_key = azurerm_express_route_circuit.branch3_er2_circuit.service_key
    attached_to = megaport_mcr.mcr2.id
    peerings {
      private_peer   = true
      microsoft_peer = false
    }
  }
}
/*
####################################################
# gateway
####################################################

# connection
#----------------------------

# hub1

resource "azurerm_virtual_network_gateway_connection" "azure_vcx_hub1_er1" {
  resource_group_name        = azurerm_resource_group.rg.name
  name                       = "${local.hub1_prefix}-azure-vcx-hub1-er1"
  location                   = local.hub1_location
  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.hub1.ergw.id
  authorization_key          = azurerm_express_route_circuit_authorization.hub1_er1_circuit.authorization_key
  express_route_circuit_id   = azurerm_express_route_circuit.hub1_er1_circuit.id
  depends_on = [
    megaport_azure_connection.azure_vcx_hub1_er1
  ]
}

# hub2

resource "azurerm_virtual_network_gateway_connection" "azure_vcx_hub2_er2" {
  resource_group_name        = azurerm_resource_group.rg.name
  name                       = "${local.hub2_prefix}-azure-vcx-hub2-er2"
  location                   = local.hub2_location
  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.hub2.ergw.id
  authorization_key          = azurerm_express_route_circuit_authorization.hub2_er2_circuit.authorization_key
  express_route_circuit_id   = azurerm_express_route_circuit.hub2_er2_circuit.id
  depends_on = [
    megaport_azure_connection.azure_vcx_hub2_er2
  ]
}

# branch2

resource "azurerm_virtual_network_gateway_connection" "azure_vcx_branch2_er1" {
  resource_group_name        = azurerm_resource_group.rg.name
  name                       = "${local.branch2_prefix}-azure-vcx-branch2-er1"
  location                   = local.branch2_location
  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.branch2.ergw.id
  authorization_key          = azurerm_express_route_circuit_authorization.branch2_er1_circuit.authorization_key
  express_route_circuit_id   = azurerm_express_route_circuit.branch2_er1_circuit.id
  depends_on = [
    megaport_azure_connection.azure_vcx_branch2_er1
  ]
}

# branch3
/*
resource "azurerm_virtual_network_gateway_connection" "azure_vcx_branch3_er2" {
  resource_group_name        = azurerm_resource_group.rg.name
  name                       = "${local.branch3_prefix}-azure-vcx-branch3-er2"
  location                   = local.branch3_location
  type                       = "ExpressRoute"
  virtual_network_gateway_id = module.branch3.ergw.id
  authorization_key          = azurerm_express_route_circuit_authorization.branch3_er2_circuit.authorization_key
  express_route_circuit_id   = azurerm_express_route_circuit.branch3_er2_circuit.id
  depends_on = [
    megaport_azure_connection.azure_vcx_branch3_er2
  ]
}*/

