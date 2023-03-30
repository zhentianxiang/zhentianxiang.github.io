---
layout: post
title: OpenStack-Rocky安装部署-11-Etcd分布式数据库
date: 2020-12-26
tags: 云计算
---

### 1.安装和配置的部件
安装软件包
```
[root@tianxiang ~]# yum install etcd
```
编辑/etc/etcd/etcd.conf文件
```
#[Member]
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="http://10.0.0.11:2380"
ETCD_LISTEN_CLIENT_URLS="http://10.0.0.11:2379"
ETCD_NAME="controller"
#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="http://10.0.0.11:2380"
ETCD_ADVERTISE_CLIENT_URLS="http://10.0.0.11:2379"
ETCD_INITIAL_CLUSTER="controller=http://10.0.0.11:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster-01"
ETCD_INITIAL_CLUSTER_STATE="new"
```
### 2.完成安装
启用并启动etcd服务
```
[root@tianxiang ~]# systemctl enable etcd
[root@tianxiang ~]# systemctl start etcd
```
