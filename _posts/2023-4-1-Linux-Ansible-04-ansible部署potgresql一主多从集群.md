---
layout: post
title: Linux-Ansible-04-ansible部署potgresql一主多从集群
date: 2023-4-1
tags: Linux-Ansible
music-id: 27731176
---
## 实验环境

| IP       | 端口 | 角色     |
| -------- | ---- | -------- |
| 11.0.1.7 | 5432 | master01 |
| 11.0.1.8 | 5432 | slave01  |
| 11.0.1.9 | 5432 | slave01  |


### 1. 准备以下工作目录

```sh
[root@master01 ansible-postgresql]# ls
group_vars  hosts.ini  install-postgreslq.yml  remove-pgsql.yml  roles

[root@master01 ansible-postgresql]# cat hosts.ini
[all]
master01 ansible_connection=local ip=11.0.1.7
slave01 ansible_host=11.0.1.8 ip=11.0.1.8
slave02 ansible_host=11.0.1.9 ip=11.0.1.9

[postgresql]
master01
slave01
slave02

[postgresql_master]
master01

[postgresql_slave]
slave01
slave02

# 多master高可用, 单master忽略该项
#[ha]
#master01 ha_name=ha-master
#master02 ha_name=ha-backup
#master03 ha_name=ha-backup

[root@master01 ansible-postgresql]# cat remove-pgsql.yml
---
- hosts: postgresql
  gather_facts: false
  tasks:
    - name: 停止服务
      shell: for i in $(ps -ef |grep postgres|grep -v grep|head -n1 |awk '{print $2}');do kill 9 $i;done

    - name: 删除数据
      file:
        path: "{{ data_dir }}"
        state: absent

- hosts: postgresql
  gather_facts: false
  tasks:
    - name: 恢复 hosts 解析
      copy: src=/etc/hosts.bak dest=/etc/hosts
```

### 2. 开始部署

```sh
[root@master01 ansible-postgresql]# ansible-playbook -i hosts.ini install-postgreslq.yml
PLAY RECAP *******************************************************************************************************************************************************************************************************
127.0.0.1                  : ok=8    changed=4    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
master01                   : ok=39   changed=20   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
slave01                    : ok=37   changed=21   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
slave02                    : ok=37   changed=21   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

### 3. 查看各个节点状态

```sh
# 查看slave节点
[root@master01 ~]# su - postgres -c "psql"
psql (9.6.3)
Type "help" for help.

postgres=# select client_addr,sync_state from pg_stat_replication;
 client_addr | sync_state
-------------+------------
 11.0.1.9    | async
 11.0.1.8    | async
(2 rows)

postgres=#

# master01
[root@master01 ansible-postgresql]# ps -ef |grep postgres
postgres  84212      1  0 20:25 ?        00:00:00 /opt/pgsql/bin/postgres -D /opt/pgsql/data
postgres  84215  84212  0 20:25 ?        00:00:00 postgres: checkpointer process   
postgres  84216  84212  0 20:25 ?        00:00:00 postgres: writer process   
postgres  84217  84212  0 20:25 ?        00:00:00 postgres: wal writer process   
postgres  84218  84212  0 20:25 ?        00:00:00 postgres: autovacuum launcher process   
postgres  84219  84212  0 20:25 ?        00:00:00 postgres: archiver process   failed on 000000010000000000000001
postgres  84220  84212  0 20:25 ?        00:00:00 postgres: stats collector process   
postgres  84535  84212  0 20:26 ?        00:00:00 postgres: wal sender process replica 11.0.1.8(4590) streaming 0/8000140
postgres  84536  84212  0 20:26 ?        00:00:00 postgres: wal sender process replica 11.0.1.9(38011) streaming 0/8000140
root      84621  37380  0 20:34 pts/1    00:00:00 grep --color=auto postgres

# slave01
[root@slave01 ~]# ps -ef |grep postgres
postgres  11561      1  0 20:26 ?        00:00:00 /opt/pgsql/bin/postgres -D /opt/pgsql/data
postgres  11563  11561  0 20:26 ?        00:00:00 postgres: startup process   recovering 000000010000000000000008
postgres  11571  11561  0 20:26 ?        00:00:00 postgres: checkpointer process   
postgres  11572  11561  0 20:26 ?        00:00:00 postgres: writer process   
postgres  11573  11561  0 20:26 ?        00:00:00 postgres: stats collector process   
postgres  11574  11561  0 20:26 ?        00:00:00 postgres: wal receiver process   streaming 0/8000140
root      11606 117074  0 20:35 pts/0    00:00:00 grep --color=auto postgres

# slave02
[root@slave02 ~]# ps -ef |grep postgres
postgres  56989      1  0 20:26 ?        00:00:00 /opt/pgsql/bin/postgres -D /opt/pgsql/data
postgres  56991  56989  0 20:26 ?        00:00:00 postgres: startup process   recovering 000000010000000000000008
postgres  56999  56989  0 20:26 ?        00:00:00 postgres: checkpointer process   
postgres  57000  56989  0 20:26 ?        00:00:00 postgres: writer process   
postgres  57001  56989  0 20:26 ?        00:00:00 postgres: stats collector process   
postgres  57002  56989  0 20:26 ?        00:00:00 postgres: wal receiver process   streaming 0/8000060
root      57007  28393  0 20:29 pts/0    00:00:00 grep --color=auto postgres
```

### 4. 验证数据库同步性

#### master01

```sh
[root@master01 ansible-postgresql]# su - postgres -c "psql"
psql (9.6.3)
Type "help" for help.

postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
 template0 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
(3 rows)

postgres=# create database test01;
CREATE DATABASE
postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
 template0 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 test01    | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
(4 rows)

postgres=#
```

#### slave01

```sh
[root@slave01 ~]# su - postgres -c "psql"
psql (9.6.3)
Type "help" for help.

postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
 template0 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 test01    | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
(4 rows)

postgres=#
```

#### slave02

```
[root@slave02 ~]# su - postgres -c "psql"
psql (9.6.3)
Type "help" for help.

postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
 template0 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 test01    | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
(4 rows)

postgres=#
```

### 5. 修改 postgres 密码

为了方便后期使用 pgsql 远程连接数据库，可以修改一下密码

```sh
[root@master01 ~]# su - postgres -c "psql"
psql (9.6.3)
Type "help" for help.

postgres=# alter role postgres with password 'postgres';    # 将密码修改为 postgres
ALTER ROLE
postgres=#
```

验证

```sh
[root@slave02 ~]# psql -h 11.0.1.7 -U postgres -p 5432
Password for user postgres:
psql (9.6.3)
Type "help" for help.

postgres=# \l
                                  List of databases
   Name    |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
-----------+----------+----------+-------------+-------------+-----------------------
 postgres  | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
 template0 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 template1 | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 | =c/postgres          +
           |          |          |             |             | postgres=CTc/postgres
 test01    | postgres | UTF8     | zh_CN.UTF-8 | zh_CN.UTF-8 |
(4 rows)

postgres=#
```

### 7. 其他操作

关于启动

```sh
[root@master01 ~]# su - postgres -c "pg_ctl -D /opt/pgsql/data -l /opt/pgsql/data/logfile start"
[root@master01 ~]# su - postgres -c "pg_ctl -D /opt/pgsql/data -l /opt/pgsql/data/logfile restart"
[root@master01 ~]# su - postgres -c "pg_ctl -D /opt/pgsql/data -l /opt/pgsql/data/logfile stop"
```

创建数据库

```sh
postgres=# create database registry;
```

给数据库赋予密码

```sh
postgres=# create user registry with password '123123';
postgres=# alter role registry with password '123123';
```
