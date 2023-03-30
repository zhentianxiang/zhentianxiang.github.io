---
layout: post
title: OpenStack-Rocky安装部署-01-概况描述
date: 2020-12-26
tags: 云计算
---

- 示例的架构
  - [控制器](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/overview.html#controller)
  - [计算](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/overview.html#id1)
  - [块设备存储](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/overview.html#id2)
  - [对象存储](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/overview.html#id3)
- 网络
  - [网络选项1：公共网络](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/overview.html#networking-option-1-provider-networks)
  - [网络选项2：私有网络](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/overview.html#networking-option-2-self-service-networks)

OpenStack项目是一个开源云计算平台，支持所有类型的云环境。该项目的目标是实现简单、可扩展性强、功能丰富。来自世界各地的云计算专家为该项目做出了贡献。

OpenStack通过各种补充服务提供基础设施即服务 *Infrastructure-as-a-Service (IaaS)<IaaS>`的解决方案。每个服务都提供便于集成的应用程序接口 :term:`Application Programming Interface (API)*。

本指南涵盖了如何安装功能示例架构逐步部署下面主要的OpenStack服务，特别适合于对Linux经验丰富的OpenStack新用户：

| 服务                                                         | 项目名称                                                     | 描述                                                         |
| :----------------------------------------------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| [Dashboard](http://www.openstack.org/software/releases/liberty/components/horizon) | [Horizon](http://docs.openstack.org/developer/horizon/)      | 提供了一个基于web的自服务门户，与OpenStack底层服务交互，诸如启动一个实例，分配IP地址以及配置访问控制。 |
| [Compute](http://www.openstack.org/software/releases/liberty/components/nova) | [Nova](http://docs.openstack.org/developer/nova/)            | 在OpenStack环境中计算实例的生命周期管理。按需响应包括生成、调度、回收虚拟机等操作。 |
| [Networking](http://www.openstack.org/software/releases/liberty/components/neutron) | [Neutron](http://docs.openstack.org/developer/neutron/)      | 确保为其它OpenStack服务提供网络连接即服务，比如OpenStack计算。为用户提供API定义网络和使用。基于插件的架构其支持众多的网络提供商和技术。 |
| 存储                                                         |                                                              |                                                              |
| [Object Storage](http://www.openstack.org/software/releases/liberty/components/swift) | [Swift](http://docs.openstack.org/developer/swift/)          | 通过一个 [*RESTful*](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/common/glossary.html#term-restful),基于HTTP的应用程序接口存储和任意检索的非结构化数据对象。它拥有高容错机制，基于数据复制和可扩展架构。它的实现并像是一个文件服务器需要挂载目录。在此种方式下，它写入对象和文件到多个硬盘中，以确保数据是在集群内跨服务器的多份复制。 |
| [Block Storage](http://www.openstack.org/software/releases/liberty/components/cinder) | [Cinder](http://docs.openstack.org/developer/cinder/)        | 为运行实例而提供的持久性块存储。它的可插拔驱动架构的功能有助于创建和管理块存储设备。 |
| 共享服务                                                     |                                                              |                                                              |
| [Identity service](http://www.openstack.org/software/releases/liberty/components/keystone) | [Keystone](http://docs.openstack.org/developer/keystone/)    | 为其他OpenStack服务提供认证和授权服务，为所有的OpenStack服务提供一个端点目录。 |
| [Image service](http://www.openstack.org/software/releases/liberty/components/glance) | Glance服务请参见<http://docs.openstack.org/developer/glance/> | 存储和检索虚拟机磁盘镜像，OpenStack计算会在实例部署时使用此服务。 |
| Telemetry服务请参见<http://www.openstack.org/software/releases/liberty/components/ceilometer> | Ceilometer服务请参见<http://docs.openstack.org/developer/ceilometer/> | 为OpenStack云的计费、基准、扩展性以及统计等目的提供监测和计量。 |
| 高层次服务                                                   |                                                              |                                                              |
| Orchestration服务请参见<http://www.openstack.org/software/releases/liberty/components/heat> | Heat服务请参见<http://docs.openstack.org/developer/heat/>    | Orchestration服务支持多样化的综合的云应用，通过调用OpenStack-native REST API和CloudFormation-compatible Query API，支持:term:[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/overview.html#id1)HOT <Heat Orchestration Template (HOT)>`格式模板或者AWS CloudFormation格式模板 |

在你对基础安装，配置，操作和故障诊断熟悉之后，你应该考虑按照以下步骤使用生产架构来进行部署

- 确定并补充必要的核心和可选服务，以满足性能和冗余要求。
- 使用诸如防火墙，加密和服务策略的方式来加强安全。
- 使用自动化部署工具，例如Ansible, Chef, Puppet, or Salt来自动化部署，管理生产环境



## 示例的架构

这个示例架构需要至少2个（主机）节点来启动基础服务：term:[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/overview.html#id1)virtual machine <virtual machine (VM)>`或者实例。像块存储服务，对象存储服务这一类服务还需要额外的节点

这个示例架构不同于下面这样的最小生产结构

- 网络代理驻留在控制节点上而不是在一个或者多个专用的网络节点上。
- 私有网络的覆盖流量通过管理网络而不是专用网络

关于生产架构的更多信息，参考`Architecture Design Guide <http://docs.openstack.org/arch-design/content/>`__, [Operations Guide `__和`Networking Guide](http://docs.openstack.org/networking-guide/)。

![](/images/posts/云计算/Train版本部署/概况描述/1.png)

**硬件需求**

### 控制器

控制节点上运行身份认证服务，镜像服务，计算服务的管理部分，网络服务的管理部分，多种网络代理以及仪表板。也需要包含一些支持服务，例如：SQL数据库，term:消息队列, and [*NTP*](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/common/glossary.html#term-ntp)。

可选的，可以在计算节点上运行部分块存储，对象存储，Orchestration 和 Telemetry 服务。

计算节点上需要至少两块网卡。

### 计算

计算节点上运行计算服务中管理实例的管理程序部分。默认情况下，计算服务使用 *KVM*。

你可以部署超过一个计算节点。每个结算节点至少需要两块网卡。

### 块设备存储

可选的块存储节点上包含了磁盘，块存储服务和共享文件系统会向实例提供这些磁盘。

为了简单起见，计算节点和本节点之间的服务流量使用管理网络。生产环境中应该部署一个单独的存储网络以增强性能和安全。

你可以部署超过一个块存储节点。每个块存储节点要求至少一块网卡。

### 对象存储

可选的对象存储节点包含了磁盘。对象存储服务用这些磁盘来存储账号，容器和对象。

为了简单起见，计算节点和本节点之间的服务流量使用管理网络。生产环境中应该部署一个单独的存储网络以增强性能和安全。

这个服务要求两个节点。每个节点要求最少一块网卡。你可以部署超过两个对象存储节点。

## 网络

从下面的虚拟网络选项中选择一种选项。



### 网络选项1：公共网络

公有网络选项使用尽可能简单的方式主要通过layer-2（网桥/交换机）服务以及VLAN网络的分割来部署OpenStack网络服务。本质上，它建立虚拟网络到物理网络的桥，依靠物理网络基础设施提供layer-3服务(路由)。额外地 ，:term:[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/overview.html#id1)DHCP`为实例提供IP地址信息。

> 注解：这个选项不支持私有网络，layer-3服务以及一些高级服务，例如:term:LBaaS and [*FWaaS*](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/common/glossary.html#term-fwaas)。如果你需要这些服务，请考虑私有网络选项

![](/images/posts/云计算/Train版本部署/概况描述/2.png)

### 网络选项2：私有网络

私有网络选项扩展了公有网络选项，增加了启用 *self-service`覆盖分段方法的layer-3（路由）服务，比如 :term:`VXLAN*。本质上，它使用 :term:[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/overview.html#id1)NAT`路由虚拟网络到物理网络。另外，这个选项也提供高级服务的基础，比如LBaas和FWaaS。

![](/images/posts/云计算/Train版本部署/概况描述/3.png)
