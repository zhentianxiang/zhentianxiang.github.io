---
layout: post
title: OpenStack-Rocky安装部署-20-Neutron控制节点配置
date: 2020-12-26
tags: 云计算
---

### 1.网络服务概念

OpenStack Networking（neutron），允许创建、插入接口设备，这些设备由其他的OpenStack服务管理。插件式的实现可以容纳不同的网络设备和软件，为OpenStack架构与部署提供了灵活性。

它包含下列组件：

- neutron-server

  接收和路由API请求到合适的OpenStack网络插件，以达到预想的目的。

- OpenStack网络插件和代理

  插拔端口，创建网络和子网，以及提供IP地址，这些插件和代理依赖于供应商和技术而不同，OpenStack网络基于插件和代理为Cisco 虚拟和物理交换机、NEC OpenFlow产品，Open vSwitch,Linux bridging以及VMware NSX 产品穿线搭桥。常见的代理L3(3层)，DHCP(动态主机IP地址)，以及插件代理。

- 消息队列

  大多数的OpenStack Networking安装都会用到，用于在neutron-server和各种各样的代理进程间路由信息。也为某些特定的插件扮演数据库的角色，以存储网络状态

OpenStack网络主要和OpenStack计算交互，以提供网络连接到它的实例。

### 2.网络neutron概念

OpenStack网络（neutron）在您的OpenStack环境中管理虚拟网络基础架构（VNI）的所有网络方面以及物理网络基础架构（PNI）的访问层方面。OpenStack Networking使项目能够创建高级的虚拟网络拓扑，其中可能包括防火墙和虚拟专用网络（VPN）之类的服务。

网络提供了网络，子网和路由器作为对象抽象。每个抽象都有模仿其物理对应物的功能：网络包含子网，路由器在不同子网和网络之间路由流量。

任何给定的网络设置都至少具有一个外部网络。与其他网络不同，外部网络不仅仅是虚拟定义的网络。取而代之的是，它表示对OpenStack安装外部可访问的物理外部网络的查看。外部网络上的任何人都可以物理访问外部网络上的IP地址。

除外部网络外，任何网络设置都具有一个或多个内部网络。这些软件定义的网络直接连接到VM。仅任何给定内部网络上的VM或通过接口连接到类似路由器的子网上的VM都可以直接访问连接到该网络的VM。

为了使外部网络访问VM，反之亦然，需要网络之间的路由器。每个路由器都有一个连接到外部网络的网关和一个或多个连接到内部网络的接口。就像物理路由器一样，子网可以访问连接到同一路由器的其他子网上的计算机，并且计算机可以通过路由器的网关访问外部网络。

此外，您可以将外部网络上的IP地址分配给内部网络上的端口。只要有东西连接到子网，该连接就称为端口。您可以将外部网络IP地址与VM的端口关联。这样，外部网络上的实体可以访问VM。

网络还支持安全组。安全组使管理员可以按组定义防火墙规则。一台虚拟机可以属于一个或多个安全组，并且网络会将这些安全组中的规则应用于该虚拟机的阻止或取消阻止端口，端口范围或流量类型。

网络使用的每个插件都有其自己的概念。尽管对操作VNI和OpenStack环境并不重要，但了解这些概念可以帮助您设置网络。所有网络安装均使用核心插件和安全组插件（或仅使用No-Op安全组插件）。此外，还可以使用防火墙即服务（FWaaS）。
### 3.前提条件

用数据库访问客户端以`root`用户身份连接到数据库服务器

```
[root@controller ~]#  mysql -u root -p
```

创建`neutron`数据库

```
MariaDB [(none)] CREATE DATABASE neutron;
```

授予对`neutron`数据库的适当访问权限

```
MariaDB [(none)]> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' \
  IDENTIFIED BY 'NEUTRON_DBPASS';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' \
  IDENTIFIED BY 'NEUTRON_DBPASS';
```

### 4.获取到管理员权限

```
[root@controller ~]#  . admin-openrc
```

### 5.要创建服务凭证

创建`neutron`用户

```
[root@controller ~]#  openstack user create --domain default --password-prompt neutron

User Password:NEUTRON_PASS
Repeat User Password:NEUTRON_PASS
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | default                          |
| enabled             | True                             |
| id                  | fdb0f541e28141719b6a43c8944bf1fb |
| name                | neutron                          |
| options             | {}                               |
| password_expires_at | None                             |
+---------------------+----------------------------------+
```

把`neutron`用户添加`admin`角色中

```
[root@controller ~]#  openstack role add --project service --user neutron admin
```

创建`neutron`服务实体

```
[root@controller ~]#  openstack service create --name neutron \
  --description "OpenStack Networking" network

+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | OpenStack Networking             |
| enabled     | True                             |
| id          | f71529314dab4a4d8eca427e701d209e |
| name        | neutron                          |
| type        | network                          |
+-------------+----------------------------------+
```

创建网络服务API端点

