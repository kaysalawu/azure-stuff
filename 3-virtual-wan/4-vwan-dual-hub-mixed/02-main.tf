
# vm startup scripts
#----------------------------

locals {
  prefix = "Vwan24"

  hub1_nva_asn   = "65010"
  hub1_vpngw_asn = "65011"
  hub1_ergw_asn  = "65012"
  hub1_ars_asn   = "65515"

  hub2_nva_asn   = "65020"
  hub2_vpngw_asn = "65021"
  hub2_ergw_asn  = "65022"
  hub2_ars_asn   = "65515"
  #mypip          = chomp(data.http.mypip.response_body)

  vm_script_targets_region1 = [
    { name = "branch1", dns = local.branch1_vm_dns, ip = local.branch1_vm_addr },
    { name = "hub1   ", dns = local.hub1_vm_dns, ip = local.hub1_vm_addr },
    { name = "hub1-pe", dns = local.hub1_pep_dns, ping = false },
    { name = "spoke1 ", dns = local.spoke1_vm_dns, ip = local.spoke1_vm_addr },
    { name = "spoke2 ", dns = local.spoke2_vm_dns, ip = local.spoke2_vm_addr },
    { name = "spoke3 ", dns = local.spoke3_vm_dns, ip = local.spoke3_vm_addr, ping = false },
  ]
  vm_script_targets_region2 = [
    { name = "branch3", dns = local.branch3_vm_dns, ip = local.branch3_vm_addr },
    { name = "hub2   ", dns = local.hub2_vm_dns, ip = local.hub2_vm_addr },
    { name = "hub2-pe", dns = local.hub2_pep_dns, ping = false },
    { name = "spoke4 ", dns = local.spoke4_vm_dns, ip = local.spoke4_vm_addr },
    { name = "spoke5 ", dns = local.spoke5_vm_dns, ip = local.spoke5_vm_addr },
    { name = "spoke6 ", dns = local.spoke6_vm_dns, ip = local.spoke6_vm_addr, ping = false },
  ]
  vm_startup = templatefile("../../scripts/server.sh", {
    TARGETS = concat(local.vm_script_targets_region1, local.vm_script_targets_region2)
  })
  branch_unbound_config = templatefile("../../scripts/unbound.sh", {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    FORWARD_ZONES        = local.onprem_forward_zones
    TARGETS              = local.vm_script_targets_region1
  })
  branch_unbound_vars = {
    ONPREM_LOCAL_RECORDS = local.onprem_local_records
    REDIRECTED_HOSTS     = local.onprem_redirected_hosts
    FORWARD_ZONES        = local.onprem_forward_zones
    TARGETS              = local.vm_script_targets_region1
  }
  onprem_local_records = [
    { name = (local.branch1_vm_dns), record = local.branch1_vm_addr },
    { name = (local.branch2_vm_dns), record = local.branch2_vm_addr },
    { name = (local.branch3_vm_dns), record = local.branch3_vm_addr },
    { name = (local.branch4_vm_dns), record = local.branch4_vm_addr },
  ]
  onprem_forward_zones = [
    { zone = "${local.cloud_domain}.", targets = [local.hub1_dns_in_addr, local.hub2_dns_in_addr, ] },
    { zone = ".", targets = [local.azuredns, ] },
  ]
  onprem_redirected_hosts = []
}

####################################################
# addresses
####################################################

resource "azurerm_public_ip" "branch1_nva_pip" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.branch1_prefix}nva-pip"
  location            = local.branch1_location
  sku                 = "Standard"
  allocation_method   = "Static"
}

resource "azurerm_public_ip" "branch3_nva_pip" {
  resource_group_name = azurerm_resource_group.rg.name
  name                = "${local.branch3_prefix}nva-pip"
  location            = local.branch3_location
  sku                 = "Standard"
  allocation_method   = "Static"
}
