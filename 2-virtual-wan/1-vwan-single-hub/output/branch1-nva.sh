Section: IOS configuration

crypto ikev2 proposal AZURE-IKE-PROPOSAL 
encryption aes-cbc-256
integrity sha1
group 2
!
crypto ikev2 policy AZURE-IKE-PROFILE 
proposal AZURE-IKE-PROPOSAL
match address local 10.10.1.9
!
crypto ikev2 keyring AZURE-KEYRING
peer 52.236.146.58
address 52.236.146.58
pre-shared-key changeme
peer 52.157.239.144
address 52.157.239.144
pre-shared-key changeme
!
crypto ikev2 profile AZURE-IKE-PROPOSAL
match address local 10.10.1.9
match identity remote address 52.236.146.58 255.255.255.255
match identity remote address 52.157.239.144 255.255.255.255
authentication remote pre-share
authentication local pre-share
keyring local AZURE-KEYRING
lifetime 28800
dpd 10 5 on-demand
!
crypto ipsec transform-set AZURE-IPSEC-TRANSFORM-SET esp-gcm 256 
mode tunnel
!
crypto ipsec profile AZURE-IPSEC-PROFILE
set transform-set AZURE-IPSEC-TRANSFORM-SET 
set ikev2-profile AZURE-IKE-PROPOSAL
set security-association lifetime seconds 3600
!
interface Tunnel0
ip address 10.10.10.1 255.255.255.252
tunnel mode ipsec ipv4
ip tcp adjust-mss 1350
tunnel source 10.10.1.9
tunnel destination 52.236.146.58
tunnel protection ipsec profile AZURE-IPSEC-PROFILE
!
interface Tunnel1
ip address 10.10.10.5 255.255.255.252
tunnel mode ipsec ipv4
ip tcp adjust-mss 1350
tunnel source 10.10.1.9
tunnel destination 52.157.239.144
tunnel protection ipsec profile AZURE-IPSEC-PROFILE
!
interface Loopback0
ip address 192.168.10.10 255.255.255.255
!
ip route 0.0.0.0 0.0.0.0 10.10.1.1
ip route 192.168.11.13 255.255.255.255 Tunnel0
ip route 192.168.11.12 255.255.255.255 Tunnel1
ip route 10.10.0.0 255.255.255.0 10.10.2.1
!
!
router bgp 65001
bgp router-id 192.168.10.10
neighbor 192.168.11.13 remote-as 65515
neighbor 192.168.11.13 ebgp-multihop 255
neighbor 192.168.11.13 soft-reconfiguration inbound
neighbor 192.168.11.13 update-source Loopback0
neighbor 192.168.11.12 remote-as 65515
neighbor 192.168.11.12 ebgp-multihop 255
neighbor 192.168.11.12 soft-reconfiguration inbound
neighbor 192.168.11.12 update-source Loopback0
network 10.10.0.0 mask 255.255.255.0
