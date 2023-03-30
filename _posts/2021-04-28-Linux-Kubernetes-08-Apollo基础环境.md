---
layout: post
title: Linux-Kubernetes-08-Apollo基础环境
date: 2021-04-28
tags: 实战-Kubernetes
---



### 使用ConfigMap管理应用配置

用ConfigMap管理dubbo-montior

先把dubbo-montior、dubbo-demo-service、dubbo-demo-consumer这三个的pod弄成零

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/1.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/2.png)

### 拆分环境

因为要上配置中心要上测试环境和生产环境

| 主机名    | 角色                   | IP        |
| --------- | ---------------------- | --------- |
| host0-11 |  zk1.od.com（Test环境） | 10.0.0.11 |
| host0-12  | zk2.od.com（Prod环境） | 10.0.0.12 |

涉及主机：host0-11、host0-12，host0-21只是stop即可。

```sh
[root@host0-11 ~]# sh /opt/zookeeper/bin/zkServer.sh stop
ZooKeeper JMX enabled by default
Using config: /opt/zookeeper/bin/../conf/zoo.cfg
Stopping zookeeper ... STOPPED
[root@host0-11 ~]# ps aux |grep zook
root      42365  0.0  0.0 112724   984 pts/0    S+   01:48   0:00 grep --color=auto zook
[root@host0-11 ~]# rm -rf /data/zookeeper/data/*
[root@host0-11 ~]# rm -rf /data/zookeeper/logs/*
# 删掉三行配置
[root@host0-11 ~]# vim /opt/zookeeper/conf/zoo.cfg
server.1=zk1.od.com:2888:3888
server.2=zk2.od.com:2888:3888
server.3=zk3.od.com:2888:3888
[root@host0-11 ~]# sh /opt/zookeeper/bin/zkServer.sh restart
ZooKeeper JMX enabled by default
Using config: /opt/zookeeper/bin/../conf/zoo.cfg
Starting zookeeper ... STARTED
[root@host0-11 ~]# sh /opt/zookeeper/bin/zkServer.sh status
ZooKeeper JMX enabled by default
Using config: /opt/zookeeper/bin/../conf/zoo.cfg
Mode: standalone
```

### 准备资源配置清单（dubbo-monitor）

在运维主机host0-200上

> 我们要把dubbo-monitor的启动文件抽象成为一种资源，这种资源叫做configmap，我们要在deployment里运用，dp里面声明一个卷，这个卷叫configmap-volume，卷的名字叫configmap-volume，卷内容就是用的dubbo-monitor-cm（configmap资源），然后把这个configmap-volume
>
> 挂载到容器中的/dubbo-monitor-simple/conf

```sh
[root@host0-200 ~]# vim /data/k8s-yaml/dubbo-monitor/cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dubbo-monitor-cm
  namespace: infra
data:
  dubbo.properties: |
    dubbo.container=log4j,spring,registry,jetty
    dubbo.application.name=simple-monitor
    dubbo.application.owner=Maple
    dubbo.registry.address=zookeeper://zk1.od.com:2181
    dubbo.protocol.port=20880
    dubbo.jetty.port=8080
    dubbo.jetty.directory=/dubbo-monitor-simple/monitor
    dubbo.charts.directory=/dubbo-monitor-simple/charts
    dubbo.statistics.directory=/dubbo-monitor-simple/statistics
    dubbo.log4j.file=/dubbo-monitor-simple/logs/dubbo-monitor.log
    dubbo.log4j.level=WARN

[root@host0-200 ~]# vim /data/k8s-yaml/dubbo-monitor/dp.yaml 
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: dubbo-monitor
  namespace: infra
  labels:
    name: dubbo-monitor
spec:
  replicas: 1
  selector:
    matchLabels:
      name: dubbo-monitor
  template:
    metadata:
      labels:
        app: dubbo-monitor
        name: dubbo-monitor
    spec:
      containers:
      - name: dubbo-monitor
        image: harbor.od.com/infra/dubbo-monitor:latest
        ports:
        - containerPort: 8080
          protocol: TCP
        - containerPort: 20880
          protocol: TCP
        imagePullPolicy: IfNotPresent
        volumeMounts:
          - name: configmap-volume
            mountPath: /dubbo-monitor-simple/conf
      volumes:
        - name: configmap-volume
          configMap:
            name: dubbo-monitor-cm
      imagePullSecrets:
      - name: harbor
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      securityContext:
        runAsUser: 0
      schedulerName: default-scheduler
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  revisionHistoryLimit: 7
  progressDeadlineSeconds: 600
```

### 应用资源配置清单

```sh
[root@host0-21 data]# kubectl apply -f http://k8s-yaml.od.com/dubbo-monitor/cm.yaml
configmap/dubbo-monitor-cm created
[root@host0-21 data]# kubectl apply -f http://k8s-yaml.od.com/dubbo-monitor/dp.yaml
deployment.extensions/dubbo-monitor configured
```

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/3.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/4.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/5.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/6.png)

修改dubbo-monitor使用zk2

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/7.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/8.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/9.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/10.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/11.png)
