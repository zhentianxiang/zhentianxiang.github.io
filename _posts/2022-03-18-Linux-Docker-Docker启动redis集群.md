---
layout: post
title: Linux-Docker-Docker启动redis 集群
date: 2022-03-18
tags: Linux-Docker
---

## 一、启动主从同步集群

### 1. 启动容器

创建一个自定义网络

```sh
[root@localhost ~]# docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
03e14c59ae8c        bridge              bridge              local
28f1dfad6e98        host                host                local
0323bb35f506        none                null                local
[root@localhost ~]# docker network create --subnet 172.10.0.0/16 redis_net
e93d76ea6f93b3fb65011b8b280f36201e1ffa9f324ba6c8374bf11253cd1c0a
[root@localhost ~]# docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
03e14c59ae8c        bridge              bridge              local
28f1dfad6e98        host                host                local
0323bb35f506        none                null                local
e93d76ea6f93        redis_net           bridge              local
```

启动容器

> --network 指定网络
>
> --ip 指定地址
>
> -d 以守护进程模式运行
>
> -p 将容器的6380端口映射到宿主机的6379端口
>
> --requirepass 设置redis密码
>
> --masterauth 设置连接主服务的密码，需要和requirepass设置一样

```sh
[root@localhost ~]# docker run --network redis_net --ip 172.10.0.2 -d --name redis-master --restart=always -p 6380:6379 hub.tianxiang.com/library/redis:5.0.3.1 --requirepass 1qaz@WSX --masterauth 1qaz@WSX
ad51da59be8f8e00cdc01777aa6ac50011e36097094b9aaa3b54f7e8c6829fd2
[root@localhost ~]# docker run --network redis_net --ip 172.10.0.3 -d --name redis-slave1 --restart=always -p 6381:6379 hub.tianxiang.com/library/redis:5.0.3.1 --requirepass 1qaz@WSX --masterauth 1qaz@WSX
cd366915e6624306f36419aab8e5887aa9347bf62e4e2579a4caead435620c37
[root@localhost ~]# docker run --network redis_net --ip 172.10.0.4 -d --name redis-slave2 --restart=always -p 6382:6379 hub.tianxiang.com/library/redis:5.0.3.1 --requirepass 1qaz@WSX --masterauth 1qaz@WSX
72ae27beb364cb61c9d36f020dfa62c0cc4e3ce03d43b56729cf8b211cc6dc09
[root@localhost ~]# docker ps
CONTAINER ID        IMAGE                                     COMMAND                  CREATED             STATUS              PORTS                    NAMES
72ae27beb364        hub.tianxiang.com/library/redis:5.0.3.1   "docker-entrypoint.s…"   15 seconds ago      Up 14 seconds       0.0.0.0:6382->6379/tcp   redis-slave2
cd366915e662        hub.tianxiang.com/library/redis:5.0.3.1   "docker-entrypoint.s…"   26 seconds ago      Up 25 seconds       0.0.0.0:6381->6379/tcp   redis-slave1
ad51da59be8f        hub.tianxiang.com/library/redis:5.0.3.1   "docker-entrypoint.s…"   43 seconds ago      Up 42 seconds       0.0.0.0:6380->6379/tcp   redis-master
```

### 2. 配置主从集群

首先发现三台全是master角色

```sh
[root@localhost ~]# docker exec -it redis-master redis-cli -a 1qaz@WSX
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
127.0.0.1:6379> info replication
# Replication
role:master
connected_slaves:0
master_replid:85dc62ad28f91cbbb90a6f23bc3076927de3664a
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:0
second_repl_offset:-1
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0
127.0.0.1:6379>
[root@localhost ~]# docker exec -it redis-slave1 redis-cli -a 1qaz@WSX
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
127.0.0.1:6379> info replication
# Replication
role:master
connected_slaves:0
master_replid:315ca3099506e7e9f478c6adeca6b74b679cd93d
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:0
second_repl_offset:-1
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0
127.0.0.1:6379>
[root@localhost ~]# docker exec -it redis-slave2 redis-cli -a 1qaz@WSX
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
127.0.0.1:6379> info replication
# Replication
role:master
connected_slaves:0
master_replid:df351e382416369fb523f15d08e96b50f825eca0
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:0
second_repl_offset:-1
repl_backlog_active:0
repl_backlog_size:1048576
repl_backlog_first_byte_offset:0
repl_backlog_histlen:0
127.0.0.1:6379>
```

进入到slave1和slave2进行配置

