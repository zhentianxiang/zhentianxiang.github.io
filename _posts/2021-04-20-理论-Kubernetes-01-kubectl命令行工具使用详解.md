---
layout: post
title: 理论-Kubernetes-01-kubectl命令行工具使用详解
date: 2021-04-20
tags: 理论-Kubernetes
---

# 管理K8S核心资源的三种基本方法

- 陈述式管理方法-主要依赖命令行CLI工具进行管理
- 声明式管理方法-主要依赖统一资源配置清单（manifest）进行管理
- GUI式管理方法-主要依赖图形化操作界面（web页面）进行管理

## 一、陈述式管理方法

### 1.查看名称空间

```
[root@master1 ~]# kubectl get ns  或者  kubectl get namespace
NAME              STATUS   AGE
default           Active   22h
kube-node-lease   Active   22h
kube-public       Active   22h
kube-system       Active   22h
```

### 2.查看命名空间里面的资源，指定命名空间

当资源在default命名空间下面的时候，默认可以不用 -n 指定

```
[root@master1 ~]# kubectl get all -n default
NAME                 READY   STATUS    RESTARTS   AGE
pod/nginx-ds-42hw6   1/1     Running   0          39m        #pod资源
pod/nginx-ds-px496   1/1     Running   0          39m        #pod资源


NAME                 TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE         #集群资源
service/kubernetes   ClusterIP   192.168.0.1   <none>        443/TCP   22h

NAME                      DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE        #pod控制器资源
daemonset.apps/nginx-ds   2         2         2       2            2           <none>          39m
```

### 3.创建命名空间

```
[root@master1 ~]# kubectl  create ns app
namespace/app created
[root@master1 ~]# kubectl get ns
NAME              STATUS   AGE
app               Active   6s
default           Active   22h
kube-node-lease   Active   22h
kube-public       Active   22h
kube-system       Active   22h
```

### 4.删除命名空间

```
[root@master1 ~]# kubectl delete ns app
namespace "app" deleted
[root@master1 ~]# kubectl get ns
NAME              STATUS   AGE
default           Active   22h
kube-node-lease   Active   22h
kube-public       Active   22h
kube-system       Active   22h
```

## 管理Deployment资源

### 1.创建deployment（pod控制器）

用来保证拉起pod，让他始终无限地接近pod事先提供的一个预期

创建一个pod的过程是：本地kubectl下发指令走127.0.0.1找到api-server，api-server去找scheduler，scheduler发现两台主机都挺闲的，然后扔色子方式去让哪台主机创建pod容器，如果说扔色子扔到另外一台node节点上了，那么它会走10.0.0.10:7443这个vip传递信息，因为kubectl的启动文件中写死了10.0.0.10:7443地址，kubectl签发了一套以自己为服务端的证书，api-server作为客户端。 

```
[root@master1 ~]# kubectl create deployment nginx-dp --image=harbor.od.com/public/nginx:src_1.14.2 -n kube-public
deployment.apps/nginx-dp created
```

### 2.查看pod

```
[root@master1 ~]# kubectl get pods -n kube-public
NAME                        READY   STATUS    RESTARTS   AGE
nginx-dp-79d757b7fb-nk2g6   1/1     Running   0          11s
```

### 3.扩展查看

```
[root@master1 ~]# kubectl get pods -n kube-public -o wide
NAME                        READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
nginx-dp-79d757b7fb-nk2g6   1/1     Running   0          59s   172.7.11.3   master1.host.com   <none>           <none>
```

### 4.详细查看

```
[root@master1 ~]# kubectl describe deployment nginx-dp -n kube-public
Name:                   nginx-dp
Namespace:              kube-public
CreationTimestamp:      Tue, 30 Mar 2021 19:44:51 +0800
Labels:                 app=nginx-dp
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=nginx-dp
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=nginx-dp
  Containers:
   nginx:
    Image:        harbor.od.com/public/nginx:src_1.14.2
    Port:         <none>
    Host Port:    <none>
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   nginx-dp-79d757b7fb (1/1 replicas created)
Events:
  Type    Reason             Age    From                   Message
  ----    ------             ----   ----                   -------
  Normal  ScalingReplicaSet  6m10s  deployment-controller  Scaled up replica set nginx-dp-79d757b7fb to 1
```

