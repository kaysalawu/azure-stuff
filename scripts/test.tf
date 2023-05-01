#!/bin/bash
# Reference: https://docs.microsoft.com/en-us/azure/virtual-wan/scenario-route-through-nva
# Parameters (make changes based on your requirements)
region1=southcentralus
region2=centralus
rg=lab-vwan-irazfw
vwanname=vwan-irazfw
hub1name=hub1
hub2name=hub2
username=azureuser
password="Msft123Msft123" #Please change your password
vmsize=Standard_DS1_v2

# Validate Firewall SKU
if [ "$1" == "basic" ]; then
    firewalltier=basic
elif [ "$1" == "standard" ]; then
    firewalltier=standard
elif [ "$1" == "premium" ]; then
    firewalltier=premium
elif [ "$1" == "help" ]; then
    echo "Usage: ./vwan-irazfw.sh [basic|standard|premium]"
    exit 0
elif [ -z "$1" ]; then
    echo "No parameter passed, defaulting Azure Firewall to basic tier"
    firewalltier=basic
fi

# Adding script starting time and finish time
start=`date +%s`
echo "Script started at $(date)"

# Pre-Requisites
# Check if virtual wan extension is installed if not install it
if ! az extension list | grep -q virtual-wan; then
    echo "virtual-wan extension is not installed, installing it now..."
    az extension add --name virtual-wan --only-show-errors
fi

# Check if azure-firewall extension is installed if not install it
if ! az extension list | grep -q azure-firewall; then
    echo "azure-firewall extension is not installed, installing it now..."
    az extension add --name azure-firewall --only-show-errors
fi

#Variables
mypip=$(curl -4 ifconfig.io -s)

# Creating rg
az group create -n $rg -l $region1 --output none

# Creating virtual wan
echo Creating vwan and both hubs...
az network vwan create -g $rg -n $vwanname --branch-to-branch-traffic true --location $region1 --type standard --output none
az network vhub create -g $rg --name $hub1name --address-prefix 192.168.1.0/24 --vwan $vwanname --location $region1 --sku standard --no-wait
az network vhub create -g $rg --name $hub2name --address-prefix 192.168.2.0/24 --vwan $vwanname --location $region2 --sku standard --no-wait

echo Creating branches VNETs...
# Creating location1 branch virtual network
az network vnet create --address-prefixes 10.100.0.0/16 -n branch1 -g $rg -l $region1 --subnet-name main --subnet-prefixes 10.100.0.0/24 --output none
az network vnet subnet create -g $rg --vnet-name branch1 -n GatewaySubnet --address-prefixes 10.100.100.0/26 --output none

# Creating location2 branch virtual network
az network vnet create --address-prefixes 10.200.0.0/16 -n branch2 -g $rg -l $region2 --subnet-name main --subnet-prefixes 10.200.0.0/24 --output none
az network vnet subnet create -g $rg --vnet-name branch2 -n GatewaySubnet --address-prefixes 10.200.100.0/26 --output none

echo Creating spoke VNETs...
# Creating spokes virtual network
# Region1
az network vnet create --address-prefixes 10.1.0.0/24 -n spoke1 -g $rg -l $region1 --subnet-name main --subnet-prefixes 10.1.0.0/27 --output none
az network vnet create --address-prefixes 10.2.0.0/24 -n spoke2 -g $rg -l $region1 --subnet-name main --subnet-prefixes 10.2.0.0/27 --output none
az network vnet create --address-prefixes 10.2.1.0/24 -n spoke5 -g $rg -l $region1 --subnet-name main --subnet-prefixes 10.2.1.0/27 --output none
az network vnet create --address-prefixes 10.2.2.0/24 -n spoke6 -g $rg -l $region1 --subnet-name main --subnet-prefixes 10.2.2.0/27 --output none

# Region2
az network vnet create --address-prefixes 10.3.0.0/24 -n spoke3 -g $rg -l $region2 --subnet-name main --subnet-prefixes 10.3.0.0/27 --output none
az network vnet create --address-prefixes 10.4.0.0/24 -n spoke4 -g $rg -l $region2 --subnet-name main --subnet-prefixes 10.4.0.0/27 --output none
az network vnet create --address-prefixes 10.4.1.0/24 -n spoke7 -g $rg -l $region2 --subnet-name main --subnet-prefixes 10.4.1.0/27 --output none
az network vnet create --address-prefixes 10.4.2.0/24 -n spoke8 -g $rg -l $region2 --subnet-name main --subnet-prefixes 10.4.2.0/27 --output none

