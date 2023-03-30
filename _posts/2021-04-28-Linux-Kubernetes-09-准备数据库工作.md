---
layout: post
title: Linux-Kubernetes-09-准备数据库工作
date: 2021-04-28
tags: 实战-Kubernetes
---

### 安装Mariadb数据库

```sh
[root@host0-11 ~]# rpm --import https://mirrors.ustc.edu.cn/mariadb/yum/RPM-GPG-KEY-MariaDB
[root@host0-11 ~]# yum install MariaDB-server -y
[root@host0-11 ~]# vim /etc/yum.repos.d/MariaDB.repo
[mariadb]
name = MariaDB
baseurl = https://mirrors.ustc.edu.cn/mariadb/yum/10.1/centos7-amd64/
gpgkey=https://mirrors.ustc.edu.cn/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1
```

### 配置优化数据库

```sh
[root@host0-11 ~]# vim /etc/my.cnf.d/server.cnf
[mysqld]
character_set_server = utf8mb4
collation_server = utf8mb4_general_ci
init_connect = "SET NAMES 'utf8mb4'"
[root@host0-11 ~]# vim /etc/my.cnf.d/mysql-clients.cnf
[mysql]
default-character-set = utf8mb4
[root@host0-11 ~]# systemctl start mariadb && systemctl enable mariadb
[root@host0-11 ~]# mysqladmin -u root password 
[root@host0-11 ~]# mysql -u root -p
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 3
Server version: 10.1.48-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> \s
--------------
mysql  Ver 15.1 Distrib 10.1.48-MariaDB, for Linux (x86_64) using readline 5.1

Connection id:		3
Current database:	
Current user:		root@localhost
SSL:			Not in use
Current pager:		stdout
Using outfile:		''
Using delimiter:	;
Server:			MariaDB
Server version:		10.1.48-MariaDB MariaDB Server
Protocol version:	10
Connection:		Localhost via UNIX socket
Server characterset:	utf8mb4
Db     characterset:	utf8mb4
Client characterset:	utf8mb4
Conn.  characterset:	utf8mb4
UNIX socket:		/var/lib/mysql/mysql.sock
Uptime:			1 min 41 sec

Threads: 1  Questions: 8  Slow queries: 0  Opens: 17  Flush tables: 1  Open tables: 11  Queries per second avg: 0.079
--------------

MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| test               |
+--------------------+
4 rows in set (0.00 sec)

MariaDB [(none)]> drop database test;
Query OK, 0 rows affected (0.00 sec)

MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
3 rows in set (0.00 sec)
```

### 执行数据库初始化脚本

```sh
[root@host0-11 ~]# wget https://raw.githubusercontent.com/ctripcorp/apollo/1.5.1/scripts/db/migration/configdb/V1.0.0__initialization.sql -O apolloconfig.sql
[root@host0-11 ~]# ls
anaconda-ks.cfg  apolloconfig.sql  zookeeper.out
[root@host0-11 ~]# mysql -uroot -p < apolloconfig.sql 
Enter password: 
[root@host0-11 ~]# mysql -uroot -p123123
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 9
Server version: 10.1.48-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| ApolloConfigDB     |
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
4 rows in set (0.00 sec)
```

### 执行数据库用户授权

因为config service 和admin service需要连接数据库

```sh
MariaDB [(none)]> grant INSERT,DELETE,UPDATE,SELECT on ApolloConfigDB.* to 'apolloconfig'@'10.0.0.%'  identified by "123123";
Query OK, 0 rows affected (0.00 sec)
MariaDB [(none)]> select user,host from mysql.user;
+--------------+-----------+
| user         | host      |
+--------------+-----------+
| apolloconfig | 10.0.0.%  |
| root         | 127.0.0.1 |
| root         | ::1       |
|              | host0-13  |
| root         | host0-13  |
|              | localhost |
| root         | localhost |
+--------------+-----------+
7 rows in set (0.00 sec)
```

### 修改初始化数据