```sh
[root@localhost ~]# docker exec -it redis-slave1 bash
root@cd366915e662:/data# ls
root@cd366915e662:/data# redis-cli -a 1qaz@WSX
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
127.0.0.1:6379> SLAVEOF 192.168.20.109 6380      #配置的地址是宿主机地址和映射出来的端口
OK
127.0.0.1:6379> info replication
# Replication
role:slave
master_host:192.168.20.109
master_port:6380
master_link_status:up
master_last_io_seconds_ago:2
master_sync_in_progress:0
slave_repl_offset:14
slave_priority:100
slave_read_only:1
connected_slaves:0
master_replid:8c13a9d708a7e4979d0df03358ae7b87cf42c843
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:14
second_repl_offset:-1
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:14
127.0.0.1:6379>

```

```sh
[root@localhost ~]# docker exec -it redis-slave2 bash
root@72ae27beb364:/data# redis-cli -a 1qaz@WSX
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
127.0.0.1:6379> SLAVEOF 192.168.20.109 6380
OK
127.0.0.1:6379> INFO replication
# Replication
role:slave
master_host:192.168.20.109
master_port:6380
master_link_status:up
master_last_io_seconds_ago:3
master_sync_in_progress:0
slave_repl_offset:140
slave_priority:100
slave_read_only:1
connected_slaves:0
master_replid:8c13a9d708a7e4979d0df03358ae7b87cf42c843
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:140
second_repl_offset:-1
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:127
repl_backlog_histlen:14
127.0.0.1:6379>
```

## 二、 配置sentinel哨兵

### 1. 准备配置文件

> sentinel monior mymaster 192.168.20.109 6380  2 监听名为mymaster（名字随便起）的主服务容器ip为172.10.0.2 端口为6379
>
> daemonize yes 以守护进程方式运行
>
> sentinel auth-pass mymaster <password> 验证主redis密码
>
> sentinel down-after-milliseconds mymaster 10000 超过10秒没有响应认为下线
>
> sentinel failover-timeout mymaster 60000 60秒超
>
>  logfile "/data/log.txt" 日志输出位置

```sh
[root@localhost ~]# mkdir /redis_data/redis -pv && cd /redis_data/redis/
mkdir: 已创建目录 "/redis_data"
mkdir: 已创建目录 "/redis_data/redis"
[root@localhost redis]# vim sentinel1.conf
sentinel monitor mymaster 192.168.20.109 6380  2
daemonize yes
sentinel auth-pass mymaster 1qaz@WSX
sentinel down-after-milliseconds mymaster 10000
logfile "/data/log.txt"
port 26379
[root@localhost redis]# cp sentinel1.conf sentinel2.conf
[root@localhost redis]# cp sentinel1.conf sentinel3.conf
```

### 2. 启动sentinel容器

```sh
[root@localhost redis]# docker run --network redis_net --ip 172.10.0.5 -it --name redis_sentinel1 --restart=always -p 26380:26379 -v /redis_data/redis/sentinel1.conf:/data/sentinel.conf -d hub.tianxiang.com/library/redis:5.0.3.1
ee06f5270c5ad4bdda2f76161ac5be16182c953aa1f8fbbbaeee5bd2b29a3511
[root@localhost redis]# docker run --network redis_net --ip 172.10.0.6 -it --name redis_sentinel2 --restart=always -p 26381:26379 -v /redis_data/redis/sentinel2.conf:/data/sentinel.conf -d hub.tianxiang.com/library/redis:5.0.3.1
4f6cc0fecf3a2a7d499dd0ed3eba15f21b566ca8dd25f168238159bee2adf8b9
[root@localhost redis]# docker run --network redis_net --ip 172.10.0.7 -it --name redis_sentinel3 --restart=always -p 26382:26379 -v /redis_data/redis/sentinel3.conf:/data/sentinel.conf -d hub.tianxiang.com/library/redis:5.0.3.1
188859c531853e5689038fd2cbb427f62ff02ea2ae6802e1bf76d5737e92c95a
[root@localhost redis]# docker ps
CONTAINER ID        IMAGE                                     COMMAND                  CREATED              STATUS              PORTS                                NAMES
188859c53185        hub.tianxiang.com/library/redis:5.0.3.1   "docker-entrypoint.s…"   33 seconds ago       Up 32 seconds       6379/tcp, 0.0.0.0:26382->26379/tcp   redis_sentinel3
4f6cc0fecf3a        hub.tianxiang.com/library/redis:5.0.3.1   "docker-entrypoint.s…"   48 seconds ago       Up 46 seconds       6379/tcp, 0.0.0.0:26381->26379/tcp   redis_sentinel2
ee06f5270c5a        hub.tianxiang.com/library/redis:5.0.3.1   "docker-entrypoint.s…"   About a minute ago   Up About a minute   6379/tcp, 0.0.0.0:26380->26379/tcp   redis_sentinel1
72ae27beb364        hub.tianxiang.com/library/redis:5.0.3.1   "docker-entrypoint.s…"   18 minutes ago       Up 18 minutes       0.0.0.0:6382->6379/tcp               redis-slave2
cd366915e662        hub.tianxiang.com/library/redis:5.0.3.1   "docker-entrypoint.s…"   18 minutes ago       Up 18 minutes       0.0.0.0:6381->6379/tcp               redis-slave1
ad51da59be8f        hub.tianxiang.com/library/redis:5.0.3.1   "docker-entrypoint.s…"   18 minutes ago       Up 18 minutes       0.0.0.0:6380->6379/tcp               redis-master
```

