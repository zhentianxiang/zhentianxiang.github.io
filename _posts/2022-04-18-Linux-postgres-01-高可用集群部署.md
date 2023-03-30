---
layout: post
title: Linux-postgres-01-高可用集群部署
date: 2022-04-18
tags: Linux-postgres
---

## 一、简单介绍

A. 某一个 postgresql 数据库挂掉 (多台数据库启动后 其中一台作为主机,其余作为备机 构成一个数据库集群)

   (1) 如果是主机primary,集群检测到挂掉会通过配置的策略重新选一个备机standby切换为主机primary, 整个集群仍旧保证可用, 当原主机恢复服务后, 重新作为一个新备机standby,同步完数据后加入集群
   (2) 如果是备机standby,对整个集群无可见影响, 当备机恢复服务后,从主库同步完数据后,恢复正常状态加入集群

B. 某一台机器上的pgpool-ii 程序挂掉

   (1) 监测每个pgpool-ii进程的状态, 监测到挂掉之后,及时"切换"虚拟ip所在的主机以保证可用性(有些人叫IP漂移)
   (2) 整个集群始终对外提供一个唯一的,可用的虚拟IP 来提供访问
   (3) 监测每个主机postgresql数据库的状态, 以即使切换数据库的主备角色

C. 某一台主机直接宕机

   (1) 当pgpool-ii监测主机挂掉之后, 需要进行数据库角色的切换和ip的切换两个操作(如果需要)

## 二、方案结构

| 机器名称      | IP            | 主从划分 |
| ------------- | ------------- | -------- |
| pgsql-master  | 192.168.20.16 | 主       |
| pgsql-slave01 | 192.168.20.17 | 从       |
|               | 192.168.20.50 | VIP      |

软件版本

| 系统版本       | CentOS Linux release 7.9.2009 (Core) |
| ------------- | ------------- |
| PostgreSQL    | 10            |
| pgpool-ii     | 4.0.1         |

整体架构

![](/images/posts/Linux-postgres/Linux-postgres-01-高可用集群部署/1.png)

## 三、安装部署

### 1. 安装postgres-10 （主备都做）

安装相关依赖包

```sh
[root@pgsql_master ~]# cat << EOF > /etc/yum.repos.d/c7-devtoolset-7-x86_64.repo
[c7-devtoolset-7]
name=c7-devtoolset-7
baseurl=https://buildlogs.centos.org/c7-devtoolset-7.x86_64/
gpgcheck=0
enabled=1

[c7-llvm-toolset-7]
name=c7-llvm-toolset-7
baseurl=https://buildlogs.centos.org/c7-llvm-toolset-7.x86_64/
gpgcheck=0
enabled=1

[fedoraproject-epel-7]
name=fedoraproject-epel-7
baseurl=https://download-ib01.fedoraproject.org/pub/epel/7/x86_64/
gpgcheck=0
enabled=1
EOF
[root@pgsql_master ~]# yum install -y glibc-devel bison flex readline-devel zlib-devel pgdg-srpm-macros lz4-devel libicu-devel llvm5.0-devel llvm-toolset-7-clang krb5-devel e2fsprogs-devel \
 openldap-devel pam-devel perl-ExtUtils-Embed python3-devel tcl-devel systemtap-sdt-devel libselinux-devel openssl-devel libuuid-devel libxml2-devel libxslt-devel systemd-devel \
gcc gcc-c++
```
这里要先安装pgpool，不然安装好pgsql之后再安装pgpool会报错
```sh
[root@pgsql_master ~]# yum -y install http://www.pgpool.net/yum/rpms/4.0/redhat/rhel-7-x86_64/pgpool-II-release-4.0-1.noarch.rpm
[root@pgsql_master ~]# yum -y install pgpool-II-pg11-*
[root@pgsql_master ~]# yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm
[root@pgsql_master ~]# yum -y install postgresql10 postgresql10-contrib postgresql10-server postgresql10-devel
[root@pgsql_master ~]# /usr/pgsql-10/bin/postgresql-10-setup initdb
[root@pgsql_master ~]# vim ~/.bash_profile
PATH=$PATH:$HOME/usr/pgsql-10/bin
[root@pgsql_master ~]# source ~/.bash_profile
```

