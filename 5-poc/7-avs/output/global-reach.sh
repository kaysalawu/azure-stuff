az network express-route peering connection create \
-g avsRG \
--circuit-name avs-er1 \
--peering-name AzurePrivatePeering \
-n avs-onprem-er1 \
--peer-circuit  \
--address-prefix 10.99.0.0/29
