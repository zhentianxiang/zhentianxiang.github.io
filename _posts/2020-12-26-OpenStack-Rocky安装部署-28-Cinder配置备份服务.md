---
layout: post
title: OpenStack-Rocky安装部署-28-Cinder配置备份服务
date: 2020-12-26
tags: 云计算
---

### 1.在“块存储”节点上执行这些步骤

安装软件包

```
[root@cinder ~]# yum install openstack-cinder
```

编辑`/etc/cinder/cinder.conf`

```
[root@cinder ~]# vim /etc/cinder/cinder.conf

[DEFAULT]
# ...
backup_driver = cinder.backup.drivers.swift
backup_swift_url = SWIFT_URL
```

替换`SWIFT_URL`为对象存储服务的URL。可以通过显示对象库API端点来找到URL

```
$ openstack catalog show object-store
```

### 2最终确定安装

```
[root@cinder ~]# systemctl enable openstack-cinder-backup.service
[root@cinder ~]# systemctl start openstack-cinder-backup.service
```
