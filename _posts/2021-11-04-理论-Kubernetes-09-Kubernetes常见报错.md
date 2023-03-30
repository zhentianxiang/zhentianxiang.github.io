---
layout: post
title: 理论-Kubernetes-09-Kubernetes常见报错
date: 2021-11-04
tags: 理论-Kubernetes
---

## 一、kubelet服务相关问题

### 1. 8080端口被拒

**现象**

```sh
The connection to the server localhost:8080 was refused - did you specify the right host or port?
```

**原因**

出现以上8080端口连接被拒，多数情况下应该是你用的非root用户登录导致的，此时你应该需要把rootsh目录下面的kube目录拷贝到你的当前目录下。

**解决办法**：

```sh
[root@centos7 ~]# sudo cp -r /root/.kube .sh
```

### 2. 6443端口被拒

```sh
The connection to the server x.x.x.x:6443 was refused - did you specify the right host or port?
```

出现以上6443端口被拒，多数情况是因为kubelet服务没正常启动导致的，此时需要检查kubelet服务。

```sh
[root@centos7 ~]# systemctl status kubelet
```

如果查看结果是未启动状态的话，这时就需要检查kubelet日志了。

```sh
[root@centos7 ~]# journalctl -xefu kubelet
```

此时日志查看非常复杂，需要认真仔细排查，这里就简单列出几例：

#### 2.1 cgroup driver问题

**现象**

```
failed to run Kubelet: misconfiguration: kubelet cgroup driver:"cgroupfs" is different from docker cgroup driver: "systemd"
```

**原因：**
kubelet cgroup driver 与docker 不一致

**解决办法**：

修改daemon.json文件

```sh
# 在配置文件中添加exec-opts项目，我这里仅是举例，实际情况需要按照你的配置文件来修改。
[root@centos7 ~]# cat /etc/docker/daemon.json
{
"exec-opts": ["native.cgroupdriver=systemd"]
}
```

#### 2.2 swap开启导致kubelet启动失败

**现象**

```sh
failed to run Kubelet: Running with swap on is not supported, please disable swap! or set --fail-swap-on flag to false. /proc/swaps contained: [Filename                                Type                Size        Used        Priority /swapfile                            sh   file                2097148        0        -2]
```

**原因**

开启了swap分区

```sh
[root@centos7 ~]# free -h
              total        used        free      shared  buff/cache   available
Mem:           3.7G        262M        738M         30M        2.7G        3.2G
Swap:          3.9G         57M        3.8G
```

**解决办法：**

```sh
# 临时关闭swap
[root@centos7 ~]# swap -ash
# 永久关闭
# 注释掉下面的swap挂载
# 于centos永久关闭swap使用此办法生效，但是对于Ubuntu来说的话不太好用，建议写一个开机脚本来解决问题
[root@centos7 ~]# vim /etc/fstab


#
# /etc/fstab
# Created by anaconda on Fri Oct 22 13:36:37 2021
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/centos-root /                       xfs     defaults        0 0
UUID=d7d4fb6a-9f02-4456-8822-d3a265a10c67 /boot                   xfs     defaults        0 0
/dev/mapper/centos-home /home                   xfs     defaults        0 0

#/dev/mapper/centos-swap swap                    swap    defaults        0 0
```

## 二、集群相关问题

### 1. pod状态

#### 1.1 Terminating

字面意思是结束的意思，但是时候pod会一直卡在这个状态下，普通的delete也无法删掉，不得已只能强制删除pod

强制删除pod如下：

```sh
[root@centos7 ~]# sudo kubectl delete pod --grace-period=0 --force -n kube-system calico-kube-controllers-77d6cbc65f-tthnc
```

删除完成后会有提示警告

```sh
warning: Immediate deletion does not wait for confirmation that the running resource has been terminated. The resource may continue to run on the cluster indefinitely.
pod "calico-kube-controllers-77d6cbc65f-tthnc" force delete
```

#### 1.2 ImagePullBackOff