### 5.进入到pod资源

```
[root@master1 ~]# kubectl get pods -n kube-public -o wide
NAME                        READY   STATUS    RESTARTS   AGE   IP           NODE               NOMINATED NODE   READINESS GATES
nginx-dp-79d757b7fb-nk2g6   1/1     Running   0          35m   172.7.11.3   master1.host.com   <none>           <none>
[root@master1 ~]# kubectl exec -it nginx-dp-79d757b7fb-nk2g6 /bin/bash -n kube-public
root@nginx-dp-79d757b7fb-nk2g6:/# ip a
bash: ip: command not found
root@nginx-dp-79d757b7fb-nk2g6:/# ip addr
bash: ip: command not found
root@nginx-dp-79d757b7fb-nk2g6:/# ls
bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
```

### 6.删除pod资源（重启）

```
# 发现名字已经不一样了，就是重新起了一个pod，这就是pod的自我修复特性
[root@master1 ~]# kubectl delete pods nginx-dp-79d757b7fb-nk2g6 -n kube-public
pod "nginx-dp-79d757b7fb-nk2g6" deleted
[root@master1 ~]# kubectl get pods -n kube-public
NAME                        READY   STATUS    RESTARTS   AGE
nginx-dp-79d757b7fb-hlsq2   1/1     Running   0          55s
# 并且通过此次scheduler的策略，pod被分配到了master2的node节点上
[root@master1 ~]# kubectl get pods -n kube-public -o wide
NAME                        READY   STATUS    RESTARTS   AGE     IP           NODE               NOMINATED NODE   READINESS GATES
nginx-dp-79d757b7fb-hlsq2   1/1     Running   0          2m49s   172.7.12.3   master2.host.com   <none>           <none>
```

### 7.删除deployment

```
[root@master1 ~]# kubectl delete deployment nginx-dp -n kube-public
deployment.extensions "nginx-dp" deleted
```

## 管理service资源

### 1.在deployment中创建集群网络

```
[root@master1 ~]# kubectl expose deployment nginx-dp --port=80 -n kube-public
service/nginx-dp exposed
[root@master1 ~]# kubectl get all -n kube-public
NAME                            READY   STATUS    RESTARTS   AGE
pod/nginx-dp-79d757b7fb-hfj28   1/1     Running   0          2m33s


NAME               TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
service/nginx-dp   ClusterIP   192.168.92.255   <none>        80/TCP    22s


NAME                       READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/nginx-dp   1/1     1            1           2m33s

NAME                                  DESIRED   CURRENT   READY   AGE
replicaset.apps/nginx-dp-79d757b7fb   1         1         1       2m33s
```

### 2.查看service集群

```
[root@master1 ~]# kubectl get svc -n kube-public
NAME       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
nginx-dp   ClusterIP   192.168.92.255   <none>        80/TCP    13m
[root@master1 ~]# kubectl describe svc nginx-dp -n kube-public
Name:              nginx-dp
Namespace:         kube-public
Labels:            app=nginx-dp
Annotations:       <none>
Selector:          app=nginx-dp
Type:              ClusterIP
IP:                192.168.92.255
Port:              <unset>  80/TCP
TargetPort:        80/TCP
Endpoints:         172.7.11.3:80
Session Affinity:  None
Events:            <none>
[root@master1 ~]# 
```

### 3.测试是否能够访问到pod服务

```
[root@master1 ~]# kubectl get pods -n kube-public -o wide
NAME                        READY   STATUS    RESTARTS   AGE     IP           NODE               NOMINATED NODE   READINESS GATES
nginx-dp-79d757b7fb-hfj28   1/1     Running   0          3m31s   172.7.11.3   master1.host.com   <none>           <none>
[root@master1 ~]# curl 192.168.92.255
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```

### 4.为什么能够访问到集群内部的资源呢？

因为是由ipvs代理了pod网络

```
[root@master1 ~]# ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.0.1:443 nq
  -> 10.0.0.11:6443               Masq    1      0          0         
  -> 10.0.0.12:6443               Masq    1      0          0         
TCP  192.168.92.255:80 nq
  -> 172.7.11.3:80                Masq    1      0          1         
```

### 5.扩容deployment新增加一个pod，测试集群网络是否会改变

