---
layout: post
title: OpenStack-Rocky安装部署-27-Cinder存储节点配置
date: 2020-12-26
tags: 云计算
---

（可选）安装和配置备份服务。为简单起见，此配置使用“块存储”节点和“对象存储”（交换）驱动程序，因此取决于“ [对象存储”服务](https://docs.openstack.org/swift/latest/install/)。

在安装和配置备份服务之前，必须先[安装和配置存储节点](https://docs.openstack.org/cinder/queens/configuration/block-storage/config-options.html[root@cinder ~]# cinder-storage)。

### 1.安装和配置的部件

安装软件包

```
[root@cinder ~]# yum install lvm2 device-mapper-persistent-data
```

启动LVM元数据服务，并将其配置为在系统引导时启动

```
[root@cinder ~]# systemctl enable lvm2-lvmetad.service
[root@cinder ~]# systemctl start lvm2-lvmetad.service
```

### 2.创建LVM物理卷`/dev/sdb`

```
[root@cinder ~]# pvcreate /dev/sdb

Physical volume "/dev/sdb" successfully created
```

### 3.创建LVM卷组`cinder-volumes`

```
[root@cinder ~]# vgcreate cinder-volumes /dev/sdb

Volume group "cinder-volumes" successfully created
```

块存储服务在此卷组中创建逻辑卷。

只有实例可以访问块存储卷。但是，底层操作系统管理与卷关联的设备。默认情况下，LVM卷扫描工具会在`/dev`目录中扫描 包含卷的块存储设备。如果项目在其卷上使用LVM，则扫描工具会检测到这些卷并尝试对其进行缓存，这可能导致基础操作系统卷和项目卷出现各种问题。您必须将LVM重新配置为仅扫描包含`cinder-volumes`卷组的设备。

### 4.编辑 `/etc/lvm/lvm.conf`文件并完成以下操作：

在cinder节点，cinder-volume使用的磁盘（/dev/sdb），需要在/etc/lvm/lvm.conf中配置：
```
devices {
...
filter = [ "a/sdb/", "r/.*/"]
```

滤波器阵列中的每个项目开始于`a`用于**接受**或 `r`用于**拒绝**，并且包括用于所述装置名称的正则表达式。阵列必须`r/.*/`以拒绝任何剩余的设备结尾。您可以使用**vgs -vvvv**命令测试过滤器。

> 警告⚠️
>
> 如果cinder节点的操作系统也安装在lvm上，则还需要（在cinder节点操作）：
>
> ```
> filter = [ "a/sda/", "a/sdb/", "r/.*/"]
> ```
>
> 如果compute节点的操作系统也安装在lvm上，则需要（在compute节点操作）：
>
> ```
> filter = [ "a/sda/", "r/.*/"]
> ```

### 5.安装和配置的部件

安装软件包

```
[root@cinder ~]# yum install openstack-cinder targetcli python-keystone
```

编辑`/etc/cinder/cinder.conf`

```
[root@cinder ~]# vim /etc/cinder/cinder.conf

配置数据库访问
[database]
# ...
connection = mysql+pymysql://cinder:CINDER_DBPASS@controller/cinder


配置RabbitMQ 消息队列访问
[DEFAULT]
# ...
transport_url = rabbit://openstack:RABBIT_PASS@controller

[DEFAULT]
# ...
auth_strategy = keystone


配置身份服务访问
[keystone_authtoken]
# ...
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_id = default
user_domain_id = default
project_name = service
username = cinder
password = CINDER_PASS

配置my_ip选项
[DEFAULT]
# ...
my_ip = 10.0.0.13

为LVM后端配置LVM驱动程序，cinder-volumes卷组，iSCSI协议和适当的iSCSI服务。如果该[lvm]部分不存在，请创建它
[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
iscsi_protocol = iscsi
iscsi_helper = lioadm

启用LVM后端
[DEFAULT]
# ...
enabled_backends = lvm

配置图像服务API的位置
[DEFAULT]
# ...
glance_api_servers = http://controller:9292

配置锁定路径
[oslo_concurrency]
# ...
lock_path = /var/lib/cinder/tmp
```

### 6.完成安装

```
[root@cinder ~]# systemctl enable openstack-cinder-volume.service target.service
[root@cinder ~]# systemctl start openstack-cinder-volume.service target.service
```

### 7.验证(controller节点)

```
[root@cinder ~]# openstack volume service list
+------------------+------------+------+---------+-------+----------------------------+
| Binary           | Host       | Zone | Status  | State | Updated At                 |
+------------------+------------+------+---------+-------+----------------------------+
| cinder-scheduler | controller | nova | enabled | up    | 2021-01-05T12:14:14.000000 |
| cinder-volume    | cinder@lvm | nova | enabled | up    | 2021-01-05T12:14:16.000000 |
+------------------+------------+------+---------+-------+----------------------------+
```