```
[root@controller ~]#  openstack endpoint create --region RegionOne \
  network public http://controller:9696

+--------------+----------------------------------+
| Field        | Value                            |
+--------------+----------------------------------+
| enabled      | True                             |
| id           | 85d80a6d02fc4b7683f611d7fc1493a3 |
| interface    | public                           |
| region       | RegionOne                        |
| region_id    | RegionOne                        |
| service_id   | f71529314dab4a4d8eca427e701d209e |
| service_name | neutron                          |
| service_type | network                          |
| url          | http://controller:9696           |
+--------------+----------------------------------+

[root@controller ~]#  openstack endpoint create --region RegionOne \
  network internal http://controller:9696

+--------------+----------------------------------+
| Field        | Value                            |
+--------------+----------------------------------+
| enabled      | True                             |
| id           | 09753b537ac74422a68d2d791cf3714f |
| interface    | internal                         |
| region       | RegionOne                        |
| region_id    | RegionOne                        |
| service_id   | f71529314dab4a4d8eca427e701d209e |
| service_name | neutron                          |
| service_type | network                          |
| url          | http://controller:9696           |
+--------------+----------------------------------+

[root@controller ~]#  openstack endpoint create --region RegionOne \
  network admin http://controller:9696

+--------------+----------------------------------+
| Field        | Value                            |
+--------------+----------------------------------+
| enabled      | True                             |
| id           | 1ee14289c9374dffb5db92a5c112fc4e |
| interface    | admin                            |
| region       | RegionOne                        |
| region_id    | RegionOne                        |
| service_id   | f71529314dab4a4d8eca427e701d209e |
| service_name | neutron                          |
| service_type | network                          |
| url          | http://controller:9696           |
+--------------+----------------------------------+
```

### 6.配置网络选项

您可以使用选项1和2表示的两种体系结构之一来部署网络服务。

选项1部署了最简单的可能体系结构，该体系结构仅支持将实例附加到提供程序（外部）网络。没有自助服务（专用）网络，路由器或浮动IP地址。只有admin或其他特权用户可以管理提供商网络。

选项2通过支持将实例附加到自助服务网络的第3层服务增强了选项1。该demo非特权用户或其他非特权用户可以管理自助服务网络，包括在自助服务网络与提供商网络之间提供连接的路由器。此外，浮动IP地址使用来自外部网络（例如Internet）的自助服务网络提供了到实例的连接性。

自助服务网络通常使用覆盖网络。诸如VXLAN之类的覆盖网络协议包括其他标头，这些标头会增加开销并减少可用于有效负载或用户数据的空间。在不了解虚拟网络基础结构的情况下，实例尝试使用默认的1500字节以太网最大传输单元（MTU）发送数据包。网络服务会通过DHCP自动为实例提供正确的MTU值。但是，某些云映像不使用DHCP或忽略DHCP MTU选项，而是需要使用元数据或脚本进行配置。

选择以下网络选项之一来配置特定于它的服务。之后，返回此处并继续 配置配置[元数据代理](http://blog.linuxtian.top/2020/12/OpenStack-Train%E5%AE%89%E8%A3%85%E9%83%A8%E7%BD%B2-23-Neutron%E6%8E%A7%E5%88%B6%E8%8A%82%E7%82%B9%E9%85%8D%E7%BD%AE/)

- [网络选项1：公共网络](http://blog.linuxtian.top/2020/12/OpenStack-Rocky%E5%AE%89%E8%A3%85%E9%83%A8%E7%BD%B2-21-%E5%85%AC%E5%85%B1%E7%BD%91%E7%BB%9C/)
- [网络选项2：私有网络](http://blog.linuxtian.top/2020/12/OpenStack-Rocky%E5%AE%89%E8%A3%85%E9%83%A8%E7%BD%B2-22-%E7%A7%81%E6%9C%89%E7%BD%91%E7%BB%9C/)

### 7.配置元数据代理

元数据代理提供配置信息，例如实例凭证

编辑`/etc/neutron/metadata_agent.ini`文件并完成以下操作

```
[root@controller ~]# vim /etc/neutron/metadata_agent.ini

配置元数据主机和共享机密
[DEFAULT]
# ...
nova_metadata_host = controller
metadata_proxy_shared_secret = METADATA_SECRET
```

### 8.配置计算服务使用网络服务

```
[root@controller ~]# vim /etc/nova/nova.conf

启用元数据代理，并配置机密
[neutron] 7663行
#...
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = NEUTRON_PASS
service_metadata_proxy = true
metadata_proxy_shared_secret = METADATA_SECRET
```

### 9.最终确定安装

网络服务初始化脚本需要`/etc/neutron/plugin.ini`指向ML2插件配置文件的符号链接 `/etc/neutron/plugins/ml2/ml2_conf.ini`。如果此符号链接不存在，请使用以下命令创建它

```
[root@controller ~]#  ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
```

填充数据库

```
[root@controller ~]#  su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
```

⚠️：由于该脚本需要完整的服务器和插件配置文件，因此稍后会为网络进行数据库填充。

### 10.重新启动Compute API服务

```
[root@controller ~]#  systemctl restart openstack-nova-api.service
```

### 11.启动网络服务，并将其配置为在系统引导时启动

对于两个网络选项：

```
[root@controller ~]#  systemctl enable neutron-server.service \
  neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
  neutron-metadata-agent.service
[root@controller ~]#  systemctl start neutron-server.service \
  neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
  neutron-metadata-agent.service
```
启动服务遇到的任何报错都是因为以上文中提到的配置文件有错误，请仔细认真检查，不要相信自己的复制粘贴。

对于网络选项2，还启用并启动第3层服务：

```
[root@controller ~]#  systemctl enable neutron-l3-agent.service
[root@controller ~]#  systemctl start neutron-l3-agent.service
```
