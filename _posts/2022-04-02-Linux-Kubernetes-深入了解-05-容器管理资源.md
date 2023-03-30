---
layout: post
title: Linux-Kubernetes-深入了解-05-容器管理资源
date: 2022-04-02
tags: Linux-Kubernetes-深入了解
---
## 一、服务质量保证（QoS）

> Kubernetes需要整体统筹平台资源使用情况、公平合理的将资源分配给相关pod容器使用，并且要保证容器生命周期内有足够的资源来保证其运行。 与此同时，由于资源发放的独占性，即资源已经分配给了某容器，同样的资源不会在分配给其他容器，对于资源利用率相对较低的容器来说，占用资源却没有实际使用（比如CPU、内存）造成了严重的资源浪费，Kubernetes需从优先级与公平性等角度综合考虑来提高资源的利用率。为了在资源被有效调度和分配的同时提高资源利用率，Kubernetes针对不同服务质量的预期，通过QoS（Quality of Service）来对pod进行服务质量管理，提供了个采用requests和limits两种类型对资源进行分配和使用限制。对于一个pod来说，服务质量体现在两个为2个具体的指标： CPU与内存。实际过程中，当NODE节点上内存资源紧张时，kubernetes会根据预先设置的不同QoS类别进行相应处理。

上面一段话的内容其意思就是，kubernetes 中有很多pod，如果不做资源管理，那么每个pod容器与每个pod容器所使用的内存/CPU是不同的，很容易造成资源浪费，为此更好的提高资源利用率，kubernetes 通过QOS（服务质量保证）来管理资源分配，其中采用 request 和 limits 这两种类型对资源进行限制。

### 1. 设置资源限制的原因

> 如果未做过节点 nodeSelector，亲和性（node affinity）或pod亲和、反亲和性（pod affinity/anti-affinity）等Pod高级调度策略设置，我们没有办法指定服务部署到指定机器上，如此可能会造成cpu或内存等密集型的pod全部都被分配到相同的Node上，造成资源竞争。另一方面，如果未对资源进行限制，一些关键的服务可能会因为资源竞争因OOM（Out of Memory）等原因被kill掉，或者被限制CPU使用。

其意思就是，如果你的pod没有做这些存活性优先级比较高的调度策略，那么遇到CPU、内存或磁盘利用与过高而导致pod被驱逐的时候系统不会管你哪些pod重要哪些pod不重要，直接会kill掉你的pod（当然这个kill也是是一定的先后顺序的，这个下面会讲到）

### 2. 资源需求（Requests）和限制（ Limits）

> 对于每一个资源，container可以指定具体的资源需求（requests）和限制（limits），requests申请范围是0到node节点的最大配置，而limits申请范围是requests到无限，即0 <= requests <=Node Allocatable, requests <= limits <= Infinity。如果 Pod 运行所在的节点具有足够的可用资源，容器可能（且可以）使用超出对应资源 request 属性所设置的资源量。不过，容器不可以使用超出其资源 limit 属性所设置的资源量。例如，如果你将容器的 memory 的请求量设置为 256 MiB，而该容器所处的 Pod 被调度到一个具有 8 GiB 内存的节点上，并且该节点上没有其他 Pods 运行，那么该容器就可以尝试使用更多的内存。如果你将某容器的 memory 约束设置为 4 GiB，kubelet （和 容器运行时） 就会确保该约束生效。 容器运行时会禁止容器使用超出所设置资源约束的资源。 例如：当容器中进程尝试使用超出所允许内存量的资源时，系统内核会将尝试申请内存的进程终止， 并引发内存不足（OOM）错误。约束值可以以被动方式来实现（系统会在发现违例时进行干预），或者通过强制生效的方式实现 （系统会避免容器用量超出约束值）。不同的容器运行时采用不同方式来实现相同的限制。

```sh
1. 对于CPU，如果pod中服务使用CPU超过设置的limits，pod不会被kill掉但会被限制。如果没有设置limits，pod可以使用全部空闲的cpu资源

2. 对于内存，当一个pod使用内存超过了设置的limits，pod中container的进程会被kernel因OOM kill掉。当container因为OOM被kill掉时，系统倾向于在其原所在的机器上重启该container或本机或其他重新创建一个pod。
```

> 说明：
如果某容器设置了自己的内存限制但未设置内存请求，Kubernetes 自动为其设置与内存限制相匹配的请求值。类似的，如果某 Container 设置了 CPU 限制值但未设置 CPU 请求值，则 Kubernetes 自动为其设置 CPU 请求并使之与 CPU 限制值匹配。