### 2. 主节点配置

创建用于主从访问的用户， 修改postgres用户的密码，用于远程登录。(切换到postgres用户操作)

```sh
[root@pgsql_master ~]# systemctl start postgresql-10.service
[root@pgsql_master ~]# su - postgres
上一次登录：一 4月 18 15:00:32 CST 2022pts/0 上
-bash-4.2$ psql
postgres=# create role actorcloud login replication encrypted password 'public';
postgres=# alter role postgres with password 'postgres';
postgres=# \q
```

修改pg_hba.conf和postgresql.conf配置

```sh
-bash-4.2$ vim /var/lib/pgsql/10/data/pg_hba.conf
# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            ident
# IPv6 local connections:
host    all             all             ::1/128                 ident
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            ident
host    replication     all             ::1/128                 ident
# 以下是添加的配置项
host    replication    actorcloud    192.168.20.16/24    trust
host    replication    actorcloud    192.168.20.17/24    trust
host    all    all    192.168.20.0/24    md5
host    all    all    0.0.0.0/0    md5
```

修改postgresql.conf配置

```sh
-bash-4.2$ vim /var/lib/pgsql/10/data/postgresql.conf
listen_addresses = '*'
port = 5432
wal_level = replica
max_wal_senders= 10
wal_keep_segments = 10240
max_connections = 512
```

重启主节点

```sh
-bash-4.2$ 登出
[root@pgsql_master ~]# systemctl restart postgresql-10.service
[root@pgsql_master ~]# systemctl enable postgresql
[root@pgsql_master ~]# systemctl status postgresql-10
● postgresql-10.service - PostgreSQL 10 database server
   Loaded: loaded (/usr/lib/systemd/system/postgresql-10.service; enabled; vendor preset: disabled)
   Active: active (running) since 一 2022-04-18 15:19:29 CST; 31min ago
     Docs: https://www.postgresql.org/docs/10/static/
  Process: 948 ExecStartPre=/usr/pgsql-10/bin/postgresql-10-check-db-dir ${PGDATA} (code=exited, status=0/SUCCESS)
 Main PID: 961 (postmaster)
   CGroup: /system.slice/postgresql-10.service
           ├─ 961 /usr/pgsql-10/bin/postmaster -D /var/lib/pgsql/10/data/
           ├─ 983 postgres: logger process   
           ├─ 985 postgres: checkpointer process   
           ├─ 986 postgres: writer process   
           ├─ 987 postgres: wal writer process   
           ├─ 988 postgres: autovacuum launcher process   
           ├─ 989 postgres: stats collector process   
           ├─ 990 postgres: bgworker: logical replication launcher   
           └─1256 postgres: wal sender process actorcloud 192.168.20.17(47454) streaming 0/30015E0

4月 18 15:19:29 pgsql_master systemd[1]: Starting PostgreSQL 10 database server...
4月 18 15:19:29 pgsql_master postmaster[961]: 2022-04-18 15:19:29.595 CST [961] 日志:  listening on IPv4 address "0.0.0.0", port 5432
4月 18 15:19:29 pgsql_master postmaster[961]: 2022-04-18 15:19:29.597 CST [961] 日志:  listening on IPv6 address "::", port 5432
4月 18 15:19:29 pgsql_master postmaster[961]: 2022-04-18 15:19:29.598 CST [961] 日志:  listening on Unix socket "/var/run/postgresql/.s.PGSQL.5432"
4月 18 15:19:29 pgsql_master postmaster[961]: 2022-04-18 15:19:29.600 CST [961] 日志:  listening on Unix socket "/tmp/.s.PGSQL.5432"
4月 18 15:19:29 pgsql_master postmaster[961]: 2022-04-18 15:19:29.776 CST [961] 日志:  日志输出重定向到日志收集进程
4月 18 15:19:29 pgsql_master postmaster[961]: 2022-04-18 15:19:29.776 CST [961] 提示:  后续的日志输出将出现在目录 "log"中.
4月 18 15:19:29 pgsql_master systemd[1]: Started PostgreSQL 10 database server.
```

