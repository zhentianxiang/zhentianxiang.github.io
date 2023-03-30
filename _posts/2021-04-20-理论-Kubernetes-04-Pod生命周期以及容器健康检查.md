---
layout: post
title: 理论-Kubernetes-04-Pod生命周期以及容器健康检查
date: 2021-04-20
tags: 理论-Kubernetes
---

## 关于创建Pod

> 比如说我们有一个pod，里面有两个容器，因为某些问题导致容器里面的服务已经死掉了，但是pod的状态还是running。所以我们要怎样去知道这个pod到底是不是处于一个我们认可的运行中呢

### 1.创建Pod流程

> **第一步：**
>
> kubectl 向api server 发起一个create pod 请求 
>
> **第二步：**
>
> api server接收到pod创建请求后，不会去直接创建pod，而是生成一个包含创建信息的yaml。
>
> **第三步：**
>
> apiserver 将刚才的yaml信息写入etcd数据库。到此为止仅仅是在etcd中添加了一条记录， 还没有任何的实质性进展。
>
> **第四步：**
>
> scheduler 查看 k8s api ，类似于通知机制。
> 首先判断：pod.spec.Node == null?
> 若为null，表示这个Pod请求是新来的，需要创建；因此先进行调度计算，找到最“闲”的node。
> 然后将信息在etcd数据库中更新分配结果：pod.spec.Node = nodeA (设置一个具体的节点)
> ps:同样上述操作的各种信息也要写到etcd数据库中中。
>
> **第五步：**
>
> kubelet 通过监测etcd数据库(即不停地看etcd中的记录)，发现api server 中有了个新的Node；
> 如果这条记录中的Node与自己的编号相同(即这个Pod由scheduler分配给自己了)；
> 则调用node中的docker api，创建container。

### 2.Pause基础容器

> 首先我们下发指令，然后api-server接收到之后会进行容器环境初始化，pod创建需要init C的初始化，pod创建完之后init C会死亡，并且每一个init C进程结束之后才会进行下一个init C进程的进行。
>
> 其实在容器生成之前还会有一个pause的基础容器，每个Pod里运行着一个特殊的被称之为Pause的容器，其他容器则为业务容器，这些业务容器共享Pause容器的网络栈和Volume挂载卷，因此他们之间通信和数据交换更为高效，在设计时我们可以充分利用这一特性将一组密切相关的服务进程放入同一个Pod中。同一个Pod里的容器之间仅需通过localhost就能互相通信。

-----

**kubernetes中的pause容器主要为每个业务容器提供以下功能：**

- PID命名空间：Pod中的不同应用程序可以看到其他应用程序的进程ID。

- 网络命名空间：Pod中的多个容器能够访问同一个IP和端口范围。

- IPC命名空间：Pod中的多个容器能够使用SystemV IPC或POSIX消息队列进行通信。

- UTS命名空间：Pod中的多个容器共享一个主机名；Volumes（共享存储卷）：

- Pod中的各个容器可以访问在Pod级别定义的Volumes。

----

## 什么是 Container Probes

> 每个Node节点上都有 `kubelet` ，Container Probe 也就是容器的健康检查是由 `kubelet` 定期执行的。