分别进入三个容器启动

```sh
[root@localhost redis]# docker exec -it redis_sentinel1 /bin/bash
redis-sentinel sentinel.conf
[root@localhost redis]# docker exec -it redis_sentinel2 /bin/bash
redis-sentinel sentinel.conf
[root@localhost redis]# docker exec -it redis_sentinel3 /bin/bash
redis-sentinel sentinel.conf
```

### 3. 验证集群

```sh
[root@localhost redis]# yum -y install redis
[root@localhost redis]# redis-cli -p 26381 -a 1qaz@WSX
127.0.0.1:26381> info sentinel
# Sentinel
sentinel_masters:1
sentinel_tilt:0
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:0
master0:name=mymaster,status=ok,address=192.168.20.109:6380,slaves=1,sentinels=3
127.0.0.1:26381>  
```

### 4. redis 官方集群 compose 文件

#### 1. yml 文件

获取文件链接：https://github.com/bitnami/containers/blob/main/bitnami/redis-cluster/docker-compose.yml

```yaml
# 麒麟安装docker版本也必须为 20.10.0-20.10.9
# 麒麟系统中部署7.2版本的需要添加：privileged: true
# docker-compose v2.26.1 版本的可以关闭 version

version: '3'
services:
  redis-node-0:
    image: docker.io/bitnami/redis-cluster:7.2
    volumes:
      - redis-cluster_data-0:/bitnami/redis/data
    environment:
      - 'REDIS_PASSWORD=bitnami'
      - 'REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5'
    ports:
      - "6379:6379"

  redis-node-1:
    image: docker.io/bitnami/redis-cluster:7.2
    volumes:
      - redis-cluster_data-1:/bitnami/redis/data
    environment:
      - 'REDIS_PASSWORD=bitnami'
      - 'REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5'
    ports:
      - "6380:6379"

  redis-node-2:
    image: docker.io/bitnami/redis-cluster:7.2
    volumes:
      - redis-cluster_data-2:/bitnami/redis/data
    environment:
      - 'REDIS_PASSWORD=bitnami'
      - 'REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5'
    ports:
      - "6381:6379"

  redis-node-3:
    image: docker.io/bitnami/redis-cluster:7.2
    volumes:
      - redis-cluster_data-3:/bitnami/redis/data
    environment:
      - 'REDIS_PASSWORD=bitnami'
      - 'REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5'
    ports:
      - "6382:6379"

  redis-node-4:
    image: docker.io/bitnami/redis-cluster:7.2
    volumes:
      - redis-cluster_data-4:/bitnami/redis/data
    environment:
      - 'REDIS_PASSWORD=bitnami'
      - 'REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5'
    ports:
      - "6383:6379"

  redis-node-5:
    image: docker.io/bitnami/redis-cluster:7.2
    volumes:
      - redis-cluster_data-5:/bitnami/redis/data
    depends_on:
      - redis-node-0
      - redis-node-1
      - redis-node-2
      - redis-node-3
      - redis-node-4
    environment:
      - 'REDIS_PASSWORD=bitnami'
      - 'REDISCLI_AUTH=bitnami'
      - 'REDIS_CLUSTER_REPLICAS=1'
      - 'REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5'
      - 'REDIS_CLUSTER_CREATOR=yes'
    ports:
      - "6384:6379"

volumes:
  redis-cluster_data-0:
    driver: local
  redis-cluster_data-1:
    driver: local
  redis-cluster_data-2:
    driver: local
  redis-cluster_data-3:
    driver: local
  redis-cluster_data-4:
    driver: local
  redis-cluster_data-5:
    driver: local
```

