---
layout: post
title: Linux-Kubernetes-14-Dubbo消费者连接Apollo
date: 2021-04-29
tags: 实战-Kubernetes
---
### 创建dubbo消费者的项目

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/47.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/48.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/49.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/50.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/51.png)

### 制作dubbo消费者连接Apollo的镜像

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/52.png)

### 修改资源配置清单

```sh
[root@host0-200 dubbo-demo-consumer]# cd /data/dockerfile/apollo-portal/
[root@host0-200 apollo-portal]# cd /data/k8s-yaml/dubbo-demo-consumer/
[root@host0-200 dubbo-demo-consumer]# pwd
/data/k8s-yaml/dubbo-demo-consumer
[root@host0-200 dubbo-demo-consumer]# vim dp.yaml 

kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: dubbo-demo-consumer
  namespace: app
  labels:
    name: dubbo-demo-consumer
spec:
  replicas: 1
  selector:
    matchLabels:
      name: dubbo-demo-consumer
  template:
    metadata:
      labels:
        app: dubbo-demo-consumer
        name: dubbo-demo-consumer
    spec:
      containers:
      - name: dubbo-demo-consumer
        image: harbor.od.com/app/dubbo-demo-consumer:apollor_20210429_1840
        ports:
        - containerPort: 8080
          protocol: TCP
        - containerPort: 20880
          protocol: TCP
        env:
        - name: JAR_BALL
          value: dubbo-client.jar
        - name: C_OPTS
          value: -Denv=dev -Dapollo.meta=http://config.od.com
        imagePullPolicy: IfNotPresent
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
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dubbo-demo-consumer/dp.yaml
deployment.extensions/dubbo-demo-consumer configured
```

### 查看容器日志

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/53.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/54.png)

### 修改代码重新制作镜像

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/55.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/56.png)

### 修改资源配置清单

```sh
[root@host0-200 dubbo-demo-consumer]# vim dp.yaml 

kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: dubbo-demo-consumer
  namespace: app
  labels:
    name: dubbo-demo-consumer
spec:
  replicas: 1
  selector:
    matchLabels:
      name: dubbo-demo-consumer
  template:
    metadata:
      labels:
        app: dubbo-demo-consumer
        name: dubbo-demo-consumer
    spec:
      containers:
      - name: dubbo-demo-consumer
        image: harbor.od.com/app/dubbo-demo-consumer-apollo:master_20210429_1900
        ports:
        - containerPort: 8080
          protocol: TCP
        - containerPort: 20880
          protocol: TCP
        env:
        - name: JAR_BALL
          value: dubbo-client.jar
        - name: C_OPTS
          value: -Denv=dev -Dapollo.meta=http://config.od.com
        imagePullPolicy: IfNotPresent
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
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dubbo-demo-consumer/dp.yaml
deployment.extensions/dubbo-demo-consumer configured
```

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/57.png)
