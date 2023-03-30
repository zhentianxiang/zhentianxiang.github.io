---
layout: post
title: OpenStack-Rocky安装部署-09-RabbitMQ消息队列
date: 2020-12-26
tags: 云计算
---

OpenStack 使用 [*message queue*](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/common/glossary.html#term-message-queue) 协调操作和各服务的状态信息。消息队列服务一般运行在控制节点上。OpenStack支持好几种消息队列服务包括 [RabbitMQ](http://www.rabbitmq.com/), [Qpid](http://qpid.apache.org/), 和 [ZeroMQ](http://zeromq.org/)。不过，大多数发行版本的OpenStack包支持特定的消息队列服务。本指南安装 RabbitMQ 消息队列服务，因为大部分发行版本都支持它。如果你想安装不同的消息队列服务，查询与之相关的文档。

### 1.安装包

```
[root@controller ~]# yum install rabbitmq-server
```

### 2.启动

```
[root@controller ~]# systemctl enable rabbitmq-server.service
[root@controller ~]# systemctl start rabbitmq-server.service
```

### 3.添加openstack用户

```
[root@controller ~]# rabbitmqctl add_user openstack RABBIT_PASS
Creating user "openstack" ...
...done.
```

### 4.给``openstack``用户配置写和读权限

```
[root@controller ~]# rabbitmqctl set_permissions openstack ".*" ".*" ".*"
Setting permissions for user "openstack" in vhost "/" ...
...done.
```
