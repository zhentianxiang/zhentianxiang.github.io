---
layout: post
title: Linux-Kubernetes-06-交付dubbo微服务到k8s集群
date: 2021-04-27
tags: 实战-Kubernetes
---

## 准备以流水线任务制作dubbo提供者镜像

使用jenkins创建一个新的项目：dubbo-demo,选择流水线构建

![image-20210427185347120](/images/posts/Linux-Kubernetes/交付dubbo/7.png)

![image-20210427185347120](/images/posts/Linux-Kubernetes/交付dubbo/8.png)

**一共创建10个参数，8个字符参数，2个选项参数**

| 参数名     | 作用                  | 举例或说明                                              |
| ---------- | --------------------- | ------------------------------------------------------- |
| app_name   | 项目名                | dubbo_demo_service                                      |
| image_name | docker镜像名          | app/dubbo-demo-service                                  |
| git_repo   | 项目的git地址         | https://gitee.com/zhen-tianxiang/dubbo-demo-service.git |
| git_ver    | 项目的git分支或版本号 | master                                                  |
| add_tag    | 镜像标签,常用时间戳   | 20210427_1200                                           |
| mvn_dir    | 执行mvn编译的目录     | ./                                                      |
| target_dir | 编译产生包的目录      | ./target                                                |
| mvn_cmd    | 编译maven项目的命令   | mvc clean package -Dmaven.                              |
| base_image | 项目的docker底包      | 不同的项目底包不一样,下拉选择                           |
| maven      | maven软件版本         | 不同的项目可能maven环境不一样                           |

最后能勾选上清空空白字符就都勾选上
**第1个参数（字符参数）**

> 项目名称：app_name
>
> 描述：项目的名称，例：dubbo-demo-service（提供者）

**第2个参数（字符参数）**

> 项目名称：image_name
>
> 描述：docker镜像的名称，例：app/dubbo-demo-service

**第3个参数（字符参数）**

> 项目名称：git_repo
>
> 描述：项目所在的git中央仓库的地址，例：https://gitee.com/zhen-tianxiang/dubbo-demo-service.git

**第4个参数（字符参数）**

> 项目名称：git_ver
>
> 描述：项目在git中央仓库所对应的分支或者版本号

**第5个参数（字符参数）**

> 名称：add_tag
>
> 描述：docker镜像标签的一部分，日期时间戳，例：20210421_1954

**第6个参数（字符参数）**

> 名称：mvn_dir
>
> 默认值：./
>
> 描述：编译项目的目录，默认为项目的根目录

**第7个参数（字符参数）**

> 名称：target_dir
>
> 默认值：./target
>
> 描述：项目编译完成项目后产生的jar或war包所在的目录例：/dubbo-server/target

**第8个参数（字符参数）**

> 名称：mvn_cmd
>
> 默认值：mvn clean package -Dmaven.test.skip=true
>
> 描述：执行编译所用的命令

**第9个参数（选项参数）**

> 名称：base_image
>
> 默认值：base/jre8:8u112
>
>         base/jre7:7u80
>
> 描述：项目使用的dockers底层镜像

**第10个参数（选项参数）**

> 名称：maven
>
> 默认值：3.6.3-8u282
>
>         3.6.1-8u282
>
> 描述：执行编译使用的maven软件版本

### 编写流水线脚本

```sh
pipeline {
  agent any
    stages {
	  stage('pull') {
	    steps {
		  sh "git clone ${params.git_repo} ${params.app_name}/${env.BUILD_NUMBER} && cd ${params.app_name}/${env.BUILD_NUMBER} &&  git checkout ${params.git_ver}"
		}
	  }
	  stage('build') {
	    steps {
		  sh "cd ${params.app_name}/${env.BUILD_NUMBER} && /var/jenkins_home/maven-${params.maven}/bin/${params.mvn_cmd}"
		}
	  }
	  stage('package') {
	    steps {
		  sh "cd ${params.app_name}/${env.BUILD_NUMBER} && cd ${params.target_dir} && mkdir project_dir && mv *.jar ./project_dir"
		}
	  }
	  stage('image') {
	    steps {
		  writeFile file: "${params.app_name}/${env.BUILD_NUMBER}/Dockerfile", text: """FROM harbor.od.com/${params.base_image} 
		  ADD ${params.target_dir}/project_dir /opt/project_dir"""
		  sh "cd ${params.app_name}/${env.BUILD_NUMBER} && docker build -t harbor.od.com/${params.image_name}:${params.git_ver}_${params.add_tag} . && docker push harbor.od.com/${params.image_name}:${params.git_ver}_${params.add_tag}"
		}
	  }
	}
}
```