```
[root@master1 ~]# kubectl scale deployment nginx-dp --replicas=2 -n kube-public
deployment.extensions/nginx-dp scaled
[root@master1 ~]# kubectl get deployment -n kube-public
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
nginx-dp   2/2     2            2           12m
[root@master1 ~]# kubectl get pods -n kube-public
NAME                        READY   STATUS    RESTARTS   AGE
nginx-dp-79d757b7fb-2sxl6   1/1     Running   0          4m6s
nginx-dp-79d757b7fb-hfj28   1/1     Running   0          9m12s
[root@master1 ~]# kubectl get pods -n kube-public -o wide
NAME                        READY   STATUS    RESTARTS   AGE     IP           NODE               NOMINATED NODE   READINESS GATES
nginx-dp-79d757b7fb-2sxl6   1/1     Running   0          4m25s   172.7.12.3   master2.host.com   <none>           <none>
nginx-dp-79d757b7fb-hfj28   1/1     Running   0          9m31s   172.7.11.3   master1.host.com   <none>           <none>
[root@master1 ~]# ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.0.1:443 nq
  -> 10.0.0.11:6443               Masq    1      0          0         
  -> 10.0.0.12:6443               Masq    1      0          0         
TCP  192.168.92.255:80 nq
  -> 172.7.11.3:80                Masq    1      0          0         
  -> 172.7.12.3:80                Masq    1      0          0         
[root@master2 ~]# curl 192.168.92.255
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

# 改回一个deployment
[root@master1 ~]# kubectl scale deployment nginx-dp --replicas=1 -n kube-public
```

### 6. 陈述式资源管理方法小结

- kubenetes集群管理资源的唯一入口是通过镶银的方法调用api-server的接口
- kubectl是官方的CLI命令行工具，用于api-server进行通信，将用户在命令行输入的命令，组织并转化为api-server能辨识的信息，进而管理k8s各种资源的一种有效途径
- kubectl命令大全
  - kubectl --help
  - http://docs.kubenetes.org.cn
- 陈述式管理资源的方法能解决80%以上的资源管理需求，但他的缺点也很明显
  - 命令冗长、复杂、难以记忆
  - 特定场景下无法实现管理需求
  - 对资源的增删改查比较容易，但是修改就很困难

## 二、声明式资源管理方法

> 声明式资源管理方法依赖于资源配置清单（yaml/json）文件

### 1.查看资源配置清单的方法

