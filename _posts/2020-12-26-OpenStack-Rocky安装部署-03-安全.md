---
layout: post
title: OpenStack-Rocky安装部署-03-安全
date: 2020-12-26
tags: 云计算
---

OpenStack 服务支持各种各样的安全方式，包括密码 password、policy 和 encryption，支持的服务包括数据库服务器，且消息 broker 至少支持 password 的安全方式。

为了简化安装过程，本指南只包含了可适用的密码安全。你可以手动创建安全密码，使用`pwgen <http://sourceforge.net/projects/pwgen/>`__工具生成密码或者通过运行下面的命令：

```
$ openssl rand -hex 10
```

对 OpenStack 服务而言，本指南使用``SERVICE_PASS`` 表示服务帐号密码，使用``SERVICE_DBPASS`` 表示数据库密码。

下面的表格给出了需要密码的服务列表以及它们在指南中关联关系：

| 密码名称                 | 描述                                   |
| :----------------------- | :------------------------------------- |
| 数据库密码(不能使用变量) | 数据库的root密码                       |
| `ADMIN_PASS`             | `admin` 用户密码                       |
| `CINDER_DBPASS`          | 块设备存储服务的数据库密码             |
| `CINDER_PASS`            | 块设备存储服务的 `cinder` 密码         |
| `DASH_DBPASS`            | Database password for the dashboard    |
| `DEMO_PASS`              | `demo` 用户的密码                      |
| `MYUSER_PASS`            | `myuser`用户的密码
| `GLANCE_DBPASS`          | 镜像服务的数据库密码                   |
| `GLANCE_PASS`            | 镜像服务的 `glance` 用户密码           |
| `KEYSTONE_DBPASS`        | 认证服务的数据库密码                   |
| `NEUTRON_DBPASS`         | 网络服务的数据库密码                   |
| `NEUTRON_PASS`           | 网络服务的 `neutron` 用户密码          |
| `NOVA_DBPASS`            | 计算服务的数据库密码                   |
| `NOVA_PASS`              | 计算服务中``nova``用户的密码           |
| `RABBIT_PASS`            | RabbitMQ的guest用户密码                |
| `SWIFT_PASS`             | 对象存储服务用户``swift``的密码        |

OpenStack和配套服务在安装和操作过程中需要管理员权限。在很多情况下，服务可以与自动化部署工具如 Ansible， Chef,和 Puppet进行交互，对主机进行修改。例如，一些OpenStack服务添加root权限 `sudo` 可以与安全策略进行交互。更多信息，可以参考 [`管理员参考`__](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/environment-security.html#id2) 。

另外，网络服务设定内核网络参数的默认值并且修改防火墙规则。为了避免你初始化安装的很多问题，我们推荐在你的主机上使用支持的发行版本。不管怎样，如果你选择自动化部署你的主机，在进一步操作前检查它们的配置和策略。
