#!/bin/bash

rg="Hspoke14RG"

vnetName=$(az network vnet list -g "$rg" --query "[].name" -o tsv | nl -s ". ")
echo $vnetName
