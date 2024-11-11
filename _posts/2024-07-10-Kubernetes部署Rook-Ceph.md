---
layout: post
title: 2024-07-11-Kubernetes部署Rook-Ceph
date: 2024-07-11
tags: 实战-Kubernetes
music-id: 2138116445
---

## 一、Kubernetes 部署 rook-ceph

### 1. k8s 环境

我这儿使用了3个节点作为提供ceph存储的节点 node01 node02 node03

```sh
[root@master01 examples]# kubectl get node
NAME       STATUS   ROLES                  AGE   VERSION
master01   Ready    control-plane,master   62m   v1.23.0
node01     Ready    <none>                 60m   v1.23.0
node02     Ready    <none>                 60m   v1.23.0
node03     Ready    <none>                 60m   v1.23.0
```

### 2. 准备 rook 的 osd 存储的数据盘

> 1. 数据盘可以是一块硬盘sdb,也可以是硬盘的一个分区sdb2,或者是逻辑卷，但是这些都必须没有被格式过，没有指定文件系统类型。
> 2. 可以使用lsblk -f 来确认数据盘有没有被文件系统格式化过。FSTYPE字段为空即代表未被文件系统格式化过。
> 3. 如下所示，sdb和sda可以作为ceph的数据盘。
> 4. 因为我这个并不是所有的sdb是数据盘，有可能是sda，你们要检查仔细
> 5. (参考文章)[https://t.goodrain.com/d/8324-rook-ceph-v18]

```sh
[root@node01 ~]# lsblk -f
NAME            FSTYPE      LABEL           UUID                                   MOUNTPOINT
sdb                                                                                
sr0             iso9660     CentOS 7 x86_64 2020-11-04-11-36-43-00                 
sda                                                                                
├─sda2          LVM2_member                 mH38aX-0lZs-dJzG-c5wU-4fgr-xiuz-Z1m9ua 
│ ├─centos-swap swap                        048499e1-7fb0-4ce1-b968-235935f7fb8a   
│ └─centos-root xfs                         eedd90ab-d017-43d8-b941-c949eadc0308   /
└─sda1          xfs                         4d3cb8e1-e6eb-4259-95d9-6588de1a65dc   /boot

[root@node02 ~]# lsblk -f
NAME            FSTYPE      LABEL           UUID                                   MOUNTPOINT
sdb                                                                                
sr0             iso9660     CentOS 7 x86_64 2020-11-04-11-36-43-00                 
sda                                                                                
├─sda2          LVM2_member                 mH38aX-0lZs-dJzG-c5wU-4fgr-xiuz-Z1m9ua 
│ ├─centos-swap swap                        048499e1-7fb0-4ce1-b968-235935f7fb8a   
│ └─centos-root xfs                         eedd90ab-d017-43d8-b941-c949eadc0308   /
└─sda1          xfs                         4d3cb8e1-e6eb-4259-95d9-6588de1a65dc   /boot

[root@node03 ~]# lsblk -f
NAME            FSTYPE      LABEL           UUID                                   MOUNTPOINT
sdb                                                                                
├─sdb2          LVM2_member                 mH38aX-0lZs-dJzG-c5wU-4fgr-xiuz-Z1m9ua 
│ ├─centos-swap swap                        048499e1-7fb0-4ce1-b968-235935f7fb8a   
│ └─centos-root xfs                         eedd90ab-d017-43d8-b941-c949eadc0308   /
└─sdb1          xfs                         4d3cb8e1-e6eb-4259-95d9-6588de1a65dc   /boot
sr0             iso9660     CentOS 7 x86_64 2020-11-04-11-36-43-00                 
sda                                                                                
```

**如果磁盘之前已经使用过，需要进行清理，使用以下脚本进行清理**

```sh
#!/usr/bin/env bash
DISK="/dev/sdb"  #按需修改自己的盘符信息

# Zap the disk to a fresh, usable state (zap-all is important, b/c MBR has to be clean)

# You will have to run this step for all disks.
sgdisk --zap-all $DISK

# Clean hdds with dd
dd if=/dev/zero of="$DISK" bs=1M count=100 oflag=direct,dsync

# Clean disks such as ssd with blkdiscard instead of dd
blkdiscard $DISK

# These steps only have to be run once on each node
# If rook sets up osds using ceph-volume, teardown leaves some devices mapped that lock the disks.
ls /dev/mapper/ceph-* | xargs -I% -- dmsetup remove %

# ceph-volume setup can leave ceph-<UUID> directories in /dev and /dev/mapper (unnecessary clutter)
rm -rf /dev/ceph-*
rm -rf /dev/mapper/ceph--*

# Inform the OS of partition table changes
partprobe $DISK
```

### 3. 基础环境准备

- 安装 lvm2

> Ceph OSD 在某些情况下(比如启用加密或指定元数据设备)依赖于 LVM(Logical Volume Manager)。如果没有安装 LVM2 软件包，则虽然 Rook 可以成功创建 Ceph OSD，但是当节点重新启动时，重新启动的节点上运行的 OSD pod 将无法启动。
>
> `yum -y install lvm2`

- 加载RBD内核

> Ceph 存储需要包含了 RBD 模块的 Linux 内核来支持。在使用 Kubernetes 环境中运行 Ceph 存储之前，需要在 Kubernetes 节点上运行 modprobe rbd 命令来测试当前内核中是否已经加载了 RBD 内核。
> 查看内核有没有加载rbd模块
> 如下所示代表已加载
> `lsmod | grep rbd`
>
> 如未加载可手动加载rbd内核模块
> `modprobe rbd`

### 4. 升级内核

如果需要使用文件存储CephFS，则需要将操作系统内核版本升级到4.17以上。

理论上说升级 ceph 提供存储的节点就行，但是为了保险起见，建议都升级一下

```sh
[root@node01 ~]# wget https://linux.cc.iitk.ac.in/mirror/centos/elrepo/kernel/el7/x86_64/RPMS/kernel-lt-5.4.160-1.el7.elrepo.x86_64.rpm
[root@node01 ~]# rpm -ivh kernel-lt-5.4.160-1.el7.elrepo.x86_64.rpm
[root@node01 ~]# grub2-mkconfig -o /boot/grub2/grub.cfg
[root@node01 ~]# grub2-set-default 0
[root@node01 ~]# reboot
```

### 5. 下载rook

```sh
[root@master01 ~]# git clone --single-branch --branch v1.13.3 https://github.com/rook/rook.git
```

拉取镜像

```sh
[root@master01 ~]# cd rook/deploy/examples
[root@master01 ~]# docker pull quay.io/ceph/ceph:v18.2.1
[root@master01 ~]# docker pull quay.io/ceph/cosi:v0.1.1
[root@master01 ~]# docker pull quay.io/cephcsi/cephcsi:v3.10.1
[root@master01 ~]# docker pull quay.io/csiaddons/k8s-sidecar:v0.8.0
[root@master01 ~]# docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/csi-attacher:v4.4.2
[root@master01 ~]# docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/csi-node-driver-registrar:v2.9.1
[root@master01 ~]# docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/csi-provisioner:v3.6.3
[root@master01 ~]# docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/csi-resizer:v1.9.2
[root@master01 ~]# docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/csi-snapshotter:v6.3.2
[root@master01 ~]# docker pull rook/ceph:v1.13.3

[root@master01 ~]# docker tag rook/ceph:v1.13.3 harbor.meta42.indc.vnet.com/rook/ceph:v1.13.3
[root@master01 ~]# docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/csi-node-driver-registrar:v2.9.1 harbor.meta42.indc.vnet.com/rook/csi-node-driver-registrar:v2.9.1
[root@master01 ~]# docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/csi-resizer:v1.9.2 harbor.meta42.indc.vnet.com/rook/csi-resizer:v1.9.2
[root@master01 ~]# docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/csi-provisioner:v3.6.3 harbor.meta42.indc.vnet.com/rook/csi-provisioner:v3.6.3
[root@master01 ~]# docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/csi-snapshotter:v6.3.2 harbor.meta42.indc.vnet.com/rook/csi-snapshotter:v6.3.2
[root@master01 ~]# docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/csi-attacher:v4.4.2 harbor.meta42.indc.vnet.com/rook/csi-attacher:v4.4.2

[root@master01 ~]# docker images |grep harbor.meta42.indc.vnet.com|awk '{print $1":"$2}'|xargs -n1 docker push

[root@master01 ~]# sed -i "s/registry.cn-hangzhou.aliyuncs.com\/google_containers/harbor.meta42.indc.vnet.com\/rook/g" operator.yaml

[root@master01 ~]# grep -rl "rook/ceph:v1.13.3" . | xargs sed -i 's/rook\/ceph:v1.13.3/harbor.meta42.indc.vnet.com\/rook\/ceph:v1.13.3/g'
```

### 6. 启动服务

```sh
[root@examples]# kubectl label nodes {k8s-node5-ceph,k8s-node6-ceph,k8s-node7-ceph} role=storage-node
[root@examples]# kubectl taint nodes {k8s-node5-ceph,k8s-node6-ceph,k8s-node7-ceph} storage-node=true:NoSchedule
[root@examples]# vim operator.yaml  # 取消109-114行注释并修改你私有仓库的镜像
[root@examples]# vim cluster.yaml   # 取消164-179行注释
[root@examples]# kubectl create -f crds.yaml -f common.yaml -f operator.yaml
[root@examples]# kubectl -n rook-ceph get pod
rook-ceph-operator-6c54c49f5f-7q8nd                1/1     Running     0          2m

# 修改配置文件，默认自动发现所有节点并使用数据盘
# 我们修改为自动的
[root@examples]# vim cluster.yaml
  removeOSDsIfOutAndSafeToRemove: false
  priorityClassNames:
    #all: rook-ceph-default-priority-class
    mon: system-node-critical
    osd: system-node-critical
    mgr: system-cluster-critical
    #crashcollector: rook-ceph-crashcollector-priority-class
  storage: # cluster level storage configuration and selection
    useAllNodes: false      # 修改 true 为 false
    useAllDevices: false    # 修改 true 为 false
    #deviceFilter:
    config:
    nodes:
    - name: "node01"        # 使用 node01 节点
      devices:
      - name: "sdb"         # 使用 sdb 数据盘
    - name: "node02"        # 使用 node02 节点
      devices:
      - name: "sdb"         # 使用 sdb 数据盘
    - name: "node03"        # 使用 node03 节点
      devices:
      - name: "sda"         # 使用 sda 数据盘

[root@examples]# kubectl create -f cluster.yaml

# 稍等10来分钟服务应该全部启动了
[root@master01 examples]# kubectl -n rook-ceph get pod
NAME                                               READY   STATUS      RESTARTS   AGE
csi-cephfsplugin-8v7lj                             2/2     Running     0          28m
csi-cephfsplugin-ch6nb                             2/2     Running     0          28m
csi-cephfsplugin-provisioner-6f5d88b7ff-kzrbw      5/5     Running     0          28m
csi-cephfsplugin-provisioner-6f5d88b7ff-ncx8d      5/5     Running     0          28m
csi-cephfsplugin-v6z5q                             2/2     Running     0          28m
csi-rbdplugin-dq4bt                                2/2     Running     0          28m
csi-rbdplugin-mbnrm                                2/2     Running     0          28m
csi-rbdplugin-provisioner-57f5ddbd7-8tl86          5/5     Running     0          28m
csi-rbdplugin-provisioner-57f5ddbd7-vcnpk          5/5     Running     0          28m
csi-rbdplugin-rp8r7                                2/2     Running     0          28m
rook-ceph-crashcollector-node01-559759d75f-g9qmg   1/1     Running     0          27m
rook-ceph-crashcollector-node02-d6965799b-cftfc    1/1     Running     0          26m
rook-ceph-crashcollector-node03-7f8f8668c7-dvm4c   1/1     Running     0          26m
rook-ceph-mgr-a-59757bdb6f-w6grv                   3/3     Running     0          27m
rook-ceph-mgr-b-78df4576db-92s5j                   3/3     Running     0          27m
rook-ceph-mon-a-7755d75f47-qz9bn                   2/2     Running     0          28m
rook-ceph-mon-b-848cc894c5-bw2bv                   2/2     Running     0          27m
rook-ceph-mon-c-86bfb74646-hzsw7                   2/2     Running     0          27m
rook-ceph-operator-6c54c49f5f-7q8nd                1/1     Running     0          29m
rook-ceph-osd-0-6db8745ff9-dd4ns                   2/2     Running     0          26m
rook-ceph-osd-1-6f98b96849-fpd7w                   2/2     Running     0          26m
rook-ceph-osd-2-55ddbc86bc-cnlb6                   2/2     Running     0          26m
rook-ceph-osd-prepare-node01-6vm7t                 0/1     Completed   0          26m
rook-ceph-osd-prepare-node02-9qdnf                 0/1     Completed   0          26m
rook-ceph-osd-prepare-node03-qz8nz                 0/1     Completed   0          26m
```

### 7. 检查服务状态

```sh
# 部署 ceph 提供的小工具
[root@master01 examples]# kubectl create -f toolbox.yaml

# 检查集群状态
[root@master01 examples]# kubectl -n rook-ceph exec -it rook-ceph-tools-598b59df89-5znpp -- ceph status
  cluster:
    id:     1d8ceab9-eab5-418c-ab00-db809b1fbb70
    health: HEALTH_OK
 
  services:
    mon: 3 daemons, quorum a,b,c (age 35m)
    mgr: a(active, since 32m), standbys: b
    osd: 3 osds: 3 up (since 34m), 3 in (since 34m)
 
  data:
    pools:   1 pools, 1 pgs
    objects: 2 objects, 449 KiB
    usage:   62 MiB used, 150 GiB / 150 GiB avail
    pgs:     1 active+clean
    
# 检查 Ceph 存储集群中 OSD（对象存储守护进程）的树状结构
[root@master01 examples]# kubectl -n rook-ceph exec -it rook-ceph-tools-598b59df89-5znpp -- ceph osd tree
ID  CLASS  WEIGHT   TYPE NAME        STATUS  REWEIGHT  PRI-AFF
-1         0.14639  root default                              
-5         0.04880      host node01                           
 2    hdd  0.04880          osd.2        up   1.00000  1.00000
-3         0.04880      host node02                           
 0    hdd  0.04880          osd.0        up   1.00000  1.00000
-7         0.04880      host node03                           
 1    hdd  0.04880          osd.1        up   1.00000  1.00000
 
# 检查 Ceph 集群中各个 OSD 的状态
[root@master01 examples]# kubectl -n rook-ceph exec -it rook-ceph-tools-598b59df89-5znpp -- ceph osd status
ID  HOST     USED  AVAIL  WR OPS  WR DATA  RD OPS  RD DATA  STATE      
 0  node02  20.5M  49.9G      0        0       0        0   exists,up  
 1  node03  20.5M  49.9G      0        0       0        0   exists,up  
 2  node01  20.5M  49.9G      0        0       0        0   exists,up
 
# 列出 Ceph 存储集群中的所有存储池
[root@master01 examples]# kubectl -n rook-ceph exec -it rook-ceph-tools-598b59df89-5znpp -- ceph osd pool ls
.mgr
```

### 8. 部署 Dashboard 控制台

```sh
[root@master01 examples]# kubectl -n rook-ceph delete svc rook-ceph-mgr-dashboard
service "rook-ceph-mgr-dashboard" deleted
[root@master01 examples]# kubectl apply -f dashboard-external-https.yaml 
service/rook-ceph-mgr-dashboard-external-https created
[root@master01 examples]# vim dashboard-ingress-https.yaml 
[root@master01 examples]# kubectl apply -f dashboard-ingress-https.yaml 
ingress.networking.k8s.io/rook-ceph-mgr-dashboard created
[root@master01 examples]# kubectl -n rook-ceph get ingress,svc
NAME                                                CLASS    HOSTS                   ADDRESS   PORTS     AGE
ingress.networking.k8s.io/rook-ceph-mgr-dashboard   <none>   rook-ceph.example.com             80, 443   8m43s

NAME                                             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
service/rook-ceph-mgr                            ClusterIP   10.101.205.181   <none>        9283/TCP            52m
service/rook-ceph-mgr-dashboard                  ClusterIP   10.105.255.190   <none>        8443/TCP            1s
service/rook-ceph-mgr-dashboard-external-https   NodePort    10.98.162.148    <none>        8443:32237/TCP      9m20s
service/rook-ceph-mon-a                          ClusterIP   10.106.94.226    <none>        6789/TCP,3300/TCP   54m
service/rook-ceph-mon-b                          ClusterIP   10.99.74.198     <none>        6789/TCP,3300/TCP   53m
service/rook-ceph-mon-c                          ClusterIP   10.103.210.177   <none>        6789/TCP,3300/TCP   53m

# 获取登录密码
[root@master01 examples]# kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}"|base64 --decode && echo
c\0ewx,Ny`g;AQ0;.HBa
```

![](/images/posts/Linux-Kubernetes/部署rook-ceph/1.png)

![](/images/posts/Linux-Kubernetes/部署rook-ceph/2.png)

## 二、kubernetes 持久化存储

**ceph使用的rbd提供块存储，kubernetes的存储方式是存储类（storageclass）**

**这里采用rook提供的storageclass.yaml来创建基于ceph的存储类**

### 1. 创建存储RBD存储类

```sh
# 里面有三种存储类的方式
[root@master01 examples]# cd csi/
[root@master01 csi]# ls
cephfs  nfs  rbd
[root@master01 csi]# cd rbd/
[root@master01 rbd]# ls
pod-ephemeral.yaml  pvc-clone.yaml    pvc.yaml            snapshot.yaml         storageclass-test.yaml
pod.yaml            pvc-restore.yaml  snapshotclass.yaml  storageclass-ec.yaml  storageclass.yaml
# 执行rook自带的创建ceph rbd 存储类的yaml,创建存储类
[root@master01 rbd]# kubectl create -f storageclass.yaml

# 配置文件中包含了一个名为 replicapool 的存储池，和名为 rook-ceph-block 的 storageClass
[root@master01 rbd]# kubectl -n rook-ceph exec -it rook-ceph-tools-598b59df89-5znpp -- ceph osd pool ls
.mgr
replicapool

[root@master01 rbd]# kubectl get sc
NAME                      PROVISIONER                  RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-provisioner-storage   example.com/nfs              Delete          Immediate           false                  103m
rook-ceph-block           rook-ceph.rbd.csi.ceph.com   Delete          Immediate           true                   5s

# 测试存储类是否可以直接创建pvc，不需要提前创建pv
[root@master01 rbd]# kubectl apply -f pvc.yaml 
persistentvolumeclaim/rbd-pvc created
[root@master01 rbd]# kubectl get pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
rbd-pvc   Bound    pvc-a1f57663-737e-448d-aef3-0cedcef14a54   1Gi        RWO            rook-ceph-block   5s
```

### 2. 创建 word press 测试

```sh
[root@master01 examples]# kubectl apply -f mysql.yaml 
service/wordpress-mysql created
persistentvolumeclaim/mysql-pv-claim created
deployment.apps/wordpress-mysql created

[root@master01 examples]# kubectl apply -f wordpress.yaml 
service/wordpress created
persistentvolumeclaim/wp-pv-claim created
deployment.apps/wordpress created
```

### 3. 报错提示

如果遇到如下报错应该是 kubelet 的数据目录不是默认的导致的

**解决方案：**
修改 /etc/docket/daemon.json，恢复root-dir 为默认 /var/lib/docker
修改 /etc/default/kubelet，恢复root-dir 为默认 /var/lib/kubelet

```sh
Events:
  Type     Reason                  Age                  From                     Message
  ----     ------                  ----                 ----                     -------
  Warning  FailedScheduling        20m                  default-scheduler        0/4 nodes are available: 4 pod has unbound immediate PersistentVolumeClaims.
  Normal   Scheduled               20m                  default-scheduler        Successfully assigned default/wordpress-mysql-79966d6c5b-fkkkf to node02
  Normal   SuccessfulAttachVolume  20m                  attachdetach-controller  AttachVolume.Attach succeeded for volume "pvc-c261b39a-bd00-4e85-8360-fd86ba2de676"
  Warning  FailedMount             15m                  kubelet                  Unable to attach or mount volumes: unmounted volumes=[mysql-persistent-storage], unattached volumes=[kube-api-access-7fqwt mysql-persistent-storage]: timed out waiting for the condition
  Warning  FailedMount             101s (x17 over 20m)  kubelet                  MountVolume.MountDevice failed for volume "pvc-c261b39a-bd00-4e85-8360-fd86ba2de676" : kubernetes.io/csi: attacher.MountDevice failed to create newCsiDriverClient: driver name rook-ceph.rbd.csi.ceph.com not found in the list of registered CSI drivers
```

```sh
[root@master01 examples]# kubectl -n rook-ceph logs -f csi-rbdplugin-rp8r7 csi-rbdplugin 
W0710 14:05:09.462037   13116 util.go:280] kernel 5.4.160-1.el7.elrepo.x86_64 does not support required features
W0710 14:05:09.462091   13116 rbd_attach.go:241] kernel version "5.4.160-1.el7.elrepo.x86_64" doesn't support cookie feature
```

### 4. 查看服务状态是否正常

```sh
# 查看 pvc 状态
[root@master01 examples]# kubectl get pvc
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
mysql-pv-claim   Bound    pvc-9cb5e087-0f91-47f9-b429-1e93f71270b4   20Gi       RWO            rook-ceph-block   7m33s
wp-pv-claim      Bound    pvc-37ece52c-e4f8-4f22-a00e-181b3fe40f8e   20Gi       RWO            rook-ceph-block   5m19s

