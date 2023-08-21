rg=terraform

cat <<EOF > cloud-init.txt
#cloud-config
package_upgrade: true
packages:
- stress
runcmd:
- sudo stress --cpu 1
EOF

az vm create \
    --resource-group $rg \
    --name vm1 \
    --location eastUS \
    --image UbuntuLTS \
    --custom-data cloud-init.txt \
    --generate-ssh-keys

VMID=$(az vm show \
        --resource-group $rg \
        --name vm1 \
        --query id \
        --output tsv)

az monitor metrics alert create \
    -n "Cpu80PercentAlert" \
    --resource-group $rg \
    --scopes $VMID \
    --condition "max percentage CPU > 80" \
    --description "Virtual machine is running at or greater than 80% CPU utilization" \
    --evaluation-frequency 1m \
    --window-size 1m \
    --severity 3