如果网络不是很好的话，那么下面的过程极有可能会报错，最后制作之前记得先去仓库创建一个app仓库(私有)。
![image-20210427015345819](/images/posts/Linux-Kubernetes/交付dubbo/补充7.png)
![image-20210427015345819](/images/posts/Linux-Kubernetes/交付dubbo/补充8.png)
![image-20210427015345819](/images/posts/Linux-Kubernetes/交付dubbo/补充9.png)
![image-20210427015345819](/images/posts/Linux-Kubernetes/交付dubbo/补充10.png)

### 镜像制作完成 

![image-20210427015345819](/images/posts/Linux-Kubernetes/交付dubbo/9.png)

![image-20210427015345819](/images/posts/Linux-Kubernetes/交付dubbo/10.png)

去harbor进行验证

![image-20210427015257741](/images/posts/Linux-Kubernetes/交付dubbo/11.png)

## 交付dubbo资源配置清单

### 创建资源配置清单

```sh
[root@host0-200 harbor]# mkdir /data/k8s-yaml/dubbo-demo-service && cd /data/k8s-yaml/dubbo-demo-service/
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
        image: harbor.od.com/app/dubbo-demo-service:master_20210427_0140
        ports:
        - containerPort: 20880
          protocol: TCP
        env:
        - name: JAR_BALL
          value: dubbo-server.jar
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

### 创建ns命名空间和secret字典

```sh
[root@host0-21 src]# kubectl create ns app
namespace/app created
[root@host0-21 src]# kubectl create secret docker-registry harbor --docker-server=harbor.od.com --docker-username=admin --docker-password=Harbor12345 -n app
secret/harbor created
```

### 应用资源清单

应用资源之前先看一下zookeeper的资源

```sh
[root@host0-11 src]# sh /opt/zookeeper/bin/zkCli.sh
[zk: localhost:2181(CONNECTING) 0] 2021-04-27 02:09:23,643 [myid:] - INFO  [main-SendThread(localhost:2181):ClientCnxn$SendThread@1299] - Session establishment complete on server localhost/127.0.0.1:2181, sessionid = 0x30000f0fffc0000, negotiated timeout = 30000

WATCHER::

WatchedEvent state:SyncConnected type:None path:null

[zk: localhost:2181(CONNECTED) 0] ls /
[zookeeper]
[zk: localhost:2181(CONNECTED) 1] 
```

应用资源

```sh
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/dubbo-demo-service/dp.yaml
deployment.extensions/dubbo-demo-service created
[root@host0-22 ~]# kubectl get pods -n app 
NAME                                 READY   STATUS              RESTARTS   AGE
dubbo-demo-service-d45fc484d-62w2v   0/1     ContainerCreating   0          9s
```

![image-20210427021242529](/images/posts/Linux-Kubernetes/交付dubbo/12.png)

![image-20210427021325364](/images/posts/Linux-Kubernetes/交付dubbo/13.png)

在次查看注册中心发现dubbo提供者服务已经注册到里面了

```sh
WATCHER::

WatchedEvent state:SyncConnected type:None path:null

