---
layout: post
title: Linux-Kubernetes-27-使用spinnaker进行自动化部署
date: 2021-05-16
tags: 实战-Kubernetes
---

# 使用spinnaker进行自动化部署

## 1. spinnaker概述和选型

### 1.1 概述

#### 1.1.1 主要功能

Spinnaker是一个开源的多云持续交付平台，提供快速、可靠、稳定的软件变更服务。主要包含两类功能：集群管理和部署管理

#### 1.1.2 集群管理

集群管理主要用于管理云资源，Spinnaker所说的”云“可以理解成AWS，即主要是laaS的资源，比如OpenStak，Google云，微软云等，后来还支持了容器与Kubernetes，但是管理方式还是按照管理基础设施的模式来设计的。

#### 1.1.3 部署管理

管理部署流程是Spinnaker的核心功能，使用minio作为持久化层，同时对接jenkins流水线创建的镜像，部署到Kubernetes集群中去，让服务真正运行起来。

#### 1.1.4 逻辑架构图

Spinnaker自己就是Spinnake一个微服务,由若干组件组成，整套逻辑架构图如下：
![](/images/posts/Linux-Kubernetes/spinnaker/spinnaker进行自动化部署/1.png)

- Deck是基于浏览器的UI。
- Gate是API网关。
- Spinnaker UI和所有api调用程序都通过Gate与Spinnaker进行通信。
- Clouddriver负责管理云平台，并为所有部署的资源编制索引/缓存。
- Front50用于管理数据持久化，用于保存应用程序，管道，项目和通知的元数据。
- Igor用于通过Jenkins和Travis CI等系统中的持续集成作业来触发管道，并且它允许在管道中使用Jenkins / Travis阶段。
- Orca是编排引擎。它处理所有临时操作和流水线。
- Rosco是管理调度虚拟机。
- Kayenta为Spinnaker提供自动化的金丝雀分析。
- Fiat 是Spinnaker的认证服务。
- Echo是信息通信服务。
- 它支持发送通知（例如，Slack，电子邮件，SMS），并处理来自Github之类的服务中传入的Webhook。

**服务组件端口**

| Service     | Port |
| :---------- | :--- |
| Clouddriver | 7002 |
| Deck        | 9000 |
| Echo        | 8089 |
| Fiat        | 7003 |
| Front50     | 8080 |
| Gate        | 8084 |
| Halyard     | 8064 |
| Igor        | 8088 |
| Kayenta     | 8090 |
| Orca        | 8083 |
| Rosco       | 8087 |
| Keel        | 8087 |

### 1.2 部署选型

