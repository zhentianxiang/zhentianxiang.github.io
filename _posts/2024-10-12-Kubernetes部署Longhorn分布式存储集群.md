---
layout: post
title: 2024-10-12-Kubernetes部署Longhorn分布式存储集群
date: 2024-10-12
tags: 实战-Kubernetes
music-id: 135362
---

## 一、Longhorn基础介绍

官方github：https://github.com/longhorn/longhorn

官方网站：[https://longhorn.io](https://longhorn.io/)

**Longhorn**是一个轻量级、可靠且功能强大的分布式块存储系统，适用于 Kubernetes。使用容器和微服务实现分布式块存储。Longhorn 为每个块储存设备卷创建一个专用的存储控制器，并在存储在多个节点上的多个副本之间同步复制该卷。存储控制器和副本本身是使用 Kubernetes 编排的。Longhorn 是免费的开源软件。它最初由Rancher Labs开发，现在作为云原生计算基金会的孵化项目进行开发。

**Longhorn 支持以下架构**：

1. AMD64
2. ARM64（实验性）

**使用Longhorn，您可以**：

- 使用 Longhorn 卷作为 Kubernetes 集群中分布式有状态应用程序的持久存储
- 将您的块存储分区为 Longhorn 卷，以便您可以在有或没有云提供商的情况下使用 Kubernetes 卷。
- 跨多个节点和数据中心复制块存储以提高可用性
- 将备份数据存储在外部存储（如 NFS 或 AWS S3）中
- 创建跨集群灾难恢复卷，以便从第二个 Kubernetes 集群中的备份中快速恢复主 Kubernetes 集群中的数据
- 计划卷的定期快照，并计划定期备份到 NFS 或与 S3 兼容的辅助存储
- 从备份还原卷
- 在不中断持久卷的情况下升级 Longhorn

Longhorn带有一个独立的UI，可以使用Helm，kubectl或Rancher应用程序目录进行安装。

**使用微服务简化分布式块存储**

由于现代云环境需要数以万计到数百万个分布式块存储卷，因此一些存储控制器已成为高度复杂的分布式系统。相比之下，Longhorn 可以通过将大型块存储控制器分区为多个较小的存储控制器来简化存储系统，只要这些卷仍然可以从公共磁盘池构建。通过为每个卷使用一个存储控制器，Longhorn 将每个卷转换为微服务。控制器被称为Longhorn Engine。

Longhorn Manager 组件编排 Longhorn 引擎，因此它们可以连贯地协同工作。

**在 Kubernetes 中使用持久性存储，而无需依赖云提供商**

Pod 可以直接引用存储，但不建议这样做，因为它不允许 Pod 或容器可移植。相反，工作负载的存储要求应该在 Kubernetes 持久卷 （PV） 和持久卷声明 （PVC） 中定义。使用 Longhorn，您可以指定卷的大小、IOPS 要求以及跨为卷提供存储资源的主机所需的同步副本数。然后，您的 Kubernetes 资源可以为每个 Longhorn 卷使用 PVC 和相应的 PV，或者使用 Longhorn 存储类自动为工作负载创建 PV。

副本在基础磁盘或网络存储上进行精简置备。

**跨多个计算或存储主机计划多个副本**

为了提高可用性，Longhorn 会创建每个卷的副本。副本包含卷的快照链，每个快照都存储与上一个快照相比的更改。卷的每个副本也在容器中运行，因此具有三个副本的卷会产生四个容器。

每个卷的副本数可在 Longhorn 中配置，以及将调度副本的节点数。Longhorn 会监控每个复制副本的运行状况并执行修复，并在必要时重建复制副本。

**为每个卷分配多个存储前端**

常见的前端包括一个 Linux 内核设备（映射在 /dev/longhorn 下）和一个 iSCSI 目标。

**为定期快照和备份操作指定计划**

指定这些操作的频率（每小时、每天、每周、每月和每年）、执行这些操作的确切时间（例如，每个星期日的凌晨 3：00）以及保留的定期快照和备份集数。

### 1. 架构介绍

Longhorn设计有两层：数据平面和控制平面。Longhorn Engine 是对应于数据平面的存储控制器，而 Longhorn Manager 对应于控制平面。

Longhorn Manager Pod 作为 Kubernetes DaemonSet 在 Longhorn 集群中的每个节点上运行。它负责在 Kubernetes 集群中创建和管理卷，并处理来自 UI 或 Kubernetes 的卷插件的 API 调用。它遵循 Kubernetes 控制器模式，有时称为运算符模式。Longhorn Manager 与 Kubernetes API 服务器通信，以创建新的 Longhorn 卷 CRD。然后，Longhorn Manager 会观察 API 服务器的响应，当它看到 Kubernetes API 服务器创建了一个新的 Longhorn 卷 CRD 时，Longhorn Manager 会创建一个新卷。当要求 Longhorn Manager 创建卷时，它会在卷附加到的节点上创建一个 Longhorn Engine 实例，并在将放置副本的每个节点上创建一个副本。副本应放置在单独的主机上，以确保最大的可用性。副本的多个数据路径确保了 Longhorn 卷的高可用性。即使某个副本或引擎出现问题，该问题也不会影响所有副本或 Pod 对卷的访问。Pod 仍将正常运行。长角引擎始终与使用 Longhorn 卷的 Pod 在同一节点中运行。它跨存储在多个节点上的多个副本同步复制卷。引擎和副本是使用 Kubernetes 编排的。

## 二、部署Longhorn

我这里部署的版本为v1.2.4最新版本，在部署 Longhorn v1.2.4 之前，请确保您的 Kubernetes 集群至少为 v1.18，因为支持的 Kubernetes 版本已在 v1.2.4 中更新 （>= v1.18）。如果是低版本请部署选择相应的版本

### 1. 安装前准备

在安装了 Longhorn 的 Kubernetes 集群中，每个节点都必须满足以下要求

- 与 Kubernetes 兼容的容器运行时（Docker v1.13+、containerd v1.3.7+ 等）
- Kubernetes v1.18+，v1.2.4要求。
- `open-iscsi`已安装，并且守护程序正在所有节点上运行。

```bash
# centos安装
$ yum install iscsi-initiator-utils

$ systemctl enable iscsid

$ systemctl start iscsid
```

- RWX 支持要求每个节点都安装了 NFSv4 客户端。

```bash
# centos安装
$ yum install nfs-utils
```

- 主机文件系统支持存储数据的功能。
  - ext4
  - XFS
- bash必须安装`curl findmnt grep awk blkid lsblk`

```bash
# centos安装
$ yum install curl util-linux grep gawk
```

- 必须启用装载传播。

官方提供了一个测试脚本，需要在kube-master节点执行：https://raw.githubusercontent.com/longhorn/longhorn/v1.2.4/scripts/environment_check.sh

```bash
# 运行脚本前安装jq
$ yum install jq

$ bash environment_check.sh
daemonset.apps/longhorn-environment-check created
waiting for pods to become ready (0/3)
waiting for pods to become ready (0/3)
all pods ready (3/3)

  MountPropagation is enabled!

cleaning up...
daemonset.apps "longhorn-environment-check" deleted
clean up complete
#以上输出表示正常
```

### 2. 使用Helm安装Longhorn

官方提供了俩种安装方式，我们在这里使用helm进行安装

首先在kube-master安装Helm v2.0+。

### 3. 部署

```bash
$ helm version
version.BuildInfo{Version:"v3.7.2", GitCommit:"663a896f4a815053445eec4153677ddc24a0a361", GitTreeState:"clean", GoVersion:"go1.16.10"}
```

**添加 Longhorn Helm 存储库**

```bash
$ helm repo add longhorn https://charts.longhorn.io
```

**从存储库中获取最新图表**

```bash
$ helm repo update
```

**下载chart包**

```bash
$ helm  pull longhorn/longhorn
```

**解压**

```bash
$ tar xf longhorn-1.2.4.tgz
```

**进入目录执行安装**

```bash
$ cd longhorn
$ helm install longhorn  --namespace longhorn-system --create-namespace ./ -f values.yaml
```

**验证**

```bash
# pod正常情况下都会是运行状态
$ kubectl get pod -n longhorn-system 
#验证存储类
$ kubectl get storageclasses.storage.k8s.io 
NAME                 PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
longhorn (default)   driver.longhorn.io   Delete          Immediate           true                   8m32s
```

**创建pvc并且挂载验证**

```yaml
apiVersion: v1  
apiVersion: apps/v1 
kind: Deployment    
metadata:           
  name: nginx       
  namespace: default
spec:               
  replicas: 3      
  selector:          
    matchLabels:     
      app: nginx   
  template:          #以下为定义pod模板信息,请查看pod详解
    metadata:
      creationTimestamp: null
      labels:
        app: nginx
    spec:
      containers:
      - name: test
        image: 192.168.10.254:5000/bash/nginx:v1
        volumeMounts: 
        - mountPath: "/data"
          name: data
      volumes:              
        - name: data          
          persistentVolumeClaim: 
            claimName: claim
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: claim
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: longhorn
  resources:
    requests:
      storage: 1Gi
```

**创建后验证**

```shell
$kubectl get pvc
NAME    STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
claim   Bound    pvc-30ec630f-4b4d-4fad-a26f-36f7036919a7   1Gi        RWX            longhorn       2m23s
$kubectl get pod
NAME                    READY   STATUS    RESTARTS   AGE
nginx-996746966-g7fsw   1/1     Running   0          2m26s
nginx-996746966-lw67n   1/1     Running   0          2m26s
nginx-996746966-v7dst   1/1     Running   0          2m26s
```

### 4. 修改配置

**存储类配置**

```yaml
persistence:
#是否设置为默认存储类
  defaultClass: true
#文件系统类型ext4与xfs选择一个
  defaultFsType: xfs
#副本数，建议三个
  defaultClassReplicaCount: 1
#删除pvc的策略
  reclaimPolicy: Delete
#以下为高级配置，之后会详细解释其作用
  recurringJobSelector:
    enable: false
    jobList: []
  backingImage:
    enable: false
    name: ~
    dataSourceType: ~
    dataSourceParameters: ~
    expectedChecksum: ~
```

**全局配置**

```yml
defaultSettings:
#备份相关
  backupTarget: ~
  backupTargetCredentialSecret: ~
  allowRecurringJobWhileVolumeDetached: ~
#仅在具有node.longhorn.io/create-default-disk=true标签的节点上初始化数据目录，默认为false在所有节点初始化数据目录
  createDefaultDiskLabeledNodes: ~
#默认数据目录位置，不配置默认为/var/lib/longhorn/
  defaultDataPath: /var/lib/longhorn
#默认数据位置，默认选项为disabled，还有best-effort，表示使用卷的pod是否与卷尽量在同一个node节点，默认为不进行这个限制。
  defaultDataLocality: ~
#卷副本是否为软亲和，默认false表示相同卷的副本强制调度到不同节点，如果为true则表示同一个卷的副本可以在同一个节点
  replicaSoftAntiAffinity: ~
#副本是否进行自动平衡。默认为disabled关闭，least-effort平衡副本以获得最小冗余，best-effort此选项指示 Longhorn 尝试平衡副本以实现冗余。
  replicaAutoBalance: ~
#存储超配置百分比默认200，已调度存储+已用磁盘空间（存储最大值-保留存储）未超过之后才允许调度新副本实际可用磁盘容量的 200%
  storageOverProvisioningPercentage: ~
#存储最小可用百分比默认,默认设置为 25，Longhorn 管理器仅在可用磁盘空间（可用存储空间）减去磁盘空间量且可用磁盘空间仍超过实际磁盘容量（存储空间）的 25%后才允许调度新副本）。否则磁盘将变得不可调度，直到释放更多空间。
  storageMinimalAvailablePercentage: ~
#定期检查版本更新，默认true启用
  upgradeChecker: ~
#创建卷时的默认副本数默认为3
  defaultReplicaCount: ~
#默认Longhorn静态存储类名称，默认值longhorn-static
  defaultLonghornStaticStorageClass: ~
#轮询备份间隔默认300，单位秒
  backupstorePollInterval: ~
#优先级配置
  priorityClass: ~
#卷出现问题自动修复，默认为true
  autoSalvage: ~
#驱逐相关
  disableSchedulingOnCordonedNode: ~
#副本亲和相关
  replicaZoneSoftAntiAffinity: ~
  nodeDownPodDeletionPolicy: ~
#存储安全相关，默认false，如果节点包含卷的最后一个健康副本，Longhorn将阻塞该节点上的kubectl清空操作。
  allowNodeDrainWithLastHealthyReplica: ~
#如果使用ext4文件系统允许设置其他创建参数，以支持旧版本系统内核
  mkfsExt4Parameters: ~
#副本有问题的重建间隔默认600秒 
  replicaReplenishmentWaitInterval: ~
#一个节点同时重建副本的个数，默认5个，超过会阻塞
  concurrentReplicaRebuildPerNodeLimit: ~
#允许引擎控制器和引擎副本在每次数据写入时禁用修订计数器文件更新。默认false
  disableRevisionCounter: ~
#Pod镜像拉取策略与k8s一致
  systemManagedPodsImagePullPolicy: ~
#此设置允许用户创建和挂载在创建时没有计划所有副本的卷，默认true，生产建议关闭
  allowVolumeCreationWithDegradedAvailability: ~
#此设置允许Longhorn在副本重建后自动清理系统生成的快照，默认true
  autoCleanupSystemGeneratedSnapshot: ~
#升级相关
  concurrentAutomaticEngineUpgradePerNodeLimit: ~
#备份相关
  backingImageCleanupWaitInterval: ~
  backingImageRecoveryWaitInterval: ~
#资源限制相关
  guaranteedEngineManagerCPU: ~
  guaranteedReplicaManagerCPU: ~
```

**csi配置**

```yaml
csi:
#主要是这里需要修改为kubelet的--root-dir参数
  kubeletRootDir: /data1/kubelet/root                                                                        
  attacherReplicaCount: ~
  provisionerReplicaCount: ~
  resizerReplicaCount: ~
  snapshotterReplicaCount: ~
```

### 5. 数据盘分区

登录存储节点机器，对数据盘进行分区格式化挂载目录

```sh
# 查看磁盘的当前状态和分区信息
$ parted /dev/sdb print

# 如果有分区可以先删除干净确保这个盘只用来做 longhorn 的存储
$ parted /dev/sdb rm 1

# 初始化一个新的 GPT 分区表
$ parted /dev/sdb mklabel gpt

# 在磁盘上创建一个新的分区，例如创建一个大小为 500GB 的主分区
$ parted /dev/sda mkpart primary ext4 1MiB 500GiB

# 磁盘空间全部分配
$ parted /dev/sdb mkpart primary ext4 0% 100%

# 如果需要调整一个已有分区的大小，可以使用 resizepart 命令
$ parted /dev/sdb resizepart 1 600GiB

#对于新创建的分区，通常需要格式化它们以指定文件系统类型
$ mkfs.ext4 /dev/sdb1

# 挂载分区
$ mkdir /var/lib/longhorn
$ blkid /dev/sdb1
$ echo 'UUID="d380a6c0-f41e-4905-ad8c-1ff5cca6f6c2" /var/lib/longhorn ext4 defaults 0 0' >> /etc/fstab
$ cat /etc/fstab
$ mount -a
```

### 6. 修改 values 配置再启动

```sh
# 准备 3 台专门用来做存储的机器
$ kubectl label node {k8s-node5-storage,k8s-node6-storage,k8s-node7-storage}   node.longhorn.io/create-default-disk=true

# 对节点打污点，只允许存储组建相关服务在该节点运行
$ kubectl taint nodes {k8s-node5-storage,k8s-node6-storage,k8s-node7-storage} longhorn=true:NoSchedule

$ vim values.yaml
4 global:
5   # -- Toleration for nodes allowed to run user-deployed components such as Longhorn Manager, Longhorn UI, and Longhorn Driver Deployer.
6   tolerations:
7   - key: "longhorn"
8     operator: "Equal"
9     value: "true"
10    effect: "NoSchedule"
113 service:
114   ui:
116     type: NodePort
118     nodePort: "32180"
119   manager:
121     type: NodePort
123     nodePort: "32188"
202   createDefaultDiskLabeledNodes: true  # 开启这个选择存储的节点
204   defaultDataPath: /var/lib/longhorn  # 选择存储目录，或者还选择默认，后面安装好之后页面添加新的挂载存储目录也可以

$ helm upgrade --install -n longhorn-system longhorn ./ -f values.yaml --create-namespace

$ kubectl edit daemonsets.apps -n longhorn-system engine-image-ei-052c0c75

      tolerations:
      - effect: NoSchedule
        key: longhorn
        operator: Equal
        value: "true"
  
$ kubectl edit daemonsets.apps -n longhorn-system longhorn-csi-plugin

      tolerations:
      - effect: NoSchedule
        key: longhorn
        operator: Equal
        value: "true"

$ kubectl get pod,svc -n longhorn-system 
NAME                                                    READY   STATUS    RESTARTS        AGE
pod/csi-attacher-64c967787b-9jx9f                       1/1     Running   0               3h49m
pod/csi-attacher-64c967787b-dnvf5                       1/1     Running   0               3h49m
pod/csi-attacher-64c967787b-rbqtz                       1/1     Running   0               3h49m
pod/csi-provisioner-7f5fc57cff-9glff                    1/1     Running   1               3h49m
pod/csi-provisioner-7f5fc57cff-h8lkb                    1/1     Running   1 (3h46m ago)   3h49m
pod/csi-provisioner-7f5fc57cff-jxxwr                    1/1     Running   0               3h49m
pod/csi-resizer-7fbf9cc9bd-7dnrs                        1/1     Running   1 (3h47m ago)   3h49m
pod/csi-resizer-7fbf9cc9bd-7nz8t                        1/1     Running   1 (3h46m ago)   3h49m
pod/csi-resizer-7fbf9cc9bd-cqz8s                        1/1     Running   0               3h49m
pod/csi-snapshotter-55878c9b44-22jht                    1/1     Running   0               3h49m
pod/csi-snapshotter-55878c9b44-9zhzs                    1/1     Running   0               3h49m
pod/csi-snapshotter-55878c9b44-sbj8l                    1/1     Running   0               3h49m
pod/engine-image-ei-052c0c75-256rw                      1/1     Running   0               3h50m
pod/engine-image-ei-052c0c75-9sdhf                      1/1     Running   0               3h50m
pod/engine-image-ei-052c0c75-fx6rg                      1/1     Running   0               3h50m
pod/engine-image-ei-052c0c75-hqbz4                      1/1     Running   0               3h50m
pod/engine-image-ei-052c0c75-l78sb                      1/1     Running   0               3h50m
pod/engine-image-ei-052c0c75-sd7wz                      1/1     Running   0               3h50m
pod/engine-image-ei-052c0c75-sxz4h                      1/1     Running   0               3h50m
pod/instance-manager-01ceee528ef1f57d1eaddef9b18d2273   1/1     Running   0               3h49m
pod/instance-manager-10d75ae37472929439734eacfbf515d8   1/1     Running   0               3h50m
pod/instance-manager-4f2d8d9c854b658ed54a9f7b5f6f718b   1/1     Running   0               3h49m
pod/instance-manager-71bf870bb25dbd2f959a43eb30a7fd69   1/1     Running   0               3h50m
pod/instance-manager-838c480c33aa76ed918139c9b7aca18f   1/1     Running   0               3h50m
pod/instance-manager-87619c5e6705e2ec28e9a04b20f3fd5b   1/1     Running   0               3h49m
pod/instance-manager-bb955981f34fd1a158dacedba2547670   1/1     Running   0               3h49m
pod/longhorn-csi-plugin-4ktcn                           3/3     Running   0               3h49m
pod/longhorn-csi-plugin-55p7d                           3/3     Running   0               3h49m
pod/longhorn-csi-plugin-5pgpq                           3/3     Running   1 (3h46m ago)   3h49m
pod/longhorn-csi-plugin-8sgqx                           3/3     Running   0               3h49m
pod/longhorn-csi-plugin-srlwx                           3/3     Running   0               3h49m
pod/longhorn-csi-plugin-wlnvx                           3/3     Running   0               3h49m
pod/longhorn-csi-plugin-xvcxf                           3/3     Running   0               3h49m
pod/longhorn-driver-deployer-58fdb7c75b-dlrtf           1/1     Running   0               3h50m
pod/longhorn-manager-6q8d9                              2/2     Running   0               3h50m
pod/longhorn-manager-b4cnb                              2/2     Running   0               3h50m
pod/longhorn-manager-bh2qb                              2/2     Running   0               3h50m
pod/longhorn-manager-f4nnw                              2/2     Running   0               3h50m
pod/longhorn-manager-lsfrq                              2/2     Running   0               3h50m
pod/longhorn-manager-np6m7                              2/2     Running   0               3h50m
pod/longhorn-manager-qvpqp                              2/2     Running   0               3h50m
pod/longhorn-ui-6f69c4445d-p9frv                        1/1     Running   0               3h50m
pod/longhorn-ui-6f69c4445d-z6mt6                        1/1     Running   0               3h50m

NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
longhorn-admission-webhook    ClusterIP   10.96.72.18     <none>        9502/TCP       3h50m
longhorn-backend              NodePort   10.96.27.121     <none>        9500:32188/TCP 3h50m
longhorn-conversion-webhook   ClusterIP   10.96.210.167   <none>        9501/TCP       3h50m
longhorn-frontend             NodePort    10.96.252.185   <none>        80:32180/TCP   3h50m
longhorn-recovery-backend     ClusterIP   10.96.57.224    <none>        9503/TCP       3h50m
```

![](/images/posts/Linux-Kubernetes/Kubernetes部署Longhorn分布式存储集群/1.png)

### 7. 卸载集群

```sh
$ kubectl -n longhorn-system patch -p '{"value": "true"}' --type=merge lhs deleting-confirmation-flag
$ helm uninstall -n longhorn-system longhorn
```

如果出现 namespace 无法删除一直 Terminating ，查看都有哪些资源没有删除干净，一般是 CRD 资源

```sh
$ kubectl get validatingwebhookconfigurations|grep long
longhorn-webhook-validator                    1          17h

$ kubectl get mutatingwebhookconfigurations|grep long
longhorn-webhook-mutator                      1          17h

$ kubectl delete validatingwebhookconfigurations longhorn-webhook-validator
validatingwebhookconfiguration.admissionregistration.k8s.io "longhorn-webhook-validator" deleted

$ kubectl delete mutatingwebhookconfigurations longhorn-webhook-mutator
mutatingwebhookconfiguration.admissionregistration.k8s.io "longhorn-webhook-mutator" deleted

$ kubectl get crd |grep longhorn
nodes.longhorn.io                                     2024-10-21T07:45:50Z
orphans.longhorn.io                                   2024-10-21T07:45:50Z

$ kubectl patch crd nodes.longhorn.io  -p '{"metadata":{"finalizers":[]}}' --type=merge

$ kubectl patch crd orphans.longhorn.io  -p '{"metadata":{"finalizers":[]}}' --type=merge

# 最后再尝试删除 namespace
$ kubectl delete ns longhorns-system
namespace "longhorns-system" deleted
```

## 三、配置 Prometheus 监控

这里采用kube-Prometheus项目进行监控。

Longhorn 在 REST 端点上以 Prometheus 文本格式原生公开指标。`http://LONGHORN_MANAGER_IP:PORT/metrics`

官方示例。监控系统使用Prometheus来收集数据和警报，Grafana用于可视化/仪表板收集的数据。从高级概述来看，监控系统包含：

- Prometheus服务器，从Longhorn指标端点抓取和存储时间序列数据。Prometheus还负责根据配置的规则和收集的数据生成警报。然后，Prometheus服务器向警报管理器发送警报。
- 然后，AlertManager 管理这些警报，包括静音、抑制、聚合以及通过电子邮件、待命通知系统和聊天平台等方法发送通知。
- Grafana查询Prometheus服务器以获取数据并绘制用于可视化的仪表板。

### 1. 使用 ServiceMonitor 获取指标数据

```sh
$ vim monitoring/longhorn-backend-monitor.yaml 
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app.kubernetes.io/instance: kube-prometheus-stack
    app.kubernetes.io/name: longhorn
    release: kube-prometheus-stack
  name: kube-prometheus-stack-longhorn
  namespace: monitoring
spec:
  endpoints:
  - honorLabels: true
    path: /metrics
    port: manager
    scheme: http
    scrapeTimeout: 30s
  jobLabel: kube-prometheus-stack
  namespaceSelector:
    matchNames:
    - longhorn-system
  selector:
    matchLabels:
      app.kubernetes.io/instance: longhorn
      app.kubernetes.io/name: longhorn
      app: longhorn-manager

$ vim  monitoring/longhorn-backend-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    app.kubernetes.io/name: kube-prometheus
    app.kubernetes.io/part-of: kube-prometheus
    prometheus: k8s
    role: alert-rules
    release: kube-prometheus-stack
  name: prometheus-longhorn-rules
  namespace: monitoring
spec:
  groups:
  - name: longhorn.rules
    rules:
    - alert: Longhorn卷实际空间使用警告
      annotations:
        description: Longhorn卷{{$labels.volume}}在{{$labels.node}}上的实际使用空间已达到容量的{{$value}}%，并且这种情况已经持续超过5分钟。
        summary: Longhorn卷的实际使用空间超过了容量的90%。
      expr: (longhorn_volume_actual_size_bytes / longhorn_volume_capacity_bytes) * 100 > 90
      for: 5m
      labels:
        issue: Longhorn卷{{$labels.volume}}在{{$labels.node}}上的实际使用空间很高。
        severity: warning
    
    - alert: Longhorn卷状态严重警告
      annotations:
        description: Longhorn卷{{$labels.volume}}在{{$labels.node}}上的状态为故障，这种情况已经持续超过2分钟。
        summary: Longhorn卷{{$labels.volume}}处于故障状态
      expr: longhorn_volume_robustness == 3
      for: 5m
      labels:
        issue: Longhorn卷{{$labels.volume}}处于故障状态。
        severity: critical
    
    - alert: Longhorn卷状态警告
      annotations:
        description: Longhorn卷{{$labels.volume}}在{{$labels.node}}上的状态为降级，这种情况已经持续超过5分钟。
        summary: Longhorn卷{{$labels.volume}}处于降级状态
      expr: longhorn_volume_robustness == 2
      for: 5m
      labels:
        issue: Longhorn卷{{$labels.volume}}处于降级状态。
        severity: warning
    
    - alert: Longhorn节点存储警告
      annotations:
        description: 节点{{$labels.node}}上的已用存储空间已达到容量的{{$value}}%，并且这种情况已经持续超过5分钟。
        summary: 节点的已用存储空间超过了容量的70%。
      expr: (longhorn_node_storage_usage_bytes / longhorn_node_storage_capacity_bytes) * 100 > 70
      for: 5m
      labels:
        issue: 节点{{$labels.node}}上的已用存储空间很高。
        severity: warning
    
    - alert: Longhorn磁盘存储警告
      annotations:
        description: 节点{{$labels.node}}上的磁盘{{$labels.disk}}的已用存储空间已达到容量的{{$value}}%，并且这种情况已经持续超过5分钟。
        summary: 磁盘的已用存储空间超过了容量的70%。
      expr: (longhorn_disk_usage_bytes / longhorn_disk_capacity_bytes) * 100 > 70
      for: 5m
      labels:
        issue: 节点{{$labels.disk}}上的磁盘{{$labels.node}}的已用存储空间很高。
        severity: warning
    
    - alert: Longhorn节点离线警告
      annotations:
        description: 有{{$value}}个Longhorn节点已经离线超过5分钟。
        summary: Longhorn节点离线
      expr: (avg(longhorn_node_count_total) or on() vector(0)) - (count(longhorn_node_status{condition="ready"} == 1) or on() vector(0)) > 0
      for: 5m
      labels:
        issue: 有{{$value}}个Longhorn节点已经离线
        severity: warning
    
    - alert: Longhorn实例管理器CPU使用警告
      annotations:
        description: Longhorn实例管理器{{$labels.instance_manager}}在{{$labels.node}}上的CPU使用率/CPU请求是{{$value}}%，这种情况已经持续超过5分钟。
        summary: Longhorn实例管理器{{$labels.instance_manager}}在{{$labels.node}}上的CPU使用率/CPU请求超过300%。
      expr: (longhorn_instance_manager_cpu_usage_millicpu/longhorn_instance_manager_cpu_requests_millicpu) * 100 > 300
      for: 5m
      labels:
        issue: Longhorn实例管理器{{$labels.instance_manager}}在{{$labels.node}}上的CPU使用率是CPU请求的3倍。
        severity: warning
    
    - alert: Longhorn节点CPU使用警告
      annotations:
        description: Longhorn节点{{$labels.node}}上的CPU使用率/CPU容量是{{$value}}%，这种情况已经持续超过5分钟。
        summary: Longhorn节点{{$labels.node}}经历了超过5分钟的高CPU压力。
      expr: (longhorn_node_cpu_usage_millicpu / longhorn_node_cpu_capacity_millicpu) * 100 > 90
      for: 5m
      labels:
        issue: Longhorn节点{{$labels.node}}经历了高CPU压力。
        severity: warning
        
$ kubectl apply -f monitoring/
```

![](/images/posts/Linux-Kubernetes/Kubernetes部署Longhorn分布式存储集群/2.png)

### 2. 导入 Grafana 模版

模板：https://grafana.com/grafana/dashboards/13032

![](/images/posts/Linux-Kubernetes/Kubernetes部署Longhorn分布式存储集群/3.png)