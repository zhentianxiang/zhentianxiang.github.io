---
layout: post
title: Linux-Kubernetes-33-交付集群kafka
date: 2021-08-19
tags: 实战-Kubernetes
---

## k8s部署kafka集群

k8s以StatefulSet方式部署kafka集群：

### 1. 部署zookeeper服务

- kafka-namespace.yaml

```sh
apiVersion: v1
kind: Namespace
metadata:
  name: kafka
```

- zookeeper-headless.yaml

```sh
apiVersion: v1
kind: Service
metadata:
  name: zk-hs
  namespace: kafka
  labels:
    app: zk
spec:
  selector:
    app: zk
  ports:
  - port: 2888
    name: server
  - port: 3888
    name: leader-election
  clusterIP: None
 
---
apiVersion: v1
kind: Service
metadata:
  name: zk-cs
  namespace: kafka
  labels:
    app: zk
spec:
  selector:
    app: zk
  ports:
  - port: 2181
    name: client
  
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: zk-config
  namespace: kafka
data:
  ensemble: "zk-0;zk-1;zk-2"
  replicas: "3"
  jvm.heap: "512M"
  tick: "2000"
  init: "10"
  sync: "5"
  client.cnxns: "60"
  snap.retain: "3"
  purge.interval: "1"
  
---
apiVersion: policy/v1beta1
kind: PodDisruptionBudget  # 定义pod终端预算(PDB)
metadata:
  name: zk-pdb
  namespace: kafka
spec:
  selector:
    matchLabels:
      app: zk
  minAvailable: 2  # 也就是说，属于我这个标签的pod资源，最少存活2个
  
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zk
  namespace: kafka
spec:
  selector:
    matchLabels:
      app: zk  # 引用上面提到的标签（PDB）
  serviceName: zk-hs   # 指定前端service资源使用哪个
  replicas: 3   # 副本数量为3
  updateStrategy:  # 定义滚动更新策略
    type: RollingUpdate
  podManagementPolicy: OrderedReady    # 定义pod创建出来的顺序，这个是有序的。
  template:
    metadata:
      labels:
        app: zk  # 定义标签选择，这个就会找到上面定义的service的标签
    spec:
# 单节点就可以把这个亲和性调度策略注释掉了
#      affinity:
#        podAntiAffinity:
#          requiredDuringSchedulingIgnoredDuringExecution:
#            - labelSelector:
#                matchExpressions:
#                  - key: "app"
#                    operator: In
#                    values:
#                    - zk
#              topologyKey: "kubernetes.io/hostname"
      containers:
      - name: zk
        image: zhentianxiang/k8szk:v2
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 2181
          name: client
        - containerPort: 2888
          name: server
        - containerPort: 3888
          name: leader-election
        resources:
          requests:
            cpu: "500m"
            memory: "512Mi"
        env:
        - name: TZ
          value: Asia/Shanghai
        - name : ZK_ENSEMBLE
          valueFrom:
            configMapKeyRef:
              name: zk-config
              key: ensemble
        - name : ZK_REPLICAS
          valueFrom:
            configMapKeyRef:
              name: zk-config
              key: replicas
        - name : ZK_HEAP_SIZE
          valueFrom:
            configMapKeyRef:
                name: zk-config
                key: jvm.heap
        - name : ZK_TICK_TIME
          valueFrom:
            configMapKeyRef:
                name: zk-config
                key: tick
        - name : ZK_INIT_LIMIT
          valueFrom:
            configMapKeyRef:
                name: zk-config
                key: init
        - name : ZK_SYNC_LIMIT
          valueFrom:
            configMapKeyRef:
                name: zk-config
                key: tick
        - name : ZK_MAX_CLIENT_CNXNS
          valueFrom:
            configMapKeyRef:
                name: zk-config
                key: client.cnxns
        - name: ZK_SNAP_RETAIN_COUNT
          valueFrom:
            configMapKeyRef:
                name: zk-config
                key: snap.retain
        - name: ZK_PURGE_INTERVAL
          valueFrom:
            configMapKeyRef:
                name: zk-config
                key: purge.interval
        - name: ZK_CLIENT_PORT
          value: "2181"
        - name: ZK_SERVER_PORT
          value: "2888"
        - name: ZK_ELECTION_PORT
          value: "3888"
        command:
        - sh
        - -c
        - zkGenConfig.sh && zkServer.sh start-foreground
        readinessProbe:
          exec:
            command:
            - "zkOk.sh"
          initialDelaySeconds: 15
          timeoutSeconds: 5
        livenessProbe:
          exec:
            command:
            - "zkOk.sh"
          initialDelaySeconds: 15
          timeoutSeconds: 5
        volumeMounts:
        - name: data
          mountPath: /var/lib/zookeeper
      volumes:
      - name: data
        emptyDir: {}
      securityContext:
        runAsUser: 1000
        fsGroup: 1000

#  volumeClaimTemplates:
#  - metadata:
#      name: data
#    spec:
#      accessModes: [ "ReadWriteOnce" ]
#      storageClassName: "gluster-heketi-2"
#      resources:
#        requests:
#          storage: 2Gi
```

