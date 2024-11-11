---
layout: post
title: 2024-05-21-docker-compose部署kafka集群
date: 2024-05-21
tags: Linux-Docker
music-id: 2051548110
---

### 1. 单节点部署

```sh
services:
  kafka:
    container_name: kafka
    image: 'bitnami/kafka:3.5'
    ports:
      - '19092:9092'
      - '19093:9093'
    environment:
      - 'KAFKA_ENABLE_KRAFT=yes'
      - 'KAFKA_CFG_NODE_ID=1'
      - 'KAFKA_CFG_PROCESS_ROLES=controller,broker'
      - 'KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093'
      - 'KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://192.168.1.99:19092'
      - 'KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT'
      - 'KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@kafka:9093'
      - 'KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER'
      - 'KAFKA_HEAP_OPTS=-Xmx512M -Xms256M'
      - 'KAFKA_KRAFT_CLUSTER_ID=xYcCyHmJlIaLzLoBzVwIcP'
      - 'ALLOW_PLAINTEXT_LISTENER=yes'
      - 'KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=false'
      - 'KAFKA_BROKER_ID=1'
     volumes:
       - kafka_data:/bitnami/kafka
     restart: always


volumes:
  kafka_data:
    driver: local
```

```sh
$ docker-compose up -d
```

### 2. 集群部署

```sh
services:  
  kafka1:  
    container_name: kafka1  
    image: bitnami/kafka:3.5  
    ports:  
      - 19092:9092  
      - 19093:9093  
    environment:  
      # 允许使用kraft，即Kafka替代Zookeeper
      - KAFKA_ENABLE_KRAFT=yes  
      - KAFKA_CFG_NODE_ID=1  
      # kafka角色，做broker，也要做controller
      - KAFKA_CFG_PROCESS_ROLES=controller,broker
      # 定义kafka服务端socket监听端口（此处表示的Docker内部的ip地址和端口）
      - KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093  
      # 定义外网访问地址（宿主机ip地址和端口）ip不能是0.0.0.0
      - KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://192.168.1.99:19092  
      # 定义安全协议
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT  
      # 集群地址
      - KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@kafka1:9093,2@kafka2:9093,3@kafka3:9093
      # 指定供外部使用的控制类请求信息
      - KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER  
      # 设置broker最大内存，和初始内存
      - KAFKA_HEAP_OPTS=-Xmx512M -Xms256M  
      # 使用Kafka时的集群id，集群内的Kafka都要用这个id做初始化，生成一个UUID即可(22byte)
      - KAFKA_KRAFT_CLUSTER_ID=xYcCyHmJlIaLzLoBzVwIcP  
      # 允许使用PLAINTEXT监听器，默认false，不建议在生产环境使用
      - ALLOW_PLAINTEXT_LISTENER=yes  
      # 不允许自动创建主题
      - KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=false  
      # broker.id，必须唯一，且与KAFKA_CFG_NODE_ID一致
      - KAFKA_BROKER_ID=1
    volumes:  
      - kafka_1_data:/bitnami/kafka
    restart: always

  kafka2:
    container_name: kafka2
    image: bitnami/kafka:3.5
    ports:
      - 29092:9092
      - 29093:9093
    environment:
      - KAFKA_ENABLE_KRAFT=yes
      - KAFKA_CFG_NODE_ID=2
      - KAFKA_CFG_PROCESS_ROLES=controller,broker
      - KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093
      - KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://192.168.1.99:29092
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      - KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@kafka1:9093,2@kafka2:9093,3@kafka3:9093
      - KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER
      - KAFKA_HEAP_OPTS=-Xmx512M -Xms256M
      - KAFKA_KRAFT_CLUSTER_ID=xYcCyHmJlIaLzLoBzVwIcP
      - ALLOW_PLAINTEXT_LISTENER=yes
      - KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=false
      - KAFKA_BROKER_ID=2
    volumes:
      - kafka_2_data:/bitnami/kafka
    restart: always

  kafka3:
    container_name: kafka3
    image: bitnami/kafka:3.5
    ports:
      - 39092:9092
      - 39093:9093
    environment:
      - KAFKA_ENABLE_KRAFT=yes
      - KAFKA_CFG_NODE_ID=3
      - KAFKA_CFG_PROCESS_ROLES=controller,broker
      - KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093
      - KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://192.168.1.99:39092
      - KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
      - KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@kafka1:9093,2@kafka2:9093,3@kafka3:9093
      - KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER
      - KAFKA_HEAP_OPTS=-Xmx512M -Xms256M
      - KAFKA_KRAFT_CLUSTER_ID=xYcCyHmJlIaLzLoBzVwIcP
      - ALLOW_PLAINTEXT_LISTENER=yes
      - KAFKA_CFG_AUTO_CREATE_TOPICS_ENABLE=false
      - KAFKA_BROKER_ID=3
    volumes:
      - kafka_3_data:/bitnami/kafka
    restart: always
  
  
volumes:
  kafka_1_data:
    driver: local
  kafka_2_data:
    driver: local
  kafka_3_data:
    driver: local
```

```sh
$ docker-compose up -d
```

### 3. Kafka可视化页面

```sh
services:
  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    ports:
    - 8080:8080
    environment:
    - TZ=Asia/Shanghai
    # 集群名称
    - KAFKA_CLUSTERS_0_NAME=local
    # 集群地址
    - KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=kafka1:9092,kafka2:9092,kafka3:9092
    networks:
    - kafka-cluster_default
    restart: always

# 因为要与 kafka 集群通信，所以要用 kafka 集群的网络
networks:
  kafka-cluster_default:
    external: true
```

```sh
$ docker-compose up -d
```

### 4. 验证

```sh
$ docker ps |grep kafka
840cd7f00082   provectuslabs/kafka-ui:latest              "/bin/sh -c 'java $J…"   3 minutes ago    Up 3 minutes    0.0.0.0:8080->8080/tcp, :::8080->8080/tcp                                                  kafka-ui
c9eeee874f12   bitnami/kafka:3.5                          "/opt/bitnami/script…"   19 minutes ago   Up 19 minutes   0.0.0.0:39092->9092/tcp, :::39092->9092/tcp, 0.0.0.0:39093->9093/tcp, :::39093->9093/tcp   kafka3
e6294604ba7a   bitnami/kafka:3.5                          "/opt/bitnami/script…"   19 minutes ago   Up 19 minutes   0.0.0.0:29092->9092/tcp, :::29092->9092/tcp, 0.0.0.0:29093->9093/tcp, :::29093->9093/tcp   kafka2
e816a386e974   bitnami/kafka:3.5                          "/opt/bitnami/script…"   19 minutes ago   Up 19 minutes   0.0.0.0:19092->9092/tcp, :::19092->9092/tcp, 0.0.0.0:19093->9093/tcp, :::19093->9093/tcp   kafka1
```

随意进入一个容器，创建一个demo

```sh
I have no name!@e816a386e974:/$ docker exec -it kafka1 bash

# 创建 demo
kafka-topics.sh --create --topic demo --partitions 3 --replication-factor 3 --bootstrap-server kafka1:9092,kafka2:9092,kafka3:9092
Created topic demo.

# 查看主题
I have no name!@e816a386e974:/$ kafka-topics.sh --bootstrap-server kafka1:9092 --list
demo

# 生产一些消息
I have no name!@e816a386e974:/$ kafka-console-producer.sh --bootstrap-server kafka1:9092 --topic demo
>hello world!!!!!
>hello world!!!!!
```