echo Creating VNET peerings...
# vnet peering from spoke 5 and spoke 6 to spoke2
az network vnet peering create -g $rg -n spoke2-to-spoke5 --vnet-name spoke2 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke5 --query id --out tsv) --output none
az network vnet peering create -g $rg -n spoke5-to-spoke2 --vnet-name spoke5 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke2  --query id --out tsv) --output none
az network vnet peering create -g $rg -n spoke2-to-spoke6 --vnet-name spoke2 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke6 --query id --out tsv) --output none
az network vnet peering create -g $rg -n spoke6-to-spoke2 --vnet-name spoke6 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke2  --query id --out tsv) --output none

# vnet peering from spoke 7 and spoke 8 to spoke4
az network vnet peering create -g $rg -n spoke4-to-spoke7 --vnet-name spoke4 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke7 --query id --out tsv) --output none
az network vnet peering create -g $rg -n spoke7-to-spoke4 --vnet-name spoke7 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke4  --query id --out tsv) --output none
az network vnet peering create -g $rg -n spoke4-to-spoke8 --vnet-name spoke4 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke8 --query id --out tsv) --output none
az network vnet peering create -g $rg -n spoke8-to-spoke4 --vnet-name spoke8 --allow-vnet-access --allow-forwarded-traffic --remote-vnet $(az network vnet show -g $rg -n spoke4  --query id --out tsv) --output none

echo Creating VMs in both branches...
# Creating a VM in each branch spoke
az vm create -n branch1VM  -g $rg --image ubuntults --public-ip-sku standard --size $vmsize -l $region1 --subnet main --vnet-name branch1 --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n branch2VM  -g $rg --image ubuntults --public-ip-sku standard --size $vmsize -l $region2 --subnet main --vnet-name branch2 --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors

echo Creating NSGs in both branches...
#Updating NSGs:
az network nsg create --resource-group $rg --name default-nsg-$region1 --location $region1 -o none
az network nsg create --resource-group $rg --name default-nsg-$region2 --location $region2 -o none
# Adding my home public IP to NSG for SSH access
az network nsg rule create -g $rg --nsg-name default-nsg-$region1 -n 'default-allow-ssh' --direction Inbound --priority 100 --source-address-prefixes $mypip --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow inbound SSH" --output none
az network nsg rule create -g $rg --nsg-name default-nsg-$region2 -n 'default-allow-ssh' --direction Inbound --priority 100 --source-address-prefixes $mypip --source-port-ranges '*' --destination-address-prefixes '*' --destination-port-ranges 22 --access Allow --protocol Tcp --description "Allow inbound SSH" --output none
# Associating NSG to the VNET subnets (Spokes and Branches)
az network vnet subnet update --id $(az network vnet list -g $rg --query '[?location==`'$region1'`].{id:subnets[0].id}' -o tsv) --network-security-group default-nsg-$region1 -o none
az network vnet subnet update --id $(az network vnet list -g $rg --query '[?location==`'$region2'`].{id:subnets[0].id}' -o tsv) --network-security-group default-nsg-$region2 -o none

echo Creating VPN Gateways in both branches...
# Creating pips for VPN GW's in each branch
az network public-ip create -n branch1-vpngw-pip -g $rg --location $region1 --sku basic --output none
az network public-ip create -n branch2-vpngw-pip -g $rg --location $region2 --sku basic --output none

# Creating VPN gateways
az network vnet-gateway create -n branch1-vpngw --public-ip-addresses branch1-vpngw-pip -g $rg --vnet branch1 --asn 65510 --gateway-type Vpn -l $region1 --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait
az network vnet-gateway create -n branch2-vpngw --public-ip-addresses branch2-vpngw-pip -g $rg --vnet branch2 --asn 65509 --gateway-type Vpn -l $region2 --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait

echo Creating Spoke VMs...
# Creating a VM in each connected spoke
az vm create -n spoke1VM  -g $rg --image ubuntults --public-ip-sku standard --size $vmsize -l $region1 --subnet main --vnet-name spoke1 --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n spoke3VM  -g $rg --image ubuntults --public-ip-sku standard --size $vmsize -l $region2 --subnet main --vnet-name spoke3 --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
# Creating VMs on each indirect spoke.
az vm create -n spoke5VM  -g $rg --image ubuntults --public-ip-sku standard --size $vmsize -l $region1 --subnet main --vnet-name spoke5 --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n spoke6VM  -g $rg --image ubuntults --public-ip-sku standard --size $vmsize -l $region1 --subnet main --vnet-name spoke6 --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n spoke7VM  -g $rg --image ubuntults --public-ip-sku standard --size $vmsize -l $region2 --subnet main --vnet-name spoke7 --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors
az vm create -n spoke8VM  -g $rg --image ubuntults --public-ip-sku standard --size $vmsize -l $region2 --subnet main --vnet-name spoke8 --admin-username $username --admin-password $password --nsg "" --no-wait --only-show-errors

# Continue only if all VMs are created
echo Waiting for VMs to be created...
az vm wait -g $rg --created --ids $(az vm list -g $rg --query '[].{id:id}' -o tsv) --only-show-errors -o none
#Enabling boot diagnostics for all VMs in the resource group
echo Enabling boot diagnostics for all VMs in the resource group...
# enable boot diagnostics for all VMs in the resource group
az vm boot-diagnostics enable --ids $(az vm list -g $rg --query '[].{id:id}' -o tsv) -o none
### Installing tools for networking connectivity validation such as traceroute, tcptraceroute, iperf and others (check link below for more details)
echo Installing tools for networking connectivity validation such as traceroute, tcptraceroute, iperf and others...
nettoolsuri="https://raw.githubusercontent.com/dmauser/azure-vm-net-tools/main/script/nettools.sh"
for vm in `az vm list -g $rg --query "[?storageProfile.imageReference.offer=='UbuntuServer'].name" -o tsv`
do
 az vm extension set \
 --resource-group $rg \
 --vm-name $vm \
 --name customScript \
 --publisher Microsoft.Azure.Extensions \
 --protected-settings "{\"fileUris\": [\"$nettoolsuri\"],\"commandToExecute\": \"./nettools.sh\"}" \
 --no-wait
done

echo Deploying Azure Firewall...
# Deploy Azure Firewall on Spoke2 and Spoke 4

# Create Firewall Policy for each region:
echo Creating Azure Firewall Policy for each region...

az network firewall policy create
-g $rg
-n $region1-AZFW-Policy
--location $region1
--threat-intel-mode Alert
--sku $firewalltier
--output none

az network firewall policy create
-g $rg
-n $region2-AZFW-Policy
--location $region2
--threat-intel-mode Alert
--sku $firewalltier
--output none

# Create firewall policy rule collection group for each region:
echo Creating Azure Firewall Policy Rule Collection Group for each region...
az network firewall policy rule-collection-group create -g $rg --policy-name $region1-AZFW-Policy -n NetworkRuleCollectionGroup --priority 200 --output none
az network firewall policy rule-collection-group create -g $rg --policy-name $region2-AZFW-Policy -n NetworkRuleCollectionGroup --priority 200 --output none

# Create a any to any Network Rule Collection for each region:
# For $region1-AZFW-Policy
az network firewall policy rule-collection-group collection add-filter-collection \
 --resource-group $rg \
 --policy-name $region1-AZFW-Policy \
 --name GenericCollection \
 --rcg-name NetworkRuleCollectionGroup \
 --rule-type NetworkRule \
 --rule-name AnytoAny \
 --action Allow \
 --ip-protocols "Any" \
 --source-addresses "*" \
 --destination-addresses  "*" \
 --destination-ports "*" \
 --collection-priority 100 \
 --output none

# For $region1-AZFW-Policy
az network firewall policy rule-collection-group collection add-filter-collection \
 --resource-group $rg \
 --policy-name $region2-AZFW-Policy\
 --name GenericCollection \
 --rcg-name NetworkRuleCollectionGroup \
 --rule-type NetworkRule \
 --rule-name AnytoAny \
 --action Allow \
 --ip-protocols "Any" \
 --source-addresses "*" \
 --destination-addresses  "*" \
 --destination-ports "*" \
 --collection-priority 100 \
 --output none

