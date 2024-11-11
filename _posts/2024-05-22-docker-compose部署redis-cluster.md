---
layout: post
title: 2024-05-22-docker-compose部署redis-cluster集群
date: 2024-05-22
tags: Linux-Docker
music-id: 1481323654
---

### 1. yml 文件

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
    restart: unless-stopped

  redis-node-1:
    image: docker.io/bitnami/redis-cluster:7.2
    volumes:
      - redis-cluster_data-1:/bitnami/redis/data
    environment:
      - 'REDIS_PASSWORD=bitnami'
      - 'REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5'
    ports:
      - "6380:6379"
    restart: unless-stopped

  redis-node-2:
    image: docker.io/bitnami/redis-cluster:7.2
    volumes:
      - redis-cluster_data-2:/bitnami/redis/data
    environment:
      - 'REDIS_PASSWORD=bitnami'
      - 'REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5'
    ports:
      - "6381:6379"
    restart: unless-stopped

  redis-node-3:
    image: docker.io/bitnami/redis-cluster:7.2
    volumes:
      - redis-cluster_data-3:/bitnami/redis/data
    environment:
      - 'REDIS_PASSWORD=bitnami'
      - 'REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5'
    ports:
      - "6382:6379"
    restart: unless-stopped

  redis-node-4:
    image: docker.io/bitnami/redis-cluster:7.2
    volumes:
      - redis-cluster_data-4:/bitnami/redis/data
    environment:
      - 'REDIS_PASSWORD=bitnami'
      - 'REDIS_NODES=redis-node-0 redis-node-1 redis-node-2 redis-node-3 redis-node-4 redis-node-5'
    ports:
      - "6383:6379"
    restart: unless-stopped

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
    restart: unless-stopped

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

### 2. 启动

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

### 3. 验证功能性

#### 1. 集群状态信息

随便进入一个容器查看集群信息

```sh
$ docker exec -it redis-cluster-redis-node-0-1 bash
I have no name!@517f09cfb86b:/$ redis-cli -c -a bitnami
127.0.0.1:6379> cluster info
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
```

- `cluster_state:ok`：集群状态是 `ok`，表示集群正在正常运行。
- `cluster_slots_assigned:16384`：集群中已分配的槽位总数是 16384，这是 Redis 集群能够管理的最大键空间。
- `cluster_slots_ok:16384`：集群中工作正常的槽位数量是 16384，表示所有槽位都已正确分配给集群中的节点，并且它们都是可访问的。
- `cluster_slots_pfail:0`：可能失败的槽位数量是 0，这通常表示没有节点报告其他节点为疑似失败（PFAIL）。
- `cluster_slots_fail:0`：失败的槽位数量是 0，这表示没有槽位因为节点失败而不可用。
- `cluster_known_nodes:6`：集群中已知的节点数量是 6，这表示集群能够识别到 6 个 Redis 节点。
- `cluster_size:3`：集群的大小是 3，这通常表示集群中有 3 个主节点（因为每个主节点都管理一部分槽位）。
- `cluster_current_epoch:6`：当前集群的纪元（epoch）是 6，纪元是集群配置更改的计数器。
- `cluster_my_epoch:1`：当前节点（您正在查询的节点）的纪元是 1，这表示该节点最后一次看到配置更改的纪元。

```sh
127.0.0.1:6379> cluster nodes
586ceef1f3c10402caa6c44f74ea7dae2d5e69fa 172.21.0.4:6379@16379 myself,master - 0 1715652372000 1 connected 0-5460
1c28b8ea52764a60a3e21604de60e5f88fa5b8cf 172.21.0.7:6379@16379 slave aceb415adf27059a4d4a09635be115174d76eb84 0 1715652373000 2 connected
d654b794102b62107fd35079d19447d0bb60cc16 172.21.0.5:6379@16379 master - 0 1715652374870 3 connected 10923-16383
2fb2571319a930fbb2538168ce828cd894b32028 172.21.0.3:6379@16379 slave d654b794102b62107fd35079d19447d0bb60cc16 0 1715652370000 3 connected
3b63907f36672ddc87dc43ae5065ce2000ccaa1b 172.21.0.2:6379@16379 slave 586ceef1f3c10402caa6c44f74ea7dae2d5e69fa 0 1715652373864 1 connected
aceb415adf27059a4d4a09635be115174d76eb84 172.21.0.6:6379@16379 master - 0 1715652372000 2 connected 5461-10922
```

1. 节点ID
   - 例如 `586ceef1f3c10402caa6c44f74ea7dae2d5e69fa`，每个 Redis 节点都有一个唯一的 ID。
2. IP地址和端口
   - 例如 `172.21.0.4:6379@16379`，这表示节点的 IP 地址是 `172.21.0.4`，主端口是 `6379`，并且集群端口（用于集群通信）是 `16379`。
3. 节点角色
   - `myself,master`：表示这是您当前连接的节点，并且它是一个主节点。
   - `slave`：表示这是一个从节点（即副本节点），它复制一个主节点的数据。
4. 标志和状态
   - `- 0`：表示节点目前没有故障，并且没有执行重新配置（reconfiguration）操作。
   - `connected`：表示节点已经连接到集群并且是可用的。
5. 负责的槽位
   - 例如 `connected 0-5460`，这表示该主节点负责管理从槽位 0 到 5460 的键。Redis 集群使用 16384 个槽位来分布数据。
6. 复制关系
   - 从节点会显示它们正在复制哪个主节点（例如 `slave of aceb415adf27059a4d4a09635be115174d76eb84`）。

从您提供的输出中，我们可以看到：

- 集群中有 3 个主节点和 3 个从节点。
- `586ceef1f3c10402caa6c44f74ea7dae2d5e69fa` 是主节点，负责管理槽位 0-5460。
- `aceb415adf27059a4d4a09635be115174d76eb84` 是另一个主节点，负责管理槽位 5461-10922。
- `d654b794102b62107fd35079d19447d0bb60cc16` 是第三个主节点，负责管理剩余的槽位 10923-16383。
- 每个主节点都有一个从节点进行复制。

#### 2. 写入测试

```sh
127.0.0.1:6379> set test 'hello world'
-> Redirected to slot [6918] located at 172.21.0.6:6379
OK
172.21.0.6:6379> get test
"hello world"
```

换节点查看数据是否同步

```sh
$ docker exec -it redis-cluster-redis-node-0-1 redis-cli -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
$ docker exec -it redis-cluster-redis-node-1-1 redis-cli -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
$ docker exec -it redis-cluster-redis-node-2-1 redis-cli -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
$ docker exec -it redis-cluster-redis-node-3-1 redis-cli -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
$ docker exec -it redis-cluster-redis-node-4-1 redis-cli -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
$ docker exec -it redis-cluster-redis-node-5-1 redis-cli -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
```

测试端口功能是否正常

```sh
# 先安装一下 redis 以便获取 redis-cli 命令
$ apt -y install redis

$ redis-cli -h 192.168.1.99 -p 6379 -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
$ redis-cli -h 192.168.1.99 -p 6380 -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
$ redis-cli -h 192.168.1.99 -p 6381 -c -a bitnami get test
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
"hello world"
```









###
