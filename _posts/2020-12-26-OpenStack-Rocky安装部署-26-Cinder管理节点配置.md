---
layout: post
title: OpenStack-Rocky安装部署-26-Cinder管理节点配置
date: 2020-12-26
tags: 云计算
---

这个部分描述怎样为块存储服务安装并配置存储节点。为简单起见，这里配置一个有一个空的本地块存储设备的存储节点。这个向导用的是 `/dev/sdb`，但是你可以为你特定的节点中替换成不同的值。

该服务在这个设备上使用：term：LVM <Logical Volume Manager (LVM)> 提供逻辑卷，并通过：term：[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/cinder-storage-install.html#id1)iSCSI`协议提供给实例使用。您可以根据这些小的修改指导，添加额外的存储节点来增加您的环境规模。

### 1.先决条件

`root`用户身份连接到数据库服务器

```
[root@controller ~]# mysql -u root -p
```

创建`cinder`数据库

```
MariaDB [(none)]> CREATE DATABASE cinder;
```

授予对`cinder`数据库的适当访问权限

```
MariaDB [(none)]> GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' \
  IDENTIFIED BY 'CINDER_DBPASS';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' \
  IDENTIFIED BY 'CINDER_DBPASS';
```

获取管理员权限

```
[root@controller ~]# . admin-openrc
```

创建一个`cinder`用户

```
[root@controller ~]# openstack user create --domain default --password-prompt cinder

User Password:CINDER_PASS
Repeat User Password:CINDER_PASS
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | default                          |
| enabled             | True                             |
| id                  | 9d7e33de3e1a498390353819bc7d245d |
| name                | cinder                           |
| options             | {}                               |
| password_expires_at | None                             |
+---------------------+----------------------------------+
```

`admin`向`cinder`用户添加角色

```
[root@controller ~]#$ openstack role add --project service --user cinder admin
```

创建`cinderv2`和`cinderv3`服务实体

```
[root@controller ~]# openstack service create --name cinderv2 \
  --description "OpenStack Block Storage" volumev2

+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | OpenStack Block Storage          |
| enabled     | True                             |
| id          | eb9fd245bdbc414695952e93f29fe3ac |
| name        | cinderv2                         |
| type        | volumev2                         |
+-------------+----------------------------------+
[root@controller ~]# openstack service create --name cinderv3 \
  --description "OpenStack Block Storage" volumev3

+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | OpenStack Block Storage          |
| enabled     | True                             |
| id          | ab3bbbef780845a1a283490d281e7fda |
| name        | cinderv3                         |
| type        | volumev3                         |
+-------------+----------------------------------+
```

创建块存储服务API端点

```
[root@controller ~]# openstack endpoint create --region RegionOne \
  volumev2 public http://controller:8776/v2/%\(project_id\)s

+--------------+------------------------------------------+
| Field        | Value                                    |
+--------------+------------------------------------------+
| enabled      | True                                     |
| id           | 513e73819e14460fb904163f41ef3759         |
| interface    | public                                   |
| region       | RegionOne                                |
| region_id    | RegionOne                                |
| service_id   | eb9fd245bdbc414695952e93f29fe3ac         |
| service_name | cinderv2                                 |
| service_type | volumev2                                 |
| url          | http://controller:8776/v2/%(project_id)s |
+--------------+------------------------------------------+

[root@controller ~]# openstack endpoint create --region RegionOne \
  volumev2 internal http://controller:8776/v2/%\(project_id\)s

+--------------+------------------------------------------+
| Field        | Value                                    |
+--------------+------------------------------------------+
| enabled      | True                                     |
| id           | 6436a8a23d014cfdb69c586eff146a32         |
| interface    | internal                                 |
| region       | RegionOne                                |
| region_id    | RegionOne                                |
| service_id   | eb9fd245bdbc414695952e93f29fe3ac         |
| service_name | cinderv2                                 |
| service_type | volumev2                                 |
| url          | http://controller:8776/v2/%(project_id)s |
+--------------+------------------------------------------+

[root@controller ~]# openstack endpoint create --region RegionOne \
  volumev2 admin http://controller:8776/v2/%\(project_id\)s

+--------------+------------------------------------------+
| Field        | Value                                    |
+--------------+------------------------------------------+
| enabled      | True                                     |
| id           | e652cf84dd334f359ae9b045a2c91d96         |
| interface    | admin                                    |
| region       | RegionOne                                |
| region_id    | RegionOne                                |
| service_id   | eb9fd245bdbc414695952e93f29fe3ac         |
| service_name | cinderv2                                 |
| service_type | volumev2                                 |
| url          | http://controller:8776/v2/%(project_id)s |
+--------------+------------------------------------------+
[root@controller ~]# openstack endpoint create --region RegionOne \
  volumev3 public http://controller:8776/v3/%\(project_id\)s

+--------------+------------------------------------------+
| Field        | Value                                    |
+--------------+------------------------------------------+
| enabled      | True                                     |
| id           | 03fa2c90153546c295bf30ca86b1344b         |
| interface    | public                                   |
| region       | RegionOne                                |
| region_id    | RegionOne                                |
| service_id   | ab3bbbef780845a1a283490d281e7fda         |
| service_name | cinderv3                                 |
| service_type | volumev3                                 |
| url          | http://controller:8776/v3/%(project_id)s |
+--------------+------------------------------------------+

[root@controller ~]# openstack endpoint create --region RegionOne \
  volumev3 internal http://controller:8776/v3/%\(project_id\)s

+--------------+------------------------------------------+
| Field        | Value                                    |
+--------------+------------------------------------------+
| enabled      | True                                     |
| id           | 94f684395d1b41068c70e4ecb11364b2         |
| interface    | internal                                 |
| region       | RegionOne                                |
| region_id    | RegionOne                                |
| service_id   | ab3bbbef780845a1a283490d281e7fda         |
| service_name | cinderv3                                 |
| service_type | volumev3                                 |
| url          | http://controller:8776/v3/%(project_id)s |
+--------------+------------------------------------------+

[root@controller ~]# openstack endpoint create --region RegionOne \
  volumev3 admin http://controller:8776/v3/%\(project_id\)s

+--------------+------------------------------------------+
| Field        | Value                                    |
+--------------+------------------------------------------+
| enabled      | True                                     |
| id           | 4511c28a0f9840c78bacb25f10f62c98         |
| interface    | admin                                    |
| region       | RegionOne                                |
| region_id    | RegionOne                                |
| service_id   | ab3bbbef780845a1a283490d281e7fda         |
| service_name | cinderv3                                 |
| service_type | volumev3                                 |
| url          | http://controller:8776/v3/%(project_id)s |
+--------------+------------------------------------------+
```

### 2.安装LVM软件包

```
[root@controller ~]# yum install openstack-cinder
[root@controller ~]# vim /etc/cinder/cinder.conf

配置数据库访问
[database]
# ...
connection = mysql+pymysql://cinder:CINDER_DBPASS@controller/cinder

配置RabbitMQ 消息队列访问
[DEFAULT]
# ...
transport_url = rabbit://openstack:RABBIT_PASS@controller

配置身份服务访问
[DEFAULT]
# ...
auth_strategy = keystone

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

配置my_ip选项以使用控制器节点的管理接口IP地址
[DEFAULT]
# ...
my_ip = 10.0.0.11

配置锁定路径
[oslo_concurrency]
# ...
lock_path = /var/lib/cinder/tmp
```

### 3.填充数据库

```
[root@controller ~]# su -s /bin/sh -c "cinder-manage db sync" cinder
```

### 4.配置计算服务使用cinder

```
[root@controller ~]# vim /etc/nova/nova.conf

[cinder]
os_region_name = RegionOne
```

### 5.最终确定安装

重启Nova服务

```
[root@controller ~]# systemctl restart openstack-nova-api.service
```

```
[root@controller ~]# systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
[root@controller ~]# systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service
```