### 3. 从节点配置

```sh
[root@pgsql_slave01 ~]# su - postgres
-bash-4.2$ rm -rf /var/lib/pgsql/10/data/*
-bash-4.2$ pg_basebackup -h 192.168.20.16 -U actorcloud -D /var/lib/pgsql/10/data -X stream -P
```

拷贝recovery.conf，编辑recovery.conf内容，其中192.168.20.16对应主机IP，actorcloud是上一节主机创建的用户

```sh
-bash-4.2$ cp /usr/pgsql-10/share/recovery.conf.sample /var/lib/pgsql/10/data/recovery.conf
```

```sh
-bash-4.2$ vim /var/lib/pgsql/10/data/recovery.conf
standby_mode = on
primary_conninfo = 'host=192.168.20.16 port=5432 user=actorcloud password=public'
recovery_target_timeline = 'latest'
trigger_file = '/tmp/trigger_file0'
```

修改从节点的postgresql.conf，用于开启standby模式

```sh
-bash-4.2$ vim /var/lib/pgsql/10/data/postgresql.conf
hot_standby = on
```

退出postgres用户，重启PostgreSQL

```sh
-bash-4.2$ 登出
[root@pgsql_slave01 ~]# systemctl restart postgresql-10.service && systemctl enable postgresql-10
```

### 4. 验证主从

登陆到主节点数据库

```sh
[root@pgsql_master ~]# su - postgres ##或者 psql -h 192.168.20.16 -U postgres -p 5432
上一次登录：一 4月 18 15:46:14 CST 2022pts/0 上
-bash-4.2$ psql
psql (14.2, 服务器 10.20)
输入 "help" 来获取帮助信息.

postgres=# select client_addr,sync_state from pg_stat_replication;
  client_addr  | sync_state
---------------+------------
 192.168.20.17 | async
(1 行记录)

postgres=#
```

在主节点写数据，从节点读数据

```sh
postgres=# create database test;
postgres=# \l
                                     数据库列表
   名称    |  拥有者  | 字元编码 |  校对规则   |    Ctype    |       存取权限        
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
 template0 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 test      | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |  
(4 行记录)
```

在从节点上查看创建之后的数据库。可以看见，数据库同步了

```sh
[root@pgsql_slave01 ~]# psql -h 192.168.20.17 -U postgres -p 5432
用户 postgres 的口令：
psql (10.20)
输入 "help" 来获取帮助信息.

postgres=# \l
                                     数据库列表
   名称    |  拥有者  | 字元编码 |  校对规则   |    Ctype    |       存取权限        
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
 template0 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 test      | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
(4 行记录)
```

### 5. 配置宿主机与psql之间的免密登陆(主备都做)

```sh
[root@pgsql_master ~]# passwd postgres
密码123123
[root@pgsql_master ~]# su - postgres
上一次登录：一 4月 18 15:57:17 CST 2022pts/0 上
-bash-4.2$ ssh-keygen # 一路回车
-bash-4.2$ ssh-copy-id 192.168.20.16 # 输入密码123123
```

### 6. 主备部署pgpool-ii(主备都做)

```sh
[root@pgsql_master ~]# vim /etc/pgpool-II/pool_hba.conf
# 最下面
# IPv4 local connections:
host    all         all         127.0.0.1/32          trust
host    all         all         ::1/128               trust
host    replication    actorcloud    192.168.20.16/24    trust
host    replication    actorcloud    192.168.20.17/24    trust
host    all    all    192.168.20.0/24    md5
host    all    all    0.0.0.0/0    md5
```

对postgres的密码进行加密。本文将postgres的密码设置为和用户名相同，将加密结果复制，并粘贴到pcp.conf中相应的位置，取消掉该行的注释。