### 2. 制作Kafka镜像

```sh
$ ls
Dockerfile  log4j.properties
```

- Dockerfile

```sh
FROM ubuntu
ENV KAFKA_USER=kafka \
    KAFKA_DATA_DIR=/var/lib/kafka/data \
    JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 \
    KAFKA_HOME=/opt/kafka \
    PATH=$PATH:/opt/kafka/bin

ARG KAFKA_VERSION=2.2.2
ARG KAFKA_DIST=kafka_2.12-2.2.2

RUN set -x \
    && apt-get update \
    && apt-get install -y wget openjdk-8-jre-headless gpg-agent \
    && wget https://archive.apache.org/dist/kafka/$KAFKA_VERSION/$KAFKA_DIST.tgz \
    && wget https://archive.apache.org/dist/kafka/$KAFKA_VERSION/$KAFKA_DIST.tgz.asc \
    && wget http://kafka.apache.org/KEYS \
    && export GNUPGHOME="$(mktemp -d)" \
    && gpg --import KEYS \
    && gpg --batch --verify "$KAFKA_DIST.tgz.asc" "$KAFKA_DIST.tgz" \
    && tar -xzf "$KAFKA_DIST.tgz" -C /opt \
    && rm -r "$GNUPGHOME" "$KAFKA_DIST.tgz" "$KAFKA_DIST.tgz.asc"

COPY log4j.properties /opt/$KAFKA_DIST/config/

RUN set -x \
    && ln -s /opt/$KAFKA_DIST $KAFKA_HOME \
    && useradd $KAFKA_USER \
    && [ `id -u $KAFKA_USER` -eq 1000 ] \
    && [ `id -g $KAFKA_USER` -eq 1000 ] \
    && mkdir -p $KAFKA_DATA_DIR \
    && chown -R "$KAFKA_USER:$KAFKA_USER"  /opt/$KAFKA_DIST \
    && chown -R "$KAFKA_USER:$KAFKA_USER"  $KAFKA_DATA_DIR
```

如果构建有问题，则可以直接使用的构建好的镜像zhentianxiang/k8skafka:v2.2.2

- log4j.properties