## 二、资源类型

CPU 和 内存 都是 资源类型。每种资源类型具有其基本单位。 CPU 表达的是计算处理能力，其单位是 Kubernetes CPUs。 内存的单位是字节。 对于 Linux 负载，则可以指定巨页（Huge Page）资源。 巨页是 Linux 特有的功能，节点内核在其中分配的内存块比默认页大小大得多。

> 例如，在默认页面大小为 4KiB 的系统上，你可以指定约束 hugepages-2Mi: 80Mi。 如果容器尝试分配 40 个 2MiB 大小的巨页（总共 80 MiB ），则分配请求会失败。

## 三、Pod 和 容器的资源请求和约束

- spec.containers[].resources.limits.cpu
- spec.containers[].resources.limits.memory
- spec.containers[].resources.limits.hugepages-<size>
- spec.containers[].resources.requests.cpu
- spec.containers[].resources.requests.memory
- spec.containers[].resources.requests.hugepages-<size>

尽管你只能逐个容器地指定请求和限制值，考虑 Pod 的总体资源请求和约束也是有用的。 对特定资源而言，Pod 的资源请求/约束值是 Pod 中各容器对该类型资源的请求/约束值的总和。

## 四、Kubernetes 中的资源单位

### 1. CPU 资源单位

CPU 资源的约束和请求以 “cpu” 为单位。 在 Kubernetes 中，一个 CPU 等于1 个物理 CPU 核 或者 一个虚拟核， 取决于节点是一台物理主机还是运行在某物理主机上的虚拟机。

你也可以表达带小数 CPU 的请求。 当你定义一个容器，将其 spec.containers[].resources.requests.cpu 设置为 0.5 时， 你所请求的 CPU 是你请求 1.0 CPU 时的一半。 对于 CPU 资源单位，数量 表达式 0.1 等价于表达式 100m，可以看作 “100 millicpu”。 有些人说成是“一百毫核”，其实说的是同样的事情。

CPU 资源总是设置为资源的绝对数量而非相对数量值。 例如，无论容器运行在单核、双核或者 48-核的机器上，500m CPU 表示的是大约相同的计算能力。

> 白话解释：如果你的CPU是4核，那么我请求资源（request）写个0.5，也就是请求了半个核的CPU，此时我4核的CPU还剩3.5个核，然后数量表达式就是0.1就是100m，也就是1核CPU等于1000m

### 2. 内存资源单位

memory 的约束和请求以字节为单位。 你可以使用普通的证书，或者带有以下 数量后缀 的定点数字来表示内存：E、P、T、G、M、k。 你也可以使用对应的 2 的幂数：Ei、Pi、Ti、Gi、Mi、Ki。 例如，以下表达式所代表的是大致相同的值：

```sh
128974848、129e6、129M、128974848000m、123Mi
```

> 请注意后缀的大小写。如果你请求 400m 内存，实际上请求的是 0.4 字节。 如果有人这样设定资源请求或限制，可能他的实际想法是申请 400 兆字节（400Mi） 或者 400M 字节。

### 3. 容器资源示例

以下 Pod 有两个容器。每个容器的请求为 0.25 CPU 和 64MiB（226 字节）内存， 每个容器的资源约束为 0.5 CPU 和 128MiB 内存。 你可以认为该 Pod 的资源请求为 0.5 CPU 和 128 MiB 内存，资源限制为 1 CPU 和 256MiB 内存。

```YAML
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  containers:
  - name: app
    image: images.my-company.example/app:v4
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
  - name: log-aggregator
    image: images.my-company.example/log-aggregator:v6
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

## 五、QoS分类

Kubernetes 创建 Pod 时就给它指定了下列一种 QoS 类：Guaranteed（稳定的），Burstable（放心的），BestEffort（尽力的）。

> 优先级：
>
> Best-Effort pods -> Burstable pods -> Guaranteed pods

### 1. Guaranteed

- Guaranteed：Pod 中的每个容器，包含初始化容器，必须指定内存和 CPU 的 requests 和 limits，并且两者要相等。

**示例：**
```YAML
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  containers:
  - name: app
    image: images.my-company.example/app:v4
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
  - name: log-aggregator
    image: images.my-company.example/log-aggregator:v6
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

> 注意：如果一个容器只指明limit而未设定request，则request的值等于limit值，同样也是Guaranteed级别

### 2.Burstable

- Burstable：Pod 不符合 Guaranteed QoS 类的标准；Pod 中至少一个容器具有内存或 CPU requests。

**示例：**