字面意思是pod启动时镜像拉取失败，但是对于这种问题我们一般不会轻易的去犯错，毕竟镜像有没有自己心里还是很清楚的，多数情况下问题会出在哪里呢？要么是有人误删了docker镜像，要么就是docker存储目录被修改了，导致镜像包括容器也被清除了。但是！还有一些情况下是本地存储打满了，触发了pod驱逐策略，由此k8s会自动清空一些镜像和容器。至此产生1.3 标题问题。

#### 1.3 Eviction

此状态就是上面提到的pod被驱逐后，pod状态会变更为Eviction
大致流程应该是：kubelet监控node资源状态——>判断是否达到驱逐阈值——>如果达到了——>尝试回收node资源，删除无用镜像——>如果node资源还未低于阈值——>则会驱逐pod

**默认node存储的驱逐触发条件：**

 - nodefs.available<10%（容器 volume 使用的文件系统的可用空间，包括文件系统剩余大小和 inode 数量）
 - imagefs.available<15%（容器镜像使用的文件系统的可用空间，包括文件系统剩余大小和 inode 数量）

当 imagefs 使用量达到阈值时，kubelet 会尝试删除不使用的镜像来清理磁盘空间。

> 当 nodefs 使用量达到阈值时，kubelet 就会拒绝在该节点上运行新 Pod，并向 API Server 注册一个 DiskPressure condition。然后 kubelet 会尝试删除死亡的 Pod 和容器来回收磁盘空间，如果此时 nodefs 使用量仍然没有低于阈值，kubelet 就会开始驱逐 Pod。从 Kubernetes 1.9 开始，kubelet 驱逐 Pod 的过程中不会参考 Pod 的 QoS，只是根据 Pod 的 nodefs 使用量来进行排名，并选取使用量最多的 Pod 进行驱逐。所以即使 QoS 等级为 Guaranteed 的 Pod 在这个阶段也有可能被驱逐（例如 nodefs 使用量最大）。如果驱逐的是 Daemonset，kubelet 会阻止该 Pod 重启，直到 nodefs 使用量超过阈值。

**默认node内存的驱逐出发条件：**

 - memory.available<100Mi

 > 当内存使用量超过阈值时，kubelet 就会向 API Server 注册一个 MemoryPressure condition，此时 kubelet 不会接受新的 QoS 等级为 Best Effort 的 Pod 在该节点上运行，并按照以下顺序来驱逐 Pod：
 当内存资源不足时，kubelet 在驱逐 Pod 时只会考虑 requests 和 Pod 的内存使用量，不会考虑 limits。

一般情况下服务器内存不会占用太多，反而是存储空间不够，如果由于存储空间导致的pod驱逐，那么可以去修改一下k8s对磁盘的使用率的上下

**解决办法**

调整磁盘使用率上限到95%，下限调整为94%，从而最大化保留数，调整驱逐策略
调整到达阈值后触发清理的等待时间，好在告警后第一时间处理
扩容当前磁盘，可通过LVM

```sh
# 在原有的配置项后面新加三条，分别为
--eviction-soft=memory.available<500Mi,nodefs.available<5%,nodefs.inodesFree<6%       #清理阈值的集合，如果达到一个清理周期将触发一次容器清理
--eviction-soft-grace-period=memory.available=300s,nodefs.available=300s,nodefs.inodesFree=300s      #清理周期的集合，在触发一个容器清理之前一个软清理阈值需要保持多久
--eviction-minimum-reclaim=memory.available=0Mi,nodefs.available=500Mi,imagefs.available=2Gi       #资源回收最小值的集合，即 kubelet 压力较大时 ，执行 pod 清理回收的资源最小值
[root@centos7 ~]# vim /var/lib/kubelet/kubeadm-flags.env
KUBELET_KUBEADM_ARGS="--cgroup-driver=systemd --network-plugin=cni --pod-infra-container-image=registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.2 \
--eviction-soft=memory.available<500Mi,nodefs.available<5%,nodefs.inodesFree<6%  \
--eviction-soft-grace-period=memory.available=300s,nodefs.available=300s,nodefs.inodesFree=300s  \
--eviction-minimum-reclaim=memory.available=0Mi,nodefs.available=500Mi,imagefs.available=2Gi"
[root@centos7 ~]# systemctl daemon-reload
[root@centos7 ~]# systemctl restart kubelet
```

 **总结**

