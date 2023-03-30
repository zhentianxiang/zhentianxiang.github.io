---
layout: post
title: Linux-Kubernetes-16-Apollo分环境部署duobbo结尾
date: 2021-05-07
tags: 实战-Kubernetes
---

## 创建测试环境和生产环境的项目

### 创建dubbo服务提供者的项目

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/1.png)

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/2.png)

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/3.png)

### 创建dubbo服务消费者的项目

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/4.png)

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/5.png)

### 准备各个环境的域名解析

```sh
[root@host0-200 ~]# vim /var/named/od.com.zone
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020010519 ; serial
                10800      ; refresh (3 hours)
                900        ; retry (15 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
                )
                NS   dns.od.com.
$TTL 60 ; 1 minute
dns                A    10.0.0.200
harbor             A    10.0.0.200
k8s-yaml           A    10.0.0.200
traefik            A    10.0.0.10
dashboard          A    10.0.0.10
zk1                A    10.0.0.21
zk2                A    10.0.0.22
zk3                A    10.0.0.200
mirrors            A    10.0.0.100
jenkins            A    10.0.0.10
dubbo-monitor      A    10.0.0.10
demo               A    10.0.0.10
config             A    10.0.0.10
mysql              A    10.0.0.11
portal             A    10.0.0.10
zk-test            A    10.0.0.21
zk-prod            A    10.0.0.22
config-test        A    10.0.0.10
config-prod        A    10.0.0.10
demo-test          A    10.0.0.10
demo-prod          A    10.0.0.10
[root@host0-200 dubbo-demo-consumer]# systemctl restart named
```

### 准备测试环境dubbo提供者配置清单

把原先的提供者资源配置清单拷贝到测试环境专用的目录下

```sh
[root@host0-200 ~]# cp -a /data/k8s-yaml/dubbo-demo-service/* /data/k8s-yaml/test/dubbo-demo-service/
[root@host0-200 ~]# vim /data/k8s-yaml/test/dubbo-demo-service/dp.yaml
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: dubbo-demo-service
  namespace: test  #修改名称空间
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
        image: harbor.od.com/app/dubbo-demo-service:apollo_20210507_1740
        ports:
        - containerPort: 20880
          protocol: TCP
        env:
        - name: JAR_BALL
          value: dubbo-server.jar
        - name: C_OPTS                      #添加修改
          value: -Denv=fat -Dapollo.meta=http://config-test.od.com   #添加修改此位置
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
[root@host0-22 src]# kubectl apply -f http://k8s-yaml.od.com/test/dubbo-demo-service/dp.yaml
```

把消费者的资源配置清单拷贝到测试环境目录下

```sh
[root@host0-200 ~]# cp -a /data/k8s-yaml/dubbo-demo-consumer/* /data/k8s-yaml/test/dubbo-demo-consumer/
[root@host0-200 ~]# vim /data/k8s-yaml/test/dubbo-demo-consumer/dp.yaml
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: dubbo-demo-consumer
  namespace: test  #修改此位置
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
        image: harbor.od.com/app/dubbo-demo-consumer:apollo_20210507_1750
        ports:
        - containerPort: 8080
          protocol: TCP
        - containerPort: 20880
          protocol: TCP
        env:
        - name: JAR_BALL
          value: dubbo-client.jar
        - name: C_OPTS                      #添加修改此位置
          value: -Denv=fat -Dapollo.meta=http://config-test.od.com #添加修改此位置
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

```sh
[root@host0-200 ~]# vim /data/k8s-yaml/test/dubbo-demo-consumer/svc.yaml
kind: Service
apiVersion: v1
metadata:
  name: dubbo-demo-consumer
  namespace: test  #修改此位置
spec:
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
  selector:
    app: dubbo-demo-consumer
  clusterIP: None
```

```sh
[root@host0-200 ~]# vim /data/k8s-yaml/test/dubbo-demo-consumer/ingress.yaml
kind: Ingress
apiVersion: extensions/v1beta1
metadata:
  name: dubbo-demo-consumer
  namespace: test
spec:
  rules:
  - host: demo-test.od.com  #修改此位置
    http:
      paths:
      - path: /
        backend:
          serviceName: dubbo-demo-consumer
          servicePort: 8080
```

### 应用资源配置清单

```sh
[root@host0-22 src]# kubectl apply -f http://k8s-yaml.od.com/test/dubbo-demo-consumer/dp.yaml
deployment.extensions/dubbo-demo-consumer created
[root@host0-22 src]# kubectl apply -f http://k8s-yaml.od.com/test/dubbo-demo-consumer/svc.yaml
service/dubbo-demo-consumer created
[root@host0-22 src]# kubectl apply -f http://k8s-yaml.od.com/test/dubbo-demo-consumer/ingress.yaml
ingress.extensions/dubbo-demo-consumer created
```

**生产环境prod同上，只是把名称空间做个修改，一定要注意修改dp的环境变量为pro**
```sh
[root@host0-200 ~]# cp -a /data/k8s-yaml/test/dubbo-demo-service/* /data/k8s-yaml/prod/dubbo-demo-service/
[root@host0-200 ~]# cp -a /data/k8s-yaml/test/dubbo-demo-consumer/* /data/k8s-yaml/prod/dubbo-demo-consumer/
[root@host0-200 ~]# vim /data/k8s-yaml/prod/dubbo-demo-service/dp.yaml 
[root@host0-200 ~]# vim /data/k8s-yaml/prod/dubbo-demo-consumer/
dp.yaml       ingress.yaml  svc.yaml      
[root@host0-200 ~]# vim /data/k8s-yaml/prod/dubbo-demo-consumer/dp.yaml 
[root@host0-200 ~]# vim /data/k8s-yaml/prod/dubbo-demo-consumer/svc.yaml 
[root@host0-200 ~]# vim /data/k8s-yaml/prod/dubbo-demo-consumer/ingress.yaml
```
> 注意：其实dp资源配置清单中的value: -Denv=fat -Dapollo.meta=http://config-test.od.com ，要把fat换成pro，域名也要换成prod
>
> 后面的http内容可以修改为相同名称空间下的service集群资源的名字，也就是apollo-configservice，因为都是在同一个名称空间下，可以不用走
>
> ingress，直接在集群内部利用service资源去找config资源，也就是去找apollo配置管理。
>
> 注意：集群名称后面要加上8080端口，例：http://apollo-configservice:8080

### 最后应用资源配置清单并检查一下服务的启动日志

```sh
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/prod/dubbo-demo-service/dp.yaml
deployment.extensions/dubbo-demo-service created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/prod/dubbo-demo-consumer/dp.yaml
deployment.extensions/dubbo-demo-consumer created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/prod/dubbo-demo-consumer/svc.yaml
service/dubbo-demo-consumer created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/prod/dubbo-demo-consumer/ingress.yaml
ingress.extensions/dubbo-demo-consumer configured
```

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/6.png)

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/7.png)

## 测试

修改消费者源代码，然后重新打包新的镜像，然后再让测试环境的消费者重新拉去新的镜像

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/8.png)

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/9.png)

然后在把测试环境的消费者的镜像修改一下，然后重新生成pod，在查看网页内容变化，发现只有测试环境发生改变，

生产环境未改变，这就说明了测试环境和生产环境划分成功

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/10.png)

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/11.png)

![](/images/posts/Linux-Kubernetes/分环境部署dubbo/12.png)

### 服务器异常宕机重启

- 首先保证DNS正常启动
- 启动test和prod的configservice和configadmin服务
- 启动infra的portal
- 启动test和prod的dubbo服务
- 浏览器访问demo-test和demo-prod

