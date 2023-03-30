---
layout: post
title: OpenStack-Rocky安装部署-08-NoSQL数据库
date: 2020-12-26
tags: 云计算
---

# 请忽略此篇文章

### 1.安装MongoDB包

```
[root@controller ~]# vim /etc/yum.repos.d/mongodb-org-3.4.repo   //配置yum安装源
[mongodb-org-3.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.4/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc

[root@controller ~]# yum install mongodb-server mongodb
```

### 2.编辑配置文件

配置 `bind_ip` 使用控制节点管理网卡的IP地址

默认情况下，MongoDB会在``/var/lib/mongodb/journal`` 目录下创建几个 1 GB 大小的日志文件。如果你想将每个日志文件大小减小到128MB并且限制日志文件占用的总空间为512MB，配置 `smallfiles` 的值：

```
[root@controller ~]# vim /etc/mongod.conf
bind_ip = 10.0.0.11
smallfiles = true
```

### 3.完成安装

```
[root@controller ~]# systemctl enable mongod.service   //开机自启
[root@controller ~]# systemctl start mongod.service    //启动数据库
```
