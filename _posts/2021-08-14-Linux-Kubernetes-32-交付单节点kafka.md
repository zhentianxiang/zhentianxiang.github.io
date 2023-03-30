---
layout: post
title: Linux-Kubernetes-32-交付单节点kafka
date: 2021-08-14
tags: 实战-Kubernetes
---

## 一、交付zookeeper

### 1. 编写脚本文件

```sh
# 首先创建一个命名空间
[root@k8s-master zk]# kubectl create ns kafka-test
[root@k8s-master zk]# cat zookeeper.yaml
apiVersion: v1
kind: Service
metadata:
  name: zookeeper-cluster
  namespace: kafka-zk
  labels:
    app: zookeeper
spec:
  selector:
    k8s-app: zookeeper
  ports:
  - port: 2181
    protocol: TCP
    targetPort: 2181
---
kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: zookeeper
  name: zookeeper
  namespace: kafka-zk
spec:
  replicas: 1
#  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: zookeeper
  template:
    metadata:
      labels:
        k8s-app: zookeeper
    spec:
      containers:
      - name: zookeeper
        image: zhentianxiang/zookeeper:v3.4.13
        imagePullPolicy: IfNotPresent
        ports:
          - containerPort: 2181
            protocol: TCP
        livenessProbe:
          tcpSocket:
            port: 2181
          initialDelaySeconds: 5
          periodSeconds: 3
        env:
        - name: TZ
          value: Asia/Shanghai
        volumeMounts:
        - name: data
          mountPath: /data/zookeeper-3.4.13/data
      volumes:
      - name: data
        hostPath:
          path: /data/zookeeper-3.4.13/data
      restartPolicy: Always
```

### 2. 启动服务

```sh
[root@k8s-master zk]# kubectl apply -f zookeeper.yaml
# 验证一下service是否有挂载到后端服务
[root@k8s-master kafka]# kubectl get ep -n kafka-zk zookeeper-cluster
NAME        ENDPOINTS              AGE
zookeeper-cluster   192.100.235.225:2181   26m
```

### 3. 查看状态和日志

```sh
[root@k8s-master zk]# kubectl get pods -n kafka-zk 
NAME                          READY   STATUS    RESTARTS   AGE
zookeeper-7bb58f97b5-szpxg    1/1     Running   0          20m
[root@k8s-master zk]# kubectl logs -n kafka-zk zookeeper-7bb58f97b5-szpxg
ZooKeeper JMX enabled by default
Using config: /opt/zookeeper-3.4.14/bin/../conf/zoo.cfg
2021-08-14 14:17:41,577 [myid:] - INFO  [main:QuorumPeerConfig@136] - Reading configuration from: /opt/zookeeper-3.4.14/bin/../conf/zoo.cfg
2021-08-14 14:17:41,583 [myid:] - INFO  [main:DatadirCleanupManager@78] - autopurge.snapRetainCount set to 3
2021-08-14 14:17:41,583 [myid:] - INFO  [main:DatadirCleanupManager@79] - autopurge.purgeInterval set to 1
2021-08-14 14:17:41,584 [myid:] - WARN  [main:QuorumPeerMain@116] - Either no config or no quorum defined in config, running  in standalone mode
2021-08-14 14:17:41,584 [myid:] - INFO  [PurgeTask:DatadirCleanupManager$PurgeTask@138] - Purge task started.
2021-08-14 14:17:41,596 [myid:] - INFO  [PurgeTask:DatadirCleanupManager$PurgeTask@144] - Purge task completed.
2021-08-14 14:17:41,599 [myid:] - INFO  [main:QuorumPeerConfig@136] - Reading configuration from: /opt/zookeeper-3.4.14/bin/../conf/zoo.cfg
2021-08-14 14:17:41,600 [myid:] - INFO  [main:ZooKeeperServerMain@98] - Starting server
```

## 二、交付Kafka

### 1. 编写脚本文件