#Build Azure Firewall / Note this section takes few minutes to complete.
echo Building Azure Firewall...
#Spoke 2
# Create Azure Firewall Subnet and Management Subnets
az network vnet subnet create -g $rg --vnet-name spoke2 -n AzureFirewallSubnet --address-prefixes 10.2.0.64/26 --output none
az network public-ip create --name spoke2-azfw-pip --resource-group $rg --location $region1 --allocation-method static --sku standard --output none --only-show-errors

az network vnet subnet create -g $rg --vnet-name spoke2 -n AzureFirewallManagementSubnet --address-prefixes 10.2.0.128/26 --output none
az network public-ip create --name spoke2-azfw-mgmtpip --resource-group $rg --location $region1 --allocation-method static --sku standard --output none --only-show-errors

# Create Azure Firewall
az network firewall create --name spoke2-azfw --resource-group $rg --location $region1 --firewall-policy $region1-AZFW-Policy --vnet-name spoke2 --sku AZFW_VNet --tier basic --conf-name FW-config --m-conf-name FW-mgmconfig --m-public-ip spoke2-azfw-mgmtpip --output none
# Add Public IP to the firewall
az network firewall ip-config create --firewall-name spoke2-azfw --name FW-config --m-name FW-mgmconfig --public-ip-address spoke2-azfw-pip --m-public-ip-address spoke2-azfw-mgmtpip --m-vnet-name spoke2 --resource-group $rg --vnet-name spoke2 --output none
az network firewall update --name spoke2-azfw --resource-group $rg --output none --only-show-errors

#Spoke4
# Create Azure Firewall Subnet and Management Subnets
az network vnet subnet create -g $rg --vnet-name spoke4 -n AzureFirewallSubnet --address-prefixes 10.4.0.64/26 --output none
az network public-ip create --name spoke4-azfw-pip --resource-group $rg --location $region2  --allocation-method static --sku standard --output none --only-show-errors

az network vnet subnet create -g $rg --vnet-name spoke4 -n AzureFirewallManagementSubnet --address-prefixes 10.4.0.128/26 --output none
az network public-ip create --name spoke4-azfw-mgmtpip --resource-group $rg --location $region2 --allocation-method static --sku standard --output none --only-show-errors
# Create Azure Firewall
az network firewall create --name spoke4-azfw --resource-group $rg --location $region2 --firewall-policy $region2-AZFW-Policy --vnet-name spoke4 --sku AZFW_VNet --tier basic --conf-name FW-config --m-conf-name FW-mgmconfig --m-public-ip spoke4-azfw-mgmtpip --output none
# Add Public IP to the firewall
az network firewall ip-config create --firewall-name spoke4-azfw --name FW-config --public-ip-address spoke4-azfw-pip --m-public-ip-address spoke4-azfw-mgmtpip --m-vnet-name spoke4 --resource-group $rg --vnet-name spoke4 --output none
az network firewall update --name spoke4-azfw --resource-group $rg --output none

#Creating Log Analytics Workspaces
## Log Analytics workspace name.
Workspacename1=AZFirewall-$region1-Logs
Workspacename2=AZFirewall-$region2-Logs

echo Creating Log Analytics Workspaces...
msinsights=$(az provider show -n microsoft.insights --query registrationState -o tsv)
if [ $msinsights == 'NotRegistered' ] || [ $msinsights == 'Unregistered' ]; then
az provider register -n microsoft.insights --accept-terms
 prState=''
 while [[ $prState != 'Registered' ]];
 do
    prState=$(az provider show -n microsoft.insights --query registrationState -o tsv)
    echo "MS Insights State="$prState
    sleep 5
 done
fi
#Spoke2-azfw
az monitor log-analytics workspace create -g $rg --workspace-name $Workspacename1 --location $region1 --no-wait
#Spoke4-azfw
az monitor log-analytics workspace create -g $rg --workspace-name $Workspacename2 --location $region2 --no-wait