[zk: localhost:2181(CONNECTED) 0] ls
[zk: localhost:2181(CONNECTED) 1] ls /
[zookeeper]
[zk: localhost:2181(CONNECTED) 2] ls /
[dubbo, zookeeper]
[zk: localhost:2181(CONNECTED) 3] ls /dubbo
[com.od.dubbotest.api.HelloService]
[zk: localhost:2181(CONNECTED) 4] 
```

## 交付dubbo-monitor到K8S集群（监控）

### 下载 源码包

[dubbo-monitor下载地址](https://github.com/Jeromefromcn/dubbo-monitor/archive/master.zip)

```sh
[root@host0-200 ~]# wget https://github.com/Jeromefromcn/dubbo-monitor/archive/master.zip
[root@host0-200 ~]# unzip master.zip
[root@host0-200 ~]# mv dubbo-monitor-master /opt/src/dubbo-monitor
```

### 修改源码包

我怎么写的你就怎么抄，该删的记得删，该改的记得改

```sh
[root@host0-200 ~]# vim /opt/src/dubbo-monitor/dubbo-monitor-simple/conf/dubbo_origin.properties
##
# Copyright 1999-2011 Alibaba Group.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
##
dubbo.container=log4j,spring,registry,jetty
dubbo.application.name=dubbo-monitor
dubbo.application.owner=zhentianxiang
dubbo.registry.address=zookeeper://zk1.od.com:2181?backup=zk2.od.com:2181,zk3.od.com:2181
dubbo.protocol.port=20880
dubbo.jetty.port=8080
dubbo.jetty.directory=/dubbo-monitor-simple/monitor
dubbo.charts.directory=/dubbo-monitor-simple/charts
dubbo.statistics.directory=/dubbo-monitor-simple/statistics
dubbo.log4j.level=WARN
```

### 制作配置文件

```sh
[root@host0-200 ~]# mkdir -pv /data/dockerfile/dubbo-monitor
[root@host0-200 ~]# cp -r /opt/src/dubbo-monitor/* /data/dockerfile/dubbo-monitor/
[root@host0-200 ~]# cd /data/dockerfile/dubbo-monitor/
[root@host0-200 dubbo-monitor]# ls
Dockerfile  dubbo-monitor-simple  README.md
[root@host0-200 dubbo-monitor]# vim dubbo-monitor-simple/bin/start.sh
 58 if [ -n "$BITS" ]; then
 59     JAVA_MEM_OPTS=" -server -Xmx128m -Xms128m -Xmn32m -XX:PermSize=16m -Xss256k -XX:+DisableExplicitGC -XX:+UseConcMarkSweepGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSCompactAtFullCollection -XX:LargePageSizeInBytes=128m -XX:+UseFastAcc    essorMethods -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=70 "
 60 else
 61     JAVA_MEM_OPTS=" -server -Xms128m -Xmx128m -XX:PermSize=16m -XX:SurvivorRatio=2 -XX:+UseParallelGC "
 62 fi
 63 
 64 echo -e "Starting the $SERVER_NAME ...\c"
 65 exec  java $JAVA_OPTS $JAVA_MEM_OPTS $JAVA_DEBUG_OPTS $JAVA_JMX_OPTS -classpath $CONF_DIR:$LIB_JARS com.alibaba.dubbo.container.Main > $STDOUT_FILE 2>&1
```

> 注：脚本的59、61、65行jvm进行调优
>
> 64行java启动脚本改成exec开头，并删除最后的&，让java前台执行，并接管这个shell的进程pid，并删除此行以下的所有内容

```sh
[root@host0-200 dubbo-monitor]# docker build -t harbor.od.com/infra/dubbo-monitor:latest .
[root@host0-200 ~]# docker push harbor.od.com/infra/dubbo-monitor:latest
```

### 准备资源配置清单

```sh
[root@host0-200 ]# mkdir -pv /data/k8s-yaml/dubbo-monitor 
mkdir: 已创建目录 "/data/k8s-yaml/dubbo-monitor"
[root@host0-200 k8s-yaml]# 
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
[root@host0-200 ~]# vim /data/k8s-yaml/dubbo-monitor/svc.yaml
kind: Service
apiVersion: v1
metadata: 
  name: dubbo-monitor
  namespace: infra
spec:
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
  selector: 
    app: dubbo-monitor
  clusterIP: None
  type: ClusterIP
  sessionAffinity: None
[root@host0-200 ~]# vim /data/k8s-yaml/dubbo-monitor/ingress.yaml
kind: Ingress
apiVersion: extensions/v1beta1
metadata: 
  name: dubbo-monitor
  namespace: infra
spec:
  rules:
  - host: dubbo-monitor.od.com
    http:
      paths:
      - path: /
        backend: 
          serviceName: dubbo-monitor
          servicePort: 8080
