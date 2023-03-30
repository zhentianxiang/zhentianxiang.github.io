---
layout: post
title: OpenStack-Rocky安装部署-32-部分命令总结
date: 2020-12-26
tags: 云计算
---




### 1.openstack命令

```
openstack-service restart  //重启openstack服务

openstack endpoint-list            //查看openstack的端口

openstack compute service list         //查看计算节点与控制节点连接状态

openstack cinder service list         //查看cinder节点与控制节点连接状态
```

### 2.nova的常用命令

```
nova list            //列举当前用户所有虚拟机

nova start ID         //开启虚拟机

nova stop ID         //关闭虚拟机

nova reboot ID         //重启虚拟机

nova rebuild ID         //重置虚拟机

nova server pause ID        //暂停

nova server unpaus         //取消暂停

nova show ID          //列举某个虚机的详细信息

nova delete ID         //直接删除某个虚机

nova service-list           //获取所有服务列表

nova flavor-list            //列举所有可用的类型

nova volume-list           //列举所有云硬盘

nova volume-show           //显示指定云硬盘的详细信息

nova volume-create           //创建云硬盘

nova volume-delete           //删除云硬盘

nova volume-snapshot-create          //创建云硬盘快照

nova volume-snapshot-delete           //删除云硬盘快照

nova live-migration ID node          //热迁移

nova migrate ID node            //冷迁移

nova migration-list          //列出迁移列表

nova get-vnc-console ID novnc           //获取虚机的vnc地址

nova reset-state --active ID           //标识主机状态

```

### 3.neutron常用命令

```
neutron agent-list           //列举所有的agent

neutron agent-show ID           //显示指定agent信息

neutron port-list           //查看端口列表

neutron net-list           //列出当前租户所有网络

neutron net-list --all-tenants           //列出所有租户所有网络

neutron net-show ID            //查看一个网络的详细信息

neutron net-delete ID            //删除一个网络
```

**ip netns         //查看命名空间**

**ip netsn exec haproxy ip a         //查看haproxy的ip**



### 4.cinder命令

```
cinder list            //列出所有的volumes

cinder service-list           //列出所有的服务

cinder snapshot-list           //列出所有的快照

cinder backup-list            //列出所有备份

cinder type-list            //列出所有volume类型

cinder show            //查看卷

cinder delete        //删除卷

一下是删除僵尸卷方法
MariaDB [cinder]> select id, status, display_name from volumes where id='c4464420-4e3c-4bad-8e85-325f82c67396';
+--------------------------------------+----------------+--------------+
| id                                   | status         | display_name |
+--------------------------------------+----------------+--------------+
| c4464420-4e3c-4bad-8e85-325f82c67396 | error_deleting |              |
+--------------------------------------+----------------+--------------+
1 row in set (0.01 sec)

MariaDB [cinder]> update volumes set deleted=1 where id='c4464420-4e3c-4bad-8e85-325f82c67396';
Query OK, 1 row affected (0.02 sec)
Rows matched: 1  Changed: 1  Warnings: 0

MariaDB [cinder]> exit

[root@controller data]# cinder list
+----+--------+------+------+-------------+----------+-------------+
| ID | Status | Name | Size | Volume Type | Bootable | Attached to |
+----+--------+------+------+-------------+----------+-------------+
+----+--------+------+------+-------------+----------+-------------+

```

### 5.glance

```
glance image list         //查看镜像列表
```

### 6.调整租户配额

以下仅供参考，调整其他组件配额相同类似
```
openstack project list          //列出project

openstack quota show project_ID        //查看project的配额信息

nova quota-update --ram=245400 --cores=90 --instances=30 projectID    //更改内存，cpu，虚机数量，此命令不会输出任何信息

cinder quota-show  project_ID       //查看卷的配额

cinder quota-update --gigabytes=4500 projectID         //升级卷存储的配额为4500G
```
