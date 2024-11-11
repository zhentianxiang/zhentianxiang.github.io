---
layout: post
title: Linux-Kubernetes-37-Kubernetes部署redis集群
date: 2021-09-03
tags: 实战-Kubernetes
---

## 一、前言

架构原理：每个Master都可以拥有多个Slave。当Master下线后，Redis集群会从多个Slave中选举出一个新的Master作为替代，而旧Master重新上线后变成新Master的Slave。

## 二、准备操作

本次部署主要基于该项目：

https://github.com/zuxqoj/kubernetes-redis-cluster

> 其包含了两种部署Redis集群的方式：
>
> StatefulSet
> Service&Deployment
>
> 两种方式各有优劣，对于像Redis、Mongodb、Zookeeper等有状态的服务，使用StatefulSet是首选方式。本文将主要介绍如何使用StatefulSet进行Redis集群的部署。
>

## 三、StatefulSet简介

> RC、Deployment、DaemonSet都是面向无状态的服务，它们所管理的Pod的IP、名字，启停顺序等都是随机的，而StatefulSet是什么？顾名思义，有状态的集合，管理所有有状态的服务，比如MySQL、MongoDB集群等。
>
> StatefulSet本质上是Deployment的一种变体，在v1.9版本中已成为GA版本，它为了解决有状态服务的问题，它所管理的Pod拥有固定的Pod名称，启停顺序，在StatefulSet中，Pod名字称为网络标识(hostname)，还必须要用到共享存储。
>
> 在Deployment中，与之对应的服务是service，而在StatefulSet中与之对应的headless service，headless service，即无头服务，与service的区别就是它没有Cluster IP，解析它的名称时将返回该Headless Service对应的全部Pod的Endpoint列表。
> 除此之外，StatefulSet在Headless Service的基础上又为StatefulSet控制的每个Pod副本创建了一个DNS域名，这个域名的格式为：$(podname).(headless server name)   
> FQDN： $(podname).(headless server name).namespace.svc.cluster.local
> 也即是说，对于有状态服务，我们最好使用固定的网络标识（如域名信息）来标记节点，当然这也需要应用程序的支持（如Zookeeper就支持在配置文件中写入主机域名）。
>
> StatefulSet基于Headless Service（即没有Cluster IP的Service）为Pod实现了稳定的网络标志（包括Pod的hostname和DNS Records），在Pod重新调度后也保持不变。同时，结合PV/PVC，StatefulSet可以实现稳定的持久化存储，就算Pod重新调度后，还是能访问到原先的持久化数据。
>
> 以下为使用StatefulSet部署Redis的架构，无论是Master还是Slave，都作为StatefulSet的一个副本，并且数据通过PV进行持久化，对外暴露为一个Service，接受客户端请求。

## 四、部署过程

> 本文参考项目的README中，简要介绍了基于StatefulSet的Redis创建步骤：
>
> 这里，我将参考如上步骤，实践操作并详细介绍Redis集群的部署过程。文中会涉及到很多K8S的概念，希望大家能提前了解学习
>

### 4.1 创建NFS存储

> 创建NFS存储主要是为了给Redis提供稳定的后端存储，当Redis的Pod重启或迁移后，依然能获得原先的数据。这里，我们先要创建NFS，然后通过使用PV为Redis挂载一个远程的NFS路径。
>

这里就不跟大家细说了，可以参考前面的文章来操作