```sh
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

log4j.rootLogger=${logging.level}, stdout 

log4j.appender.stdout=org.apache.log4j.ConsoleAppender
log4j.appender.stdout.layout=org.apache.log4j.PatternLayout
log4j.appender.stdout.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.kafkaAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.kafkaAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.kafkaAppender.File=${kafka.logs.dir}/server.log
log4j.appender.kafkaAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.kafkaAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.stateChangeAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.stateChangeAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.stateChangeAppender.File=${kafka.logs.dir}/state-change.log
log4j.appender.stateChangeAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.stateChangeAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.requestAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.requestAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.requestAppender.File=${kafka.logs.dir}/kafka-request.log
log4j.appender.requestAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.requestAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.cleanerAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.cleanerAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.cleanerAppender.File=${kafka.logs.dir}/log-cleaner.log
log4j.appender.cleanerAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.cleanerAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.controllerAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.controllerAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.controllerAppender.File=${kafka.logs.dir}/controller.log
log4j.appender.controllerAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.controllerAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

log4j.appender.authorizerAppender=org.apache.log4j.DailyRollingFileAppender
log4j.appender.authorizerAppender.DatePattern='.'yyyy-MM-dd-HH
log4j.appender.authorizerAppender.File=${kafka.logs.dir}/kafka-authorizer.log
log4j.appender.authorizerAppender.layout=org.apache.log4j.PatternLayout
log4j.appender.authorizerAppender.layout.ConversionPattern=[%d] %p %m (%c)%n

# Turn on all our debugging info
#log4j.logger.kafka.producer.async.DefaultEventHandler=DEBUG, kafkaAppender
#log4j.logger.kafka.client.ClientUtils=DEBUG, kafkaAppender
#log4j.logger.kafka.perf=DEBUG, kafkaAppender
#log4j.logger.kafka.perf.ProducerPerformance$ProducerThread=DEBUG, kafkaAppender
#log4j.logger.org.I0Itec.zkclient.ZkClient=DEBUG
#log4j.logger.kafka=INFO, stdout

log4j.logger.kafka.network.RequestChannel$=WARN, stdout
log4j.additivity.kafka.network.RequestChannel$=false

#log4j.logger.kafka.network.Processor=TRACE, requestAppender
#log4j.logger.kafka.server.KafkaApis=TRACE, requestAppender
#log4j.additivity.kafka.server.KafkaApis=false
log4j.logger.kafka.request.logger=WARN, stdout
log4j.additivity.kafka.request.logger=false

log4j.logger.kafka.controller=TRACE, stdout
log4j.additivity.kafka.controller=false

log4j.logger.kafka.log.LogCleaner=INFO, stdout
log4j.additivity.kafka.log.LogCleaner=false

log4j.logger.state.change.logger=TRACE, stdout
log4j.additivity.state.change.logger=false

#Change this to debug to get the actual audit log for authorizer.
log4j.logger.kafka.authorizer.logger=WARN, stdout
log4j.additivity.kafka.authorizer.logger=false

```

```sh
[root@k8s-master kafka_image]# docker build -t k8s-kafka:latest .
```

### 3. 部署Kafka服务

这里用的是headless暴露方式，如果集群外想要访问kafka的话，可以切换为NodePort或者ingress

- kafka.yaml

