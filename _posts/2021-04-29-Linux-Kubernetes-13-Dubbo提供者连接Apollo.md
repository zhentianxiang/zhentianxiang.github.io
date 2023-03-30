---
layout: post
title: Linux-Kubernetes-13-Dubbo提供者连接Apollo
date: 2021-04-29
tags: 实战-Kubernetes
---
### 配置相关登陆信息

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/19.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/20.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/21.png)

### 明白管理员工具里面的相关服务

### 系统参数

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/22.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/23.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/24.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/25.png)

测试添加数据信息

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/26.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/27.png)

### 创建dubbo提供者的项目

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/28.png)

这就创建了一个dubbo提供者的Apollo配置项目

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/29.png)

### 配置dubbo提供者的Apollo配置项

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/30.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/31.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/32.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/33.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/34.png)

### 制作dubbo提供者连接Apollo的镜像

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/35.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/36.png)

### 修改资源配置清单

或者直接再dashboard控制台修改镜像

```sh
[root@host0-200 conf]# cd /data/k8s-yaml/dubbo-demo-service/
[root@host0-200 dubbo-demo-service]# ls
dp.yaml
[root@host0-200 dubbo-demo-service]# vim dp.yaml 

kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: dubbo-demo-service
  namespace: app
  labels:
    name: dubbo-demo-service
spec:
  replicas: 1
  selector:
    matchLabels:
      name: dubbo-demo-service
  template:
    metadata:
      labels:
        app: dubbo-demo-service
        name: dubbo-demo-service
    spec:
      containers:
      - name: dubbo-demo-service
        image: harbor.od.com/app/dubbo-demo-service:apollo_20210429_1730
        ports:
        - containerPort: 20880
          protocol: TCP
        env:
        - name: JAR_BALL
          value: dubbo-server.jar
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

```
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dubbo-demo-service/dp.yaml
deployment.extensions/dubbo-demo-consumer configured
```

### 查看容器的变化

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/37.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/38.png)

发现dubbo已经连接到了Apollo注册中心，这时再添加一个dubbo提供者

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/39.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/40.png)

查看monitor监控

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/41.png)

### 通过apollo来修改容器的监听端口

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/42.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/43.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/44.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/45.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/46.png)

### 测试修改消费者的zk主机

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/补充1.png)
![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/补充2.png)
![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/补充3.png)
![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/补充4.png)
![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/补充5.png)
![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/补充6.png)
![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/补充7.png)
