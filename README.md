
# Azure Network Architecture - Terraform Examples <!-- omit from toc -->

Contents
<!-- TOC -->
- [1. Hub and Spoke](#1-hub-and-spoke)
  - [1.1. Hub and Spoke - Single Region](#11-hub-and-spoke---single-region)
  - [1.2. Hub and Spoke - Dual Region](#12-hub-and-spoke---dual-region)
  - [1.3. Hub and Spoke Secure - Single Region](#13-hub-and-spoke-secure---single-region)
- [2. Virtual WAN](#2-virtual-wan)
  - [2.1. Virtual WAN - Single Hub](#21-virtual-wan---single-hub)
  - [2.2. Virtual WAN - Dual Hub](#22-virtual-wan---dual-hub)
  - [2.3. Virtual WAN - Single Hub (VPN)](#23-virtual-wan---single-hub-vpn)
  - [2.4. Virtual WAN - Dual Hub (Mixed)](#24-virtual-wan---dual-hub-mixed)
  - [2.5. Secure Virtual WAN - Single Hub](#25-secure-virtual-wan---single-hub)
  - [2.6. Secure Virtual WAN - Dual Hub](#26-secure-virtual-wan---dual-hub)
- [3. Virtual Network Manager](#3-virtual-network-manager)
- [4. General](#4-general)
<!-- /TOC -->

## [1. Hub and Spoke](./1-hub-and-spoke/)

### 1.1. Hub and Spoke - Single Region
[Terraform Code](./1-hub-and-spoke/1-hub-spoke-single-region)
![Hub and Spoke - Single Region](./images/scenarios//1-1-hub-spoke-single-region.png)

### 1.2. Hub and Spoke - Dual Region
[Terraform Code](./1-hub-and-spoke/2-hub-spoke-dual-region/)
![Hub and Spoke - Dual Region](./images/scenarios//1-2-hub-spoke-dual-region.png)

### 1.3. Hub and Spoke Secure - Single Region
[Terraform Code](./1-hub-and-spoke/3-hub-spoke-sec-single-region)
![Hub and Spoke Secure - Single Region](./images/scenarios//1-3-hub-spoke-sec-single-region.png)

## [2. Virtual WAN](./2-virtual-wan/)

### 2.1. Virtual WAN - Single Hub
[Terraform Code](./2-virtual-wan/1-virtual-wan-single-hub/)
![Virtual WAN - Single Hub](./images/scenarios//2-1-vwan-single-hub.png)


### 2.2. Virtual WAN - Dual Hub
[Terraform Code](./2-virtual-wan/2-virtual-wan-dual-hub/)
![Virtual WAN - Dual Hub](./images/scenarios//2-2-vwan-dual-hub.png)


### 2.3. Virtual WAN - Single Hub (VPN)
[Terraform Code](./2-virtual-wan/3-virtual-wan-single-hub-vpn/)
![Virtual WAN - Single Hub (VPN)](./images/scenarios//2-3-vwan-single-hub-vpn.png)


### 2.4. Virtual WAN - Dual Hub (Mixed)
[Terraform Code](./2-virtual-wan/4-virtual-wan-dual-hub-mixed/)
![Virtual WAN - Dual Hub (Mixed)](./images/scenarios//2-4-vwan-dual-hub-mixed.png)

### 2.5. Secure Virtual WAN - Single Hub
[Terraform Code](./2-virtual-wan/5-secure-virtual-wan-single-hub/)

This code deploys a secure virtual WAN architecture playground to observe dynamic routing patterns.

![Virtual WAN - Single Hub](./images/scenarios//2-5-secure-vwan-single-hub.png)


### 2.6. Secure Virtual WAN - Dual Hub
[Terraform Code](./2-virtual-wan/6-secure-virtual-wan-dual-hub/)
![Virtual WAN - Dual Hub](./images/scenarios//2-6-secure-vwan-dual-hub.png)

## [3. Virtual Network Manager](./3-virtual-network-manager/)

## [4. General](./4-general/)