#EnablingAzure Firewall diagnostics
#Spoke2-azfw
az monitor diagnostic-settings create -n 'toLogAnalytics' \
--resource $(az network firewall show --name spoke2-azfw --resource-group $rg --query id -o tsv) \
--workspace $(az monitor log-analytics workspace show -g $rg --workspace-name $Workspacename1 --query id -o tsv) \
--logs '[{"category":"AzureFirewallApplicationRule","Enabled":true}, {"category":"AzureFirewallNetworkRule","Enabled":true}, {"category":"AzureFirewallDnsProxy","Enabled":true}]' \
--metrics '[{"category": "AllMetrics","enabled": true}]' \
--output none
#Spoke4-azfw
az monitor diagnostic-settings create -n 'toLogAnalytics' \
--resource $(az network firewall show --name spoke4-azfw --resource-group $rg --query id -o tsv) \
--workspace $(az monitor log-analytics workspace show -g $rg --workspace-name $Workspacename2 --query id -o tsv) \
--logs '[{"category":"AzureFirewallApplicationRule","Enabled":true}, {"category":"AzureFirewallNetworkRule","Enabled":true}, {"category":"AzureFirewallDnsProxy","Enabled":true}]' \
--metrics '[{"category": "AllMetrics","enabled": true}]' \
--output none

echo Updating indirect spoke UDRs to use Firewall as next hop...
#UDRs for Spoke 5 and 6
## Creating UDR + Disable BGP Propagation
az network route-table create --name RT-to-Spoke2-AzFW  --resource-group $rg --location $region1 --disable-bgp-route-propagation true --output none
## Default route to AzFW
az network route-table route create --resource-group $rg --name Default-to-AzFw --route-table-name RT-to-Spoke2-AzFW \
--address-prefix 0.0.0.0/0 \
--next-hop-type VirtualAppliance \
--next-hop-ip-address $(az network firewall show --name spoke2-azfw --resource-group $rg --query "ipConfigurations[].privateIpAddress" -o tsv) \
--output none
## Associated RT-Hub-to-AzFW to Spoke 5 and 6.
az network vnet subnet update -n main -g $rg --vnet-name spoke5 --route-table RT-to-Spoke2-AzFW --output none
az network vnet subnet update -n main -g $rg --vnet-name spoke6 --route-table RT-to-Spoke2-AzFW --output none

#UDRs for Spoke 7 and 8
## Creating UDR + Disable BGP Propagation
az network route-table create --name RT-to-Spoke4-AzFW  --resource-group $rg --location $region2 --disable-bgp-route-propagation true --output none
## Default route to AzFW
az network route-table route create --resource-group $rg --name Default-to-AzFw --route-table-name RT-to-Spoke4-AzFW \
--address-prefix 0.0.0.0/0 \
--next-hop-type VirtualAppliance \
--next-hop-ip-address $(az network firewall show --name spoke4-azfw --resource-group $rg --query "ipConfigurations[].privateIpAddress" -o tsv) \
--output none
## Associated RT-Hub-to-AzFW to Spoke 7 and 8.
az network vnet subnet update -n main -g $rg --vnet-name spoke7 --route-table RT-to-Spoke4-AzFW --output none
az network vnet subnet update -n main -g $rg --vnet-name spoke8 --route-table RT-to-Spoke4-AzFW --output none

echo Checking Hub1 provisioning status...
# Checking Hub1 provisioning and routing state
prState=''
rtState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub show -g $rg -n $hub1name --query 'provisioningState' -o tsv)
    echo "$hub1name provisioningState="$prState
    sleep 5
done

while [[ $rtState != 'Provisioned' ]];
do
    rtState=$(az network vhub show -g $rg -n $hub1name --query 'routingState' -o tsv)
    echo "$hub1name routingState="$rtState
    sleep 5
done
echo Creating Hub1 VPN Gateway...
# Creating VPN gateways in each Hub1
az network vpn-gateway create -n $hub1name-vpngw -g $rg --location $region1 --vhub $hub1name --no-wait

echo Checking Hub2 provisioning status...
# Checking Hub2 provisioning and routing state
prState=''
rtState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub show -g $rg -n $hub2name --query 'provisioningState' -o tsv)
    echo "$hub2name provisioningState="$prState
    sleep 5
done

while [[ $rtState != 'Provisioned' ]];
do
    rtState=$(az network vhub show -g $rg -n $hub2name --query 'routingState' -o tsv)
    echo "$hub2name routingState="$rtState
    sleep 5
done

echo Creating Hub2 VPN Gateway...
# Creating VPN gateways in each Hub2
az network vpn-gateway create -n $hub2name-vpngw -g $rg --location $region2 --vhub $hub2name --no-wait

