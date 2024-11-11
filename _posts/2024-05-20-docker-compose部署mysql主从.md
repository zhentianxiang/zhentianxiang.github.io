---
layout: post
title: 2024-05-20-docker-compose部署mysql主从
date: 2024-05-20
tags: Linux-Docker
music-id: 21274655
---

### 1. compose 文件

```yaml
services:
  mysql-slave-lb:
    image: nginx:latest
    container_name: mysql-slave-lb
    ports:
    - 3307:3307
    volumes:
    - ./nginx-lb/nginx.conf:/etc/nginx/nginx.conf
    networks:
    - mysql
    depends_on:
    - mysql-master
    - mysql-slave1
    - mysql-slave2
  mysql-master:
    image: mysql:8.0
    container_name: mysql-master
    environment:
      MYSQL_ROOT_PASSWORD: "123456"
      MASTER_SYNC_USER: "sync_admin" #设置脚本中定义的用于同步的账号
      MASTER_SYNC_PASSWORD: "123456" #设置脚本中定义的用于同步的密码
      ADMIN_USER: "root" #当前容器用于拥有创建账号功能的数据库账号
      ADMIN_PASSWORD: "123456"
      ALLOW_HOST: "10.10.%.%" #允许同步账号的host地址
      TZ: "Asia/Shanghai" #解决时区问题
    ports:
    - 3306:3306
    networks:
      mysql:
        ipv4_address: "10.10.10.10" #固定ip，因为从库在连接master的时候，需要设置host
    volumes:
    - ./init/master:/docker-entrypoint-initdb.d #挂载master脚本
    - mysql-master-data:/var/lib/mysql
    command:
    -  "--server-id=1"
    -  "--character-set-server=utf8mb4"
    -  "--collation-server=utf8mb4_unicode_ci"
    -  "--log-bin=mysql-bin"
    -  "--sync_binlog=1"
    restart: unless-stopped
  mysql-slave1:
    image: mysql:8.0
    container_name: mysql-slave1
    environment:
      MYSQL_ROOT_PASSWORD: "123456"
      SLAVE_SYNC_USER: "sync_admin" #用于同步的账号，由master创建
      SLAVE_SYNC_PASSWORD: "123456"
      ADMIN_USER: "root"
      ADMIN_PASSWORD: "123456"
      MASTER_HOST: "10.10.10.10" #master地址，开启主从同步需要连接master
      TZ: "Asia/Shanghai" #设置时区
    networks:
     mysql:
       ipv4_address: "10.10.10.20" #固定ip
    volumes:
    - ./init/slave1:/docker-entrypoint-initdb.d #挂载slave脚本
    - mysql-slave1-data:/var/lib/mysql
    command:
    -  "--server-id=2"
    -  "--character-set-server=utf8mb4"
    -  "--collation-server=utf8mb4_unicode_ci"
    depends_on:
    - mysql-master
    restart: unless-stopped
  mysql-slave2:
    image: mysql:8.0
    container_name: mysql-slave2
    environment:
      MYSQL_ROOT_PASSWORD: "123456"
      SLAVE_SYNC_USER: "sync_admin"
      SLAVE_SYNC_PASSWORD: "123456"
      ADMIN_USER: "root"
      ADMIN_PASSWORD: "123456"
      MASTER_HOST: "10.10.10.10"
      TZ: "Asia/Shanghai"
    networks:
      mysql:
        ipv4_address: "10.10.10.30" #固定ip
    volumes:
    - ./init/slave2:/docker-entrypoint-initdb.d #挂载slave脚本
    - mysql-slave2-data:/var/lib/mysql
    command: #这里需要修改server-id，保证每个mysql容器的server-id都不一样
    -  "--server-id=3"
    -  "--character-set-server=utf8mb4"
    -  "--collation-server=utf8mb4_unicode_ci"
    depends_on:
    - mysql-master
    restart: unless-stopped

volumes:
  mysql-master-data:
  mysql-slave1-data:
  mysql-slave2-data:

networks:
  mysql:
    driver: bridge
    ipam:
      driver: default
      config:
      - subnet: "10.10.0.0/16"
```

不使用自定义 network 和固定的 IP 地址