Kubelet通过调用Pod中容器的[Handler](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.11/#probe-v1-core)来执行检查的动作，Handler有三种类型。

- ExecAction，在容器中执行特定的命令，命令退出返回0表示成功
- TCPSocketAction，根据容器IP地址及特定的端口进行TCP检查，端口开放表示成功
- HTTPGetAction，根据容器IP、端口及访问路径发起一次HTTP请求，如果返回码在200到400之间表示成功
  每种检查动作都可能有三种返回状态。
- Success，表示通过了健康检查
- Failure，表示没有通过健康检查
- Unknown，表示检查动作失败

> 在创建Pod时，可以通过`liveness`和`readiness`两种方式来探测Pod内容器的运行情况。`liveness`可以用来检查容器内应用的存活的情况来，如果检查失败会杀掉容器进程，是否重启容器则取决于Pod的[重启策略](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/#restart-policy)。`readiness`检查容器内的应用是否能够正常对外提供服务，如果探测失败，则Endpoint Controller会将这个Pod的IP从服务中删除。

----

### 1.大白话解释

> 如果说我们有一个pod（nginx），它的状态是running了，已经集群外提供服务了，但是它里面的服务没有正常起来，比如80端口没有监听，那么他的状态还是running，这就导致了它从根本上没有对我们提供服务，所以说它的状态还是running，那不就是在扯淡吗。
>
> 那么我们如何正确的判断这个pod里面的服务有没有正常启动呢？所以我们就需要`readiness（就绪性探针）`，它会根据命令、TCP、http连接来判断这个服务到底有没有被外界正常访问，从而来判断这个容器是否是正常的running。
>
> 那么再比如说一个nginx Pod，它的问题是无法访问，但是端口还在正常监听，所以readiness无法进行判断，这个时候就需要还有`liveness（存活性检查）`，它会检查这个服务到底有没有正常的被外界访问，如果检查是失败的，它会杀死Pod然后重新启动Pod。

### 2. 应用场景

> 我们都知道Kubernetes会维持Pod的状态及个数，因此如果你只是希望保持Pod内容器失败后能够重启，那么其实没有必要添加健康检查，只需要合理配置Pod的重启策略即可。更适合健康检查的场景是在我们根据检查结果需要主动杀掉容器并重启的场景，还有一些容器在正式提供服务之前需要加载一些数据，那么可以采用`readiness`来检查这些动作是否完成。

### 3.liveness 检查实例

#### Exec

通过命令进行检查检查

```sh
#定义api版本
apiVersion: v1
#定义资源类型pod
kind: Pod
#定义元数据
metadata:
#定义标签
  labels:
    test: liveness
#定义标签名字
  name: liveness-exec
#定义容器
spec:
  containers:
#定于容器名称
  - name: liveness
#定义容器使用镜像
    image: docker.io/alpine
#指定多个启动命令参数，因为是数组可以指定多个
    args:
    - /bin/sh
    - -c
#容器启动时创建一个文件，容器运行30秒后，将文件删除，为了容器为了不可避免的退出，所以停留600秒等待健康检查
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
#定义liveness探针
    livenessProbe:
#进入容器
      exec:
#执行命令进行探测
        command:
        - cat
        - /tmp/healthy
#容器创建好5秒后开始检测
      initialDelaySeconds: 5
#每5秒执行一次
      periodSeconds: 5
```

> 这样的话一开始容器是running的，30秒之后应该会重启，之后再次存活30秒，如果不想容器重启，只需要删除【sleep 30; rm -rf /tmp/healthy; sleep 600】

####  HTTP

通过http进行健康检查

```sh
apiVersion: v1
kind: Pod
metadata:
  labels:
    test: liveness
    app: httpd
  name: liveness-http
spec:
  containers:
  - name: liveness
    image: docker.io/httpd
    ports:
    - containerPort: 80
#定义liveness探针
    livenessProbe:
#访问index.html是否存有来判断服务是否存活
      httpGet:
        path: /index.html
#定义要以80端口访问
        port: 80
#定义http访问开头
        httpHeaders:
        - name: X-Custom-Header
          value: Awesome
#容器创建好5秒后开始检测
      initialDelaySeconds: 5
#每5秒执行一次
      periodSeconds: 5
```

#### TCP

不再做解释，相信能看的明白

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: default 
  labels:
    app: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        livenessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
```



### 4.readiness

#### exec样例

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: busybox-deployment
  namespace: default
  labels:
    app: busybox
spec:
  selector:
    matchLabels:
      app: busybox
  replicas: 3
  template:
    metadata:
      labels:
        app: busybox
 
    spec:
      containers:
      - name: busybox
        image: busybox:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
#指定多个启动命令参数，因为是数组可以指定多个
        args:
        - /bin/sh
        - -c
#容器启动时创建一个文件，容器运行30秒后，将文件删除，为了容器为了不可避免的退出，所以停留600秒等待健康检查
        - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
#定义readiness探针
        readinessProbe:
#进入容器
          exec:
#执行命令进行探测
            command:
            - cat
            - /tmp/healthy
#容器创建好5秒后开始检测
          initialDelaySeconds: 5
#每5秒执行一次
          periodSeconds: 5
```

> readiness类型的pod启动，创建健康检查文件，这个时候是正常的，30s后删除，ready变成0，但pod没有被删除或者重启，k8s只是不管他了，仍然可以登录

```sh
[root@k8s-master health]# kubectl get pods
NAME                                  READY   STATUS    RESTARTS   AGE
busybox-deployment-6f86ddd894-l9phc   0/1     Running   0          3m10s
busybox-deployment-6f86ddd894-lh46t   0/1     Running   0          3m
busybox-deployment-6f86ddd894-sz5c2   0/1     Running   0          3m17s
```

#### http样例

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: default
  labels:
    app: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx
 
    spec:
      containers:
      - name: nginx
        image: nginx
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
#定义一个readiness类型的探针
        readinessProbe:
#访问index.html文件
          httpGet:
            path: /index.html
#定义要以80端口访问
            port: 80
#定义http访问开头
            httpHeaders:
            - name: X-Custom-Header
              value: hello
#容器创建好5秒后开始检测
          initialDelaySeconds: 5
#每5秒执行一次
          periodSeconds: 3
```

**创建一个svc能访问**

```sh
apiVersion: v1
#定义资源为service
kind: Service
#定义元数据
metadata:
#名字为nginx
  name: nginx
spec:
#服务暴露类型
  type: NodePort
#定义暴露端口
  ports:
#容器外端口
    - port: 80
#容器内端口
      nodePort: 30001
#标签选择器
  selector:  
    app: nginx
```

**测试服务可以访问**

```sh
[root@k8s-master health]# kubectl get pods -o wide
NAME                                READY   STATUS    RESTARTS   AGE   IP            NODE         NOMINATED NODE   READINESS GATES
nginx-deployment-7db8445987-9wplj   1/1     Running   0          57s   10.254.1.81   k8s-node-1   <none>           <none>
nginx-deployment-7db8445987-mlc6d   1/1     Running   0          57s   10.254.2.65   k8s-node-2   <none>           <none>
[root@k8s-master health]# kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP        5d3h
nginx        NodePort    10.108.167.58   <none>        80:30001/TCP   27m
[root@k8s-master health]#
[root@k8s-master health]# curl -I 10.108.167.58:30001/index.html
HTTP/1.1 200 OK
Server: nginx/1.17.3
Date: Tue, 03 Sep 2019 04:40:05 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 13 Aug 2019 08:50:00 GMT
Connection: keep-alive
ETag: "5d5279b8-264"
Accept-Ranges: bytes
```

**修改容器的配置文件**

把index文件删除

```sh
[root@k8s-master health]# kubectl exec -it  nginx-deployment-7db8445987-9wplj /bin/bash
root@nginx-deployment-7db8445987-9wplj:/# cd /usr/share/nginx/html/
root@nginx-deployment-7db8445987-9wplj:/usr/share/nginx/html# ls
50x.html  index.html
root@nginx-deployment-7db8445987-9wplj:/usr/share/nginx/html# rm -f index.html
root@nginx-deployment-7db8445987-9wplj:/usr/share/nginx/html# nginx -s reload
2019/09/03 03:58:52 [notice] 14#14: signal process started
root@nginx-deployment-7db8445987-9wplj:/usr/share/nginx/html# exit
[root@k8s-master health]# kubectl get pods -o wide
NAME                                READY   STATUS    RESTARTS   AGE    IP            NODE         NOMINATED NODE   READINESS GATES
nginx-deployment-7db8445987-9wplj   0/1     Running   0          110s   10.254.1.81   k8s-node-1   <none>           <none>
nginx-deployment-7db8445987-mlc6d   1/1     Running   0          110s   10.254.2.65   k8s-node-2   <none>           <none>

#此时已经无法正常访问，出现404报错
[root@k8s-master health]# curl -I 10.254.1.81/index.html
HTTP/1.1 404 Not Found
Server: nginx/1.17.3
Date: Tue, 03 Sep 2019 03:59:16 GMT
Content-Type: text/html
Content-Length: 153
Connection: keep-alive

#查看容器详细信息提示: HTTP probe failed with statuscode: 404，探测失败
[root@k8s-master health]# kubectl describe pod nginx-deployment-7db8445987-9wplj
Events:
  Type     Reason     Age                    From                 Message
  ----     ------     ----                   ----                 -------
  Normal   Scheduled  43m                    default-scheduler    Successfully assigned default/nginx-deployment-7db8445987-9wplj tok8s-node-1
  Normal   Pulled     43m                    kubelet, k8s-node-1  Container image "nginx" already present on machine
  Normal   Created    43m                    kubelet, k8s-node-1  Created container nginx
  Normal   Started    43m                    kubelet, k8s-node-1  Started container nginx
  Warning  Unhealthy  3m47s (x771 over 42m)  kubelet, k8s-node-1  Readiness probe failed: HTTP probe failed with statuscode: 404
```

**不在分发流量**

多 curl几次集群IP

```sh
[root@k8s-master health]# curl -I 10.108.167.58:30001/index.html
HTTP/1.1 200 OK
Server: nginx/1.17.3
Date: Tue, 03 Sep 2019 04:40:05 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 13 Aug 2019 08:50:00 GMT
Connection: keep-alive
ETag: "5d5279b8-264"
Accept-Ranges: bytes
```

查看日志只有没被删除文件的容器可以正常接受流量，删除文件的容器不在接受流量

```sh
[root@k8s-master health]# kubectl logs  nginx-deployment-7db8445987-mlc6d | tail -10
10.254.1.0 - - [03/Sep/2019:04:43:44 +0000] "HEAD /index.html HTTP/1.1" 200 0 "-" "curl/7.29.0" "-"
10.254.1.0 - - [03/Sep/2019:04:43:45 +0000] "HEAD /index.html HTTP/1.1" 200 0 "-" "curl/7.29.0" "-"
10.254.1.0 - - [03/Sep/2019:04:43:45 +0000] "HEAD /index.html HTTP/1.1" 200 0 "-" "curl/7.29.0" "-"
10.254.2.1 - - [03/Sep/2019:04:43:46 +0000] "GET /index.html HTTP/1.1" 200 612 "-" "kube-probe/1.15" "-"
10.254.2.1 - - [03/Sep/2019:04:43:49 +0000] "GET /index.html HTTP/1.1" 200 612 "-" "kube-probe/1.15" "-"
10.254.2.1 - - [03/Sep/2019:04:43:52 +0000] "GET /index.html HTTP/1.1" 200 612 "-" "kube-probe/1.15" "-"
10.254.2.1 - - [03/Sep/2019:04:43:55 +0000] "GET /index.html HTTP/1.1" 200 612 "-" "kube-probe/1.15" "-"
10.254.2.1 - - [03/Sep/2019:04:43:58 +0000] "GET /index.html HTTP/1.1" 200 612 "-" "kube-probe/1.15" "-"
10.254.2.1 - - [03/Sep/2019:04:44:01 +0000] "GET /index.html HTTP/1.1" 200 612 "-" "kube-probe/1.15" "-"
10.254.2.1 - - [03/Sep/2019:04:44:04 +0000] "GET /index.html HTTP/1.1" 200 612 "-" "kube-probe/1.15" "-"
[root@k8s-master health]# kubectl logs  nginx-deployment-7db8445987- | tail -10
nginx-deployment-7db8445987-9wplj  nginx-deployment-7db8445987-mlc6d
[root@k8s-master health]# kubectl logs  nginx-deployment-7db8445987-9wplj | tail -10
2019/09/03 04:44:11 [error] 15#15: *939 open() "/usr/share/nginx/html/index.html" failed (2: No such file or directory), client: 10.254.1.1, server: localhost, request: "GET /index.html HTTP/1.1", host: "10.254.1.81:80"
10.254.1.1 - - [03/Sep/2019:04:44:11 +0000] "GET /index.html HTTP/1.1" 404 153 "-" "kube-probe/1.15" "-"
10.254.1.1 - - [03/Sep/2019:04:44:14 +0000] "GET /index.html HTTP/1.1" 404 153 "-" "kube-probe/1.15" "-"
2019/09/03 04:44:14 [error] 15#15: *940 open() "/usr/share/nginx/html/index.html" failed (2: No such file or directory), client: 10.254.1.1, server: localhost, request: "GET /index.html HTTP/1.1", host: "10.254.1.81:80"
2019/09/03 04:44:17 [error] 15#15: *941 open() "/usr/share/nginx/html/index.html" failed (2: No such file or directory), client: 10.254.1.1, server: localhost, request: "GET /index.html HTTP/1.1", host: "10.254.1.81:80"
10.254.1.1 - - [03/Sep/2019:04:44:17 +0000] "GET /index.html HTTP/1.1" 404 153 "-" "kube-probe/1.15" "-"
10.254.1.1 - - [03/Sep/2019:04:44:20 +0000] "GET /index.html HTTP/1.1" 404 153 "-" "kube-probe/1.15" "-"
2019/09/03 04:44:20 [error] 15#15: *942 open() "/usr/share/nginx/html/index.html" failed (2: No such file or directory), client: 10.254.1.1, server: localhost, request: "GET /index.html HTTP/1.1", host: "10.254.1.81:80"
2019/09/03 04:44:23 [error] 15#15: *943 open() "/usr/share/nginx/html/index.html" failed (2: No such file or directory), client: 10.254.1.1, server: localhost, request: "GET /index.html HTTP/1.1", host: "10.254.1.81:80"
10.254.1.1 - - [03/Sep/2019:04:44:23 +0000] "GET /index.html HTTP/1.1" 404 153 "-" "kube-probe/1.15" "-"
[root@k8s-master health]#
```

#### TCP

不再做解释，相信能看的明白

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: default 
  labels:
    app: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        readinessProbe:
          tcpSocket:
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
```

