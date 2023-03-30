---
layout: post
title: OpenStack-Rocky安装部署-04-主机网络
date: 2020-12-26
tags: 云计算

---

# 主机网络

在你按照你选择的架构，完成各个节点操作系统安装以后，你必须配置网络接口。我们推荐你禁用自动网络管理工具并手动编辑你相应版本的配置文件。更多关于如何配置你版本网络信息内容，参考 [documentation](https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/Networking_Guide/sec-Using_the_Command_Line_Interface.html) 。

出于管理目的，例如：安装包，安全更新， *DNS`和 :term:`NTP*，所有的节点都需要可以访问互联网。在大部分情况下，节点应该通过管理网络接口访问互联网。为了更好的突出网络隔离的重要性，示例架构中为管理网络使用`private address space <https://tools.ietf.org/html/rfc1918>`__ 并假定物理网络设备通过 :term:[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment-networking.html#id1)NAT`或者其他方式提供互联网访问。示例架构使用可路由的IP地址隔离服务商（外部）网络并且假定物理网络设备直接提供互联网访问。

在提供者网络架构中，所有实例直接连接到提供者网络。在自服务（私有）网络架构，实例可以连接到自服务或提供者网络。自服务网络可以完全在openstack环境中或者通过外部网络使用:term:NAT 提供某种级别的外部网络访问。

![](/images/posts/云计算/Train版本部署/主机网络/1.png)

示例架构假设使用如下网络：

- 管理使用 10.0.0.0/24 带有网关 10.0.0.1

  这个网络需要一个网关以为所有节点提供内部的管理目的的访问，例如包的安装、安全更新、 [*DNS*](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/common/glossary.html#term-dns)，和 [*NTP*](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/common/glossary.html#term-ntp)。

- 提供者网段 203.0.113.0/24，网关203.0.113.1

  这个网络需要一个网关来提供在环境中内部实例的访问。

您可以修改这些范围和网关来以您的特定网络设施进行工作。

网络接口由发行版的不同而有各种名称。传统上，接口使用 “eth” 加上一个数字序列命名。为了覆盖到所有不同的名称，本指南简单地将数字最小的接口引用为第一个接口，第二个接口则为更大数字的接口。

除非您打算使用该架构样例中提供的准确配置，否则您必须在本过程中修改网络以匹配您的环境。并且，每个节点除了 IP 地址之外，还必须能够解析其他节点的名称。例如，controller这个名称必须解析为 10.0.0.11，即控制节点上的管理网络接口的 IP 地址。

> 警告：重新配置网络接口会中断网络连接。我们建议使用本地终端会话来进行这个过程。

> 注解：你的发行版本默认启用了限制 [*firewall*](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/common/glossary.html#term-firewall) 。在安装过程中，有些步骤可能会失败，除非你允许或者禁用了防火墙。更多关于安全的资料，参考 [OpenStack Security Guide](http://docs.openstack.org/sec/)。

- [控制节点服务器](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment-networking-controller.html)
- [计算节点](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment-networking-compute.html)
- [块存储节点（可选）](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment-networking-storage-cinder.html)
- [对象存储节点（可选）](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment-networking-storage-swift.html)
- [验证连通性](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment-networking-verify.html)
