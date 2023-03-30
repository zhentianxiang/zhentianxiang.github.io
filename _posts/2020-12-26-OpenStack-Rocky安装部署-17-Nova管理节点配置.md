---
layout: post
title: OpenStack-Rocky安装部署-17-Nova管理节点配置
date: 2020-12-26
tags: 云计算
---

### 1.先决条件

在安装和配置 Compute 服务前，你必须创建数据库服务的凭据以及 API endpoints。

```
用数据库连接客户端以 root 用户连接到数据库服务器
[root@controller ~]# mysql -u root -p
创建 nova_api 和 nova 数据库：
MariaDB [(none)]> CREATE DATABASE nova_api;
MariaDB [(none)]> CREATE DATABASE nova;
MariaDB [(none)]> CREATE DATABASE nova_cell0;
MariaDB [(none)]> CREATE DATABASE placement;
授予对数据库的适当访问权限：
MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' \
  IDENTIFIED BY 'NOVA_DBPASS';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' \
  IDENTIFIED BY 'NOVA_DBPASS';

MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' \
  IDENTIFIED BY 'NOVA_DBPASS';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' \
  IDENTIFIED BY 'NOVA_DBPASS';

MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' \
  IDENTIFIED BY 'NOVA_DBPASS';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' \
  IDENTIFIED BY 'NOVA_DBPASS';

  MariaDB [(none)]> GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' \
  IDENTIFIED BY 'PLACEMENT_DBPASS';
MariaDB [(none)]> GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' \
  IDENTIFIED BY 'PLACEMENT_DBPASS';
```

### 2.获得 `admin` 凭证来获取只有管理员能执行的命令的访问权限

```
[root@controller ~]# . admin-openrc
```

### 3.创建计算服务凭据：

创建`nova`用户

```
[root@controller ~]# openstack user create --domain default --password-prompt nova

User Password:NOVA_PASS
Repeat User Password:NOVA_PASS
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | default                          |
| enabled             | True                             |
| id                  | 8a7dbf5279404537b1c7b86c033620fe |
| name                | nova                             |
| options             | {}                               |
| password_expires_at | None                             |
+---------------------+----------------------------------+
```

`admin`向`nova`用户添加角色：

```
[root@controller ~]# openstack role add --project service --user nova admin
```

创建`nova`服务实体：

```
[root@controller ~]# openstack service create --name nova \
  --description "OpenStack Compute" compute

+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | OpenStack Compute                |
| enabled     | True                             |
| id          | 060d59eac51b4594815603d75a00aba2 |
| name        | nova                             |
| type        | compute                          |
+-------------+----------------------------------+
```

创建Compute API服务端点：

```
[root@controller ~]# openstack endpoint create --region RegionOne \
  compute public http://controller:8774/v2.1

+--------------+-------------------------------------------+
| Field        | Value                                     |
+--------------+-------------------------------------------+
| enabled      | True                                      |
| id           | 3c1caa473bfe4390a11e7177894bcc7b          |
| interface    | public                                    |
| region       | RegionOne                                 |
| region_id    | RegionOne                                 |
| service_id   | 060d59eac51b4594815603d75a00aba2          |
| service_name | nova                                      |
| service_type | compute                                   |
| url          | http://controller:8774/v2.1               |
+--------------+-------------------------------------------+

[root@controller ~]# openstack endpoint create --region RegionOne \
  compute internal http://controller:8774/v2.1

+--------------+-------------------------------------------+
| Field        | Value                                     |
+--------------+-------------------------------------------+
| enabled      | True                                      |
| id           | e3c918de680746a586eac1f2d9bc10ab          |
| interface    | internal                                  |
| region       | RegionOne                                 |
| region_id    | RegionOne                                 |
| service_id   | 060d59eac51b4594815603d75a00aba2          |
| service_name | nova                                      |
| service_type | compute                                   |
| url          | http://controller:8774/v2.1               |
+--------------+-------------------------------------------+

[root@controller ~]# openstack endpoint create --region RegionOne \
  compute admin http://controller:8774/v2.1

+--------------+-------------------------------------------+
| Field        | Value                                     |
+--------------+-------------------------------------------+
| enabled      | True                                      |
| id           | 38f7af91666a47cfb97b4dc790b94424          |
| interface    | admin                                     |
| region       | RegionOne                                 |
| region_id    | RegionOne                                 |
| service_id   | 060d59eac51b4594815603d75a00aba2          |
| service_name | nova                                      |
| service_type | compute                                   |
| url          | http://controller:8774/v2.1               |
+--------------+-------------------------------------------+
```

创建展示位置服务用户

```
[root@controller ~]# openstack user create --domain default --password-prompt placement

User Password:PLACEMENT_PASS
Repeat User Password:PLACEMENT_PASS
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | default                          |
| enabled             | True                             |
| id                  | fa742015a6494a949f67629884fc7ec8 |
| name                | placement                        |
| options             | {}                               |
| password_expires_at | None                             |
+---------------------+----------------------------------+
```

使用管理员角色将Placement用户添加到服务项目中

```
[root@controller ~]# openstack role add --project service --user placement admin
```

在服务目录中创建Placement API条目

```
[root@controller ~]# openstack service create --name placement \
  --description "Placement API" placement

+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | Placement API                    |
| enabled     | True                             |
| id          | 2d1a27022e6e4185b86adac4444c495f |
| name        | placement                        |
| type        | placement                        |
+-------------+----------------------------------+
```

创建Placement API服务端点