```sh
[root@pgsql_master ~]# pg_md5 postgres
e8a48653851e28c69d0506508fb27fc5
[root@pgsql_master ~]# vim /etc/pgpool-II/pcp.conf
postgres:e8a48653851e28c69d0506508fb27fc5
[root@pgsql_master ~]# su - postgres
上一次登录：一 4月 18 14:19:50 CST 2022从 pgsql_masterpts/1 上
-bash-4.2$ pg_md5 -m -p -u postgres pool_passwd
password:
ERROR: pid 1607: initializing pool password, failed to open file:"/etc/pgpool-II/pool_passwd"
```

配置文件需要有postgres的权限，于是：

```sh
[root@pgsql_master ~]# chmod u+x /usr/sbin/ip
[root@pgsql_master ~]# chmod u+s /usr/sbin/arping
[root@pgsql_master ~]# chmod u+s /sbin/ip
[root@pgsql_master ~]# chmod u+s /sbin/ifconfig
[root@pgsql_master ~]# chown -R postgres.postgres /etc/pgpool-II
[root@pgsql_master ~]# mkdir -p /var/log/pgpool/
[root@pgsql_master ~]# touch /var/log/pgpool/pgpool_status
[root@pgsql_master ~]# chown -R postgres.postgres /var/log/pgpool/
```

再次重新尝试

```sh
[root@pgsql_master ~]# su - postgres
上一次登录：一 4月 18 14:19:50 CST 2022从 pgsql_masterpts/1 上
-bash-4.2$ pg_md5 -m -p -u postgres pool_passwd
password: postgres
```
### 7. 集群的配置
```sh
[root@pgsql_master ~]# vim /etc/pgpool-II/pgpool.conf
```

(1)修改监听地址，将localhost改为*，即监听所有地址发来的请求

```sh
修改前：listen_addresses = 'localhost'
修改后：listen_addresses = '*'
```

(2)修改backend相关参数，对应的是PostgreSQ两个节点的相关信息

```sh
修改前：
	backend_hostname0 = 'localhost'                           
	backend_port0 = 5432
	backend_weight0 = 1
	backend_data_directory0 = '/var/lib/pgsql/data'
	backend_flag0 = 'ALLOW_TO_FAILOVER'
修改后：
	backend_hostname0 = '192.168.20.16'
	backend_port0 = 5432
	backend_weight0 = 1
	backend_data_directory0 = '/var/lib/pgsql/10/data'
	backend_flag0 = 'ALLOW_TO_FAILOVER'

    backend_hostname1 = '192.168.20.17'
    backend_port1 = 5432
    backend_weight1 = 1
    backend_data_directory1 = '/var/lib/pgsql/10/data'
    backend_flag1 = 'ALLOW_TO_FAILOVER'
```

(3)pg_hba.conf生效

```sh
修改前：enable_pool_hba = off
修改后：enable_pool_hba = on
```

(4)使负载均衡生效

```sh
修改前：load_balance_mode = off
修改后：load_balance_mode = on
```

(5)主从流复制生效，并配置用于检查的用户，这个用户就用上方创建的用于主从访问的用户

```sh
修改前：
	master_slave_mode = off
	sr_check_period = 0
	sr_check_user = 'nobody'
	sr_check_password = ''
	sr_check_database = 'postgres'
	delay_threshold = 0
修改后：
	master_slave_mode = on
	sr_check_period = 6
	sr_check_user = 'actorcloud'
	sr_check_password = 'public'
	sr_check_database = 'postgres'
	delay_threshold = 10000000
```

(6)健康检查相关配置，并配置用于检查的用户，这个用户就用上方创建的用于主从访问的用户

```sh
修改前：
	health_check_period = 0
	health_check_user = 'nobody'
	health_check_password = ''
	health_check_database = ''
修改后：
	health_check_period = 10
	health_check_user = 'actorcloud'
	health_check_password = 'public'
	health_check_database = 'postgres'
```

