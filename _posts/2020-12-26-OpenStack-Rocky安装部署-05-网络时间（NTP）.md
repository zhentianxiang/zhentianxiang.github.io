---
layout: post
title: OpenStack-Rocky安装部署-05-网络时间（NTP）
date: 2020-12-26
tags: 云计算
---

# 网络时间（NTP）

你应该安装Chrony，一个在不同节点同步服务实现的方案。我们建议你配置控制器节点引用更准确的(lower stratum)NTP服务器，然后其他节点引用控制节点。

### 1.controller部署

```
[root@controller ~]# yum -y install chrony
[root@controller ~]# cat /etc/chrony.conf 
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
server 0.centos.pool.ntp.org iburst
server 1.centos.pool.ntp.org iburst
server 2.centos.pool.ntp.org iburst
server 3.centos.pool.ntp.org iburst    //添加一行内容
server controller iburst
[root@controller ~]# systemctl enable chronyd.service //开机自启
[root@controller ~]# systemctl start chronyd.service  //启动服务
```

### 2.computer部署

```
[root@computer ~]# yum -y install chrony
[root@computer ~]# cat /etc/chrony.conf 
# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
server 0.centos.pool.ntp.org iburst
server 1.centos.pool.ntp.org iburst
server 2.centos.pool.ntp.org iburst
server 3.centos.pool.ntp.org iburst    //添加一行内容
server controller iburst
[root@computer ~]# systemctl enable chronyd.service //开机自启
[root@computer ~]# systemctl start chronyd.service  //启动服务
```

### 3.controller验证

```
[root@controller ~]# chronyc sources
  210 Number of sources = 2
  MS Name/IP address         Stratum Poll Reach LastRx Last sample
  ===============================================================================
  ^- 192.0.2.11                    2   7    12   137  -2814us[-3000us] +/-   43ms
  ^* 192.0.2.12                    2   6   177    46    +17us[  -23us] +/-   68ms
```

### 4.computer验证

```
[root@computer ~]# chronyc sources
  210 Number of sources = 2
  MS Name/IP address         Stratum Poll Reach LastRx Last sample
  ===============================================================================
  ^- 192.0.2.11                    2   7    12   137  -2814us[-3000us] +/-   43ms
  ^* 192.0.2.12                    2   6   177    46    +17us[  -23us] +/-   68ms
  ^* controller                    3    9   377   421    +15us[  -87us] +/-   15ms
```