# 查看 pod 启动状态
[root@master01 examples]# kubectl get pod -o wide
NAME                               READY   STATUS    RESTARTS   AGE     IP                NODE     NOMINATED NODE   READINESS GATES
wordpress-b98c66fff-j46cf          1/1     Running   0          4m14s   192.168.196.153   node01   <none>           <none>
wordpress-mysql-79966d6c5b-wbvms   1/1     Running   0          6m28s   192.168.196.152   node01   <none>           <none>

# 进入容器查看挂载盘
[root@master01 examples]# kubectl exec -it wordpress-mysql-79966d6c5b-wbvms -- df -h
Filesystem                         Size  Used Avail Use% Mounted on
overlay                             24G   15G  8.1G  64% /
tmpfs                               64M     0   64M   0% /dev
tmpfs                              1.9G     0  1.9G   0% /sys/fs/cgroup
/dev/mapper/ubuntu--vg-ubuntu--lv   24G   15G  8.1G  64% /etc/hosts
shm                                 64M     0   64M   0% /dev/shm
/dev/rbd0                           20G  116M   20G   1% /var/lib/mysql        # 可以看到使用的设备是 rbd0 ，容量为 20G
tmpfs                              3.7G   12K  3.7G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                              1.9G     0  1.9G   0% /proc/acpi
tmpfs                              1.9G     0  1.9G   0% /proc/scsi
tmpfs                              1.9G     0  1.9G   0% /sys/firmware

[root@master01 examples]# kubectl exec -it wordpress-b98c66fff-j46cf -- df -h
Filesystem                         Size  Used Avail Use% Mounted on
overlay                             24G   15G  8.1G  64% /
tmpfs                               64M     0   64M   0% /dev
tmpfs                              1.9G     0  1.9G   0% /sys/fs/cgroup
/dev/mapper/ubuntu--vg-ubuntu--lv   24G   15G  8.1G  64% /etc/hosts
shm                                 64M     0   64M   0% /dev/shm
/dev/rbd1                           20G   26M   20G   1% /var/www/html              # 可以看到使用的设备是 rbd1 ，容量为 20G
tmpfs                              3.7G   12K  3.7G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                              1.9G     0  1.9G   0% /proc/acpi
tmpfs                              1.9G     0  1.9G   0% /proc/scsi
tmpfs                              1.9G     0  1.9G   0% /sys/firmware
```
![](/images/posts/Linux-Kubernetes/部署rook-ceph/3.png)