```yaml
services:
  mysql-slave-lb:
    image: nginx:latest
    container_name: mysql-slave-lb
    ports:
    - 3307:3307
    volumes:
    - ./nginx-lb/nginx.conf:/etc/nginx/nginx.conf
    depends_on:
    - mysql-master
    - mysql-slave1
    - mysql-slave2
  mysql-master:
    image: mysql:8.0
    container_name: mysql-master
    environment:
      MYSQL_ROOT_PASSWORD: "123456"
      MASTER_SYNC_USER: "sync_admin" #设置脚本中定义的用于同步的账号
      MASTER_SYNC_PASSWORD: "123456" #设置脚本中定义的用于同步的密码
      ADMIN_USER: "root" #当前容器用于拥有创建账号功能的数据库账号
      ADMIN_PASSWORD: "123456"
      ALLOW_HOST: "%" #允许同步账号的host地址
      TZ: "Asia/Shanghai" #解决时区问题
    ports:
    - 3306:3306
    volumes:
    - ./init/master:/docker-entrypoint-initdb.d #挂载master脚本
    - mysql-master-data:/var/lib/mysql
    command:
    -  "--server-id=1"
    -  "--character-set-server=utf8mb4"
    -  "--collation-server=utf8mb4_unicode_ci"
    -  "--log-bin=mysql-bin"
    -  "--sync_binlog=1"
    restart: unless-stopped
  mysql-slave1:
    image: mysql:8.0
    container_name: mysql-slave1
    environment:
      MYSQL_ROOT_PASSWORD: "123456"
      SLAVE_SYNC_USER: "sync_admin" #用于同步的账号，由master创建
      SLAVE_SYNC_PASSWORD: "123456"
      ADMIN_USER: "root"
      ADMIN_PASSWORD: "123456"
      MASTER_HOST: "mysql-master" #master地址，开启主从同步需要连接master
      TZ: "Asia/Shanghai" #设置时区
    volumes:
    - ./init/slave1:/docker-entrypoint-initdb.d #挂载slave脚本
    - mysql-slave1-data:/var/lib/mysql
    command:
    -  "--server-id=2"
    -  "--character-set-server=utf8mb4"
    -  "--collation-server=utf8mb4_unicode_ci"
    depends_on:
    - mysql-master
    restart: unless-stopped
  mysql-slave2:
    image: mysql:8.0
    container_name: mysql-slave2
    environment:
      MYSQL_ROOT_PASSWORD: "123456"
      SLAVE_SYNC_USER: "sync_admin"
      SLAVE_SYNC_PASSWORD: "123456"
      ADMIN_USER: "root"
      ADMIN_PASSWORD: "123456"
      MASTER_HOST: "mysql-master"
      TZ: "Asia/Shanghai"
    volumes:
    - ./init/slave2:/docker-entrypoint-initdb.d #挂载slave脚本
    - mysql-slave2-data:/var/lib/mysql
    command: #这里需要修改server-id，保证每个mysql容器的server-id都不一样
    -  "--server-id=3"
    -  "--character-set-server=utf8mb4"
    -  "--collation-server=utf8mb4_unicode_ci"
    depends_on:
    - mysql-master
    restart: unless-stopped

volumes:
  mysql-master-data:
  mysql-slave1-data:
  mysql-slave2-data:
```

### 2. 准备初始化脚本

- master 脚本

```sh
$ cat init/master/create_sync_user.sh
#!/bin/bash
#定义用于同步的用户名
MASTER_SYNC_USER=${MASTER_SYNC_USER:-sync_admin}
#定义用于同步的用户密码
MASTER_SYNC_PASSWORD=${MASTER_SYNC_PASSWORD:-123456}
#定义用于登录mysql的用户名
ADMIN_USER=${ADMIN_USER:-root}
#定义用于登录mysql的用户密码
ADMIN_PASSWORD=${ADMIN_PASSWORD:-123456}
#定义运行登录的host地址
ALLOW_HOST=${ALLOW_HOST:-%}
#定义创建账号的sql语句
CREATE_USER_SQL="CREATE USER '$MASTER_SYNC_USER'@'$ALLOW_HOST' IDENTIFIED BY '$MASTER_SYNC_PASSWORD';"
#定义赋予同步账号权限的sql,这里设置两个权限，REPLICATION SLAVE，属于从节点副本的权限，REPLICATION CLIENT是副本客户端的权限，可以执行show master status语句
GRANT_PRIVILEGES_SQL="GRANT REPLICATION SLAVE,REPLICATION CLIENT ON *.* TO '$MASTER_SYNC_USER'@'$ALLOW_HOST';"
#定义刷新权限的sql
FLUSH_PRIVILEGES_SQL="FLUSH PRIVILEGES;"
#执行sql
mysql -u"$ADMIN_USER" -p"$ADMIN_PASSWORD" -e "$CREATE_USER_SQL $GRANT_PRIVILEGES_SQL $FLUSH_PRIVILEGES_SQL"
echo -e "\033[1;36mMySQL Master 节点授权从节点允许同步已完成!!!\033[0m"
```

