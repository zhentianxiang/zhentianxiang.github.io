---
layout: post
title: OpenStack-Rocky安装部署-19-Nova验证
date: 2020-12-26
tags: 云计算
---

⚠️：验证计算服务的操作

### 1.获得 `admin` 凭证来获取只有管理员能执行的命令的访问权限

```
[root@controller ~]# . admin-openrc
```

### 2.列出服务组件，以验证是否成功启动并注册了每个进程

```
[root@controller ~]# openstack compute service list
+----+--------------------+------------+----------+---------+-------+----------------------------+
| Id | Binary             | Host       | Zone     | Status  | State | Updated At                 |
+----+--------------------+------------+----------+---------+-------+----------------------------+
|  1 | nova-consoleauth   | controller | internal | enabled | up    | 2016-02-09T23:11:15.000000 |
|  2 | nova-scheduler     | controller | internal | enabled | up    | 2016-02-09T23:11:15.000000 |
|  3 | nova-conductor     | controller | internal | enabled | up    | 2016-02-09T23:11:16.000000 |
|  4 | nova-compute       | compute1   | nova     | enabled | up    | 2016-02-09T23:11:20.000000 |
+----+--------------------+------------+----------+---------+-------+----------------------------+
```

⚠️：此输出应指示在控制器节点上启用的三个服务组件和在计算节点上启用的一个服务组件

### 3.列出身份服务中的API端点以验证与身份服务的连接性

⚠️：以下端点列表可能会有所不同，具体取决于OpenStack组件的安装

```
[root@controller ~]# openstack catalog list

+-----------+-----------+-----------------------------------------+
| Name      | Type      | Endpoints                               |
+-----------+-----------+-----------------------------------------+
| keystone  | identity  | RegionOne                               |
|           |           |   public: http://controller:5000/v3/    |
|           |           | RegionOne                               |
|           |           |   internal: http://controller:5000/v3/  |
|           |           | RegionOne                               |
|           |           |   admin: http://controller:5000/v3/     |
|           |           |                                         |
| glance    | image     | RegionOne                               |
|           |           |   admin: http://controller:9292         |
|           |           | RegionOne                               |
|           |           |   public: http://controller:9292        |
|           |           | RegionOne                               |
|           |           |   internal: http://controller:9292      |
|           |           |                                         |
| nova      | compute   | RegionOne                               |
|           |           |   admin: http://controller:8774/v2.1    |
|           |           | RegionOne                               |
|           |           |   internal: http://controller:8774/v2.1 |
|           |           | RegionOne                               |
|           |           |   public: http://controller:8774/v2.1   |
|           |           |                                         |
| placement | placement | RegionOne                               |
|           |           |   public: http://controller:8778        |
|           |           | RegionOne                               |
|           |           |   admin: http://controller:8778         |
|           |           | RegionOne                               |
|           |           |   internal: http://controller:8778      |
|           |           |                                         |
+-----------+-----------+-----------------------------------------+
```

⚠️：忽略输出的警告

### 4.列出图像服务中的图像以验证与图像服务的连接性

```
[root@controller ~]# openstack image list

+--------------------------------------+-------------+-------------+
| ID                                   | Name        | Status      |
+--------------------------------------+-------------+-------------+
| 9a76d9f9-9620-4f2e-8c69-6c5691fae163 | cirros      | active      |
+--------------------------------------+-------------+-------------+
```

### 5.检查单元格和展示位置API是否正常运行，以及其他必要的前提条件是否到位

```
[root@controller ~]# nova-status upgrade check

+--------------------------------------------------------------------+
| Upgrade Check Results                                              |
+--------------------------------------------------------------------+
| Check: Cells v2                                                    |
| Result: Success                                                    |
| Details: None                                                      |
+--------------------------------------------------------------------+
| Check: Placement API                                               |
| Result: Success                                                    |
| Details: None                                                      |
+--------------------------------------------------------------------+
| Check: Ironic Flavor Migration                                     |
| Result: Success                                                    |
| Details: None                                                      |
+--------------------------------------------------------------------+
| Check: Cinder API                                                  |
| Result: Success                                                    |
| Details: None                                                      |
+--------------------------------------------------------------------+
```