```YAML
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  containers:
  - name: app
    image: images.my-company.example/app:v4
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
  - name: log-aggregator
    image: images.my-company.example/log-aggregator:v6
```

### 3. BestEffort

- BestEffort：Pod 中的容器必须没有设置内存和 CPU requests 或 limits。

```YAML
apiVersion: v1
kind: Pod
metadata:
  name: frontend
spec:
  containers:
  - name: app-01
    image: images.my-company.example/app:v4
  - name: log-aggregator
    image: images.my-company.example/log-aggregator:v6
```

## 六、Kubelet 策略

### 1. 静态 Pod

在Kubernetes中有一种DaemonSet类型pod，此类pod可以常驻在某个Node上运行，由该Node上kubelet服务直接管理而无需api server介入。静态pod也无需关联任何RC，完全由kubelet服务来监控，当kubelet发现静态pod停止时，kubelet会重新启动静态pod。

### 2. 资源回收策略

当kubernetes集群中某个节点上可用资源比较小时，kubernetes提供了资源回收策略保证被调度到该节点pod服务正常运行。当节点上的内存或者CPU资源耗尽时，可能会造成该节点上正在运行的pod服务不稳定。Kubernetes通过kubelet来进行回收策略控制，保证节点上pod在节点资源比较小时可以稳定运行。

### 3.驱逐策略

#### 3.1 默认 node 存储的驱逐触发条件

- nodefs.available<10%（容器 volume 使用的文件系统的可用空间，包括文件系统剩余大小和 inode 数量）

- imagefs.available<15%（容器镜像使用的文件系统的可用空间，包括文件系统剩余大小和 inode 数量）

> 当 nodefs 使用量达到阈值时，kubelet 就会拒绝在该节点上运行新 Pod，并向 API Server 注册一个 DiskPressure condition。然后 kubelet 会尝试删除死亡的 Pod 和容器来回收磁盘空间，如果此时 nodefs 使用量仍然没有低于阈值，kubelet 就会开始驱逐 Pod。从 Kubernetes 1.9 开始，kubelet 驱逐 Pod 的过程中不会参考 Pod 的 QoS，只是根据 Pod 的 nodefs 使用量来进行排名，并选取使用量最多的 Pod 进行驱逐。所以即使 QoS 等级为 Guaranteed 的 Pod 在这个阶段也有可能被驱逐（例如 nodefs 使用量最大）。如果驱逐的是 Daemonset，kubelet 会阻止该 Pod 重启，直到 nodefs 使用量超过阈值。

#### 3.2 默认 node 内存的驱逐出发条件

- memory.available<100Mi

> 当内存使用量超过阈值时，kubelet 就会向 API Server 注册一个 MemoryPressure condition，此时 kubelet 不会接受新的 QoS 等级为 Best Effort 的 Pod 在该节点上运行，并按照以下顺序来驱逐 Pod： 当内存资源不足时，kubelet 在驱逐 Pod 时只会考虑 requests 和 Pod 的内存使用量，不会考虑 limits。

#### 3.3 调整 node 存触发条件

```sh
[root@centos7 ~]# vim /var/lib/kubelet/kubeadm-flags.env
KUBELET_KUBEADM_ARGS="--cgroup-driver=systemd --network-plugin=cni --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.2 \
--eviction-soft=memory.available<500Mi,nodefs.available<5%,nodefs.inodesFree<6%  \
--eviction-soft-grace-period=memory.available=300s,nodefs.available=300s,nodefs.inodesFree=300s  \
--eviction-minimum-reclaim=memory.available=0Mi,nodefs.available=500Mi,imagefs.available=2Gi"
[root@centos7 ~]# systemctl daemon-reload
[root@centos7 ~]# systemctl restart kubelet
```
调整磁盘使用率上限到95%，下限调整为94%，从而最大化保留数，调整驱逐策略 调整到达阈值后触发清理的等待时间，好在告警后第一时间处理 扩容当前磁盘，可通过LVM

```sh
--eviction-soft=memory.available<500Mi,nodefs.available<5%,nodefs.inodesFree<6%       #清理阈值的集合，如果达到一个清理周期将触发一次容器清理
--eviction-soft-grace-period=memory.available=300s,nodefs.available=300s,nodefs.inodesFree=300s      #清理周期的集合，在触发一个容器清理之前一个软清理阈值需要保持多久
--eviction-minimum-reclaim=memory.available=0Mi,nodefs.available=500Mi,imagefs.available=2Gi       #资源回收最小值的集合，即 kubelet 压力较大时 ，执行 pod 清理回收的资源最小值
```