- slave 脚本

```sh
$ cat init/slave1/slave.sh
#!/bin/bash
#定义连接master进行同步的账号
SLAVE_SYNC_USER="${SLAVE_SYNC_USER:-sync_admin}"
#定义连接master进行同步的账号密码
SLAVE_SYNC_PASSWORD="${SLAVE_SYNC_PASSWORD:-123456}"
#定义slave数据库账号
ADMIN_USER="${ADMIN_USER:-root}"
#定义slave数据库密码
ADMIN_PASSWORD="${ADMIN_PASSWORD:-123456}"
#定义连接master数据库host地址
MASTER_HOST="${MASTER_HOST:-%}"
#等待10s，保证master数据库启动成功，不然会连接失败
sleep 60
#连接master数据库，查询二进制数据，并解析出logfile和pos，这里同步用户要开启 REPLICATION CLIENT权限，才能使用SHOW MASTER STATUS;
RESULT=`mysql -u"$SLAVE_SYNC_USER" -h$MASTER_HOST -p"$SLAVE_SYNC_PASSWORD" -e "SHOW MASTER STATUS;" | grep -v grep |tail -n +2| awk '{print $1,$2}'`
#解析出logfile
LOG_FILE_NAME=`echo $RESULT | grep -v grep | awk '{print $1}'`
#解析出pos
LOG_FILE_POS=`echo $RESULT | grep -v grep | awk '{print $2}'`
#设置连接master的同步相关信息
SYNC_SQL="change master to master_host='$MASTER_HOST',master_user='$SLAVE_SYNC_USER',master_password='$SLAVE_SYNC_PASSWORD',master_log_file='$LOG_FILE_NAME',master_log_pos=$LOG_FILE_POS;"
#开启同步
START_SYNC_SQL="start slave;"
#查看同步状态
STATUS_SQL="show slave status\G;"
mysql -u"$ADMIN_USER" -p"$ADMIN_PASSWORD" -e "$SYNC_SQL $START_SYNC_SQL $STATUS_SQL"
echo -e "\033[1;36mMySQL replication is running normally!!!\033[0m"
```

- nginx 配置文件

```sh
$ cat nginx-lb/nginx.conf
user  nginx;
worker_processes  auto;

# 将错误日志输出到标准错误
error_log  /dev/stderr warn;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

# 添加stream模块，实现tcp反向代理
stream {
    log_format main '$remote_addr [$time_local] '
                     '$protocol $status $bytes_sent $bytes_received '
                     '$session_time "$upstream_addr" '
                     '"$upstream_bytes_sent" "$upstream_bytes_received" "$upstream_connect_time"';

    # 将访问日志输出到标准输出
    access_log  /dev/stdout main;

    # 请注意我这里用的是容器名称通信的
    upstream mysql-slave-cluster {
        server mysql-slave1:3306 weight=1 max_fails=3 fail_timeout=30s;
        server mysql-slave2:3306 weight=1 backup max_fails=3 fail_timeout=30s;
    }

    server {
        listen  0.0.0.0:3307;
        proxy_connect_timeout 1s;
        proxy_timeout 30m;
        proxy_pass mysql-slave-cluster;
    }
}
```

目录结构如下：

```sh
$ tree
.
├── docker-compose.yml
├── init
│   ├── master
│   │   └── create_sync_user.sh
│   ├── slave1
│   │   └── slave.sh
│   └── slave2
│       └── slave.sh
├── nginx-lb
│   └── nginx.conf
└── slave.sh

5 directories, 6 files
```

### 3. 启动容器

```sh
$ docker-compose up -d
[+] Running 8/8
 ✔ Network mysql-cluster_mysql               Created                                                                                                                 0.2s
 ✔ Volume "mysql-cluster_mysql-slave2-data"  Created                                                                                                                 0.1s
 ✔ Volume "mysql-cluster_mysql-master-data"  Created                                                                                                                 0.1s
 ✔ Volume "mysql-cluster_mysql-slave1-data"  Created                                                                                                                 0.1s
 ✔ Container mysql-master                    Started                                                                                                                 0.8s
 ✔ Container mysql-slave1                    Started                                                                                                                 0.7s
 ✔ Container mysql-slave2                    Started                                                                                                                 0.7s
 ✔ Container mysql-slave-lb                  Started                                                                                                                 0.6s
```