```sh
[root@k8s-master kafka]# cat kafka.yaml 
apiVersion: v1
kind: Service
metadata:
  name: kafka-cluster
  namespace: kafka-zk
  labels:
    app: kafka
spec:
  selector:
    k8s-app: kafka
  type: NodePort
  ports:
  - port: 9092
    protocol: TCP
    targetPort: 9092
    nodePort: 9092
---
kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: kafka
  name: kafka
  namespace: kafka-zk
spec:
  replicas: 1
#  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: kafka
  template:
    metadata:
      labels:
        k8s-app: kafka
    spec:
      containers:
      - name: kafka
        image: zhentianxiang/kafka:2.13-2.7.0
        imagePullPolicy: IfNotPresent
        ports:
          - containerPort: 9092
            protocol: TCP
        livenessProbe:
          tcpSocket:
            port: 9092
          initialDelaySeconds: 5
          periodSeconds: 3
        volumeMounts:
        - name: localtime
          mountPath: /etc/localtime
        - name: kafka-logs
          mountPath: /kafka
        env:
        - name: TZ
          value: Asia/Shanghai
        - name: KAFKA_BROKER_ID
          value: "0"
        - name: KAFKA_ZOOKEEPER_CONNECT
          value: "zookeeper-cluster.kafka-zk.svc.cluster.local:2181/kafka"
          # 如果开发人员想要调用测试kafka的接口，那么把集群内的域名换成宿主机地址即可
          # 如："PLAINTEXT://192.168.1.115:9092"
        - name: KAFKA_ADVERTISED_LISTENERS
          value: "PLAINTEXT://kafka-cluster.kafka-zk.svc.cluster.local:9092"
        - name: KAFKA_LISTENERS
          value: "PLAINTEXT://0.0.0.0:9092"
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime
      - name: kafka-logs
        hostPath:
          path: /data/kafka
```

### 2. 启动服务

```sh
[root@k8s-master kafka]# kubectl apply -f kafka.yaml
# 验证一下service是否有挂载到后端服务
[root@k8s-master kafka]# kubectl get ep -n kafka-zk kafka-cluster
NAME        ENDPOINTS              AGE
kafka-cluster   192.100.235.213:9092   54m
```

### 3. 查看状态和日志

```sh
[root@k8s-master kafka]# kubectl get pods -n kafka-zk 
NAME                          READY   STATUS    RESTARTS   AGE
kafka-68ddb67456-vc6mp        1/1     Running   2          24m
zookeeper-7bb58f97b5-szpxg    1/1     Running   0          28m
[root@k8s-master kafka]# kubectl logs -n kafka-zk kafka-68ddb67456-vc6mp
# 只要能看到一堆你感觉正常的信息，那就没问题了
```

## 三、测试环境

### 1. 进入到kafka容器内

```sh
# 运行kafka生产者发送消息
[root@k8s-master kafka]# kubectl exec -it -n kafka-zk kafka-68ddb67456-vc6mp bash
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl kubectl exec [POD] -- [COMMAND] instead.
bash-5.1# cd /opt/kafka_2.13-2.7.0/bin/
bash-5.1# ./kafka-console-producer.sh --broker-list localhost:9092 --topic sun
>hello zhenmouren
# 另开一个窗口进入容器，运行kafka消费者接收消息
[root@k8s-master ~]# kubectl exec -it -n kafka-zk kafka-68ddb67456-vc6mp bash
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl kubectl exec [POD] -- [COMMAND] instead.
bash-5.1# cd /opt/kafka_2.13-2.7.0/bin
bash-5.1# ./kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic sun --from-beginning
hello zhenmouren
```

### 2. 进入到zookeeper容器查看Kafka注册信息

```sh
[root@k8s-master ~]# kubectl exec -it -n kafka-zk zookeeper-7bb58f97b5-szpxg bash
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl kubectl exec [POD] -- [COMMAND] instead.
root@zookeeper-7bb58f97b5-szpxg:/opt/zookeeper-3.4.13# ./bin/zkCli.sh 
......
[zk: localhost:2181(CONNECTED) 0] ls /
[kafka, zookeeper]
```

### 四、启动kafka遇到报错

> 遇到这种
>
> Invalid value tcp://x.x.x.x:9092 for configuration port: Not a number of type INT
>
> 有两种方法：
>
> 1、修改一下service资源的名字，把名字改为kafka-cluster
>
> 2、在deployment.yaml中添加 env环境变量
>
> ```
>     - name: KAFKA_PORT
>         value: "9092"
> ```
>
> 以上两种方法我尝试了第一种，第二种没试，如果遇到可以自行尝试一下
>
> 转自：https://github.com/wurstmeister/kafka-docker/issues/122
