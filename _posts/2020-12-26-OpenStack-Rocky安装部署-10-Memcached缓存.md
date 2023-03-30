---
layout: post
title: OpenStack-Rocky安装部署-10-Memcached缓存
date: 2020-12-26
tags: 云计算
---

认证服务认证缓存使用Memcached缓存令牌。缓存服务memecached运行在控制节点。在生产部署中，我们推荐联合启用防火墙、认证和加密保证它的安全。

### 1.安装包

```
[root@controller ~]# yum install memcached python-memcached
```

### 2.配置文件

配置服务以使用控制器节点的管理IP地址。这是为了允许其他节点通过管理网络进行访问

```
[root@controller ~]# vim /etc/sysconfig/memcached
OPTIONS="-l 127.0.0.1,::1,controller"
```

### 3.完成安装

```
[root@controller ~]# systemctl enable memcached.service
[root@controller ~]# systemctl start memcached.service
```