查看日志

```sh
# 大约 5 分钟左右看到这个提示就说明主从启动成功了
$ docker-compose logs -f
mysql-slave1    |            Master_SSL_Crlpath:
mysql-slave1    |            Retrieved_Gtid_Set:
mysql-slave1    |             Executed_Gtid_Set:
mysql-slave1    |                 Auto_Position: 0
mysql-slave1    |          Replicate_Rewrite_DB:
mysql-slave1    |                  Channel_Name:
mysql-slave1    |            Master_TLS_Version:
mysql-slave1    |        Master_public_key_path:
mysql-slave1    |         Get_master_public_key: 0
mysql-slave1    |             Network_Namespace:
mysql-slave1    | MySQL replication is running normally!!!

mysql-slave2    |             Executed_Gtid_Set:
mysql-slave2    |                 Auto_Position: 0
mysql-slave2    |          Replicate_Rewrite_DB:
mysql-slave2    |                  Channel_Name:
mysql-slave2    |            Master_TLS_Version:
mysql-slave2    |        Master_public_key_path:
mysql-slave2    |         Get_master_public_key: 0
mysql-slave2    |             Network_Namespace:
mysql-slave2    | MySQL replication is running normally!!!
```

### 4. 测试主从数据同步

#### 实例一

登录到 master 实例创建一个数据库

```sh
$ docker exec -it mysql-master mysql -uroot -p123456
```

```mysql
mysql> create database tianxiang;
Query OK, 1 row affected (0.12 sec)

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
| tianxiang          |
+--------------------+
5 rows in set (0.00 sec)
```

进入数据库

```mysql
mysql> use tianxiang;
Database changed
```

创建一个表；假设您想创建一个名为 `students` 的表，其中有两个字段：`id` 和 `name`

```mysql
mysql> CREATE TABLE students (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255) NOT NULL);
Query OK, 0 rows affected (0.47 sec)
```

插入数据；使用 `INSERT INTO` 语句向 `students` 表中插入数据

```mysql
mysql> INSERT INTO students (name) VALUES ('zhangsan');
mysql> INSERT INTO students (name) VALUES ('lisi');
```

查询数据

```mysql
mysql> SELECT * FROM students;
+----+----------+
| id | name     |
+----+----------+
|  1 | zhangsan |
|  2 | lisi     |
+----+----------+
3 rows in set (0.00 sec)
```

登录到从数据库看数据是否同步

```sh
$ docker exec -it mysql-slave1 mysql -uroot -p123456
```

查看数据库是否存在

```sh
mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| mysql              |
| performance_schema |
| sys                |
| tianxiang          |
+--------------------+
5 rows in set (0.01 sec)
```

进入 tianxiang 库

```mysql
mysql> use tianxiang;
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
```

查询`students`表数据

```mysql
mysql> SELECT * FROM students;
+----+----------+
| id | name     |
+----+----------+
|  1 | zhangsan |
|  2 | lisi     |
+----+----------+
3 rows in set (0.00 sec)
```

#### 实例二、

创建数据库和用户的步骤
登录到 MySQL：
首先，使用具有足够权限的用户（如 root）登录到 MySQL。

```sh
mysql -u root -p
输入密码后，你将进入 MySQL 命令行界面。
```

创建数据库：
使用 CREATE DATABASE 命令创建名为 nextcloud 的数据库。
```sh
CREATE DATABASE nextcloud;
```

创建用户：
使用 CREATE USER 命令创建名为 nextcloud，密码为 nextcloud 的用户，并允许该用户从任意主机登录。
```sh
CREATE USER 'nextcloud'@'%' IDENTIFIED BY 'nextcloud';
这里 % 表示允许从任意主机登录。
```

授予权限：
使用 GRANT 命令为 nextcloud 用户授予 nextcloud 数据库的全部权限。
```sh
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'%';
刷新权限：
在 MySQL 中修改权限后，需要刷新权限以使更改生效。
FLUSH PRIVILEGES;
```

查看用户
```sh
SELECT User, Host FROM mysql.user;
```