echo Validating Branches VPN Gateways provisioning...
#Branches VPN Gateways provisioning status
prState=$(az network vnet-gateway show -g $rg -n branch1-vpngw --query provisioningState -o tsv)
if [[ $prState == 'Failed' ]];
then
    echo VPN Gateway is in fail state. Deleting and rebuilding.
    az network vnet-gateway delete -n branch1-vpngw -g $rg
    az network vnet-gateway create -n branch1-vpngw --public-ip-addresses branch1-vpngw-pip -g $rg --vnet branch1 --asn 65510 --gateway-type Vpn -l $region1 --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait
    sleep 5
else
    prState=''
    while [[ $prState != 'Succeeded' ]];
    do
        prState=$(az network vnet-gateway show -g $rg -n branch1-vpngw --query provisioningState -o tsv)
        echo "branch1-vpngw provisioningState="$prState
        sleep 5
    done
fi

prState=$(az network vnet-gateway show -g $rg -n branch2-vpngw --query provisioningState -o tsv)
if [[ $prState == 'Failed' ]];
then
    echo VPN Gateway is in fail state. Deleting and rebuilding.
    az network vnet-gateway delete -n branch2-vpngw -g $rg
    az network vnet-gateway create -n branch2-vpngw --public-ip-addresses branch2-vpngw-pip -g $rg --vnet branch2 --asn 65509 --gateway-type Vpn -l $region2 --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait
    sleep 5
else
    prState=''
    while [[ $prState != 'Succeeded' ]];
    do
        prState=$(az network vnet-gateway show -g $rg -n branch2-vpngw --query provisioningState -o tsv)
        echo "branch2-vpngw provisioningState="$prState
        sleep 5
    done
fi

echo Validating vHubs VPN Gateways provisioning...
#vWAN Hubs VPN Gateway Status
prState=$(az network vpn-gateway show -g $rg -n $hub1name-vpngw --query provisioningState -o tsv)
if [[ $prState == 'Failed' ]];
then
    echo VPN Gateway is in fail state. Deleting and rebuilding.
    az network vpn-gateway delete -n $hub1name-vpngw -g $rg
    az network vpn-gateway create -n $hub1name-vpngw -g $rg --location $region1 --vhub $hub1name --no-wait
    sleep 5
else
    prState=''
    while [[ $prState != 'Succeeded' ]];
    do
        prState=$(az network vpn-gateway show -g $rg -n $hub1name-vpngw --query provisioningState -o tsv)
        echo $hub1name-vpngw "provisioningState="$prState
        sleep 5
    done
fi

prState=$(az network vpn-gateway show -g $rg -n $hub2name-vpngw --query provisioningState -o tsv)
if [[ $prState == 'Failed' ]];
then
    echo VPN Gateway is in fail state. Deleting and rebuilding.
    az network vpn-gateway delete -n $hub2name-vpngw -g $rg
    az network vpn-gateway create -n $hub2name-vpngw -g $rg --location $region2 --vhub $hub2name --no-wait
    sleep 5
else
    prState=''
    while [[ $prState != 'Succeeded' ]];
    do
        prState=$(az network vpn-gateway show -g $rg -n $hub2name-vpngw --query provisioningState -o tsv)
        echo $hub2name-vpngw "provisioningState="$prState
        sleep 5
    done
fi

