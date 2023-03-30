---
layout: post
title: OpenStack-Rocky安装部署-24-Neutron验证
date: 2020-12-26
tags: 云计算
---

在控制节点上执行命令

### 1.获取管理员权限

```
[root@controller ~]# . admin-openrc
```

列出已加载的扩展，以验证该`neutron-server`过程是否成功启动

```
[root@controller ~]# openstack extension list --network

+---------------------------+---------------------------+----------------------------+
| Name                      | Alias                     | Description                |
+---------------------------+---------------------------+----------------------------+
| Default Subnetpools       | default-subnetpools       | Provides ability to mark   |
|                           |                           | and use a subnetpool as    |
|                           |                           | the default                |
| Availability Zone         | availability_zone         | The availability zone      |
|                           |                           | extension.                 |
| Network Availability Zone | network_availability_zone | Availability zone support  |
|                           |                           | for network.               |
| Port Binding              | binding                   | Expose port bindings of a  |
|                           |                           | virtual port to external   |
|                           |                           | application                |
| agent                     | agent                     | The agent management       |
|                           |                           | extension.                 |
| Subnet Allocation         | subnet_allocation         | Enables allocation of      |
|                           |                           | subnets from a subnet pool |
| DHCP Agent Scheduler      | dhcp_agent_scheduler      | Schedule networks among    |
|                           |                           | dhcp agents                |
| Neutron external network  | external-net              | Adds external network      |
|                           |                           | attribute to network       |
|                           |                           | resource.                  |
| Neutron Service Flavors   | flavors                   | Flavor specification for   |
|                           |                           | Neutron advanced services  |
| Network MTU               | net-mtu                   | Provides MTU attribute for |
|                           |                           | a network resource.        |
| Network IP Availability   | network-ip-availability   | Provides IP availability   |
|                           |                           | data for each network and  |
|                           |                           | subnet.                    |
| Quota management support  | quotas                    | Expose functions for       |
|                           |                           | quotas management per      |
|                           |                           | tenant                     |
| Provider Network          | provider                  | Expose mapping of virtual  |
|                           |                           | networks to physical       |
|                           |                           | networks                   |
| Multi Provider Network    | multi-provider            | Expose mapping of virtual  |
|                           |                           | networks to multiple       |
|                           |                           | physical networks          |
| Address scope             | address-scope             | Address scopes extension.  |
| Subnet service types      | subnet-service-types      | Provides ability to set    |
|                           |                           | the subnet service_types   |
|                           |                           | field                      |
| Resource timestamps       | standard-attr-timestamp   | Adds created_at and        |
|                           |                           | updated_at fields to all   |
|                           |                           | Neutron resources that     |
|                           |                           | have Neutron standard      |
|                           |                           | attributes.                |
| Neutron Service Type      | service-type              | API for retrieving service |
| Management                |                           | providers for Neutron      |
|                           |                           | advanced services          |
| resources: subnet,        |                           | more L2 and L3 resources.  |
| subnetpool, port, router  |                           |                            |
| Neutron Extra DHCP opts   | extra_dhcp_opt            | Extra options              |
|                           |                           | configuration for DHCP.    |
|                           |                           | For example PXE boot       |
|                           |                           | options to DHCP clients    |
|                           |                           | can be specified (e.g.     |
|                           |                           | tftp-server, server-ip-    |
|                           |                           | address, bootfile-name)    |
| Resource revision numbers | standard-attr-revisions   | This extension will        |
|                           |                           | display the revision       |
|                           |                           | number of neutron          |
|                           |                           | resources.                 |
| Pagination support        | pagination                | Extension that indicates   |
|                           |                           | that pagination is         |
|                           |                           | enabled.                   |
| Sorting support           | sorting                   | Extension that indicates   |
|                           |                           | that sorting is enabled.   |
| security-group            | security-group            | The security groups        |
|                           |                           | extension.                 |
| RBAC Policies             | rbac-policies             | Allows creation and        |
|                           |                           | modification of policies   |
|                           |                           | that control tenant access |
|                           |                           | to resources.              |
| standard-attr-description | standard-attr-description | Extension to add           |
|                           |                           | descriptions to standard   |
|                           |                           | attributes                 |
| Port Security             | port-security             | Provides port security     |
| Allowed Address Pairs     | allowed-address-pairs     | Provides allowed address   |
|                           |                           | pairs                      |
| project_id field enabled  | project-id                | Extension that indicates   |
|                           |                           | that project_id field is   |
|                           |                           | enabled.                   |
+---------------------------+---------------------------+----------------------------+
```

输出应指示控制器节点上的三个代理，每个计算节点上的一个代理。



⚠️：自己搭建的哪个网络环境，就验证哪个网络环境

### 2.验证-网络选项1：公共网络

列出代理以验证启动 neutron 代理是否成功：

```
[root@controller ~]# openstack network agent list

+--------------------------------------+--------------------+------------+-------------------+-------+-------+---------------------------+
| ID                                   | Agent Type         | Host       | Availability Zone | Alive | State | Binary                    |
+--------------------------------------+--------------------+------------+-------------------+-------+-------+---------------------------+
| 0400c2f6-4d3b-44bc-89fa-99093432f3bf | Metadata agent     | controller | None              | True  | UP    | neutron-metadata-agent    |
| 83cf853d-a2f2-450a-99d7-e9c6fc08f4c3 | DHCP agent         | controller | nova              | True  | UP    | neutron-dhcp-agent        |
| ec302e51-6101-43cf-9f19-88a78613cbee | Linux bridge agent | compute    | None              | True  | UP    | neutron-linuxbridge-agent |
| fcb9bc6e-22b1-43bc-9054-272dd517d025 | Linux bridge agent | controller | None              | True  | UP    | neutron-linuxbridge-agent |
+--------------------------------------+--------------------+------------+-------------------+-------+-------+---------------------------+
```

输出应指示控制器节点上的三个代理，每个计算节点上的一个代理。

### 3.验证-网络选项2：私有网络

列出代理商以验证中子代理商的成功发射：

```
[root@controller ~]# openstack network agent list

+--------------------------------------+--------------------+------------+-------------------+-------+-------+---------------------------+
| ID                                   | Agent Type         | Host       | Availability Zone | Alive | State | Binary                    |
+--------------------------------------+--------------------+------------+-------------------+-------+-------+---------------------------+
| f49a4b81-afd6-4b3d-b923-66c8f0517099 | Metadata agent     | controller | None              | True  | UP    | neutron-metadata-agent    |
| 27eee952-a748-467b-bf71-941e89846a92 | Linux bridge agent | controller | None              | True  | UP    | neutron-linuxbridge-agent |
| 08905043-5010-4b87-bba5-aedb1956e27a | Linux bridge agent | compute1   | None              | True  | UP    | neutron-linuxbridge-agent |
| 830344ff-dc36-4956-84f4-067af667a0dc | L3 agent           | controller | nova              | True  | UP    | neutron-l3-agent          |
| dd3644c9-1a3a-435a-9282-eb306b4b0391 | DHCP agent         | controller | nova              | True  | UP    | neutron-dhcp-agent        |
+--------------------------------------+--------------------+------------+-------------------+-------+-------+---------------------------+
```

输出应指示控制器节点上的四个代理，每个计算节点上的一个代理。
