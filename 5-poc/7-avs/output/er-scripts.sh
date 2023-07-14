!#/bin/bash

clear
echo -e "\nER1 Circuit Routes Summary"
echo "======================================"
az network express-route list-route-tables-summary \
-g avsRG \
-n avs-er1 \
--path primary \
--peering-name AzurePrivatePeering \
--query value -o table --only-show-errors

echo -e "\nER1 Circuit Routes Full"
echo "======================================"
az network express-route list-route-tables \
-g avsRG \
-n avs-er1 \
--path primary \
--peering-name AzurePrivatePeering \
--query value -o table --only-show-errors

echo -e "\nCore1 Effective Routes"
echo "======================================"
az network nic show-effective-route-table -g avsRG -n avs-core1-bak-srv-nic -o table --only-show-errors

echo -e "\nCore2 Effective Routes"
echo "======================================"
az network nic show-effective-route-table -g avsRG -n avs-core2-bak-srv-nic -o table --only-show-errors

echo -e "\nYellow Effective Routes"
echo "======================================"
az network nic show-effective-route-table -g avsRG -n avs-yellow-vm-nic -o table --only-show-errors

echo -e "\nHub Effective Routes"
echo "======================================"
az network nic show-effective-route-table -g avsRG -n avs-yellow-vm-nic -o table --only-show-errors

echo -e "\nOnprem Effective Routes"
echo "======================================"
az network nic show-effective-route-table -g avsRG -n avs-onprem-bak-srv-nic -o table --only-show-errors