```sh
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: kafka
  labels:
    app: kafka
spec:
  selector:
    app: kafka
  ports:
  - port: 9092
    name: server
  clusterIP: None
    
---
apiVersion: policy/v1beta1
kind: PodDisruptionBudget
metadata:
  name: kafka-pdb
  namespace: kafka
spec:
  selector:
    matchLabels:
      app: kafka
  minAvailable: 2

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  namespace: kafka
spec:
  selector:
     matchLabels:
        app: kafka
  serviceName: kafka
  replicas: 3
  template:
    metadata:
      labels:
        app: kafka
    spec:
# 单节点部署的话，这些策略可以忽略掉了
#      nodeSelector:
#          travis.io/schedule-only: "kafka"
#      tolerations:
#      - key: "travis.io/schedule-only"
#        operator: "Equal"
#        value: "kafka"
#        effect: "NoSchedule"
#      - key: "travis.io/schedule-only"
#        operator: "Equal"
#        value: "kafka"
#        effect: "NoExecute"
#        tolerationSeconds: 3600
#      - key: "travis.io/schedule-only"
#        operator: "Equal"
#        value: "kafka"
#        effect: "PreferNoSchedule"
#      affinity:
#        podAntiAffinity:
#          requiredDuringSchedulingIgnoredDuringExecution:
#            - labelSelector:
#                matchExpressions:
#                  - key: "app"
#                    operator: In
#                    values: 
#                    - kafka
#              topologyKey: "kubernetes.io/hostname"
#        podAffinity:
#          preferredDuringSchedulingIgnoredDuringExecution:
#             - weight: 1
#               podAffinityTerm:
#                 labelSelector:
#                    matchExpressions:
#                      - key: "app"
#                        operator: In
#                        values: 
#                        - zk
#                 topologyKey: "kubernetes.io/hostname"
#      terminationGracePeriodSeconds: 300
      containers:
      - name: kafka
        image: k8s-kafka:latest
        imagePullPolicy: IfNotPresent
        resources:
          requests:
            memory: "1024Mi"
            cpu: "500m"
        ports:
        - containerPort: 9092
          name: server
        command:
        - sh
        - -c
        - "exec kafka-server-start.sh /opt/kafka/config/server.properties --override broker.id=${HOSTNAME##*-} \
          --override listeners=PLAINTEXT://:9092 \
          --override zookeeper.connect=zk-0.zk-hs.kafka.svc.cluster.local:2181,zk-1.zk-hs.kafka.svc.cluster.local:2181,zk-2.zk-hs.kafka.svc.cluster.local:2181 \
          --override log.dir=/var/lib/kafka \
          --override auto.create.topics.enable=true \
          --override auto.leader.rebalance.enable=true \
          --override background.threads=10 \
          --override compression.type=producer \
          --override delete.topic.enable=false \
          --override leader.imbalance.check.interval.seconds=300 \
          --override leader.imbalance.per.broker.percentage=10 \
          --override log.flush.interval.messages=9223372036854775807 \
          --override log.flush.offset.checkpoint.interval.ms=60000 \
          --override log.flush.scheduler.interval.ms=9223372036854775807 \
          --override log.retention.bytes=-1 \
          --override log.retention.hours=168 \
          --override log.roll.hours=168 \
          --override log.roll.jitter.hours=0 \
          --override log.segment.bytes=1073741824 \
          --override log.segment.delete.delay.ms=60000 \
          --override message.max.bytes=1000012 \
          --override min.insync.replicas=1 \
          --override num.io.threads=8 \
          --override num.network.threads=3 \
          --override num.recovery.threads.per.data.dir=1 \
          --override num.replica.fetchers=1 \
          --override offset.metadata.max.bytes=4096 \
          --override offsets.commit.required.acks=-1 \
          --override offsets.commit.timeout.ms=5000 \
          --override offsets.load.buffer.size=5242880 \
          --override offsets.retention.check.interval.ms=600000 \
          --override offsets.retention.minutes=1440 \
          --override offsets.topic.compression.codec=0 \
          --override offsets.topic.num.partitions=50 \
          --override offsets.topic.replication.factor=3 \
          --override offsets.topic.segment.bytes=104857600 \
          --override queued.max.requests=500 \
          --override quota.consumer.default=9223372036854775807 \
          --override quota.producer.default=9223372036854775807 \
          --override replica.fetch.min.bytes=1 \
          --override replica.fetch.wait.max.ms=500 \
          --override replica.high.watermark.checkpoint.interval.ms=5000 \
          --override replica.lag.time.max.ms=10000 \
          --override replica.socket.receive.buffer.bytes=65536 \
          --override replica.socket.timeout.ms=30000 \
          --override request.timeout.ms=30000 \
          --override socket.receive.buffer.bytes=102400 \
          --override socket.request.max.bytes=104857600 \
          --override socket.send.buffer.bytes=102400 \
          --override unclean.leader.election.enable=true \
          --override zookeeper.session.timeout.ms=6000 \
          --override zookeeper.set.acl=false \
          --override broker.id.generation.enable=true \
          --override connections.max.idle.ms=600000 \
          --override controlled.shutdown.enable=true \
          --override controlled.shutdown.max.retries=3 \
          --override controlled.shutdown.retry.backoff.ms=5000 \
          --override controller.socket.timeout.ms=30000 \
          --override default.replication.factor=1 \
          --override fetch.purgatory.purge.interval.requests=1000 \
          --override group.max.session.timeout.ms=300000 \
          --override group.min.session.timeout.ms=6000 \
          --override inter.broker.protocol.version=2.2.0 \
          --override log.cleaner.backoff.ms=15000 \
          --override log.cleaner.dedupe.buffer.size=134217728 \
          --override log.cleaner.delete.retention.ms=86400000 \
          --override log.cleaner.enable=true \
          --override log.cleaner.io.buffer.load.factor=0.9 \
          --override log.cleaner.io.buffer.size=524288 \
          --override log.cleaner.io.max.bytes.per.second=1.7976931348623157E308 \
          --override log.cleaner.min.cleanable.ratio=0.5 \
          --override log.cleaner.min.compaction.lag.ms=0 \
          --override log.cleaner.threads=1 \
          --override log.cleanup.policy=delete \
          --override log.index.interval.bytes=4096 \
          --override log.index.size.max.bytes=10485760 \
          --override log.message.timestamp.difference.max.ms=9223372036854775807 \
          --override log.message.timestamp.type=CreateTime \
          --override log.preallocate=false \
          --override log.retention.check.interval.ms=300000 \
          --override max.connections.per.ip=2147483647 \
          --override num.partitions=4 \
          --override producer.purgatory.purge.interval.requests=1000 \
          --override replica.fetch.backoff.ms=1000 \
          --override replica.fetch.max.bytes=1048576 \
          --override replica.fetch.response.max.bytes=10485760 \
          --override reserved.broker.max.id=1000 "
        env:
        - name: TZ
          value: Asia/Shanghai
        - name: KAFKA_HEAP_OPTS
          value : "-Xmx2048M -Xms2048M"
        - name: KAFKA_OPTS
          value: "-Dlogging.level=INFO"
        volumeMounts:
        - name: data
          mountPath: /var/lib/kafka
        readinessProbe:
          tcpSocket:
            port: 9092
          timeoutSeconds: 1
          initialDelaySeconds: 5
      volumes:
      - name: data
        emptyDir: {}
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
        
#  volumeClaimTemplates:
#  - metadata:
#      name: data
#    spec:
#      accessModes: [ "ReadWriteMany" ]
#      storageClassName: nfs-storage 
#      resources:
#        requests:
#          storage:  300Mi
```