```
[root@master1 ~]# kubectl get pods -n kube-public
NAME                        READY   STATUS    RESTARTS   AGE
nginx-dp-79d757b7fb-hfj28   1/1     Running   0          48m
[root@master1 ~]# kubectl get pods nginx-dp-79d757b7fb-hfj28 -o yaml -n kube-public
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: "2021-03-30T12:45:12Z"
  generateName: nginx-dp-79d757b7fb-
  labels:
    app: nginx-dp
    pod-template-hash: 79d757b7fb
  name: nginx-dp-79d757b7fb-hfj28
  namespace: kube-public
  ownerReferences:
  - apiVersion: apps/v1
    blockOwnerDeletion: true
    controller: true
    kind: ReplicaSet
    name: nginx-dp-79d757b7fb
    uid: 6ea9e94e-2c42-4cfc-a9c9-0210d266d0be
  resourceVersion: "99527"
  selfLink: /api/v1/namespaces/kube-public/pods/nginx-dp-79d757b7fb-hfj28
  uid: bb107cc3-2198-4787-845b-b64be75ec25c
spec:
  containers:
  - image: harbor.od.com/public/nginx:src_1.14.2
    imagePullPolicy: IfNotPresent
    name: nginx
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: default-token-gb5bt
      readOnly: true
  dnsPolicy: ClusterFirst
  enableServiceLinks: true
  nodeName: master1.host.com
  priority: 0
  restartPolicy: Always
  schedulerName: default-scheduler
  securityContext: {}
  serviceAccount: default
  serviceAccountName: default
  terminationGracePeriodSeconds: 30
  tolerations:
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
    tolerationSeconds: 300
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
    tolerationSeconds: 300
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
    tolerationSeconds: 300
  volumes:
  - name: default-token-gb5bt
    secret:
      defaultMode: 420
      secretName: default-token-gb5bt
status:
  conditions:
  - lastProbeTime: null
    lastTransitionTime: "2021-03-30T12:45:12Z"
    status: "True"
    type: Initialized
  - lastProbeTime: null
    lastTransitionTime: "2021-03-30T12:45:20Z"
    status: "True"
    type: Ready
  - lastProbeTime: null
    lastTransitionTime: "2021-03-30T12:45:20Z"
    status: "True"
    type: ContainersReady
  - lastProbeTime: null
    lastTransitionTime: "2021-03-30T12:45:12Z"
    status: "True"
    type: PodScheduled
  containerStatuses:
  - containerID: docker://4d5281865f42d5f462f36fc3fe27b589bf3cc01ba1699886893334ec6172c2fd
    image: harbor.od.com/public/nginx:latest
    imageID: docker-pullable://harbor.od.com/public/nginx@sha256:706446e9c6667c0880d5da3f39c09a6c7d2114f5a5d6b74a2fafd24ae30d2078
    lastState: {}
    name: nginx
    ready: true
    restartCount: 0
    state:
      running:
        startedAt: "2021-03-30T12:45:19Z"
  hostIP: 10.0.0.11
  phase: Running
  podIP: 172.7.11.3
  qosClass: BestEffort
  startTime: "2021-03-30T12:45:12Z"
  
# 当然也可以看service的资源配置清单
[root@master1 ~]# kubectl get pods nginx-dp-79d757b7fb-hfj28 -o yaml -n kube-public
apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: "2021-03-30T12:45:12Z"
  generateName: nginx-dp-79d757b7fb-
  labels:
    app: nginx-dp
    pod-template-hash: 79d757b7fb
  name: nginx-dp-79d757b7fb-hfj28
  namespace: kube-public
  ownerReferences:
  - apiVersion: apps/v1
    blockOwnerDeletion: true
    controller: true
    kind: ReplicaSet
    name: nginx-dp-79d757b7fb
    uid: 6ea9e94e-2c42-4cfc-a9c9-0210d266d0be
  resourceVersion: "99527"
  selfLink: /api/v1/namespaces/kube-public/pods/nginx-dp-79d757b7fb-hfj28
  uid: bb107cc3-2198-4787-845b-b64be75ec25c
spec:
  containers:
  - image: harbor.od.com/public/nginx:src_1.14.2
    imagePullPolicy: IfNotPresent
    name: nginx
    resources: {}
    terminationMessagePath: /dev/termination-log
    terminationMessagePolicy: File
    volumeMounts:
    - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
      name: default-token-gb5bt
      readOnly: true
  dnsPolicy: ClusterFirst
  enableServiceLinks: true
  nodeName: master1.host.com
  priority: 0
  restartPolicy: Always
  schedulerName: default-scheduler
  securityContext: {}
  serviceAccount: default
  serviceAccountName: default
  terminationGracePeriodSeconds: 30
  tolerations:
  - effect: NoExecute
    key: node.kubernetes.io/not-ready
    operator: Exists
    tolerationSeconds: 300
  - effect: NoExecute
    key: node.kubernetes.io/unreachable
    operator: Exists
    tolerationSeconds: 300
  volumes:
  - name: default-token-gb5bt
    secret:
      defaultMode: 420
      secretName: default-token-gb5bt
status:
  conditions:
  - lastProbeTime: null
    lastTransitionTime: "2021-03-30T12:45:12Z"
    status: "True"
    type: Initialized
  - lastProbeTime: null
    lastTransitionTime: "2021-03-30T12:45:20Z"
    status: "True"
    type: Ready
  - lastProbeTime: null
    lastTransitionTime: "2021-03-30T12:45:20Z"
    status: "True"
    type: ContainersReady
  - lastProbeTime: null
    lastTransitionTime: "2021-03-30T12:45:12Z"
    status: "True"
    type: PodScheduled
  containerStatuses:
  - containerID: docker://4d5281865f42d5f462f36fc3fe27b589bf3cc01ba1699886893334ec6172c2fd
    image: harbor.od.com/public/nginx:latest
    imageID: docker-pullable://harbor.od.com/public/nginx@sha256:706446e9c6667c0880d5da3f39c09a6c7d2114f5a5d6b74a2fafd24ae30d2078
    lastState: {}
    name: nginx
    ready: true
    restartCount: 0
    state:
      running:
        startedAt: "2021-03-30T12:45:19Z"
  hostIP: 10.0.0.11
  phase: Running
  podIP: 172.7.11.3
  qosClass: BestEffort
  startTime: "2021-03-30T12:45:12Z"
[root@master1 ~]# kubectl get svc nginx-dp -o yaml -n kube-public
apiVersion: v1
kind: Service
metadata:
  creationTimestamp: "2021-03-30T12:47:23Z"
  labels:
    app: nginx-dp
  name: nginx-dp
  namespace: kube-public
  resourceVersion: "99707"
  selfLink: /api/v1/namespaces/kube-public/services/nginx-dp
  uid: 3a410009-5a18-43e6-b10b-f1ed60ef8e05
spec:
  clusterIP: 192.168.92.255
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx-dp
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
```