因为 kubelet 默认每 10 秒抓取一次 cAdvisor 的监控数据，所以可能在资源使用量低于阈值时，kubelet 仍然在驱逐 Pod。
kubelet 将 Pod 从节点上驱逐之后，Kubernetes 会将该 Pod 重新调度到另一个资源充足的节点上。但有时候 Scheduler 会将该 Pod 重新调度到与之前相同的节点上，比如设置了节点亲和性，或者该 Pod 以 Daemonset 的形式运行。

> 参考原著：https://blog.csdn.net/a8138

#### 1.4 ContainerCreating

这个状态字面意思就是在创建容器中，一般多为拉取镜像中。但是个别情况下会出现镜像能拉取到，但是无法启动容器，有时会报错为如下

```sh
Error response from daemon: OCI runtime create failed: unable to retrieve OCI runtime error (open /run/containerd/io.containerd.runtime.
或者
Error response from daemon: cgroup-parent for systemd cgroup should be a valid slice named as "xxx.slice"
```

**问题1**

那出现这种情况就是kubelet的和docker的文件驱动不一致才导致的这个问题。docker默认的是Cgroup Driver: cgroupfs，而kubelet推荐使用systemd。

**解决办法**

编辑 /etc/docker/daemon.json (没有该文件就新建一个），添加如下启动项参数即可

```#!/bin/sh
{
  "exec-opts": ["native.cgroupdriver=systemd"]
}
```

编辑 /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf

```#!/bin/sh
在--kubeconfig=/etc/kubernetes/kubelet.conf后面添加--cgroup-driver=systemd
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --cgroup-driver=systemd"
```

重启docker和kubelet

```#!/bin/sh
[root@centos7 ~]# systemctl daemon-reload
[root@centos7 ~]# systemctl restart docker
[root@centos7 ~]# systemctl daemon-reload
[root@centos7 ~]# systemctl restart kubelet
```

**问题2**

出现以下这种情况pod也会一直创建中，而这种情况多半是网络出现故障导致的，此时首先要检查的是出问题的节点上有没有网关，然后才能依次往下进行判断

```#!/bin/sh
[root@localhost]# kubectl describe pod -n kube-system calico-kube-controllers-858fbfbc9-4l6rn
................
Failed to create pod sandbox: rpc error: code = Unknown desc = [failed to set up sandbox container "ab88af7b5685c1cf2e21f41273a41497767ca4c27a015c22186eb09a2e25983c" network for pod "calico-kube-controllers-858fbfbc9-4l6rn": networkPlugin cni failed to set up pod "calico-kube-controllers-858fbfbc9-4l6rn_kube-system" network: error getting ClusterInformation: Get "https://[10.96.0.1]:443/apis/crd.projectcalico.org/v1/clusterinformations/default": dial tcp 10.96.0.1:443: connect: network is unreachable, failed to clean up sandbox container "ab88af7b5685c1cf2e21f41273a41497767ca4c27a015c22186eb09a2e25983c" network for pod "calico-kube-controllers-858fbfbc9-4l6rn": networkPlugin cni failed to teardown pod "calico-kube-controllers-858fbfbc9-4l6rn_kube-system" network: error getting ClusterInformation: Get "https://[10.96.0.1]:443/apis/crd.projectcalico.org/v1/clusterinformations/default": dial tcp 10.96.0.1:443: connect: network is unreachable]
```

**解决方法**

因为我在测试离线环境，所以一开始我直接把网关注释掉了，才导致出现以上问题，k8s集群初始化包括启动pod，你可以没有网，但不能没有网关，哪怕是随便写网关也行
```#!/bin/sh
[root@localhost]# vim /etc/sysconfig/network-scripts/ifcfg-eth0
TYPE="Ethernet"
BOOTPROTO="static"
IPADDR=192.168.1.110
GATEWAY=192.168.2.1  #随便写的，很明显不是和地址一个网段
NETMASK=255.255.255.0
DNS1=192.168.2.1
DEFROUTE="yes"
NAME="eth0"
DEVICE="eth0"
ONBOOT="yes"
[root@localhost]# systemctl restart network
[root@localhost]# ip r
default via 192.168.2.1 dev eth0 proto static metric 100
blackhole 10.100.102.128/26 proto bird
10.100.102.130 dev calid12fef61571 scope link
10.100.102.131 dev calic98ccb2907d scope link
10.100.102.132 dev cali1fa932eec01 scope link
172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1
172.18.0.0/16 dev br-584e70b7b572 proto kernel scope link src 172.18.0.1
192.168.1.0/24 dev eth0 proto kernel scope link src 192.168.1.110 metric 100
192.168.2.1 dev eth0 proto static scope link metric 100      #网关
[root@localhost]# kubectl delete pod -n kube-system calico-kube-controllers-858fbfbc9-4l6rn
[root@localhost calico]# kubectl get pods -A
NAMESPACE     NAME                                            READY   STATUS    RESTARTS   AGE
kube-system   calico-kube-controllers-858fbfbc9-frnsg         1/1     Running   0          36s
kube-system   calico-node-wdhjr                               1/1     Running   1          2m24s
kube-system   coredns-546565776c-j6bw8                        1/1     Running   0          3m32s
kube-system   coredns-546565776c-sgtm6                        1/1     Running   0          3m32s
kube-system   etcd-localhost.localdomain                      1/1     Running   0          3m47s
kube-system   kube-apiserver-localhost.localdomain            1/1     Running   0          3m47s
kube-system   kube-controller-manager-localhost.localdomain   1/1     Running   0          3m47s
kube-system   kube-proxy-2dq2c                                1/1     Running   0          3m32s
kube-system   kube-scheduler-localhost.localdomain            1/1     Running   0          3m46s
```
### 2. node节点状态

#### 2.1 NotReady

一般情况下遇到这种问题是由于cni网络插件导致的，多数情况下需要重新安装cni网络插件，以下举例：

此次用的是calico网络插件

```sh
[root@centos7 ~]# wget https://docs.projectcalico.org/manifests/calico.yaml
[root@centos7 ~]# vim calico.yaml
3848             # add IP automatic detection
3849             - name: IP_AUTODETECTION_METHODsh
3850               value: "interface=ens3"  #本机网卡名称
[root@centos7 ~]# kubectl apply -f calico.yaml
[root@centos7 ~]# kubectl get pods -A
NAMESPACE     NAME                                            READY   STATUS             RESTARTS   AGE
kube-system   calico-kube-controllers-6c68d67746-vdfvc        1/1     Running            0          18h
kube-system   calico-node-qzt4j                               1/1     Running            0          18h
kube-system   coredns-546565776c-9mkqh                        1/1     Running            0          18h
kube-system   coredns-546565776c-btknr                        1/1     Running            0          18h
kube-system   etcd-localhost.localdomain                      1/1     Running            1          18h
kube-system   kube-apiserver-localhost.localdomain            1/1     Running            1          18h
kube-system   kube-controller-manager-localhost.localdomain   1/1     Running            1          18h
kube-system   kube-proxy-5k75n                                1/1     Running            1          18h
kube-system   kube-scheduler-localhost.localdomain            1/1     Running            1          18h
[root@centos7 ~]# kubectl get node
NAME            STATUS   ROLES    AGE   VERSION
master         Ready    master   18h   v1.18.19
```

但是！极端情况下可能是由于你对k8s集群的版本进行升级或者降低后，导致的这个状态也变为NotReady

```sh
[root@centos7 ~]# sudo kubectl get node
NAME     STATUS     ROLES    AGE    VERSION
master   Ready      master   300d   v1.22.2
node1    NotReady   <none>   105d   v1.16.0
```

查看日志发现

```sh
[root@centos7 ~]# journalctl -f
Failed to initialize CSINode: error updating CSINode annotationsh: timed out waiting for the condition; caused by: the server could not find the requested resource
```

系统自动将kubeadm kubelet kubectl更新到最新版本(当前为1.16.0)。新版本中默认启动了一个新特性，导致node1节点处于NotReady状态

**解决办法：**

禁用CSIMigration属性

在/var/lib/kubelet/config.yaml配置文件末尾下添加以下配置

```sh
featureGates:
  CSIMigration: false
```

重启kubelet

```sh
[root@centos7 ~]# systemctl daemon-reload
[root@centos7 ~]# systemctl restart kubelet
```

### 3. 容器网络报错

#### 3.1 容器无法解析service DNS

**环境**

Pod 开启了 hostNetwork: true

**问题**

pod 开启了hostNetwork无法正常解析service资源


**参考文献**


参考文献：https://blog.csdn.net/a8138/article/details/121184631


具体什么问题怎么造成的这里就不解释了，详情可以观看上面博主的文章


**解决方法**

如果开启了hostNetwork，需要添加一个字段key为`dnsPolicy` value为`ClusterFirstWithHostNet`

```#!/bin/sh
$ kubectl edit deployment nginx
···
spec:
  template:
    spec:
      dnsPolicy: ClusterFirstWithHostNet     # 调整策略
···
```

**分析**

以上问题就是，设置了hostnetwork的pod其默认情况下未指定的dnspolicy就是clusterfirst，然后，pod会继承所运行节点的解析配置。

![](/images/posts/Linux-Kubernetes/Kubernetes常见报错/1.png)

综上所说，所以就需要手动指定一下dnspolicy为ClusterFirstWithHostNet，详情可查阅官网：https://kubernetes.io/zh/docs/concepts/services-networking/dns-pod-service/

### 4.CoreDNS启动报错

**背景：**aarch64机器上面刚刚初始化完k8s集群，然后刚刚交付了CNI网络插件，查看pod状态，coredns 启动 bakoff

查看logs发现不输出日志，然后查看kubelet，发现cgroups方面提示报错

```#!/bin/sh
esc = failed to start container "359d3ce6e9117b3f8c1fb0efa25219c103c1163ad2b6abcd2d84d1841ff7fe0d": Error response from daemon: OCI runtime create failed: container_linux.go:318: starting container process caused "process_linux.go:281: applying cgroup configuration for process caused \"No such device or address\"": unknown
12月 22 17:53:24 kubernetes kubelet[290264]: E1222 17:53:24.370155  290264 kuberuntime_manager.go:818] container start failed: RunContainerError: failed to start container "359d3ce6e9117b3f8c1fb0efa25219c103c1163ad2b6abcd2d84d1841ff7fe0d": Error response from daemon: OCI runtime create failed: container_linux.go:318: starting container process caused "process_linux.go:281: applying cgroup configuration for process caused \"No such device or address\"": unknown
12月 22 17:53:24 kubernetes kubelet[290264]: E1222 17:53:24.370210  290264 pod_workers.go:191] Error syncing pod 7776dcf5-4013-46e4-97b3-67ff8f53b3fc ("coredns-7ff77c879f-lwcdg_kube-system(7776dcf5-4013-46e4-97b3-67ff8f53b3fc)"), skipping: failed to "StartContainer" for "coredns" with RunContainerError: "failed to start container \"359d3ce6e9117b3f8c1fb0efa25219c103c1163ad2b6abcd2d84d1841ff7fe0d\": Error response from daemon: OCI runtime create failed: container_linux.go:318: starting container process caused \"process_linux.go:281: applying cgroup configuration for process caused \\\"No such device or address\\\"\": unknown"
```

大概问题说的就是，docker的cgroups和kubelet的不一样，kubelet推荐使用systemd，而docker的是cgroups，但是问题来了，我们通常做k8s环境的时候都会修改一下docker的daemons.json文件，在里面添加一行配置，用来配置docker的cgroups变为systemd，`"exec-opts": ["native.cgroupdriver=systemd"]`，但是操蛋的问题就出来了，偏偏就是因为配置了这个选项，他提示报错，删了这条配置，coredns也就起来了

**解决方法就是：**

删除daemon.json文件中指定的systemd的驱动程序，而删除了之后，重启docker，执行docker info查看，默认的cgroups，这就与k8s推荐的冲突了，人家推荐用systemd，但是在aarch64机器上用推荐的还不行。。。

```#!/bin/sh
[root@kubernetes]# docker info |grep Cgroup
 Cgroup Driver: cgroupfs
```