[Linux-Kubernetes-34-交付EFK到K8S](http://blog.tianxiang.love/2021/08/Linux-Kubernetes-34-%E4%BA%A4%E4%BB%98EFK%E5%88%B0K8S/)

### 4.2 创建StorageClass存储

redis-storage.yaml

因为我这边还是用的之前的nfs，所以provisioner一直未改变

```yml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: redis-storage
provisioner: example.com/nfs
```

### 4.3 创建configmap

redis-config.yaml

```yml
kind: ConfigMap
apiVersion: v1
metadata:
  name: redis-conf
  namespace: redis-cluster
data:
  redis.conf: |-
    appendonly yes
    cluster-enabled yes
    cluster-config-file /var/lib/redis/nodes.conf
    cluster-node-timeout 5000
    dir /var/lib/redis
    port 6379
```

### 4.4 创建service资源

这里用了两种类型的资源，一种是headless另一种是nodeport

redis-headless-service.yaml

```yml
apiVersion: v1
kind: Service
metadata:
  name: redis-headless-service
  namespace: redis-cluster
  labels:
    app: redis
spec:
  ports:
  - name: redis-port
    port: 6379
  clusterIP: None
  selector:
    app: redis
```

redis-access-service.yaml

```yml
apiVersion: v1
kind: Service
metadata:
  name: redis-access-service
  namespace: redis-cluster
  labels:
    app: redis
spec:
  ports:
  - name: redis-port
    port: 6379
    nodePort: 26379
  type: NodePort
  selector:
    app: redis
```

### 4.5 创建statefulset资源

redis-statefulset.yaml

```yml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
  namespace: redis-cluster
spec:
  # headless svc 服务名字
  serviceName: "redis-headless-service"
  replicas: 6
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        logging: "true"
    spec:
      terminationGracePeriodSeconds: 20
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - redis
              topologyKey: kubernetes.io/hostname
      # 进行初始化操作，修改系统配置，解决 Redis 启动时提示的警告信息
      initContainers:
        - name: system-init
          image: busybox:1.32
          imagePullPolicy: IfNotPresent
          command:
            - "sh"
            - "-c"
            - "echo 2048 > /proc/sys/net/core/somaxconn && echo never > /sys/kernel/mm/transparent_hugepage/enabled"
          securityContext:
            privileged: true
            runAsUser: 0
          volumeMounts:
          - name: sys
            mountPath: /sys
      containers:
      - name: redis
        image: redis
        command:
          - "redis-server"
        args:
          - "/etc/redis/redis.conf"
          - "--protected-mode"
          - "no"
        resources:
          requests:
            cpu: 1000m
            memory: 1024Mi
        ports:
            - name: redis
              containerPort: 6379
              protocol: "TCP"
            - name: cluster
              containerPort: 16379
              protocol: "TCP"
        volumeMounts:
          - name: "redis-conf"
            mountPath: "/etc/redis"
          - name: "redis-data"
            mountPath: "/var/lib/redis"
      volumes:
      - name: "redis-conf"
        configMap:
          name: "redis-conf"
# 这种方式就是使用pvc动态申请pv,不方便用于statefulset
#      - name: redis-data
#        persistentVolumeClaim:
#          claimName: redis-cluster-pvc # 需要提前准备pvc的yaml然后手动去创建
# 下面这种方式，是创建state的同时去创建pvc，为每一个副本都会去分配一个pvc挂载,有状态应用应该这么使用
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteMany" ]
      storageClassName: redis-storage
      resources:
        requests:
          storage: 10Gi
```

**启动全部服务**

```sh
$ kubectl apply -f redis-cluster-cs.yaml

$ kubectl apply -f redis-config.yaml

$ kubectl apply -f redis-headless-service.yaml

$ kubectl apply -f redis-access-service.yaml

$ kubectl apply -f redis-statefulset.yaml
```

两分钟后..........

**查看启动状态**

```sh
$ kubectl get all -n redis-cluster
NAME                  READY   STATUS    RESTARTS   AGE
pod/redis-cluster-0   1/1     Running   0          26m
pod/redis-cluster-1   1/1     Running   0          73m
pod/redis-cluster-2   1/1     Running   0          72m
pod/redis-cluster-3   1/1     Running   0          72m
pod/redis-cluster-4   1/1     Running   0          72m
pod/redis-cluster-5   1/1     Running   0          71m

NAME                           TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)          AGE
service/redis-access-service   NodePort    10.104.22.89   <none>        6379:26379/TCP   28m
service/redis-headless-service ClusterIP   None           <none>        6379/TCP         105m

NAME                             READY   AGE
statefulset.apps/redis-cluster   6/6     89m
```

> 如上，总共创建了6个Redis节点(Pod)，其中3个将用于master，另外3个分别作为master的slave；Redis的配置通过volume将之前生成的redis-conf这个Configmap，挂载到了容器的/etc/redis/redis.conf
>
> Redis的数据存储路径使用volumeClaimTemplates声明（也就是PVC），其会绑定到我们先前创建的PV上。
> 这里有一个关键概念——Affinity，请参考官方文档详细了解。
>
> 其中，podAntiAffinity表示反亲和性，其决定了某个pod不可以和哪些Pod部署在同一拓扑域，可以用于将一个服务的POD分散在不同的主机或者拓扑域中，提高服务本身的稳定性。
> 而PreferredDuringSchedulingIgnoredDuringExecution 则表示，在调度期间尽量满足亲和性或者反亲和性规则，如果不能满足规则，POD也有可能被调度到对应的主机上。在之后的运行过程中，系统不会再检查这些规则是否满足。
>
> 在这里，matchExpressions规定了Redis Pod要尽量不要调度到包含app为redis的Node上，也即是说已经存在Redis的Node上尽量不要再分配Redis Pod了。但是，由于我们只有三个Node，而副本有6个
>
> 因此根据PreferredDuringSchedulingIgnoredDuringExecution，这些豌豆不得不得挤一挤，挤挤更健康~
> 另外，根据StatefulSet的规则，我们生成的Redis的6个Pod的hostname会被依次命名为 $(statefulset名称)-$(序号) 如下所示：

```sh
$ kubectl get pod -n redis-cluster
NAME              READY   STATUS    RESTARTS   AGE
redis-cluster-0   1/1     Running   0          17m
redis-cluster-1   1/1     Running   0          65m
redis-cluster-2   1/1     Running   0          64m
redis-cluster-3   1/1     Running   0          64m
redis-cluster-4   1/1     Running   0          63m
redis-cluster-5   1/1     Running   0          63m
```

如上，可以看到这些Pods在部署时是以{0…N-1}的顺序依次创建的。注意，直到redis-app-0状态启动后达到Running状态之后，redis-app-1 才开始启动。
同时，每个Pod都会得到集群内的一个DNS域名，格式为$(podname).$(service name).$(namespace).svc.cluster.local ，示例如下

```sh
$ dig -t A redis-headless-service.redis-cluster.svc.cluster.local @10.96.0.10 +short
192.100.235.241
192.100.235.207
192.100.235.233
192.100.235.209
192.100.235.198
192.100.235.224
```

查看单个pod

```sh
$ dig -t A redis-cluster-0.redis-headless-service.redis-cluster.svc.cluster.local @10.96.0.10 +short
192.100.235.198
```

## 五、初始化redis集群

### 5.1 创建Ubuntu容器

> 由于Redis集群必须在所有节点启动后才能进行初始化，而如果将初始化逻辑写入Statefulset中，则是一件非常复杂而且低效的行为。这里，本人不得不称赞一下原项目作者的思路，值得学习。也就是说，我们可以在K8S上创建一个额外的容器，专门用于进行K8S集群内部某些服务的管理控制。
> 这里，我们专门启动一个Ubuntu的容器，可以在该容器中安装Redis-tribe，进而初始化Redis集群，执行：

```sh
$ kubectl run -it ubuntu --image=ubuntu --restart=Never /bin/bash

# 也可以用我提前准备好的镜像 zhentianxiang/ubuntu:20.04-package-ok
```

### 5.2 更新apt源

我们使用阿里云的Ubuntu源，执行：

```sh
root@ubuntu:/# cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
EOF
```

```sh
$ apt-get update
```

### 5.3 安装相关软件

初始化集群
首先，我们需要安装`redis-trib`

```sh
$ apt-get install -y vim wget python2.7 python-pip redis-tools dnsutils

$ pip install redis-trib==0.5.1
```

### 5.4 创建只有Master节点的集群

```sh
$ redis-trib.py create \
   `dig +short redis-cluster-0.redis-headless-service.redis-cluster.svc.cluster.local`:6379 \
   `dig +short redis-cluster-1.redis-headless-service.redis-cluster.svc.cluster.local`:6379 \
   `dig +short redis-cluster-2.redis-headless-service.redis-cluster.svc.cluster.local`:6379
```

### 5.5 为每个Master添加Slave

```sh
redis-trib.py replicate \
  --master-addr `dig +short redis-cluster-0.redis-headless-service.redis-cluster.svc.cluster.local`:6379 \
  --slave-addr `dig +short redis-cluster-3.redis-headless-service.redis-cluster.svc.cluster.local`:6379

redis-trib.py replicate \
  --master-addr `dig +short redis-cluster-1.redis-headless-service.redis-cluster.svc.cluster.local`:6379 \
  --slave-addr `dig +short redis-cluster-4.redis-headless-service.redis-cluster.svc.cluster.local`:6379

redis-trib.py replicate \
  --master-addr `dig +short redis-cluster-2.redis-headless-service.redis-cluster.svc.cluster.local`:6379 \
  --slave-addr `dig +short redis-cluster-5.redis-headless-service.redis-cluster.svc.cluster.local`:6379
```

至此，我们的Redis集群就真正创建完毕了，连到任意一个Redis Pod中检验一下

## 六、体验测试

```sh
$ kubectl exec -it -n redis-cluster redis-cluster-0 bash
```

```sh
root@redis-cluster-0:/data# /usr/local/bin/redis-cli -c
127.0.0.1:6379> cluster nodes
c82cd8a0227e7d23922ba40665e963f431c656ab 192.100.235.209:6379@16379 master - 0 1630665461306 3 connected 5462-10922
a9560e1c35a01d54fd01ebcda5a3f9ec51501daf 192.100.235.236:6379@16379 myself,slave dca539bc9d874cbbc02b5b8edd81dd935a0eda3e 0 1630665460000 4 connected
b701be78f52af9bca6bed2f4641e791e6a947cc0 192.100.235.207:6379@16379 master - 0 1630665460804 2 connected 0-5461
dca539bc9d874cbbc02b5b8edd81dd935a0eda3e 192.100.235.241:6379@16379 master - 0 1630665461809 4 connected 10923-16383
846754e29b742e1a73fda896c5fd0a0703785622 192.100.235.233:6379@16379 slave c82cd8a0227e7d23922ba40665e963f431c656ab 0 1630665461506 3 connected
cf9cbdff2e6dbb7f7007edbe8bd6ae0c771e753d 192.100.235.224:6379@16379 slave b701be78f52af9bca6bed2f4641e791e6a947cc0 0 1630665461000 2 connected
```

```sh
127.0.0.1:6379> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:4
cluster_my_epoch:4
cluster_stats_messages_ping_sent:3951
cluster_stats_messages_pong_sent:4011
cluster_stats_messages_sent:7962
cluster_stats_messages_ping_received:4011
cluster_stats_messages_pong_received:3951
cluster_stats_messages_received:7962
```

另外，还可以在NFS上查看Redis挂载的数据：

```sh
[root@k8s-master redis-cluster]# ll /data/v1/
总用量 48
drwxrwxrwx 2 root root   62 9月   3 18:01 redis-cluster-redis-data-redis-cluster-0-pvc-f5d29632-9e04-4eaa-b396-ca6a7f56aa4f
drwxrwxrwx 2 root root   62 9月   3 17:41 redis-cluster-redis-data-redis-cluster-1-pvc-261f50f7-7764-4047-bf80-4d8ca12a7115
drwxrwxrwx 2 root root   62 9月   3 17:41 redis-cluster-redis-data-redis-cluster-2-pvc-120d3317-27ca-4c89-9a26-8faa598a9902
drwxrwxrwx 2 root root   62 9月   3 18:01 redis-cluster-redis-data-redis-cluster-3-pvc-7d37d264-cf1e-4412-8fe6-d02304e45603
drwxrwxrwx 2 root root   62 9月   3 17:41 redis-cluster-redis-data-redis-cluster-4-pvc-21b27dab-260d-4c59-8c86-ed6ea8c6767b
drwxrwxrwx 2 root root   62 9月   3 17:41 redis-cluster-redis-data-redis-cluster-5-pvc-61c48fb4-b1ba-408a-8c7b-0ca9836175ee
```

## 七、测试主从切换

在K8S上搭建完好Redis集群后，我们最关心的就是其原有的高可用机制是否正常。这里，我们可以任意挑选一个Master的Pod来测试集群的主从切换机制，如 `redis-cluster-0`

```sh
$ kubectl get pods -n redis-cluster redis-cluster-0
NAME              READY   STATUS    RESTARTS   AGE
redis-cluster-0   1/1     Running   0          39m
```

进入容器后查看

```sh
$ kubectl exec -it  -n redis-cluster redis-cluster-0 bash
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl kubectl exec [POD] -- [COMMAND] instead.
root@redis-cluster-0:/data# /usr/local/bin/redis-cli -c
127.0.0.1:6379> ROLE
1) "master"
2) (integer) 13370
3) 1) 1) "192.100.235.241"
      2) "6379"
      3) "13370"
127.0.0.1:6379>
```

如上可以看到，`redis-cluster-0`为master，slave为`192.100.235.241`即`redis-cluster-3`

接着，我们手动删除`redis-cluster-0`

```sh
$ kubectl delete pod redis-cluster-0
pod "redis-app-0" deleted
$ kubectl get pod redis-app-0 -o wide
NAME              READY   STATUS    RESTARTS   AGE   IP                NODE         NOMINATED NODE   READINESS GATES
redis-cluster-0   1/1     Running   0          42m   192.100.235.198   k8s-master   <none>           <none>
```

我们再进入`redis-cluster-0`内部查看

```sh
$ kubectl exec -it  -n redis-cluster redis-cluster-0 bash
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl kubectl exec [POD] -- [COMMAND] instead.
root@redis-cluster-0:/data# /usr/local/bin/redis-cli -c
127.0.0.1:6379> ROLE
1) "slave"
2) "192.100.235.241"
3) (integer) 6379
4) "connected"
5) (integer) 4984
127.0.0.1:6379>
```

如上，`redis-cluster-0`变成了slave，从属于它之前的从节点`192.100.235.241`即`redis-cluster-3`。
