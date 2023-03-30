---
layout: post
title: OpenStack-Rocky安装部署-07-SQL数据库
date: 2020-12-26
tags: 云计算
---

### 1.安装软件包

```
[root@controller ~]# yum install mariadb mariadb-server python2-PyMySQL
```

### 2.创建编辑文件

```
[root@controller ~]# vim /etc/my.cnf.d/openstack.cnf
[mysqld]
bind-address = 10.0.0.11

default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8

[root@controller ~]# systemctl enable mariadb.service   //开机自启
[root@controller ~]# systemctl start mariadb.service    //启动数据库
```

### 3.初始化数据库

```
# mysql_secure_installation
```

 