```
[root@controller ~]# openstack endpoint create --region RegionOne \
  placement public http://controller:8778

+--------------+----------------------------------+
| Field        | Value                            |
+--------------+----------------------------------+
| enabled      | True                             |
| id           | 2b1b2637908b4137a9c2e0470487cbc0 |
| interface    | public                           |
| region       | RegionOne                        |
| region_id    | RegionOne                        |
| service_id   | 2d1a27022e6e4185b86adac4444c495f |
| service_name | placement                        |
| service_type | placement                        |
| url          | http://controller:8778           |
+--------------+----------------------------------+

[root@controller ~]# openstack endpoint create --region RegionOne \
  placement internal http://controller:8778

+--------------+----------------------------------+
| Field        | Value                            |
+--------------+----------------------------------+
| enabled      | True                             |
| id           | 02bcda9a150a4bd7993ff4879df971ab |
| interface    | internal                         |
| region       | RegionOne                        |
| region_id    | RegionOne                        |
| service_id   | 2d1a27022e6e4185b86adac4444c495f |
| service_name | placement                        |
| service_type | placement                        |
| url          | http://controller:8778           |
+--------------+----------------------------------+

[root@controller ~]# openstack endpoint create --region RegionOne \
  placement admin http://controller:8778

+--------------+----------------------------------+
| Field        | Value                            |
+--------------+----------------------------------+
| enabled      | True                             |
| id           | 3d71177b9e0f406f98cbff198d74b182 |
| interface    | admin                            |
| region       | RegionOne                        |
| region_id    | RegionOne                        |
| service_id   | 2d1a27022e6e4185b86adac4444c495f |
| service_name | placement                        |
| service_type | placement                        |
| url          | http://controller:8778           |
+--------------+----------------------------------+
```

### 6.安装和配置组件

安装软件包

```
[root@controller ~]# yum install openstack-nova-api openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy \
  openstack-nova-scheduler openstack-nova-placement-api
```

编辑`/etc/nova/nova.conf`

```
[root@controller ~]# vim /etc/nova/nova.conf

只启用计算和元数据API
[DEFAULT]
#...
enabled_apis = osapi_compute,metadata

配置数据库访问
[api_database]
#...
connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova_api

[database]
#...
connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova

[placement_database]
# ...
connection = mysql+pymysql://placement:PLACEMENT_DBPASS@controller/placement

配置RabbitMQ消息队列访问
[DEFAULT]
#...
transport_url = rabbit://openstack:RABBIT_PASS@controller

配置身份服务访问
[api]
#...
auth_strategy = keystone

[keystone_authtoken]
#...
auth_url = http://controller:5000/v3
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = NOVA_PASS

配置my_ip选项以使用控制器节点的管理接口IP地址
[DEFAULT]
#...
my_ip = 10.0.0.11

启用对网络服务的支持
[DEFAULT]
#...
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver

将VNC代理配置为使用控制器节点的管理接口IP地址
[vnc]
enabled = true
#...
server_listen = $my_ip
server_proxyclient_address = $my_ip

配置镜像服务API的位置
[glance]
#...
api_servers = http://controller:9292

配置锁路径
[oslo_concurrency]
...
lock_path = /var/lib/nova/tmp

配置对展示位置服务的访问权限

[placement]
#...
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://controller:5000/v3
username = placement
password = PLACEMENT_PASS
```
在使用openstack的过程中，默认创建的实例最多10个，这是因为配额默认实例就是10

所以我们需要修改配置文件/etc/nova/nova.conf中的配额参数就可以了

[default] 末尾添加
quota_instances=1000000
quota_cores=20000
quota_ram=5120000000
quota_floating_ips=100000

### .由于[包装错误](https://bugzilla.redhat.com/show_bug.cgi?id=1430540)，您必须通过将以下配置添加到来启用对Placement API的访问 `/etc/httpd/conf.d/00-nova-placement-api.conf`：

```
在最下面填写
[root@controller ~]# vim /etc/httpd/conf.d/00-nova-placement-api.conf
<Directory /usr/bin>
   <IfVersion >= 2.4>
      Require all granted
   </IfVersion>
   <IfVersion < 2.4>
      Order allow,deny
      Allow from all
   </IfVersion>
</Directory>
[root@controller ~]# systemctl restart httpd
```

### 7.填充`nova-api`和`placement`数据库

```
[root@controller ~] su -s /bin/sh -c "nova-manage api_db sync" nova
```

### 8.注册`cell0`数据库

```
[root@controller ~]# su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
```

### 9.创建`cell1`单元格：

```
[root@controller ~]# su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
```
### .填充nova数据库

```
[root@controller ~]# su -s /bin/sh -c "nova-manage db sync" nova
忽略弃用信息
```

### 11.验证nova cell0和cell1是否正确注册

```
[root@controller ~]# su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
+-------+--------------------------------------+----------------------------------------------------+--------------------------------------------------------------+----------+
|  Name |                 UUID                 |                   Transport URL                    |                     Database Connection                      | Disabled |
+-------+--------------------------------------+----------------------------------------------------+--------------------------------------------------------------+----------+
| cell0 | 00000000-0000-0000-0000-000000000000 |                       none:/                       | mysql+pymysql://nova:****@controller/nova_cell0?charset=utf8 |  False   |
| cell1 | f690f4fd-2bc5-4f15-8145-db561a7b9d3d | rabbit://openstack:****@controller:5672/nova_cell1 | mysql+pymysql://nova:****@controller/nova_cell1?charset=utf8 |  False   |
+-------+--------------------------------------+----------------------------------------------------+--------------------------------------------------------------+----------+
```

### 12.完成安装

启动Compute服务并将其配置为在系统启动时启动

```
[root@controller ~]# systemctl enable openstack-nova-api.service \
  openstack-nova-consoleauth openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service
[root@controller ~]# systemctl start openstack-nova-api.service \
  openstack-nova-consoleauth openstack-nova-scheduler.service \
  openstack-nova-conductor.service openstack-nova-novncproxy.service
```
