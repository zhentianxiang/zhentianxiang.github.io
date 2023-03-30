---
layout: post
title: OpenStack-Rocky安装部署-31-Openstack启动实例
date: 2020-12-26
tags: 云计算
---

## 启动实例

本部分创建必要的虚拟网络以支持启动实例。网络选项1包括一个提供程序（外部）网络，以及一个使用它的实例。联网选项2包括一个带有一个使用它的实例的提供者网络，以及一个带有一个使用它的实例的自助服务（专用）网络。

本节中的说明使用控制器节点上的命令行界面（CLI）工具。但是，您可以在安装了该工具的任何主机上按照说明进行操作。

有关CLI工具的更多信息，请参阅 [Pike](https://docs.openstack.org/python-openstackclient/pike/cli/command-objects/server.html#server-create)的 [OpenStackClient文档，Queens](https://docs.openstack.org/python-openstackclient/queens/cli/command-objects/server.html#server-create)的[OpenStackClient文档](https://docs.openstack.org/python-openstackclient/rocky/cli/command-objects/server.html#server-create)或[Rocky](https://docs.openstack.org/python-openstackclient/rocky/cli/command-objects/server.html#server-create)的 [OpenStackClient文档](https://docs.openstack.org/python-openstackclient/rocky/cli/command-objects/server.html#server-create)。

要使用仪表板，请参阅 [Pike](https://docs.openstack.org/horizon/pike/user/)的 [仪表板用户文档，Queens](https://docs.openstack.org/horizon/queens/user/)的[仪表板用户文档](https://docs.openstack.org/horizon/rocky/user/)或[Rocky](https://docs.openstack.org/horizon/rocky/user/)的 [仪表板用户文档](https://docs.openstack.org/horizon/rocky/user/)。

### 创建虚拟网络

为配置Neutron时选择的联网选项创建虚拟网络。如果选择选项1，则仅创建提供商网络。如果选择选项2，则创建提供商和自助服务网络。

- [公共网络](https://docs.openstack.org/install-guide/launch-instance-networks-provider.html)
- [私有网络](https://docs.openstack.org/install-guide/launch-instance-networks-selfservice.html)

以下说明和图表使用示例IP地址范围。您必须针对特定环境进行调整。

![](/images/posts/云计算/Train版本部署/启动实例/1.png)

**联网选项1：提供商网络-概述**

![](/images/posts/云计算/Train版本部署/启动实例/2.png)

**联网选项1：提供商网络-连接性**

### 建立供应商网络

在控制器节点上，`admin`获取凭据以访问仅管理员的CLI命令

```
[root@controller ~]  . admin-openrc
```

创建网络

```
[root@controller ~]  openstack network create  --share --external \
  --provider-physical-network provider \
  --provider-network-type flat provider

Created a new network:

+---------------------------+--------------------------------------+
| Field                     | Value                                |
+---------------------------+--------------------------------------+
| admin_state_up            | UP                                   |
| availability_zone_hints   |                                      |
| availability_zones        |                                      |
| created_at                | 2017-03-14T14:37:39Z                 |
| description               |                                      |
| dns_domain                | None                                 |
| id                        | 54adb94a-4dce-437f-a33b-e7e2e7648173 |
| ipv4_address_scope        | None                                 |
| ipv6_address_scope        | None                                 |
| is_default                | None                                 |
| mtu                       | 1500                                 |
| name                      | provider                             |
| port_security_enabled     | True                                 |
| project_id                | 4c7f48f1da5b494faaa66713686a7707     |
| provider:network_type     | flat                                 |
| provider:physical_network | provider                             |
| provider:segmentation_id  | None                                 |
| qos_policy_id             | None                                 |
| revision_number           | 3                                    |
| router:external           | External                             |
| segments                  | None                                 |
| shared                    | True                                 |
| status                    | ACTIVE                               |
| subnets                   |                                      |
| updated_at                | 2017-03-14T14:37:39Z                 |
+---------------------------+--------------------------------------+
```

该`--share`选项允许所有项目使用虚拟网络。

该`--external`选项将虚拟网络定义为外部。如果您想创建一个内部网络，则可以使用`--internal`。默认值为`internal`。

在和 选项平坦虚拟网络连接到所述平坦的上（天然/未标记的）的物理网络使用从下面的文件的信息在主机上的接口：`--provider-physical-network provider``--provider-network-type flat``eth1`

`ml2_conf.ini`：

```
[ml2_type_flat]
flat_networks = provider
```

`linuxbridge_agent.ini`：

```
[linux_bridge]
physical_interface_mappings = provider:eth1
```

在网络上创建一个子网：

```
[root@controller ~]  openstack subnet create --network provider \
  --allocation-pool start=START_IP_ADDRESS,end=END_IP_ADDRESS \
  --dns-nameserver DNS_RESOLVER --gateway PROVIDER_NETWORK_GATEWAY \
  --subnet-range PROVIDER_NETWORK_CIDR provider
```

用`PROVIDER_NETWORK_CIDR`CIDR表示法替换为提供商物理网络上的子网。

更换`START_IP_ADDRESS`和`END_IP_ADDRESS`与要分配的情况下，子网内的范围内的第一个和最后一个IP地址。此范围不得包含任何现有的活动IP地址。

替换`DNS_RESOLVER`为DNS解析器的IP地址。在大多数情况下，您可以使用`/etc/resolv.conf`主机上文件中的一个。

用`PROVIDER_NETWORK_GATEWAY`提供商网络上的网关IP地址替换，通常是“ .1” IP地址。

**例**

提供者网络使用192.168.0.0/24，网关位于192.168.0.1。DHCP服务器为每个实例分配从192.168.0.10到192.168.0.250的IP地址。所有实例均使用8.8.8.8作为DNS解析器。

因为我宿主级网卡就是192.168.0.0/24网段的，所以我桥接网卡也是要用此网段，注意不要和宿主机网卡起地址冲突就行。

```
[root@controller ~]  openstack subnet create --network provider \
  --allocation-pool start=203.0.113.101,end=203.0.113.250 \
  --dns-nameserver 8.8.4.4 --gateway 203.0.113.1 \
  --subnet-range 203.0.113.0/24 provider

Created a new subnet:
+-------------------+--------------------------------------+
| Field             | Value                                |
+-------------------+--------------------------------------+
| allocation_pools  | 192.168.0.10-192.168.0.250           |
| cidr              | 192.168.0.0/24                       |
| created_at        | 2017-03-29T05:48:29Z                 |
| description       |                                      |
| dns_nameservers   | 8.8.8.8                              |
| enable_dhcp       | True                                 |
| gateway_ip        | 192.168.0.1                          |
| host_routes       |                                      |
| id                | e84b4972-c7fc-4ce9-9742-fdc845196ac5 |
| ip_version        | 4                                    |
| ipv6_address_mode | None                                 |
| ipv6_ra_mode      | None                                 |
| name              | provider                             |
| network_id        | 1f816a46-7c3f-4ccf-8bf3-fe0807ddff8d |
| project_id        | 496efd248b0c46d3b80de60a309177b5     |
| revision_number   | 2                                    |
| segment_id        | None                                 |
| service_types     |                                      |
| subnetpool_id     | None                                 |
| updated_at        | 2017-03-29T05:48:29Z                 |
+-------------------+--------------------------------------+
```

### 创建实例类型

最小的默认风格每个实例消耗512 MB内存。对于计算节点的内存少于4 GB的环境，我们建议创建`m1.nano`每个实例仅需要64 MB的风味。仅将此口味与CirrOS图像一起用于测试目的。

```
[root@controller ~]  openstack flavor create --id 0 --vcpus 1 --ram 64 --disk 1 m1.nano

+----------------------------+---------+
| Field                      | Value   |
+----------------------------+---------+
| OS-FLV-DISABLED:disabled   | False   |
| OS-FLV-EXT-DATA:ephemeral  | 0       |
| disk                       | 1       |
| id                         | 0       |
| name                       | m1.nano |
| os-flavor-access:is_public | True    |
| properties                 |         |
| ram                        | 64      |
| rxtx_factor                | 1.0     |
| swap                       |         |
| vcpus                      | 1       |
+----------------------------+---------+
```

### 添加安全组规则

默认情况下，`default`安全组适用于所有实例，并包括拒绝对实例进行远程访问的防火墙规则。对于CirrOS之类的Linux映像，我们建议至少允许ICMP（ping）和安全Shell（SSH）。

将规则添加到`default`安全组

允许[ICMP](https://docs.openstack.org/install-guide/common/glossary.html#term-Internet-Control-Message-Protocol-ICMP)（ping)

```
[root@controller ~]  openstack security group rule create --proto icmp default

+-------------------+--------------------------------------+
| Field             | Value                                |
+-------------------+--------------------------------------+
| created_at        | 2017-03-30T00:46:43Z                 |
| description       |                                      |
| direction         | ingress                              |
| ether_type        | IPv4                                 |
| id                | 1946be19-54ab-4056-90fb-4ba606f19e66 |
| name              | None                                 |
| port_range_max    | None                                 |
| port_range_min    | None                                 |
| project_id        | 3f714c72aed7442681cbfa895f4a68d3     |
| protocol          | icmp                                 |
| remote_group_id   | None                                 |
| remote_ip_prefix  | 0.0.0.0/0                            |
| revision_number   | 1                                    |
| security_group_id | 89ff5c84-e3d1-46bb-b149-e621689f0696 |
| updated_at        | 2017-03-30T00:46:43Z                 |
+-------------------+--------------------------------------+
```

允许远程（SSH）访问

```
[root@controller ~]  openstack security group rule create --proto tcp --dst-port 22 default

+-------------------+--------------------------------------+
| Field             | Value                                |
+-------------------+--------------------------------------+
| created_at        | 2017-03-30T00:43:35Z                 |
| description       |                                      |
| direction         | ingress                              |
| ether_type        | IPv4                                 |
| id                | 42bc2388-ae1a-4208-919b-10cf0f92bc1c |
| name              | None                                 |
| port_range_max    | 22                                   |
| port_range_min    | 22                                   |
| project_id        | 3f714c72aed7442681cbfa895f4a68d3     |
| protocol          | tcp                                  |
| remote_group_id   | None                                 |
| remote_ip_prefix  | 0.0.0.0/0                            |
| revision_number   | 1                                    |
| security_group_id | 89ff5c84-e3d1-46bb-b149-e621689f0696 |
| updated_at        | 2017-03-30T00:43:35Z                 |
+-------------------+--------------------------------------+
```

## 启动一个实例

- [使用公共网络启动实例](https://docs.openstack.org/install-guide/launch-instance-provider.html)

要启动实例，您必须至少指定风味，映像名称，网络，安全组，密钥和实例名称。

在控制器节点上，`demo`获取凭据以访问仅用户的CLI命令：

```
[root@controller ~]  . demo-openrc
```

列出实例类型（CPU、内存）

```
[root@controller ~]  openstack flavor list

+----+---------+-----+------+-----------+-------+-----------+
| ID | Name    | RAM | Disk | Ephemeral | VCPUs | Is Public |
+----+---------+-----+------+-----------+-------+-----------+
| 0  | m1.nano |  64 |    1 |         0 |     1 | True      |
+----+---------+-----+------+-----------+-------+-----------+
```

列出镜像：

```
[root@controller ~]  openstack image list

+--------------------------------------+--------+--------+
| ID                                   | Name   | Status |
+--------------------------------------+--------+--------+
| 390eb5f7-8d49-41ec-95b7-68c0d5d54b34 | cirros | active |
+--------------------------------------+--------+--------+
该实例使用cirros图像
```

列出可用的网络：

```
[root@controller ~]  openstack network list

+--------------------------------------+--------------+--------------------------------------+
| ID                                   | Name         | Subnets                              |
+--------------------------------------+--------------+--------------------------------------+
| 4716ddfe-6e60-40e7-b2a8-42e57bf3c31c | selfservice  | 2112d5eb-f9d6-45fd-906e-7cabd38b7c7c |
| b5b6993c-ddf9-40e7-91d0-86806a42edb8 | provider     | 310911f6-acf0-4a47-824e-3032916582ff |
+--------------------------------------+--------------+--------------------------------------+
该实例使用provider公共网络。但是，您必须使用ID而不是名称来引用此网络。
```

列出可用的安全组：

```
[root@controller ~]  openstack security group list

+--------------------------------------+---------+------------------------+----------------------------------+
| ID                                   | Name    | Description            | Project                          |
+--------------------------------------+---------+------------------------+----------------------------------+
| dd2b614c-3dad-48ed-958b-b155a3b38515 | default | Default security group | a516b957032844328896baa01e0f906c |
+--------------------------------------+---------+------------------------+----------------------------------+
```

## 启动实例

如果您选择选项1，并且您的环境仅包含一个网络，则可以省略该`--nic`选项，因为OpenStack会自动选择唯一可用的网络。

```
[root@controller ~]  openstack server create --flavor m1.nano --image cirros \
  --nic net-id=PROVIDER_NET_ID --security-group default \
  --key-name mykey provider-instance

+-----------------------------+-----------------------------------------------+
| Field                       | Value                                         |
+-----------------------------+-----------------------------------------------+
| OS-DCF:diskConfig           | MANUAL                                        |
| OS-EXT-AZ:availability_zone |                                               |
| OS-EXT-STS:power_state      | NOSTATE                                       |
| OS-EXT-STS:task_state       | scheduling                                    |
| OS-EXT-STS:vm_state         | building                                      |
| OS-SRV-USG:launched_at      | None                                          |
| OS-SRV-USG:terminated_at    | None                                          |
| accessIPv4                  |                                               |
| accessIPv6                  |                                               |
| addresses                   |                                               |
| adminPass                   | PwkfyQ42K72h                                  |
| config_drive                |                                               |
| created                     | 2017-03-30T00:59:44Z                          |
| flavor                      | m1.nano (0)                                   |
| hostId                      |                                               |
| id                          | 36f3130e-cf1b-42f8-a80b-ebd63968940e          |
| image                       | cirros (97e06b44-e9ed-4db4-ba67-6e9fc5d0a203) |
| key_name                    | mykey                                         |
| name                        | provider-instance                             |
| progress                    | 0                                             |
| project_id                  | 3f714c72aed7442681cbfa895f4a68d3              |
| properties                  |                                               |
| security_groups             | name='default'                                |
| status                      | BUILD                                         |
| updated                     | 2017-03-30T00:59:44Z                          |
| user_id                     | 1a421c69342348248c7696e3fd6d4366              |
| volumes_attached            |                                               |
+-----------------------------+-----------------------------------------------+
```

检查实例的状态：

```
[root@controller ~]  openstack server list

+--------------------------------------+-------------------+--------+------------------------+------------+
| ID                                   | Name              | Status | Networks               | Image Name |
+--------------------------------------+-------------------+--------+------------------------+------------+
| 181c52ba-aebc-4c32-a97d-2e8e82e4eaaf | provider-instance | ACTIVE | provider=192.168.0.103 | cirros     |
+--------------------------------------+-------------------+--------+------------------------+------------+
```

## 使用虚拟控制台访问实例

获取 您的实例的[虚拟网络计算（VNC）](https://docs.openstack.org/install-guide/common/glossary.html#term-Virtual-Network-Computing-VNC)会话URL并从Web浏览器访问它：

```
[root@controller ~]  openstack console url show provider-instance

+-------+---------------------------------------------------------------------------------+
| Field | Value                                                                           |
+-------+---------------------------------------------------------------------------------+
| type  | novnc                                                                           |
| url   | http://controller:6080/vnc_auto.html?token=5eeccb47-525c-4918-ac2a-3ad1e9f1f493 |
+-------+---------------------------------------------------------------------------------+
```

如果您的Web浏览器在无法解析`controller`主机名的主机上运行，则 可以用`controller`控制器节点上管理接口的IP地址替换。

如果您的实例无法启动或无法按预期工作，请参阅 [Pike](https://docs.openstack.org/nova/pike/admin/support-compute.html)的“ [故障排除计算”文档，Queens](https://docs.openstack.org/nova/queens/admin/support-compute.html)的“ [故障排除计算”文档以](https://docs.openstack.org/nova/rocky/admin/support-compute.html) 获取更多信息，或使用[许多其他选项之一](https://docs.openstack.org/install-guide/common/app-support.html) 寻求帮助。我们希望您的首次安装能够正常工作！

返回[启动实例](https://docs.openstack.org/install-guide/launch-instance.html#launch-instance-complete)。