[Spinnaker官网](https://www.spinnaker.io/)
Spinnaker包含组件众多,部署相对复杂,因此官方提供的脚手架工具halyard,但是可惜里面涉及的部分镜像地址被墙
[Armory发行版](https://www.armory.io/)
基于Spinnaker,众多公司开发了开发第三方发行版来简化Spinnaker的部署工作,例如我们要用的Armory发行版
Armory也有自己的脚手架工具,虽然相对halyard更简化了,但仍然部分被墙

因此我们部署的方式是手动交付Spinnaker的Armory发行版

## 2. 部署spinnaker第一部分

### 2.1 spinnaker之minio部署

#### 2.1.1 准备minio镜像

```sh
[root@host0-200 harbor]# docker pull minio/minio:latest
latest: Pulling from minio/minio
8f403cb21126: Pull complete 
65c0f2178ac8: Pull complete 
6e32ce08526e: Pull complete 
932fb72de569: Pull complete 
71bfd33c61af: Pull complete 
588b2addab38: Pull complete 
093f7de724c9: Pull complete 
Digest: sha256:fe69dcaed404faa1a36953513bf2fe2d5427071fa612487295eddb2b18cfe918
Status: Downloaded newer image for minio/minio:latest
docker.io/minio/minio:latest
[root@host0-200 harbor]# docker tag minio/minio:latest harbor.od.com/armory/minio:latest
[root@host0-200 harbor]# docker  push harbor.od.com/armory/minio:latest
The push refers to repository [harbor.od.com/armory/minio]
64500ed41576: Pushed 
5930fa31e9c1: Pushed 
d3b1e218425e: Pushed 
5498416a4a7d: Pushed 
fc65bea8cf35: Pushed 
144a43b910e8: Pushed 
4a2bc86056a8: Pushed 
latest: digest: sha256:b735a99a4e122121111f6c0d28216fd3c875c4b05d878f3f6b15da7b00250623 size: 1782
```

**准备目录**

```sh
[root@host0-200 harbor]# mkdir -pv /data/nfs-volume/minio
[root@host0-200 harbor]# mkdir -pv /data/k8s-yaml/armory/minio
mkdir: 已创建目录 "/data/k8s-yaml/armory"
mkdir: 已创建目录 "/data/k8s-yaml/armory/minio"
[root@host0-200 harbor]# cd /data/k8s-yaml/armory/minio
```

#### 2.1.2 准备dp资源清单

```sh
[root@host0-200 minio]# vim dp.yaml
kind: Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    name: minio
  name: minio
  namespace: armory
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      name: minio
  template:
    metadata:
      labels:
        app: minio
        name: minio
    spec:
      containers:
      - name: minio
        image: harbor.od.com/armory/minio:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9000
          protocol: TCP
        args:
        - server
        - /data
        env:
        - name: MINIO_ACCESS_KEY
          value: admin
        - name: MINIO_SECRET_KEY
          value: admin123
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /minio/health/ready
            port: 9000
            scheme: HTTP
          initialDelaySeconds: 10
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 5
        volumeMounts:
        - mountPath: /data
          name: data
      imagePullSecrets:
      - name: harbor
      volumes:
      - nfs:
          server: host0-200.host.com
          path: /data/nfs-volume/minio
        name: data
```

#### 2.1.3 准备svc资源清单

```sh
[root@host0-200 minio]# vim svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: armory
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 9000
  selector:
    app: minio
```

#### 2.1.4 准备ingress资源清单

```sh
[root@host0-200 minio]# vim ingress.yaml
kind: Ingress
apiVersion: extensions/v1beta1
metadata:
  name: minio
  namespace: armory
spec:
  rules:
  - host: minio.od.com
    http:
      paths:
      - path: /
        backend:
          serviceName: minio
          servicePort: 80
```

#### 2.1.5 应用资源配置清单

**任意master节点**
创建namespace和secret

```sh
[root@host0-22 ~]# kubectl create ns armory
namespace/armory created
[root@host0-22 ~]# kubectl create secret docker-registry harbor --docker-server=harbor.od.com --docker-username=admin --docker-password=Harbor12345 -n armory
secret/harbor created
```

```sh
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/armory/minio/dp.yaml
deployment.apps/minio created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/armory/minio/svc.yaml
service/minio created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/armory/minio/ingress.yaml
ingress.extensions/minio created
```

####  2.1.6 配置 named解析 

```sh
[root@host0-200 minio]# vim /var/named/od.com.zone
minio              A    10.0.0.10
[root@host0-200 minio]# systemctl restart named
```

浏览器测试访问http://minio.od.com

用户名密码为:admin/admin123
如果访问并登陆成功,表示minio部署成功

![](/images/posts/Linux-Kubernetes/spinnaker/spinnaker进行自动化部署/2.png)

### 2.2. spinnaker之redis部署

#### 2.2.1 准备镜像 

```sh
[root@host0-200 minio]# docker pull redis:4.0.14
4.0.14: Pulling from library/redis
54fec2fa59d0: Pull complete 
9c94e11103d9: Pull complete 
04ab1bfc453f: Pull complete 
7988789e1fb7: Pull complete 
8ce1bab2086c: Pull complete 
40e134f79af1: Pull complete 
Digest: sha256:2e03fdd159f4a08d2165ca1c92adde438ae4e3e6b0f74322ce013a78ee81c88d
Status: Downloaded newer image for redis:4.0.14
docker.io/library/redis:4.0.14
[root@host0-200 minio]# docker tag redis:4.0.14 harbor.od.com/armory/redis:v4.0.14
[root@host0-200 minio]# docker push harbor.od.com/armory/redis:v4.0.14 
The push refers to repository [harbor.od.com/armory/redis]
4502cfd21986: Pushed 
327eedfc6a79: Pushed 
34b4fc871ab1: Pushed 
379ef5d5cb40: Pushed 
744315296a49: Pushed 
c2adabaecedb: Pushed 
v4.0.14: digest: sha256:5bd4fe08813b057df2ae55003a75c39d80a4aea9f1a0fbc0fbd7024edf555786 size: 1572
```

**准备目录**

```sh
[root@host0-200 minio]# mkdir -pv /data/k8s-yaml/armory/redis
mkdir: 已创建目录 "/data/k8s-yaml/armory/redis"
[root@host0-200 minio]# cd /data/k8s-yaml/armory/redis
```

#### 2.2.2 准备dp资源清单

```sh
[root@host0-200 redis]# vim dp.yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    name: redis
  name: redis
  namespace: armory
spec:
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      name: redis
  template:
    metadata:
      labels:
        app: redis
        name: redis
    spec:
      containers:
      - name: redis
        image: harbor.od.com/armory/redis:v4.0.14
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 6379
          protocol: TCP
      imagePullSecrets:
      - name: harbor
```

```sh
[root@host0-200 redis]# vim svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: armory
spec:
  ports:
  - port: 6379
    protocol: TCP
    targetPort: 6379
  selector:
    app: redis
```

#### 2.2.3 应用资源配置清单

```sh
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/armory/redis/dp.yaml
deployment.apps/redis created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/armory/redis/svc.yaml
service/redis created
```
