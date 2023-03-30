---
layout: post
title: OpenStack-Rocky安装部署-18-Nova计算节点配置
date: 2020-12-26
tags: 云计算
---

### 1.安装软件包

```
[root@computer~]# yum install openstack-nova-compute
```

### 2.编辑`/etc/nova/nova.conf`

```
[root@computer~]# vim /etc/nova/nova.conf

仅启用计算和元数据API
[DEFAULT]
# ...
enabled_apis = osapi_compute,metadata

配置RabbitMQ消息队列访问
[DEFAULT]
# ...
transport_url = rabbit://openstack:RABBIT_PASS@controller

配置身份服务访问
[api]
# ...
auth_strategy = keystone

[keystone_authtoken]
# ...
auth_url = http://controller:5000/v3
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = nova
password = NOVA_PASS

配置my_ip选项
[DEFAULT]
# ...
my_ip = 10.0.0.12

启用对网络服务的支持
[DEFAULT]
# ...
use_neutron = true
firewall_driver = nova.virt.firewall.NoopFirewallDriver

启用和配置远程控制台访问
[vnc]
# ...
enabled = true
server_listen = 0.0.0.0
server_proxyclient_address = $my_ip
novncproxy_base_url = http://controller:6080/vnc_auto.html

配置镜像服务API的位置
[glance]
# ...
api_servers = http://controller:9292

配置锁定路径
[oslo_concurrency]
# ...
lock_path = /var/lib/nova/tmp

配置Placement API
[placement]
# ...
region_name = RegionOne
project_domain_name = Default
project_name = service
auth_type = password
user_domain_name = Default
auth_url = http://controller:5000/v3
username = placement
password = PLACEMENT_PASS
```

### 3.最终确定安装

确定您的计算节点是否支持虚拟机的硬件加速

```
[root@computer~]# egrep -c '(vmx|svm)' /proc/cpuinfo
```

如果这个命令返回了1 的值，那么你的计算节点支持硬件加速且不需要额外的配置。

如果这个命令返回了0 值，那么你的计算节点不支持硬件加速。你必须配置 `libvirt` 来使用 QEMU 去代替 KVM

在 `/etc/nova/nova.conf` 文件的 `[libvirt]` 区域做出如下的编辑

```
[root@computer~]# vim /etc/nova/nova.conf

[libvirt]
...
cpu_mode = none
virt_type = qemu
```

### 4.启动计算服务及其依赖，并将其配置为随系统自动启动

```
[root@computer~]# systemctl enable libvirtd.service openstack-nova-compute.service
[root@computer~]# systemctl start libvirtd.service openstack-nova-compute.service
```
如果nova-compute服务无法启动，请检查 /var/log/nova/nova-compute.log。该错误消息可能表明控制器节点上的防火墙阻止访问端口5672。将防火墙配置为打开控制器节点上的端口5672并重新启动 计算节点上的服务。AMQP server on controller:5672 is unreachablenova-compute

# 添加计算节点

```
在控制节点

[root@controller ~]# . admin-openrc

然后确认数据库中有计算主机

[root@controller ~]# openstack compute service list --service nova-compute
+----+-------+--------------+------+-------+---------+----------------------------+
| ID | Host  | Binary       | Zone | State | Status  | Updated At                 |
+----+-------+--------------+------+-------+---------+----------------------------+
| 1  | node1 | nova-compute | nova | up    | enabled | 2017-04-14T15:30:44.000000 |
+----+-------+--------------+------+-------+---------+----------------------------+

发现计算主机

[root@controller ~]# su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova

Found 2 cell mappings.
Skipping cell0 since it does not contain hosts.
Getting compute nodes from cell 'cell1': ad5a5985-a719-4567-98d8-8d148aaae4bc
Found 1 computes in cell: ad5a5985-a719-4567-98d8-8d148aaae4bc
Checking host mapping for compute host 'compute': fe58ddc1-1d65-4f87-9456-bc040dc106b3
Creating host mapping for compute host 'compute': fe58ddc1-1d65-4f87-9456-bc040dc106b3

添加新的计算节点时，必须在控制器节点上运行以注册这些新的计算节点

设置300秒自动发现新主机
[root@controller ~]# vim /etc/nova/nova.conf

[scheduler]
discover_hosts_in_cells_interval = 300
```
