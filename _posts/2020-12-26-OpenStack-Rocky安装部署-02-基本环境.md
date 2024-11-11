---
layout: post
title: OpenStack-Rocky安装部署-02-基本环境
date: 2020-12-26
tags: 云计算
---

这个部分解释如何按示例架构配置控制节点和一个计算节点

尽管大多数环境中包含认证，镜像，计算，至少一个网络服务，还有仪表盘，但是对象存储服务也可以单独操作。如果你的使用情况与涉及到对象存储，你可以在配置完适当的节点后跳到：ref:swift。然而仪表盘要求至少要有镜像服务，计算服务和网络服务。

你必须用有管理员权限的帐号来配置每个节点。可以用 `root` 用户或 `sudo` 工具来执行这些命令。

为获得最好的性能，我们推荐在你的环境中符合或超过在 :ref:[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment.html#id1)figure-hwreqs`中的硬件要求。

以下最小需求支持概念验证环境，使用核心服务和几个:term:[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment.html#id1)CirrOS`实例:

- 控制节点: 1 处理器, 4 GB 内存, 及5 GB 存储
- 计算节点: 1 处理器, 2 GB 内存, 及10 GB 存储, 至少两块网卡
因为10段的地址是用来节点之间的作用，第二块网卡是把虚拟机桥接到宿主机，从而使得虚拟机能够与外界通信

由于Openstack服务数量以及虚拟机数量的正常，为了获得最好的性能，我们推荐你的环境满足或者超过基本的硬件需求。如果在增加了更多的服务或者虚拟机后性能下降，请考虑为你的环境增加硬件资源。

为了避免混乱和为OpenStack提供更多资源，我们推荐你最小化安装你的Linux发行版。同时，你必须在每个节点安装你的发行版的64位版本。

每个节点配置一个磁盘分区满足大多数的基本安装。但是，对于有额外服务如块存储服务的，你应该考虑采用 :term:[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment.html#id1)Logical Volume Manager (LVM)`进行安装。

对于第一次安装和测试目的，很多用户选择使用 :term:[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment.html#id1)virtual machine (VM)`作为主机。使用虚拟机的主要好处有一下几点：

- 一台物理服务器可以支持多个节点，每个节点几乎可以使用任意数目的网络接口。
- 在安装过程中定期进行“快照”并且在遇到问题时可以“回滚”到上一个可工作配置的能力。

但是，虚拟机会降低您实例的性能，特别是如果您的 hypervisor 和/或 进程缺少硬件加速的嵌套虚拟机支持时。

>  注解：如果你选择在虚拟机内安装，请确保你的hypervisor提供了在public网络接口上禁用MAC地址过滤的方法。

### 基本环境部署

```
以controller主机为例，其余以此参考（computer1、cinder）
[root@controller ~]# systemctl stop firewalld.service
[root@controller ~]# curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
[root@controller ~]# yum install -y epel-release chrony bash-completion wget net-tools telnet tree nmap sysstat lrzsz dos2unix bind-utils vim less
[root@controller ~]# hostnamectl set-hostname controller
[root@controller~]# bash
controller一块网卡即可，computer1最少两张网卡，第二张网卡为虚拟机桥接使用
[root@computer1 ~]# cat /etc/sysconfig/network-scripts/ifcfg-ens33
TYPE="Ethernet"
BOOTPROTO="static"
IPADDR=10.0.0.11
GATEWAY=10.0.0.2
NETMASK=255.255.255.0
DNS1=8.8.8.8
DEFROUTE="yes"
NAME="ens33"
DEVICE="ens33"
ONBOOT="yes"
[root@computer1 ~]# cat /etc/sysconfig/network-scripts/ifcfg-ens34
TYPE="Ethernet"
BOOTPROTO="static"
IPADDR=10.0.0.12
GATEWAY=192.168.0.1
NETMASK=255.255.255.0
DNS1=8.8.8.8
DEFROUTE="yes"
NAME="ens34"
DEVICE="ens34"
ONBOOT="yes"
[root@controller ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.0.0.11 controller
10.0.0.12 computer
[root@controller ~]# ping computer
PING computer (10.0.0.11) 56(84) bytes of data.
64 bytes from computer (10.0.0.12): icmp_seq=1 ttl=64 time=0.301 ms
64 bytes from computer (10.0.0.12): icmp_seq=2 ttl=64 time=0.709 ms
64 bytes from computer (10.0.0.12): icmp_seq=3 ttl=64 time=1.10 ms
64 bytes from computer (10.0.0.12): icmp_seq=4 ttl=64 time=0.666 ms
64 bytes from computer (10.0.0.12): icmp_seq=5 ttl=64 time=0.720 ms
```
当然后期，你也可以根据自己的意愿去搭建一个内网DNS环境

更多关于系统要求的信息，查看 [OpenStack Operations Guide](http://docs.openstack.org/ops/).

- [安全](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-03-安全/)
- [主机网络](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-04-主机网络/)
- [网络时间协议(NTP)](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-05-网络时间-NTP/)
- [OpenStack包](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-06-openstack安装包/)
- [SQL数据库](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-07-SQL数据库/)
- [NoSQL 数据库](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-08-NoSQL数据库/)
- [消息队列](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-09-RabbitMQ消息队列/)
- [Memcached](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-10-Memcached缓存/)