### 2.创建资源配置清单

```
[root@master1 ~]# vim nginx-ds-svc.yaml
apiVersion: v1
kind: Service
metadata:
  labels
    app: nginx-ds
  name: nginx-ds
  namespace: default
spec:
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx-ds
  type: ClusterIP
[root@master1 ~]# kubectl create -f nginx-ds-svc.yaml
service/nginx-ds created
[root@master1 ~]# kubectl get svc
NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   192.168.0.1   <none>        443/TCP   24h
nginx-ds     ClusterIP   192.168.3.8   <none>        80/TCP    46s
```

### 3.离线修改资源配置清单

```
# 修改80为8080
[root@master1 ~]# vim nginx-ds-svc.yaml
apiVersion: v1
kind: Service
metadata:
  labels
    app: nginx-ds
  name: nginx-ds
  namespace: default
spec:
  ports:
  - port: 8080  #修改为8080
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx-ds
  type: ClusterIP
[root@master1 ~]# kubectl apply -f nginx-ds-svc.yaml 
service/nginx-ds created
[root@master1 ~]# kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes   ClusterIP   192.168.0.1     <none>        443/TCP    25h
nginx-ds     ClusterIP   192.168.17.60   <none>        8080/TCP   5s
```

### 4.在线修改

```
[root@master1 ~]# kubectl edit svc nginx-ds
[root@master1 ~]# kubectl edit svc nginx-ds-svc.yaml 
Error from server (NotFound): services "nginx-ds-svc.yaml" not found
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
kind: Service
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"labels":{"app":"nginx-ds"},"name":"nginx-ds","namespace":"default"},"spec":{"ports":[{"port":8080,"protocol":"TCP","targetPort":80}],"selector":{"app":"nginx-ds"},"type":"ClusterIP"}}
  creationTimestamp: "2021-03-30T14:03:19Z"
  labels:
    app: nginx-ds
  name: nginx-ds
  namespace: default
  resourceVersion: "106248"
  selfLink: /api/v1/namespaces/default/services/nginx-ds
  uid: 99b0aa28-af8d-4dc2-88ab-33034f1cfbcd
spec:
  clusterIP: 192.168.17.60
  ports:
  - port: 8081  #修改为8081
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx-ds
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
[root@master1 ~]# kubectl get svc
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
kubernetes   ClusterIP   192.168.0.1     <none>        443/TCP    25h
nginx-ds     ClusterIP   192.168.17.60   <none>        8081/TCP   3m28s
```

### 5.删除资源配置清单

```
# 声明式删除
[root@master1 ~]# kubectl delete -f nginx-ds-svc.yaml 
service "nginx-ds" deleted
[root@master1 ~]# kubectl get svc
NAME         TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   192.168.0.1   <none>        443/TCP   27h

# 陈述式删除
[root@master1 ~]# kubectl delete svc nginx-ds 
```

### 6.声明式资源管理方法小结

- 声明式资源管理方法，依赖于同一资源配置清单文件对资源进行管理
- 对资源的管理，是通过事先定义在统一资源配置清单内，再通过陈述式命令应用到k8s集群里
- 语法格式：kubectl create/apply/delete -f /path/to/yaml
- 资源配置清单的学习方法：
  1. 多看别人写的（官方）能读懂
  2. 能照见现成的文件改着用
  3. 遇到不懂的，善用kubectl explain 。。。查
  4. 初学切记不要上来手撕yaml命令，能憋死自己
