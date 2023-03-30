---
layout: post
title: 理论-Kubernetes-03-YAML资源配置清单
date: 2021-04-20
tags: 理论-Kubernetes
---

### 资源配置清单格式

```sh
apiVersion: group/apiversion  # 如果没有给定group名称，那么默认为 core，可以使用 kubectl api-versions # 获取当前k8s版本上所有的apiVersion 版本信息( 每个版本可能不同 )
kind:       #资源类别
metadata：  #资源元数据   
   namenamespace   
   lables   
   annotations   # 主要目的是方便用户阅读查找
spec: # 期望的状态（disired state）
status：# 当前状态，本字段有 Kubernetes 自身维护，用户不能去定义
```

### 常用字段解析

注意参数名称中间有个（.），其意思就是二级层下面了

| 参数名                                      | 字段类型 | 说明                                                         |
| ------------------------------------------- | -------- | ------------------------------------------------------------ |
| version                                     | String   | 这里指的是k8s的API版本，目前基本上是v1，可以用kubectl api-version命令查询 |
| kind                                        | String   | 这里指的是yaml文件定义的资源类型和角色，比如：Pod、Deployment等 |
| metadata                                    | Object   | 元数据对象，固定值就写metadata                               |
| metadata.name                               | String   | 元数据对象的名字，这里有我们编写，比如写Pod的名字            |
| metadata.namespace                          | String   | 元数据对象的命名空间，也就是Pod的命名空间，有我们自定义，不写默认在default下面 |
| Spec                                        | Object   | 详细定义对象，也就是要指定Pod里面容器的信息了                |
| spec.containers[]                           | list     | 这里是Spec对象的容器列表定义，是个列表，然后下面指定容器的信息 |
| spec.containers[].name                      | String   | 这里定义容器的名字                                           |
| spec.containers[].image                     | String   | 定义容器要用的镜像                                           |
| spec.containers[].imagePullPolicy           | String   | 定义镜像拉取策略，有Always、Never、IfNotPresent三个值可以选<br />（1）Always：每次都尝试重新拉取镜像<br />（2）Nerver：表示仅使用本地镜像<br />（3）IfNotPresent：如果本地没有镜像，那就拉取在线镜像<br />如过没有设置的参数的话，那么默认就是Always |
| spec.containers[].command                   | List     | 指定容器启动命令，因为是数组可以指定多个，不指定则使用镜像打包时候<br />默认的启动命令 |
| spec.containers[].args[]                    | List     | 指定多个启动命令参数，因为是数组可以指定多个                 |
| spec.containers[].workingDir                | List     | 指定容器的工作目录                                           |
| spec.containers[].volumeMounts              | List     | 指定容器内部的存储卷配置                                     |
| spec.containers[].volumeMounts[].name       | String   | 指定可以被容器挂载的存储卷的名称                             |
| spec.containers[].volumeMounts[].mountPath  | String   | 指定可以被容器挂载的存储卷的路径                             |
| spec.containers[].volumeMounts[].readOnly   | String   | 设置存储卷路径的读写模式，ture或者false默认为读写模式        |
| spec.containers[].ports[]                   | List     | 指定容器需要用到的端口列表                                   |
| spec.containers[].ports[].name              | String   | 指定端口名称（映射出来的端口）                               |
| spec.containers[].ports[].containerPort     | String   | 指定容器需要监听的端口号（容器的端口）                       |
| spec.containers[].ports[].hostPort          | String   | 指定容器所在主机需要监听的端口号，<br />默认跟上面containerPort相同，<br />注意设置了hostPort同一台主机无法启动该容器<br />的相同副本（因为主机的端口号不能相同，会冲突） |
| spec.containers[].ports[].protocol          | String   | 指定端口协议，支持TCP和UDP，默认为TCP                        |
| spec.containers[].ports[].env[]             | List     | 指定容器运行前需要设置的环境变量列表，同上端口列表类似       |
| spec.containers[].ports[].env[].name        | String   | 指定环境变量名称                                             |
| spec.containers[].ports[].env[].value       | String   | 指定环境变量值                                               |
| spec.containers[].resources                 | Object   | 指定资源限制和资源请求的值（这里开始就是设置容器的资源上限） |
| spec.containers[].resources.limits          | Object   | 指定设置容器运行时资源的运行上限                             |
| spec.containers[].resources.limits.cpu      | String   | 指定CPU资源的限制，单位为core数，将用于docker run --cpu-shares参数 |
| spec.containers[].resources.limits.memory   | String   | 指定内存的限制，单位为MIB、GIB                               |
| spec.containers[].resources.requests        | Object   | 指定容器启动和调度时的限制设置                               |
| spec.containers[].resources.requests.cpu    | String   | CPU请求，单位为core数，容器启动时初始化可用数量              |
| spec.containers[].resources.requests.memory | String   | 内存请求，单位为MIB、GIB，容器启动时初始化可用数量           |
| spec.restartPolicy                          | String   | 定义Pod的重启策略，可选值为Always、OnFailure、Never，默认值为Always。<br />1.Always：Pod一旦终止运行，则无论是如何终止的，kubectl服务都要将它重启。<br />2.OnFailure：只有Pod以非零退出码终止时，kubectl才会重启该容器，如果容器正常结束（退出码为0），则kubectl不重启它。<br />3.Never：Pod终止后，kubectl将退出码报告给master，不会重启该Pod。 |
| spec.nodeSelector                           | Object   | 定义Node的Label过滤标签，以key:value格式指定                 |
| spec.imagePullSecrets                       | Object   | 定义pull镜像时候使用secret名称，以name:secret格式指定        |
| spec.hostNetWork                            | Boolean  | 定义是否使用主机网络模式，默认值为false，只是true表示使用宿主机网络，不适用docker网桥，同时设置了true将无法在同一台宿主机上启动第二个副本。 |

