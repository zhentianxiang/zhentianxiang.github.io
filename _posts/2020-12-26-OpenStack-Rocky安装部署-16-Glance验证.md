---
layout: post
title: OpenStack-Rocky安装部署-16-Glance验证
date: 2020-12-26
tags: 云计算
---

使用[CirrOS](http://launchpad.net/cirros)（一个小型Linux映像，可帮助您测试OpenStack部署）验证Image Service的运行 。

> 注意：在controller节点上运行这些命令

### 1.获得 `admin` 凭证来获取只有管理员能执行的命令的访问权限

```
[root@controller ~]# . admin-openrc
```

### 2.下载镜像

```
[root@controller ~]# wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
[root@controller ~]# mv cirros-0.4.0-x86_64-disk.img /var/lib/glance/
```

### 3.使用 [*QCOW2*](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/common/glossary.html#term-qemu-copy-on-write-2-qcow2) 磁盘格式， [*bare*](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/common/glossary.html#term-bare) 容器格式上传镜像到镜像服务并设置公共可见，这样所有的项目都可以访问它

```
[root@controller ~]# openstack image create "cirros" \
  --file /var/lib/glance/images/cirros-0.4.0-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --public
+------------------+------------------------------------------------------+
| Field            | Value                                                |
+------------------+------------------------------------------------------+
| checksum         | 133eae9fb1c98f45894a4e60d8736619                     |
| container_format | bare                                                 |
| created_at       | 2015-03-26T16:52:10Z                                 |
| disk_format      | qcow2                                                |
| file             | /v2/images/cc5c6982-4910-471e-b864-1098015901b5/file |
| id               | cc5c6982-4910-471e-b864-1098015901b5                 |
| min_disk         | 0                                                    |
| min_ram          | 0                                                    |
| name             | cirros                                               |
| owner            | ae7a98326b9c455588edd2656d723b9d                     |
| protected        | False                                                |
| schema           | /v2/schemas/image                                    |
| size             | 13200896                                             |
| status           | active                                               |
| tags             |                                                      |
| updated_at       | 2015-03-26T16:52:10Z                                 |
| virtual_size     | None                                                 |
| visibility       | public                                               |
+------------------+------------------------------------------------------+

使用centos官方提供的qcow2镜像：http://cloud.centos.org/centos/7/images/

可以直接wget下载镜像，然后用命令生成一下就能创建虚拟机

```

### 4.确认上传图片并验证属性

```
[root@controller ~]# openstack image list

+--------------------------------------+--------+--------+
| ID                                   | Name   | Status |
+--------------------------------------+--------+--------+
| 38047887-61a7-41ea-9b49-27987d5e8bb9 | cirros | active |
+--------------------------------------+--------+--------+
```
