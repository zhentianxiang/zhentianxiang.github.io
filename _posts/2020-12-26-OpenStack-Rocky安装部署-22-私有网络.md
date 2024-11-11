---
layout: post
title: OpenStack-Rocky安装部署-22-私有网络
date: 2020-12-26
tags: 云计算
---
#### 如果配置控制节点，请操作全部文档
#### 如果配置计算节点，请看标题

`5.配置Linux网桥代理（计算节点也配置）`

`6.通过验证以下所有sysctl值是否设置为确保Linux操作系统内核支持网桥过滤器1（计算节点也配置）`

### 1.安装组件

```
[root@controller ~]#  yum install openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-linuxbridge ebtables
```

### 2.配置服务器组件

```
[root@controller ~]#  vim  /etc/neutron/neutron.conf

配置数据库访问
[database]
#...
connection = mysql+pymysql://neutron:NEUTRON_DBPASS@controller/neutron

启用Modular Layer 2 (ML2)插件，路由服务和重叠的IP地址

[DEFAULT]
...
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = true

配置RabbitMQ 消息队列访问
[DEFAULT]
#...
transport_url = rabbit://openstack:RABBIT_PASS@controller

配置身份服务访问
[DEFAULT]
#...
auth_strategy = keystone

[keystone_authtoken]
#...
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = NEUTRON_PASS

配置网络服务来通知计算节点的网络拓扑变化
[DEFAULT]
#...
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true

[nova] 自己创建
#...
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = nova
password = NOVA_PASS

配置锁定路径
[oslo_concurrency] 546行
#...
lock_path = /var/lib/neutron/tmp
```

### 4.配置 Modular Layer 2 (ML2) 插件

ML2插件使用Linuxbridge机制来为实例创建layer－2虚拟网络基础设施

如果没有`ml2`和以下的需要自己创建

```
[root@controller ~]#  vim  /etc/neutron/plugins/ml2/ml2_conf.ini

启用flat，VLAN以及VXLAN网络
[ml2]
...
type_drivers = flat,vlan,vxlan

启用VXLAN私有网络
[ml2]
...
tenant_network_types = vxlan

启用Linuxbridge和layer－2机制
[ml2]
...
mechanism_drivers = linuxbridge,l2population

⚠️：Linuxbridge代理只支持VXLAN覆盖网络

启用端口安全扩展驱动
[ml2]
...
extension_drivers = port_security

配置公共虚拟网络为flat网络
[ml2_type_flat]
...
flat_networks = provider

为私有网络配置VXLAN网络识别的网络范围
[ml2_type_vxlan]
...
vni_ranges = 1:1000

启用ipset以提高安全组规则的效率
[securitygroup]
#...
enable_ipset = true
```

### 5.配置Linux网桥代理（计算节点也配置）

Linuxbridge代理为实例建立layer－2虚拟网络并且处理安全组规则。

```
[root@controller ~]#  vim  /etc/neutron/plugins/ml2/linuxbridge_agent.ini

将公共虚拟网络和公共物理网络接口对应起来
[linux_bridge]
physical_interface_mappings = provider:ens37

启用VXLAN覆盖网络，配置用于处理覆盖网络的物理网络接口的IP地址，并启用第2层填充

[vxlan]
enable_vxlan = true
local_ip = OVERLAY_INTERFACE_IP_ADDRESS  //桥接网卡地址
l2_population = true

启用安全组并配置Linux网桥iptables防火墙驱动程序
[securitygroup]
#...
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
```

### 6.通过验证以下所有`sysctl`值是否设置为确保Linux操作系统内核支持网桥过滤器1（计算节点也配置）

```
[root@controller ~]#  vim /etc/sysctl.conf

net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

[root@controller ~]#   modprobe br_netfilter

[root@controller ~]#   sysctl -p
```

### 7.配置layer－3代理

配置Linux网桥接口驱动程序

```
[root@controller ~]#  vim  /etc/neutron/l3_agent.ini

[DEFAULT]
#...
interface_driver = linuxbridge
```

### 8.配置DHCP代理

```
[root@controller ~]#  vim  /etc/neutron/dhcp_agent.ini

配置Linux桥接接口驱动程序Dnsmasq DHCP驱动程序，并启用隔离的元数据，以便提供商网络上的实例可以通过网络访问元数据
[DEFAULT]
#...
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true
```
返回[网络Neutron控制节点](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-20-Neutron控制节点配置/)继续部署

返回[网络Neutron计算节点](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-23-Neutron计算节点配置/)继续部署