--------

### 字段配置格式

```sh
apiVersion <string>		#表示字符串类型
metedata <Object>		#表示需要嵌套多层字段
labels <map[string] string> #表示由k：v组成的映射
finalizers <[]string>	#表示字串列表
ownerReferences <[]Object> #表示对象列表
hostPID <boolean>		#布尔类型
priority <integer>		#整型
name <string> -required- #如果类型后面接	-required-，表示为必填字段
```

### 资源清单格式

```
apiVersion: group/apiversion  # 如果有没给定 group名称，那么默认为core，可以使用 kubectl api-versions 获取当前 k8s版本上所有的apiVersion 版本信息（每个版本可能不同）
kind: 	#资源类别
metadata: #资源元数据
  name:
  namespace:
  lables:
  annotations:	#主要目的是方便用户阅读查找
spec:  #期望的状态（disired state）
status:  #当前状态，文本段有 Kubernetes 自身维护，用户不能去定义
```

### 资源清单的常用命令

> 获取apiversion版本信息

```sh
~]# kubectl api-versions
admissionregistration.k8s.io/v1beta1
apiextensions.k8s.io/v1beta1
apiregistration.k8s.io/v1
apiregistration.k8s.io/v1beta1
apps/v1
apps/v1beta1
apps/v1beta2
......(以下省略)
```

> 获取资源的apiVersion版本信息

```sh
~]# kubectl explain pod
KIND:     Pod
VERSION:  v1
......(以下省略)

[root@k8s-master01 ~]# kubectl explain Ingress
KIND:     Ingress
VERSION:  extensions/v1beta1
......(以下省略)
```

> 获取字段设置帮助文档

```sh
~]# kubectl explain pod
KIND:     Pod
VERSION:  v1

DESCRIPTION:
     Pod is a collection of containers that can run on a host. This resource is
     created by clients and scheduled onto hosts.

FIELDS:
   apiVersion	<string>
     APIVersion defines the versioned schema of this representation of an
     object. Servers should convert recognized schemas to the latest internal
     value, and may reject unrecognized values. More info:
     https://git.k8s.io/community/contributors/devel/api-conventions.md#resources

   kind	<string>
     Kind is a string value representing the REST resource this object
     represents. Servers may infer this from the endpoint the client submits
     requests to. Cannot be updated. In CamelCase. More info:
     https://git.k8s.io/community/contributors/devel/api-conventions.md#types-kinds

   metadata	<Object>
     Standard object's metadata. More info:
     https://git.k8s.io/community/contributors/devel/api-conventions.md#metadata

   spec	<Object>
     Specification of the desired behavior of the pod. More info:
     https://git.k8s.io/community/contributors/devel/api-conventions.md#spec-and-status

   status	<Object>
   
......
```

### 通过定义清单文件创建Pod

```sh
#利用资源清单定义pod
~]# vim pod1.yaml

apiVersion: v1
kind: Pod
metadata:
  name: nginx-tx
  namespace: default
  labels:
    app: tianxiangapp
    version: v1
spec:
  containers:
  - name: nginx
    image: harbor.od.com/public/nginx:latest
    command:
    - "/bin/sh"
    - "-c"
    - "sleep 3600"
    
**注意区分大小写**

#从资源清单生成pod
~]# kubectl create -f pod1.yaml

#查看pod
~]# kubectl get pod
NAME       READY   STATUS    RESTARTS   AGE
nginx-tx  1/1     Running   0          12s
```