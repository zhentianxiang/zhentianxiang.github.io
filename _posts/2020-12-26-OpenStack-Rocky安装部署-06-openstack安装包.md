---
layout: post
title: OpenStack-Rocky安装部署-06-openstack安装包
date: 2020-12-26
tags: 云计算
---

### 1.部署安装源(包括计算节点)

```
[root@controller ~]# yum install centos-release-openstack-rocky
```

### 2.升级软件包(包括计算节点)

```
[root@controller ~]# yum upgrade
```

### 3.安装OpenStack客户端

```
[root@controller ~]# yum install python-openstackclient
```

### 4.RHEL和CentOS默认情况下启用SELinux安装 `openstack-selinux`软件包以自动管理OpenStack服务的安全策略

```
[root@controller ~]# yum install openstack-selinux
```
