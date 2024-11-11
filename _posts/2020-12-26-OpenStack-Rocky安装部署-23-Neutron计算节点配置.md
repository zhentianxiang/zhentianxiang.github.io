---
layout: post
title: OpenStack-Rocky安装部署-23-Neutron计算节点配置
date: 2020-12-26
tags: 云计算
---

### 1.安装组件

```
[root@computer ~]#  yum install openstack-neutron-linuxbridge ebtables ipset
```

### 2.配置公共部件

网络公共组件配置包括身份验证机制，消息队列和插件

```
[root@computer ~]# vim  /etc/neutron/neutron.conf

配置RabbitMQ 消息队列访问
[DEFAULT]
#...
transport_url = rabbit://openstack:RABBIT_PASS@controller

配置身份服务访问
[DEFAULT]
#...
auth_strategy = keystone

[keystone_authtoken]
#...
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
memcached_servers = controller:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = neutron
password = NEUTRON_PASS

配置锁定路径
[oslo_concurrency]
#...
lock_path = /var/lib/neutron/tmp
```

### 3.配置网络选项

选择与您之前在控制节点上选择的相同的网络选项。之后，回到这里并进行下一步：[*为计算节点配置网络服务*](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/neutron-compute-install.html[root@computer ~]# neutron-compute-compute)。

- [网络选项1：公共网络](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-21-公共网络/)
- [网络选项2：私有网络](http://blog.tianxiang.love/2020/12/OpenStack-Rocky安装部署-22-私有网络/)

### 4.为计算节点配置网络服务

```
[root@computer ~]# vim /etc/nova/nova.conf

配置访问参数
[neutron] 7661行
...
auth_url = http://controller:9696
auth_url = http://controller:5000
auth_type = password
project_domain_name = default
user_domain_name = default
region_name = RegionOne
project_name = service
username = neutron
password = NEUTRON_PASS
```

### 5.最终确定安装

重新启动计算服务

```
[root@computer ~]#  systemctl restart openstack-nova-compute.service
```

启动Linux网桥代理，并将其配置为在系统引导时启动

```
[root@computer ~]#  systemctl enable neutron-linuxbridge-agent.service
[root@computer ~]#  systemctl start neutron-linuxbridge-agent.service
```
