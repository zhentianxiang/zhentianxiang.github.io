---
layout: post
title: OpenStack-Rocky安装部署-15-Glance镜像服务
date: 2020-12-26
tags: 云计算
---

### 1.先决条件

安装和配置镜像服务之前，你必须创建创建一个数据库、服务凭证和API端点。

```
使用数据库访问客户端以`root`用户身份连接到数据库服务器
[root@controller ~]# mysql -u root -p
创建glance数据库：
MariaDB [(none)]> CREATE DATABASE glance;

授予对glance数据库的适当访问权限：
MariaDB [(none)]> GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' \
  IDENTIFIED BY 'GLANCE_DBPASS';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' \
  IDENTIFIED BY 'GLANCE_DBPASS';
```

### 2.获得 `admin` 凭证来获取只有管理员能执行的命令的访问权限

```
[root@controller ~]# . admin-openrc
```

### 3.要创建服务凭证，请完成以下步骤

创建`glance`用户

```
[root@controller ~]# openstack user create --domain default --password-prompt glance

User Password:GLANCE_PASS
Repeat User Password:GLANCE_PASS
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | default                          |
| enabled             | True                             |
| id                  | 3f4e777c4062483ab8d9edd7dff829df |
| name                | glance                           |
| options             | {}                               |
| password_expires_at | None                             |
+---------------------+----------------------------------+
```

将`admin`角色添加到`glance`用户和 `service`项目

```
[root@controller ~]# openstack role add --project service --user glance admin
```

创建glance服务实体
```
[root@controller ~]# openstack service create --name glance \
  --description "OpenStack Image" image

+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | OpenStack Image                  |
| enabled     | True                             |
| id          | 8c2c7f1b9b5049ea9e63757b5533e6d2 |
| name        | glance                           |
| type        | image                            |
+-------------+----------------------------------+
```
创建图像服务API端点

```
[root@controller ~]# openstack endpoint create --region RegionOne \
  image public http://controller:9292

+--------------+----------------------------------+
| Field        | Value                            |
+--------------+----------------------------------+
| enabled      | True                             |
| id           | 340be3625e9b4239a6415d034e98aace |
| interface    | public                           |
| region       | RegionOne                        |
| region_id    | RegionOne                        |
| service_id   | 8c2c7f1b9b5049ea9e63757b5533e6d2 |
| service_name | glance                           |
| service_type | image                            |
| url          | http://controller:9292           |
+--------------+----------------------------------+

[root@controller ~]# openstack endpoint create --region RegionOne \
  image internal http://controller:9292

+--------------+----------------------------------+
| Field        | Value                            |
+--------------+----------------------------------+
| enabled      | True                             |
| id           | a6e4b153c2ae4c919eccfdbb7dceb5d2 |
| interface    | internal                         |
| region       | RegionOne                        |
| region_id    | RegionOne                        |
| service_id   | 8c2c7f1b9b5049ea9e63757b5533e6d2 |
| service_name | glance                           |
| service_type | image                            |
| url          | http://controller:9292           |
+--------------+----------------------------------+

[root@controller ~]# openstack endpoint create --region RegionOne \
  image admin http://controller:9292

+--------------+----------------------------------+
| Field        | Value                            |
+--------------+----------------------------------+
| enabled      | True                             |
| id           | 0c37ed58103f4300a84ff125a539032d |
| interface    | admin                            |
| region       | RegionOne                        |
| region_id    | RegionOne                        |
| service_id   | 8c2c7f1b9b5049ea9e63757b5533e6d2 |
| service_name | glance                           |
| service_type | image                            |
| url          | http://controller:9292           |
+--------------+----------------------------------+
```

### 4.安全并配置组件

```
[root@controller ~]# yum install openstack-glance  

[root@controller ~]# vim /etc/glance/glance-api.conf

配置数据库访问
[database]
# ...
connection = mysql+pymysql://glance:GLANCE_DBPASS@controller/glance

配置身份服务访问
[keystone_authtoken] 4859行
# ...
www_authenticate_uri  = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = GLANCE_PASS

[paste_deploy]
# ...
flavor = keystone

配置本地文件系统存储和镜像文件的位置
[glance_store]
# ...
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images/

[root@controller ~]# vim /etc/glance/glance-registry.conf

配置数据库访问
[database]
# ...
connection = mysql+pymysql://glance:GLANCE_DBPASS@controller/glance

配置身份服务访问
[keystone_authtoken]
# ...
www_authenticate_uri  = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = GLANCE_PASS

[paste_deploy]
# ...
flavor = keystone
```

### 5.填充镜像服务数据库

```
[root@controller ~]# su -s /bin/sh -c "glance-manage db_sync" glance
```

### 6.完成安装

```
[root@controller ~]# systemctl enable openstack-glance-api.service openstack-glance-registry.service
[root@controller ~]# systemctl start openstack-glance-registry.service openstack-glance-api.service
```