echo Building VPN connections from VPN Gateways to the respective Branches...
# get bgp peering and public ip addresses of VPN GW and VWAN to set up connection
bgp1=$(az network vnet-gateway show -n branch1-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
pip1=$(az network vnet-gateway show -n branch1-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
vwanbgp1=$(az network vpn-gateway show -n $hub1name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
vwanpip1=$(az network vpn-gateway show -n $hub1name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)

bgp2=$(az network vnet-gateway show -n branch2-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
pip2=$(az network vnet-gateway show -n branch2-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
vwanbgp2=$(az network vpn-gateway show -n $hub2name-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
vwanpip2=$(az network vpn-gateway show -n $hub2name-vpngw  -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)

# Creating virtual wan vpn site
echo Creating VPN Sites...
az network vpn-site create --ip-address $pip1 -n site-branch1 -g $rg --asn 65510 --bgp-peering-address $bgp1 -l $region1 --virtual-wan $vwanname --device-model 'Azure' --device-vendor 'Microsoft' --link-speed '50' --with-link true --output none
az network vpn-site create --ip-address $pip2 -n site-branch2 -g $rg --asn 65509 --bgp-peering-address $bgp2 -l $region2 --virtual-wan $vwanname --device-model 'Azure' --device-vendor 'Microsoft' --link-speed '50' --with-link true --output none

# Creating virtual wan vpn connection
echo Creating VPN Connections...
az network vpn-gateway connection create --gateway-name $hub1name-vpngw -n site-branch1-conn -g $rg --enable-bgp true --remote-vpn-site site-branch1 --internet-security --shared-key 'abc123' --output none
az network vpn-gateway connection create --gateway-name $hub2name-vpngw -n site-branch2-conn -g $rg --enable-bgp true --remote-vpn-site site-branch2 --internet-security --shared-key 'abc123' --output none

# Creating connection from vpn gw to local gateway and watch for connection succeeded
echo Creating VPN Connections from VPN Gateways to the respective Branches...
az network local-gateway create -g $rg -n site-$hub1name-LG --gateway-ip-address $vwanpip1 --asn 65515 --bgp-peering-address $vwanbgp1 -l $region1 --output none
az network vpn-connection create -n branch1-to-site-$hub1name -g $rg -l $region1 --vnet-gateway1 branch1-vpngw --local-gateway2 site-$hub1name-LG --enable-bgp --shared-key 'abc123' --output none

az network local-gateway create -g $rg -n site-$hub2name-LG --gateway-ip-address $vwanpip2 --asn 65515 --bgp-peering-address $vwanbgp2 -l $region2 --output none
az network vpn-connection create -n branch2-to-site-$hub2name -g $rg -l $region2 --vnet-gateway1 branch2-vpngw --local-gateway2 site-$hub2name-LG --enable-bgp --shared-key 'abc123' --output none

echo Configuring spoke1 and spoke3 vnet connection to their respective vHubs...
# **** Configuring vWAN route default route table to send traffic to Azure Firewall and reach indirect spokes: *****
echo Configuring spoke connections to their respective hubs...
echo Creating spoke 1 and 3 connection to their respective hubs...
# Spoke1 vnet connection
az network vhub connection create -n spoke1conn --remote-vnet spoke1 -g $rg --vhub-name $hub1name --output none --no-wait
# Spoke3 vnet connection
az network vhub connection create -n spoke3conn --remote-vnet spoke3 -g $rg --vhub-name $hub2name --no-wait

echo creating spoke 2 and spoke 4 vnet connections using static route to their respective Azure Firewalls...
#Spoke2 vnet connection and Static Route to Spoke2-azfw
spokevnet=spoke2
vnetid=$(az network vnet show -n $spokevnet -g $rg --query id -o tsv)
spk2nvaip=$(az network firewall show --name spoke2-azfw --resource-group $rg --query "ipConfigurations[].privateIpAddress" -o tsv)
dstcidr=10.2.0.0/16
conn=spoke2conn
propagateStaticRoutes=false #Static Route propagation true or false
vnetLocalRouteOverrideCriteria=Equal #possible values Equal = Onlink enabled or Contains=Onlink disabled
apiversion='2022-01-01' #Set API version
#SubID
subid=$(az account list --query "[?isDefault == \`true\`].id" --all -o tsv)
#vHubRegion
vhubregion=$(az network vhub show -g $rg -n $hub1name --query id --query location -o tsv)

az rest --method put --uri https://management.azure.com/subscriptions/$subid/resourceGroups/$rg/providers/Microsoft.Network/virtualHubs/$hub1name/hubVirtualNetworkConnections/$conn?api-version=$apiversion \
 --body '{"name": "'$conn'", "properties": {"remoteVirtualNetwork": {"id": "'$vnetid'"}, "enableInternetSecurity": true, "routingConfiguration": {"propagatedRouteTables": {}, "vnetRoutes": {"staticRoutes": [{"name": "'$hub1name-indirect-spokes-rt'", "addressPrefixes": ["'$dstcidr'"], "nextHopIpAddress": "'$spk2nvaip'"}], "staticRoutesConfig": {"propagateStaticRoutes": "'$propagateStaticRoutes'", "vnetLocalRouteOverrideCriteria": "'$vnetLocalRouteOverrideCriteria'"}}}}}' \
 --output none

prState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub connection show -n spoke2conn --vhub-name $hub1name -g $rg  --query 'provisioningState' -o tsv)
    echo "vnet connection spoke2conn provisioningState="$prState
    sleep 5
done

#Spoke4 vnet connection and Static Route to Spoke2-azfw
spokevnet=spoke4
vnetid=$(az network vnet show -n $spokevnet -g $rg --query id -o tsv)
spk4nvaip=$(az network firewall show --name spoke4-azfw --resource-group $rg --query "ipConfigurations[].privateIpAddress" -o tsv)
dstcidr="10.4.0.0/16"
conn=spoke4conn
propagateStaticRoutes=false #Static Route propagation true or false
vnetLocalRouteOverrideCriteria=Equal #Equal = Onlink enabled Contains=Onlink disabled
apiversion='2022-01-01' #Set API version
#SubID
subid=$(az account list --query "[?isDefault == \`true\`].id" --all -o tsv)
#vHubRegion
vhubregion=$(az network vhub show -g $rg -n $hub2name --query id --query location -o tsv)

az rest --method put --uri https://management.azure.com/subscriptions/$subid/resourceGroups/$rg/providers/Microsoft.Network/virtualHubs/$hub2name/hubVirtualNetworkConnections/$conn?api-version=$apiversion \
 --body '{"name": "'$conn'", "properties": {"remoteVirtualNetwork": {"id": "'$vnetid'"}, "enableInternetSecurity": true, "routingConfiguration": {"propagatedRouteTables": {}, "vnetRoutes": {"staticRoutes": [{"name": "'$hub2name-indirect-spokes-rt'", "addressPrefixes": ["'$dstcidr'"], "nextHopIpAddress": "'$spk4nvaip'"}], "staticRoutesConfig": {"propagateStaticRoutes": "'$propagateStaticRoutes'", "vnetLocalRouteOverrideCriteria": "'$vnetLocalRouteOverrideCriteria'"}}}}}' \
 --output none

prState=''
while [[ $prState != 'Succeeded' ]];
do
    prState=$(az network vhub connection show -n spoke4conn --vhub-name $hub2name -g $rg  --query 'provisioningState' -o tsv)
    echo "vnet connection spoke4conn provisioningState="$prState
    sleep 5
done

echo Adding static routes in the Hub1 default route table to the indirect spokes via Azure Firewall...
# Creating summary route to indirect spokes 5 and 6 via spoke2
az network vhub route-table route add --destination-type CIDR --resource-group $rg \
 --destinations 10.2.0.0/16 \
 --name defaultroutetable \
 --next-hop-type ResourceID \
 --next-hop $(az network vhub connection show --name spoke2conn --resource-group $rg --vhub-name $hub1name --query id -o tsv) \
 --vhub-name $hub1name \
 --route-name to-spoke2-azfw \
 --output none

# Creating summary route to indirect spokes 7 and 8 via spoke4
az network vhub route-table route add --destination-type CIDR --resource-group $rg \
 --destinations 10.4.0.0/16 \
 --name defaultroutetable \
 --next-hop-type ResourceID \
 --next-hop $(az network vhub connection show --name spoke4conn --resource-group $rg --vhub-name $hub2name --query id -o tsv) \
 --vhub-name $hub1name \
 --route-name to-spoke4-azfw \
 --no-wait

echo Adding static routes in the Hub2 default route table to the indirect spokes via Azure Firewall...
# Creating summary route to indirect spokes 7 and 8 via spoke4
az network vhub route-table route add --destination-type CIDR --resource-group $rg \
 --destinations 10.4.0.0/16 \
 --name defaultroutetable \
 --next-hop-type ResourceID \
 --next-hop $(az network vhub connection show --name spoke4conn --resource-group $rg --vhub-name $hub2name --query id -o tsv) \
 --vhub-name $hub2name \
 --route-name to-spoke4-azfw \
 --output none
# Creating summary route to indirect spokes 5 and 6 via spoke2
az network vhub route-table route add --destination-type CIDR --resource-group $rg \
 --destinations 10.2.0.0/16 \
 --name defaultroutetable \
 --next-hop-type ResourceID \
 --next-hop $(az network vhub connection show --name spoke2conn --resource-group $rg --vhub-name $hub1name --query id -o tsv) \
 --vhub-name $hub2name \
 --route-name to-spoke2-azfw \
 --no-wait
echo Deployment has finished
# Add script ending time but hours, minutes and seconds
end=`date +%s`
runtime=$((end-start))
echo "Script finished at $(date)"
echo "Total script execution time: $(($runtime / 3600)) hours $((($runtime / 60) % 60)) minutes and $(($runtime % 60)) seconds."
