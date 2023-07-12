#! /bin/bash

apt update
apt install -y tcpdump bind9-utils dnsutils net-tools
apt install -y unbound

touch /etc/unbound/unbound.log
chmod a+x /etc/unbound/unbound.log

cat <<EOF > /etc/unbound/unbound.conf
server:
        port: 53
        do-ip4: yes
        do-udp: yes
        do-tcp: yes

        interface: 0.0.0.0

        access-control: 0.0.0.0 deny
        access-control: 127.0.0.0/8 allow
        access-control: 10.0.0.0/8 allow
        access-control: 192.168.0.0/16 allow
        access-control: 172.16.0.0/12 allow
        access-control: 35.199.192.0/19 allow

        # local data records
        local-data: "vm.avs.corp 3600 IN A 10.10.0.5"
        local-data: "backup.onprem.corp 3600 IN A 10.20.0.5"

        # hosts redirected to PrivateLink


forward-zone:
        name: "az.corp."
        forward-addr: 10.11.5.4

forward-zone:
        name: "."
        forward-addr: 168.63.129.16
EOF

sleep 10
systemctl restart unbound
systemctl enable unbound

# test scripts
#-----------------------------------

# ping-ip

cat <<EOF > /usr/local/bin/ping-ip
echo -e "\n ping ip ...\n"
echo "hub    - 10.11.0.5 -\$(ping -qc2 -W1 10.11.0.5 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "\$5" ms":"NA") }')"
echo "core1  - 10.1.0.5 -\$(ping -qc2 -W1 10.1.0.5 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "\$5" ms":"NA") }')"
echo "core2  - 10.2.0.5 -\$(ping -qc2 -W1 10.2.0.5 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "\$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-ip

# ping-dns

cat <<EOF > /usr/local/bin/ping-dns
echo -e "\n ping dns ...\n"
echo "vm.hub.az.corp - \$(dig +short vm.hub.az.corp | tail -n1) -\$(ping -qc2 -W1 vm.hub.az.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "\$5" ms":"NA") }')"
echo "bak-srv.core1.az.corp - \$(dig +short bak-srv.core1.az.corp | tail -n1) -\$(ping -qc2 -W1 bak-srv.core1.az.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "\$5" ms":"NA") }')"
echo "bak-srv.core2.az.corp - \$(dig +short bak-srv.core2.az.corp | tail -n1) -\$(ping -qc2 -W1 bak-srv.core2.az.corp 2>&1 | awk -F'/' 'END{ print (/^rtt/? "OK "\$5" ms":"NA") }')"
EOF
chmod a+x /usr/local/bin/ping-dns

# curl-ip

cat <<EOF > /usr/local/bin/curl-ip
echo -e "\n curl ip ...\n"
echo  "\$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.11.0.5) - hub    (10.11.0.5)"
echo  "\$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.1.0.5) - core1  (10.1.0.5)"
echo  "\$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.2.0.5) - core2  (10.2.0.5)"
echo  "\$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null 10.3.0.5) - yellow  (10.3.0.5)"
EOF
chmod a+x /usr/local/bin/curl-ip

# curl-dns

cat <<EOF > /usr/local/bin/curl-dns
echo -e "\n curl dns ...\n"
echo  "\$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.hub.az.corp) - vm.hub.az.corp"
echo  "\$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null bak-srv.core1.az.corp) - bak-srv.core1.az.corp"
echo  "\$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null bak-srv.core2.az.corp) - bak-srv.core2.az.corp"
echo  "\$(curl -kL --max-time 2.0 -H 'Cache-Control: no-cache' -w "%{http_code} (%{time_total}s) - %{remote_ip}" -s -o /dev/null vm.yellow.az.corp) - vm.yellow.az.corp"
EOF
chmod a+x /usr/local/bin/curl-dns

# trace-ip

cat <<EOF > /usr/local/bin/trace-ip
echo -e "\n trace ip ...\n"
traceroute 10.11.0.5
echo -e "hub   \n"
traceroute 10.1.0.5
echo -e "core1 \n"
traceroute 10.2.0.5
echo -e "core2 \n"
traceroute 10.3.0.5
echo -e "yellow \n"
EOF
chmod a+x /usr/local/bin/trace-ip