#### 2. 启动

```sh
$ docker-compose up -d
[+] Running 6/6
 ✔ Container redis-cluster-redis-node-1-1  Started                                                                                                               4.1s 
 ✔ Container redis-cluster-redis-node-3-1  Started                                                                                                               5.1s 
 ✔ Container redis-cluster-redis-node-4-1  Started                                                                                                               3.8s 
 ✔ Container redis-cluster-redis-node-0-1  Started                                                                                                               5.0s 
 ✔ Container redis-cluster-redis-node-2-1  Started                                                                                                               4.9s 
 ✔ Container redis-cluster-redis-node-5-1  Started                                                                                                              11.8s
$ docker-compose ps
NAME                           IMAGE                                 COMMAND                  SERVICE        CREATED          STATUS          PORTS
redis-cluster-redis-node-0-1   docker.io/bitnami/redis-cluster:7.2   "/opt/bitnami/script…"   redis-node-0   10 minutes ago   Up 10 minutes   0.0.0.0:6379->6379/tcp, :::6379->6379/tcp
redis-cluster-redis-node-1-1   docker.io/bitnami/redis-cluster:7.2   "/opt/bitnami/script…"   redis-node-1   10 minutes ago   Up 10 minutes   0.0.0.0:6380->6379/tcp, :::6380->6379/tcp
redis-cluster-redis-node-2-1   docker.io/bitnami/redis-cluster:7.2   "/opt/bitnami/script…"   redis-node-2   10 minutes ago   Up 10 minutes   0.0.0.0:6381->6379/tcp, :::6381->6379/tcp
redis-cluster-redis-node-3-1   docker.io/bitnami/redis-cluster:7.2   "/opt/bitnami/script…"   redis-node-3   10 minutes ago   Up 10 minutes   0.0.0.0:6382->6379/tcp, :::6382->6379/tcp
redis-cluster-redis-node-4-1   docker.io/bitnami/redis-cluster:7.2   "/opt/bitnami/script…"   redis-node-4   10 minutes ago   Up 10 minutes   0.0.0.0:6383->6379/tcp, :::6383->6379/tcp
redis-cluster-redis-node-5-1   docker.io/bitnami/redis-cluster:7.2   "/opt/bitnami/script…"   redis-node-5   10 minutes ago   Up 10 minutes   0.0.0.0:6384->6379/tcp, :::6384->6379/tcp
```

#### 3. 验证功能性

```sh
$ docker exec -it redis-cluster-redis-node-0-1 redis-cli -c -a bitnami cluster info 
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:6
cluster_my_epoch:1
cluster_stats_messages_ping_sent:808
cluster_stats_messages_pong_sent:840
cluster_stats_messages_sent:1648
cluster_stats_messages_ping_received:840
cluster_stats_messages_pong_received:808
cluster_stats_messages_received:1648
total_cluster_links_buffer_limit_exceeded:0
$ docker exec -it redis-cluster-redis-node-0-1 redis-cli -c -a bitnami cluster nodes
586ceef1f3c10402caa6c44f74ea7dae2d5e69fa 172.21.0.4:6379@16379 myself,master - 0 1715652372000 1 connected 0-5460
1c28b8ea52764a60a3e21604de60e5f88fa5b8cf 172.21.0.7:6379@16379 slave aceb415adf27059a4d4a09635be115174d76eb84 0 1715652373000 2 connected
d654b794102b62107fd35079d19447d0bb60cc16 172.21.0.5:6379@16379 master - 0 1715652374870 3 connected 10923-16383
2fb2571319a930fbb2538168ce828cd894b32028 172.21.0.3:6379@16379 slave d654b794102b62107fd35079d19447d0bb60cc16 0 1715652370000 3 connected
3b63907f36672ddc87dc43ae5065ce2000ccaa1b 172.21.0.2:6379@16379 slave 586ceef1f3c10402caa6c44f74ea7dae2d5e69fa 0 1715652373864 1 connected
aceb415adf27059a4d4a09635be115174d76eb84 172.21.0.6:6379@16379 master - 0 1715652372000 2 connected 5461-10922

# 写入测试
$ docker exec -it redis-cluster-redis-node-0-1 redis-cli -c -a bitnami set test "hello world"
$ docker exec -it redis-cluster-redis-node-0-1 redis-cli -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
$ docker exec -it redis-cluster-redis-node-5-1 redis-cli -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
```
