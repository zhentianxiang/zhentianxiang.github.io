---
layout: post
title: OpenStack-Rocky安装部署-21-公共网络
date: 2020-12-26
tags: 云计算
---

#### 如果配置控制节点，请完成全部文档
#### 如果部署计算节点，请完成标题

`5.配置Linuxbridge代理`

`6.通过验证以下所有sysctl值是否设置为确保Linux操作系统内核支持网桥过滤器`

### 1.安装组件

```
[root@controller ~]#  yum install openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-linuxbridge ebtables
```

### 2.配置服务器组件

网络服务器组件配置包括数据库，身份验证机制，消息队列，拓扑更改通知和插件

### 3.编辑`/etc/neutron/neutron.conf`文件并完成以下操作

```
[root@controller ~]# vim /etc/neutron/neutron.conf

配置数据库访问
[database]
#...
connection = mysql+pymysql://neutron:NEUTRON_DBPASS@controller/neutron

启用模块化第2层（ML2）插件并禁用其他插件
[DEFAULT]
#...
core_plugin = ml2
service_plugins =

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

将网络配置为通知Compute网络拓扑更改
[DEFAULT]
#...
notify_nova_on_port_status_changes = true
notify_nova_on_port_data_changes = true

[nova]
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
[oslo_concurrency]
#...
lock_path = /var/lib/neutron/tmp
```

### 4.配置Modular Layer 2 (ML2) 插件

ML2插件使用Linux桥接器机制为实例构建第2层（桥接和交换）虚拟网络基础结构

如果没有`[ml2]` 、`[ml2_type_flat]`、`[securitygroup]`自己找个地儿创建个

```
[root@controller ~]# vim /etc/neutron/plugins/ml2/ml2_conf.ini

启用flat和VLAN网络
[ml2]
#...
type_drivers = flat,vlan

禁用私有网络
[ml2]
...
tenant_network_types =

启用Linuxbridge机制
[ml2]
...
mechanism_drivers = linuxbridge

启用端口安全扩展驱动
[ml2]
...
extension_drivers = port_security

配置公共虚拟网络为flat网络
[ml2_type_flat]
...
flat_networks = provider

启用 ipset 增加安全组规则的高效性
[securitygroup]
...
enable_ipset = True
```

### 5.配置Linuxbridge代理(计算节点也配置)

Linuxbridge代理为实例建立layer－2虚拟网络并且处理安全组规则

没有`[linux_bridge`]、`[vxlan]`、`[securitygroup]`也自己找个地儿创建

```
[root@controller ~]# vim /etc/neutron/plugins/ml2/linuxbridge_agent.ini

将公共虚拟网络和公共物理网络接口对应起来
[linux_bridge]
physical_interface_mappings = provider:ens37

禁止VXLAN覆盖网络
[vxlan]
enable_vxlan = false

启用安全组并配置Linux网桥iptables防火墙驱动程序
[securitygroup]
...
enable_security_group = true
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
```

### 6.通过验证以下所有sysctl值是否设置为确保Linux操作系统内核支持网桥过滤器（计算节点也配置）

```
[root@controller ~]# vim /etc/sysctl.conf

net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1

[root@controller ~]#  modprobe br_netfilter

[root@controller ~]#  sysctl -p
```

### 7.配置DHCP代理

DHCP代理为虚拟网络提供DHCP服务

```
[root@controller ~]# vim /etc/neutron/dhcp_agent.ini

配置Linux桥接接口驱动程序Dnsmasq DHCP驱动程序，并启用隔离的元数据，以便提供商网络上的实例可以通过网络访问元数据
[DEFAULT]
#...
interface_driver = linuxbridge
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = true
```

返回[Neutron控制节点配置](http://blog.linuxtian.top/2020/12/OpenStack-Rocky安装部署-20-Neutron控制节点配置/)继续配置

返回[Neutron计算节点配置](http://blog.linuxtian.top/2020/12/OpenStack-Rocky安装部署-23-Neutron计算节点配置/)继续配置