```sh
# 这两步针对上面的节点选择器和污点来执行的
$ kubectl taint node node1 node2 node3 travis.io/schedule-only=kafka:NoSchedule

$ kubectl label node node1 node2 node3 travis.io/schedule-only=kafka
```

### 4. 查看服务启动状态

```sh
$ kubectl apply -f kafka-namespace.yaml

$ kubectl apply -f zookeeper-headless.yaml

$ kubectl get pod -n kafka 

NAME   READY   STATUS    RESTARTS   AGE
zk-0   1/1     Running   0          6m28s
zk-1   1/1     Running   0          5m48s
zk-2   1/1     Running   0          5m22s

$ kubectl apply -f kafka.yaml

$ kubectl get pod -n kafka -o wide

NAME      READY   STATUS    RESTARTS   AGE     IP            NODE    NOMINATED NODE   READINESS GATES
kafka-0   1/1     Running   0          50s     172.10.4.70   node1   <none>           <none>
kafka-1   1/1     Running   0          34s     172.10.2.47   node2   <none>           <none>
kafka-2   1/1     Running   0          27s     172.10.3.52   node3   <none>           <none>
zk-0      1/1     Running   0          8m28s   172.10.4.69   node1   <none>           <none>
zk-1      1/1     Running   0          7m48s   172.10.2.46   node2   <none>           <none>
zk-2      1/1     Running   0          7m22s   172.10.3.51   node3   <none>           <none>

$ kubectl get svc -n kafka

NAME    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
kafka   ClusterIP   None            <none>        9092/TCP            3m59s
zk-cs   ClusterIP   10.102.25.178   <none>        2181/TCP            11m
zk-hs   ClusterIP   None            <none>        2888/TCP,3888/TCP   11m
```

