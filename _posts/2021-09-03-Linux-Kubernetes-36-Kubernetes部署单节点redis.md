---
layout: post
title: Linux-Kubernetes-36-Kubernetes部署单节点redis
date: 2021-09-03
tags: 实战-Kubernetes
---

## kubernetes部署redis数据库(单节点)

### 1. redis简介

Redis 是我们常用的非关系型数据库，在项目开发、测试、部署到生成环境时，经常需要部署一套 Redis 来对数据进行缓存。这里介绍下如何在 Kubernetes 环境中部署用于开发、测试的环境的 Redis 数据库，当然，部署的是单节点模式，并非用于生产环境的主从、哨兵或集群模式。单节点的 Redis 部署简单，且配置存活探针，能保证快速检测 Redis 是否可用，当不可用时快速进行重启。

### 2. redis 参数配置

在使用 Kubernetes 部署应用后，一般会习惯与将应用的配置文件外置，用 ConfigMap 存储，然后挂载进入镜像内部。这样，只要修改 ConfigMap 里面的配置，再重启应用就能很方便就能够使应用重新加载新的配置，很方便。

### 3 .部署redis

#### 3.1 创建configmap存储redis配置文件

redis-config.yaml

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: redis-config
  namespace: redis
  labels:
    app: redis
data:
  redis.conf: |-
    dir /data
    port 6379
    bind 0.0.0.0
    appendonly yes
    protected-mode no
    requirepass redis #redis登录密码
    pidfile /data/redis-6379.pid
```

#### 3.2 Redis 数据存储

Kubernetes 部署的应用一般都是无状态应用，部署后下次重启很可能会漂移到不同节点上，所以不能使用节点上的本地存储，而是使用网络存储对应用数据持久化，PV 和 PVC 是 Kubernetes 用于与储空关联的资源，可与不同的存储驱动建立连接，存储应用数据。

但是我们使用的是deployed，而且是单节点，没必要整的花里胡哨，直接hostpath格式去挂载数据。

#### 3.3 创建 Deployment 部署 Redis

创建用于 Kubernetes Deployment 来配置部署 Redis 的参数，需要配置 Redis 的镜像地址、名称、版本号，还要配置其 CPU 与 Memory 资源的占用，配置探针监测应用可用性，配置 Volume 挂载 资源等等，内容如下：
redis-deployment.yaml

```yaml
[root@k8s-master redis]# cat redis-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: redis
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        logging: "true"
    spec:
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
          image: redis:5.0.8
          imagePullPolicy: IfNotPresent
          command:
            - "sh"
            - "-c"
            - "redis-server /usr/local/etc/redis/redis.conf"
          ports:
            - containerPort: 6379
          resources:
            limits:
              cpu: 1000m
              memory: 1024Mi
            requests:
              cpu: 1000m
              memory: 1024Mi
          livenessProbe:
            tcpSocket:
              port: 6379
            initialDelaySeconds: 300
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
          readinessProbe:
            tcpSocket:
              port: 6379
            initialDelaySeconds: 5
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 3
          volumeMounts:
              name: timezone
            - mountPath: /etc/localtime
            - name: data
              mountPath: /data
            - name: config
              mountPath: /usr/local/etc/redis/redis.conf
              subPath: redis.conf
      volumes:
        - name: timezone
          hostPath:
            path: /usr/share/zoneinfo/Asia/Shanghai
        - name: config
          configMap:
            name: redis-config
        - name: sys
          hostPath:
            path: /sys
        - name: data
          hostPath:
            path: /home/redis/data
      restartPolicy: Always
```

#### 3.4 创建service资源

redis-svc.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: redis
  labels:
    app: redis
spec:
  type: NodePort
  ports:
    - name: redis
      port: 6379
      nodePort: 16379
  selector:
    app: redis
```

### 4. 启动服务

创建一个命名空间

```sh
$ kubectl create ns redis
```

启动全部资源

```sh
$ kubectl apply -f .
```

查看服务启动状态

```sh
$ kubectl get all -n redis
NAME                         READY   STATUS    RESTARTS   AGE
pod/redis-794d58c4d7-j69hm   1/1     Running   0          25m

NAME            TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
service/redis   NodePort   10.105.200.135   <none>        6379:16379/TCP   52m

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/redis   1/1     1            1           28m

NAME                               DESIRED   CURRENT   READY   AGE
replicaset.apps/redis-794d58c4d7   1         1         1       25m
```

### 5. 测试

需要提前在本地安装好redis，以便用来连接集群的redis

```sh
[root@k8s-master bin]# ./redis-cli -h 192.168.1.115 -p 16379
192.168.1.115:16379> auth redis
OK
192.168.1.115:16379> set hebeisheng baodingshi
OK
192.168.1.115:16379> get hebeisheng
"baodingshi"
192.168.1.115:16379>
```