```

### 应用资源配置清单

```sh
[root@host0-21 ]# kubectl apply -f http://k8s-yaml.od.com/dubbo-monitor/svc.yaml
[root@host0-21 ]# kubectl apply -f http://k8s-yaml.od.com/dubbo-monitor/dp.yaml
[root@host0-21 ]# kubectl apply -f http://k8s-yaml.od.com/dubbo-monitor/ingress.yaml
```

### 域名解析

```sh
[root@host0-200 ~]# vim /var/named/od.com.zone
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020010511 ; serial
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
zk1                A    10.0.0.11
zk2                A    10.0.0.12
zk3                A    10.0.0.21
mirrors            A    10.0.0.200
jenkins            A    10.0.0.10
dubbo-monitor      A    10.0.0.10
[root@host0-15 ~]# systemctl restart named
```

![image-20210427145632504](/images/posts/Linux-Kubernetes/交付dubbo/14.png)

## 交付dubbo消费者

### Jenkins制作镜像

![image-20210427171031208](/images/posts/Linux-Kubernetes/交付dubbo/15.png)

![image-20210427171737082](/images/posts/Linux-Kubernetes/交付dubbo/16.png)

![image-20210427171536801](/images/posts/Linux-Kubernetes/交付dubbo/17.png)

![image-20210427171556692](/images/posts/Linux-Kubernetes/交付dubbo/18.png)

![image-20210427171823888](/images/posts/Linux-Kubernetes/交付dubbo/19.png)

### 准备资源配置清单

```sh
[root@host0-200 ]# mkdir -pv /data/k8s-yaml/dubbo-demo-consumer && cd /data/k8s-yaml/dubbo-demo-consumer
[root@host0-200 dubbo-demo-consumer]# cat dp.yaml 
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
        image: harbor.od.com/app/dubbo-demo-consumer:master_20210427_1700
        ports:
        - containerPort: 8080
          protocol: TCP
        - containerPort: 20880
          protocol: TCP
        env:
        - name: JAR_BALL
          value: dubbo-client.jar
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
[root@host0-200 dubbo-demo-consumer]# cat svc.yaml 
kind: Service
apiVersion: v1
metadata: 
  name: dubbo-demo-consumer
  namespace: app
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
[root@host0-200 dubbo-demo-consumer]# cat ingress.yaml 
kind: Ingress
apiVersion: extensions/v1beta1
metadata: 
  name: dubbo-demo-consumer
  namespace: app
spec:
  rules:
  - host: demo.od.com
    http:
      paths:
      - path: /
        backend: 
          serviceName: dubbo-demo-consumer
          servicePort: 8080
```

### 提交资源配置清单

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dubbo-demo-consumer/svc.yaml
deployment.extensions/dubbo-demo-consumer created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dubbo-demo-consumer/dp.yaml
service/dubbo-demo-consumer created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dubbo-demo-consumer/ingress.yaml
ingress.extensions/dubbo-demo-consumer created
```

### 解析域名

```sh
[root@host0-15 ~]# cat  /var/named/od.com.zone 
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020010511 ; serial
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
mirrors            A    10.0.0.200
jenkins            A    10.0.0.10
dubbo-monitor      A    10.0.0.10
demo               A    10.0.0.10

[root@host0-15 ~]# systemctl restart naemd
[root@host0-15 ~]# dig -t A demo.od.com @10.0.0.200 +short
10.0.0.10
```

![image-20210427173512935](/images/posts/Linux-Kubernetes/交付dubbo/20.png)

![image-20210427173533679](/images/posts/Linux-Kubernetes/交付dubbo/21.png)

![image-20210427180658020](/images/posts/Linux-Kubernetes/交付dubbo/22.png)

![image-20210427180714732](/images/posts/Linux-Kubernetes/交付dubbo/23.png)

至此就完成了duboo的全部搭建，应对没有状态服务，k8s可以随意的给你扩容集群，而ingress就会自动的进行调度流量为你合理的划分分配流量，如果不用k8s集群部署服务，还得申请开通虚拟机，部署底层服务（Java环境）以及各种这包那包的还得启动弄脚本改配置，还要挂载到负载均衡器上，而现在鼠标点点扩缩容就完成了集群部署的问题。