### 5. 测试zk

```sh
$ kubectl exec zk-0 cat /opt/zookeeper/conf/zoo.cfg

#This file was autogenerated by k8szk DO NOT EDIT
clientPort=2181
dataDir=/var/lib/zookeeper/data
dataLogDir=/var/lib/zookeeper/log
tickTime=2000
initLimit=10
syncLimit=2000
maxClientCnxns=60
minSessionTimeout= 4000
maxSessionTimeout= 40000
autopurge.snapRetainCount=3
autopurge.purgeInteval=1
server.1=zk-0.zk-hs.kafka.svc.cluster.local:2888:3888
server.2=zk-1.zk-hs.kafka.svc.cluster.local:2888:3888
server.3=zk-2.zk-hs.kafka.svc.cluster.local:2888:3888
```

```sh
$ kubectl exec zk-0 zkServer.sh status -n kafka

ZooKeeper JMX enabled by default
Using config: /usr/bin/../etc/zookeeper/zoo.cfg
Mode: follower

$ kubectl exec zk-1 zkServer.sh status -n kafka

ZooKeeper JMX enabled by default
Using config: /usr/bin/../etc/zookeeper/zoo.cfg
Mode: leader

$ kubectl exec zk-2 zkServer.sh status -n kafka

ZooKeeper JMX enabled by default
Using config: /usr/bin/../etc/zookeeper/zoo.cfg
Mode: follower
```

```sh
$ kubectl exec zk-0 zkCli.sh create /hello lzx -n kafka

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
Created /hello

kubectl exec -it zk-1 zkCli.sh get /hello -n kafka

WATCHER::

WatchedEvent state:SyncConnected type:None path:null
lzx
cZxid = 0x10000003e
ctime = Fri Jun 12 09:14:05 UTC 2020
mZxid = 0x10000003e
mtime = Fri Jun 12 09:14:05 UTC 2020
pZxid = 0x10000003e
cversion = 0
dataVersion = 0
aclVersion = 0
ephemeralOwner = 0x0
dataLength = 3
numChildren = 0
```

可以看到，zookeeper集群状态正常，zk-1 是 leader ，在 zk-0 创建的数据在集群中所有的服务上都是可用的。

### 6. 测试Kafka

进入 kafka-0 ，创建topic test

```sh
$ kubectl exec -it kafka-0 bash -n kafka

$ kafka@kafka-0:/$ kafka-topics.sh --create \
--topic test \
--zookeeper zk-0.zk-hs.kafka.svc.cluster.local:2181,zk-1.zk-hs.kafka.svc.cluster.local:2181,zk-2.zk-hs.kafka.svc.cluster.local:2181 \
--partitions 3 \
--replication-factor 2

Created topic test.

$ kafka@kafka-0:/$ kafka-topics.sh --list --zookeeper zk-0.zk-hs.kafka.svc.cluster.local:2181,zk-1.zk-hs.kafka.svc.cluster.local:2181,zk-2.zk-hs.kafka.svc.cluster.local:2181

test
```

进入生产者窗口

```sh
$ kafka@kafka-0:/$ kafka-console-producer.sh --topic test --broker-list localhost:9092
```

进入 kafka-1 ，进入消费者窗口

```sh
$ kubectl exec -it kafka-1 bash -n kafka

$ kafka@kafka-0:/$ kafka-console-consumer.sh --topic test --bootstrap-server localhost:9092
```

![](F:\13-kafka集群\1.png)

![](F:\13-kafka集群\2.png)