(7)配置主机故障触发执行的脚本

```sh
修改前：failover_command = ''
修改后：failover_command = '/var/lib/pgsql/10/failover_stream.sh %d %H'
```

(8)开启开门狗，IP为本机IP

```sh
修改前：
	use_watchdog = off
	wd_hostname = ''
修改后：
	use_watchdog = on
	wd_hostname = '192.168.20.16'
```

(9)开启虚拟IP，并修改网卡信息。启动后直接使用虚拟IP进行数据库操作剧哦,把所有eth0改为了ens33，ens33是该主机的网卡设备名称，可通过命令ip addr查看

```sh
修改前：
	delegate_IP = ''
	if_up_cmd = 'ip addr add $_IP_$/24 dev eth0 label eth0:0'
	if_down_cmd = 'ip addr del $_IP_$/24 dev eth0'
	arping_cmd = 'arping -U $_IP_$ -w 1 -I eth0'
修改后：
	delegate_IP = '192.168.20.50'
	if_up_cmd = 'ip addr add $_IP_$/24 dev ens33 label ens33:0'
	if_down_cmd = 'ip addr del $_IP_$/24 dev ens33'
	arping_cmd = 'arping -U $_IP_$ -w 1 -I ens33'
```

(10)心跳检查的配置与看门狗配置。IP为从节点的IP

```sh
修改前：
	heartbeat_destination0 = 'host0_ip1'
	heartbeat_device0 = ''
	#other_pgpool_hostname0 = 'host0'
	#other_pgpool_port0 = 5432
	#other_wd_port0 = 9000
修改后：
	heartbeat_destination0 = '192.168.20.17'
	heartbeat_device0 = 'ens33'
	other_pgpool_hostname0 = '192.168.20.17'
	other_pgpool_port0 = 9999
	other_wd_port0 = 9000
```

以上，是主节点的配置。对于从节点，只有（8）和（10）的IP需要更改，其他的一致

### 8. 编写故障切换脚本

```sh
[root@pgsql_master ~]# vim /var/lib/pgsql/10/failover_stream.sh
#!/bin/sh
# Failover command for streaming replication.
# Arguments: $1: new master hostname.
failed_node=$1
new_master=$2
trigger_file=$3
# Do nothing if standby goes down.
if [ $failed_node = 1 ]; then
exit 0;
fi
# Create the trigger file.
# use commond
/usr/bin/ssh -T $new_master /usr/pgsql-10/bin/pg_ctl promote -D /var/lib/pgsql/10/data/
# use file
# /usr/bin/ssh -T $new_master  /bin/touch /tmp/trigger_file0
exit 0
[root@pgsql_master ~]# chown postgres:postgres /var/lib/pgsql/10/failover_stream.sh && chmod 777 /var/lib/pgsql/10/failover_stream.sh
[root@pgsql_master ~]# scp /var/lib/pgsql/10/failover_stream.sh 192.168.20.17:/var/lib/pgsql/10/failover_stream.sh
```

### 9. 启动服务(主备都做)

```sh
[root@pgsql_master ~]# systemctl start pgpool.service
[root@pgsql_master ~]# systemctl enable pgpool.service
```

### 10. 验证

登录虚拟ip查看集群节点，以后所有的操作均可通过连接虚拟IP操作数据库

```sh
[root@pgsql_master ~]# psql -h 192.168.20.50 -U postgres -p 5432  # 端口也可以用看门狗端口9999
用户 postgres 的口令：
psql (14.2, 服务器 10.20)
输入 "help" 来获取帮助信息.

postgres=# create database tianxiang;
CREATE DATABASE
postgres=# \l
                                     数据库列表
   名称    |  拥有者  | 字元编码 |  校对规则   |    Ctype    |       存取权限        
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
 template0 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 test      | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
 tianxiang | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
(5 行记录)
```

关闭主节点机器，观察从机器IP信息，会发现VIP会漂移过去，psql集群照常能使用。