```sh
MariaDB [(none)]> use ApolloConfigDB
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
MariaDB [ApolloConfigDB]> show tabales;
ERROR 1064 (42000): You have an error in your SQL syntax; check the manual that corresponds to your MariaDB server version for the right syntax to use near 'tabales' at line 1
MariaDB [ApolloConfigDB]>  show tables;
+--------------------------+
| Tables_in_ApolloConfigDB |
+--------------------------+
| App                      |
| AppNamespace             |
| Audit                    |
| Cluster                  |
| Commit                   |
| GrayReleaseRule          |
| Instance                 |
| InstanceConfig           |
| Item                     |
| Namespace                |
| NamespaceLock            |
| Release                  |
| ReleaseHistory           |
| ReleaseMessage           |
| ServerConfig             |
+--------------------------+
15 rows in set (0.00 sec)
MariaDB [ApolloConfigDB]> 
MariaDB [ApolloConfigDB]> update ApolloConfigDB.ServerConfig set ServerConfig.Value="http://config.od.com/eureka" where ServerConfig.Key="eureka.service.url";
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

MariaDB [ApolloConfigDB]> select * from ServerConfig\G
*************************** 1. row ***************************
                       Id: 1
                      Key: eureka.service.url
                  Cluster: default
                    Value: http://config.od.com/eureka        #这里已被修改
                  Comment: Eureka服务Url，多个service以英文逗号分隔
                IsDeleted:  
     DataChange_CreatedBy: default
   DataChange_CreatedTime: 2021-04-28 06:19:21
DataChange_LastModifiedBy: 
      DataChange_LastTime: 2021-04-28 06:29:58
*************************** 2. row ***************************
                       Id: 2
                      Key: namespace.lock.switch
                  Cluster: default
                    Value: false
                  Comment: 一次发布只能有一个人修改开关
                IsDeleted:  
     DataChange_CreatedBy: default
   DataChange_CreatedTime: 2021-04-28 06:19:21
DataChange_LastModifiedBy: 
      DataChange_LastTime: 2021-04-28 06:19:21
*************************** 3. row ***************************
                       Id: 3
                      Key: item.key.length.limit
                  Cluster: default
                    Value: 128
                  Comment: item key 最大长度限制
                IsDeleted:  
     DataChange_CreatedBy: default
   DataChange_CreatedTime: 2021-04-28 06:19:21
DataChange_LastModifiedBy: 
      DataChange_LastTime: 2021-04-28 06:19:21
*************************** 4. row ***************************
                       Id: 4
                      Key: item.value.length.limit
                  Cluster: default
                    Value: 20000
                  Comment: item value最大长度限制
                IsDeleted:  
     DataChange_CreatedBy: default
   DataChange_CreatedTime: 2021-04-28 06:19:21
DataChange_LastModifiedBy: 
      DataChange_LastTime: 2021-04-28 06:19:21
*************************** 5. row ***************************
                       Id: 5
                      Key: config-service.cache.enabled
                  Cluster: default
                    Value: false
                  Comment: ConfigService是否开启缓存，开启后能提高性能，但是会增大内存消耗！
                IsDeleted:  
     DataChange_CreatedBy: default
   DataChange_CreatedTime: 2021-04-28 06:19:21
DataChange_LastModifiedBy: 
      DataChange_LastTime: 2021-04-28 06:19:21
5 rows in set (0.00 sec)
```

### 配置解析

```sh
[root@host0-200 ~]# vim /var/named/od.com.zone
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020010512 ; serial
                10800      ; refresh (3 hours)
                900        ; retry (15 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
                )
                NS   dns.od.com.
$TTL 60 ; 1 minute
dns                A    10.0.0.200
harbor             A    10.0.0.200
k8s-yaml           A    10.0.0.200
traefik            A    10.0.0.10
dashboard          A    10.0.0.10
zk1                A    10.0.0.11
zk2                A    10.0.0.12
zk3                A    10.0.0.21
mirrors            A    10.0.0.200
jenkins            A    10.0.0.10
dubbo-monitor      A    10.0.0.10
demo               A    10.0.0.10
config             A    10.0.0.10
[root@host0-200 ~]# systemctl restart named
[root@host0-200 ~]# nslookup config.od.com
Server:		10.0.0.200
Address:	10.0.0.200#53

Name:	config.od.com
Address: 10.0.0.10
```
