---
layout: post
title: Linux-Kubernetes-43-Kubernetes持久化存储实战(一)
date: 2021-12-25
tags: 实战-Kubernetes
---

## 一、NFS存储

| 服务器名称           | IP地址        | 配置  |      |
| -------------------- | ------------- | ----- | ---- |
| k8s-cluster-master01 | 192.168.1.171 | 8H8G  |      |
| k8s-cluster-master02 | 192.168.1.175 | 8H8G  |      |
| k8s-cluster-master03 | 192.168.1.180 | 8H8G  |      |
| k8s-cluster-node01   | 192.168.1.181 | 8H16G |      |
| nfs-server           | 192.168.1.184 | 2H1G  |      |

### 1. NFS服务端配置

```sh
[root@nfs-server ~]# yum -y install nfs-utils
[root@nfs-server ~]# mkdir /home/nfs_volume -pv
mkdir: 已创建目录 "/home/nfs_volume"
[root@nfs-server ~]# systemctl start nfs
[root@nfs-server ~]# systemctl enable nfs
[root@nfs-server ~]# vim /etc/exports
[root@nfs-server ~]# cat /etc/exports
/home/nfs_volume 192.168.1.184(rw,no_root_squash,async)
[root@nfs-server ~]# systemctl restart nfs
[root@nfs-server ~]# exportfs -arv
exporting 192.168.1.184:/home/nfs_volume
```

### 2. NFS客户端配置

k8s集群四台节点均同样操作

```sh
[root@k8s-cluster-master01 ~]# yum -y install nfs-utils
[root@k8s-cluster-master01 ~]# mkdir /home/nfs_volume
[root@k8s-cluster-master01 ~]# mount -t nfs 192.168.1.184:/home/nfs_volume /home/nfs_volume
[root@k8s-cluster-master01 ~]# df -h |tail -n 1
192.168.1.184:/home/nfs_volume 1023G  267G  757G   27% /home/nfs_volume
[root@k8s-cluster-master01 ~]# vim /etc/fstab
192.168.1.184:/home/nfs_volume /home/nfs_volume nfs defaults 0 0
```

### 3. 配置k8s使用nfs作为共享存储

#### 3.1 静态创建nfs存储的pv

准备资源清单

```sh
[root@k8s-cluster-master01 loki]# ls
ConfigMap.yaml  Deployment.yaml  PVC.yaml  PV.yaml  Rbac.yaml  service.yaml
```

静态创建pv资源

```yaml
[root@k8s-cluster-master01 nginx]# cat > PV.yaml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nginx-pv
  labels:
    app: nginx-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: nfs  #名字相同
  nfs:
    path: /home/nfs_volume
    server: 192.168.1.184
EOF
```

绑定pv

```sh
[root@k8s-cluster-master01 nginx]# cat > PVC.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-pvc
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: nfs
  selector:
    matchLabels:
      app: nginx-pv    # pv 的 labels
EOF
```

- Deploy清单

```yaml
[root@k8s-cluster-master01 nginx]# cat > nginx-ds.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    k8s-app: nginx
spec:
  type: NodePort
  selector:
    k8s-app: nginx
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
    nodePort: 8080
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx
  labels:
    k8s-app: nginx
spec:
  selector:
    matchLabels:
      k8s-app: nginx
  template:
    metadata:
      labels:
        k8s-app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        persistentVolumeClaim:
          claimName: nginx-pvc
      restartPolicy: Always
EOF
```

### 4. 启动服务

```sh
[root@k8s-cluster-master01 nginx]# kubectl apply -f .
persistentvolume/nginx-pv created
persistentvolumeclaim/nginx-pvc created
service/nginx created
daemonset.apps/nginx created
```

查看各个资源

```sh
[root@k8s-cluster-master01 nginx]# kubectl get pods,svc,pv,pvc
NAME              READY   STATUS    RESTARTS   AGE
pod/nginx-d6pkf   1/1     Running   0          2m35s
pod/nginx-h5jj6   1/1     Running   0          2m35s
pod/nginx-n8q76   1/1     Running   0          2m35s
pod/nginx-zblf9   1/1     Running   0          2m35s

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)       AGE
service/kubernetes   ClusterIP   10.96.0.1      <none>        443/TCP       115m
service/nginx        NodePort    10.107.52.35   <none>        80:8080/TCP   2m35s

NAME                          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                 STORAGECLASS   REASON   AGE

persistentvolume/nginx-pv     10Gi       RWX            Recycle          Bound    default/nginx-pvc     nfs                     2m36s

NAME                              STATUS   VOLUME     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/nginx-pvc   Bound    nginx-pv   10Gi       RWX            nfs            2m36s
```

#### 4.1 动态创建nfs存储的pv

首先我们要创建一个nfs-provisioner的pod

```yaml
[root@k8s-cluster-master01 nfs-provisioner]# cat > class.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-provisioner-storage
  #annotations:
    #storageclass.beta.kubernetes.io/is-default-class: "true"  #这个是让这个storage充当默认，这里不需要就注释掉
provisioner: example.com/nfs
EOF
```

```yaml
[root@k8s-cluster-master01 nfs-provisioner]# cat > rbac.yaml <<EOF
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
  - apiGroups: [""]
    resources: ["services", "endpoints"]
    verbs: ["get"]
  - apiGroups: ["extensions"]
    resources: ["podsecuritypolicies"]
    resourceNames: ["nfs-provisioner"]
    verbs: ["use"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-provisioner
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-provisioner
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-provisioner
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF
```

```yaml
[root@k8s-cluster-master01 nfs-provisioner]# cat > serviceaccount.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-provisioner
EOF
```

```yaml
[root@k8s-cluster-master01 nfs-provisioner]# cat > deployment.yaml <<EOF
kind: Deployment
apiVersion: apps/v1
metadata:
  name: nfs-provisioner
spec:
  selector:
    matchLabels:
      app: nfs-provisioner
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: nfs-provisioner
    spec:
      serviceAccount: nfs-provisioner
      containers:
        - name: nfs-provisioner
          image: registry.cn-hangzhou.aliyuncs.com/open-ali/nfs-client-provisioner:latest
          imagePullPolicy: IfNotPresent
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
            # 注意这个值要和class里面的一致
              value: example.com/nfs
            - name: NFS_SERVER
            # 注意修改地址
              value: 192.168.1.184
            - name: NFS_PATH
              value: /home/nfs_volume
      volumes:
        - name: nfs-client-root
          nfs:
          # 注意修改地址
            server: 192.168.1.184
            path: /home/nfs_volume
EOF
```
再准备一个nginx的服务用来测试动态创建pv

```yaml
[root@k8s-cluster-master01 nfs-provisioner]# cat > nginx-dp.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  labels:
    k8s-app: nginx-test
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: nginx-test
  template:
    metadata:
      labels:
        k8s-app: nginx-test
    spec:
      containers:
      - name: nginx-test
        image: nginx:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        persistentVolumeClaim:
          claimName: nginx-test-pvc
      restartPolicy: Always
EOF
```
```yaml
[root@k8s-cluster-master01 nfs-provisioner]# cat > nginx-pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-test-pvc
  annotations:
    volume.beta.kubernetes.io/storage-class: "nfs-provisioner-storage"
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
EOF
```

如果pvc无法绑定nfs，则查看nfs-provisioner提示报错如下
`Unexpected error getting claim reference to claim"default/nginx-test-pvc": selfLink was empty, can't make reference`

这个是由于k8s 1.20以后禁用了selfLink，需要在master节点的/etc/kubernetes/manifests/kube-apiserver.yaml文件添加

解决方法：spec.containers.command结尾处增加

```sh
- --feature-gates=RemoveSelfLink=false
```

## 二、ceph存储集群搭建

| 机器名称    | IP地址        | 配置          |
| ----------- | ------------- | ------------- |
| ceph-01     | 192.168.1.182 | 4H2G、vdb100G |
| ceph-02     | 192.168.1.134 | 4H2G、vdb100G |
| ceph-03     | 192.168.1.159 | 4H2G、vdb100G |
| ceph-client | 192.168.1.161 | 4H2G          |

ceph机器都要添加一块硬盘，用来做存储的数据盘

### 1. 基础环境配置

**四台机器同样操作**

关闭防火墙和selinux防护墙

```sh
[root@ceph-01 ~]# systemctl stop firewalld && systemctl disable firewalld
[root@ceph-01 ~]# setenforce 0
[root@ceph-01 ~]# sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```

修改机器名称

```sh
[root@ceph-01 ~]# hostnamectl set-hostname ceph-01
```

配置hosts地址解析

```sh
[root@ceph-01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.1.182 ceph-01
192.168.1.134 ceph-02
192.168.1.159 ceph-03
192.168.1.161 ceph-client
```

ceph01-ceph-clietn之间的免密登录

```sh
# 遇到提示就回车
[root@ceph-01 ~]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:2iq1E1Wt9wfKp3eEc50TLw+9yHOscljS0PSdlCWLN3U root@k8s-master01
The key's randomart image is:
+---[RSA 2048]----+
|           .  . E|
|          . .o *.|
|         . .+ * o|
|        . ...o.=.|
|       .S  ooo +=|
|      oo   .ooBoB|
|     ..o.   =ooOo|
|    . o.   o.=.+o|
|     ...    oo+. |
+----[SHA256]-----+
[root@ceph-01 ~]# ls ~/.ssh/
id_rsa  id_rsa.pub  known_hosts
```

拷贝公钥到3台机器上

```sh
[root@ceph-01 ~]# ssh-copy-id -i ~/.ssh/id_rsa.pub 192.168.1.134:~/.ssh/
```

验证ssh免密登录，都要验证一遍

```sh
[root@ceph-01 ~]# ssh 192.168.1.134
Last login: Tue Dec 21 14:04:15 2021 from 192.168.1.182
```

配置时间同步

```sh
[root@ceph-01 ~]# yum install ntpdate -y && ntpdate time.windows.com
```

### 2. 配置repo安装源

**四台机器同样操作**

```sh
[root@ceph-01 ~]# cat /etc/yum.repos.d/ceph.repo
[ceph]
name=ceph
baseurl=http://mirrors.aliyun.com/ceph/rpm-nautilus/el7/x86_64
enabled=1
gpgcheck=0
priority=1

[ceph-noarch]
name=cephnoarch
baseurl=http://mirrors.aliyun.com/ceph/rpm-nautilus/el7/noarch
enabled=1
gpgcheck=0
priority=1

[ceph-source]
name=ceph-source
baseurl=http://mirrors.aliyun.com/ceph/rpm-nautilus/el7/SRPMS
enabled=1
gpgcheck=0
priority=1
```

配置 epel 源

```sh
[root@ceph-01 ~]# wget -O /etc/yum.repos.d/epel-7.repo http://mirrors.aliyun.com/repo/epel-7.repo
```

### 3. 安装组件并配置

以下操作，有提示到多台机器操作就多台机器操作，没提示到就单台

```sh
[root@ceph-01 ~]# yum -y install ceph-deploy python-setuptools
[root@ceph-01 ~]# ceph-deploy --version
2.0.1
```

创建ceph工作目录

```sh
[root@ceph-01 ~]# mkdir /etc/ceph/ && cd /etc/ceph
[root@ceph-01 ceph]# ceph-deploy new ceph-01
[root@ceph-01 ceph]# ls
```

三台机器安装如下

安装ceph 程序和rgw对象存储，下面要用，所以提前装了

```sh
[root@ceph-01 ceph]# yum -y install ceph ceph-radosgw
[root@ceph-01 ceph]# ceph -v
ceph version 14.2.22 (ca74598065096e6fcbd8433c8779a2be0c889351) nautilus (stable)
[root@ceph-02 ceph]# yum -y install ceph ceph-radosgw
[root@ceph-03 ceph]# yum -y install ceph ceph-radosgw
```

或者也可以使用如下命令去安装

```sh
[root@ceph-01 ceph]# ceph-deploy install ceph-01 ceph-02 ceph-03
```

配置一下网段信息

```sh
[root@ceph-01 ceph]# echo public network = 192.168.1.0/24 >> /etc/ceph/ceph.conf
```

#### 3.1 mon 监控节点初始化

配置文件同步到所有节点

```sh
[root@ceph-01 ceph]# ceph-deploy mon create-initial
[root@ceph-01 ceph]# ps -ef |grep ceph-mon
ceph       23717       1  0 11:03 ?        00:00:17 /usr/bin/ceph-mon -f --cluster ceph --id ceph-01 --setuser ceph --setgroup ceph
root       23894   23803  0 11:44 pts/0    00:00:00 grep --color=auto ceph-mon
# 提示警报信息
[root@ceph-01 ~]# ceph health
HEALTH_WARN mon is allowing insecure glabal_id reclaim
# 添加三台ceph为监控节点
[root@ceph-01 ceph]# ceph-deploy admin ceph-01 ceph-02 ceph-03
[root@ceph-01 ceph]#  ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK
            mon is allowing insecure glabal_id reclaim     ////这里提示的和上面的一样

  services:
    mon: 1 daemons, quorum ceph-01 (age 48m)
    mgr: no daemons active
    osd: 0 osds: 0 up (since 11h), 0 in (since 11h)

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:
# 禁用不安全模式
[root@ceph-01 ceph]# ceph config set mon auth_allow_insecure_global_id_reclaim false
[root@ceph-01 ceph]# ceph health
HEALTH_OK
[root@ceph-01 ceph]#  ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK

  services:
    mon: 1 daemons, quorum ceph-01 (age 48m)
    mgr: no daemons active
    osd: 0 osds: 0 up (since 11h), 0 in (since 11h)

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:
```

防止mon单点故障，可以加多个mon节点（建议奇数个，因为有quorum仲载投票）

```sh
[root@ceph-01 ceph]# ceph-deploy mon add ceph-02
[root@ceph-01 ceph]# ceph-deploy mon add ceph-03
[root@ceph-01 ceph]# ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-01,ceph-02,ceph-03 (age 55m)      ////这里变成了3个节点
    mgr: no daemons active
    osd: 0 osds: 0 up (since 11h), 0 in (since 11h)

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:
```

查看mon各个状态

```sh
# 查看mon状态信息
root@ceph-01 ceph]# ceph mon stat
# 查看mon的选举状态
root@ceph-01 ceph]# ceph quorum_status
# 查看mon映射信息
root@ceph-01 ceph]# ceph mon dump
# 查看mon 详细状态
root@ceph-01 ceph]# ceph daemon mon.ceph-01 mon_status
```

#### 3.2 mgr 管理节点创建

```sh
# 创建一个mgr节点
[root@ceph-01 ceph]# ceph-deploy mgr create ceph-01
[root@ceph-01 ceph]# ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-01,ceph-02,ceph-03 (age 55m)      ////这里变成了3个节点
    mgr: ceph-01(active, since 11h)
    osd: 0 osds: 0 up (since 11h), 0 in (since 11h)

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:
# 添加多个mgr实现HA
[root@ceph-01 ceph]# ceph-deploy mgr create ceph-02
[root@ceph-01 ceph]# ceph-deploy mgr create ceph-03
[root@ceph-01 ceph]# ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-01,ceph-02,ceph-03 (age 55m)      ////这里变成了3个节点
    mgr: ceph-01(active, since 11h), standbys: ceph-02, ceph-03
    osd: 0 osds: 0 up (since 11h), 0 in (since 11h)

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   0 B used, 0 B / 0 B avail
    pgs:
```

#### 3.3 osd 存储盘创建

```sh
# 帮助命令
[root@ceph-01 ceph]# ceph-deploy disk --help
usage: ceph-deploy disk [-h] {zap,list} ...

Manage disks on a remote host.

positional arguments:
  {zap,list}
    zap       destroy existing data and filesystem on LV or partition
    list      List disk info from remote host(s)

optional arguments:
  -h, --help  show this help message and exit
# 帮助命令
[root@ceph-01 ceph]# ceph-deploy ods --help
usage: ceph-deploy [-h] [-v | -q] [--version] [--username USERNAME]
                   [--overwrite-conf] [--ceph-conf CEPH_CONF]
                   COMMAND ...
ceph-deploy: error: argument COMMAND: invalid choice: 'ods' (choose from 'new', 'install', 'rgw', 'mgr', 'mds', 'mon', 'gatherkeys', 'disk', 'osd', 'repo', 'admin', 'config', 'uninstall', 'purgedata', 'purge', 'forgetkeys', 'pkg', 'calamari')
# 格式化操作
[root@ceph-01 ceph]# ceph-deploy disk zap ceph-01 /dev/vdb
[root@ceph-01 ceph]# ceph-deploy disk zap ceph-02 /dev/vdb
[root@ceph-01 ceph]# ceph-deploy disk zap ceph-03 /dev/vdb
# 创建ceph盘
[root@ceph-01 ceph]# ceph-deploy osd create --data /dev/vdb ceph-01
[root@ceph-01 ceph]# ceph-deploy osd create --data /dev/vdb ceph-02
[root@ceph-01 ceph]# ceph-deploy osd create --data /dev/vdb ceph-03
[root@ceph-01 ceph]# ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-01,ceph-02,ceph-03 (age 79m)
    mgr: ceph-01(active, since 11h), standbys: ceph-02, ceph-03
    osd: 3 osds: 3 up (since 11h), 3 in (since 11h)

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   3.0 GiB used, 297 GiB / 300 GiB avail
    pgs:
```

#### 3.4 查看ceph osd 状态

```sh

[root@ceph-01 ceph]#  ceph osd stat
3 osds: 3 up (since 11h), 3 in (since 11h); epoch: e13
[root@ceph-01 ceph]# ceph osd dump
epoch 13
fsid 3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
created 2021-12-25 00:11:50.425025
modified 2021-12-25 00:47:42.840853
flags sortbitwise,recovery_deletes,purged_snapdirs,pglog_hardlimit
crush_version 7
full_ratio 0.95
backfillfull_ratio 0.9
nearfull_ratio 0.85
require_min_compat_client jewel
min_compat_client jewel
require_osd_release nautilus
max_osd 3
osd.0 up   in  weight 1 up_from 5 up_thru 0 down_at 0 last_clean_interval [0,0) [v2:192.168.1.182:6802/22120,v1:192.168.1.182:6803/22120] [v2:192.168.1.182:6804/22120,v1:192.168.1.182:6805/22120] exists,up 9482647f-4929-43e5-9b71-9f457e834406
osd.1 up   in  weight 1 up_from 9 up_thru 0 down_at 0 last_clean_interval [0,0) [v2:192.168.1.134:6800/21495,v1:192.168.1.134:6801/21495] [v2:192.168.1.134:6802/21495,v1:192.168.1.134:6803/21495] exists,up 961272ce-976f-4bd6-8d1f-a58f78b27cc0
osd.2 up   in  weight 1 up_from 13 up_thru 0 down_at 0 last_clean_interval [0,0) [v2:192.168.1.159:6800/20986,v1:192.168.1.159:6801/20986] [v2:192.168.1.159:6802/20986,v1:192.168.1.159:6803/20986] exists,up 7a1a7a75-5fd5-4bf2-8637-430169d123c1
[root@ceph-01 ceph]# ceph osd perf
osd commit_latency(ms) apply_latency(ms)
  2                  0                 0
  1                  0                 0
  0                  0                 0
[root@ceph-01 ceph]# ceph osd df
ID CLASS WEIGHT  REWEIGHT SIZE    RAW USE DATA    OMAP META  AVAIL   %USE VAR  PGS STATUS
 0   hdd 0.09769  1.00000 100 GiB 1.0 GiB 1.8 MiB  0 B 1 GiB  99 GiB 1.00 1.00   0     up
 1   hdd 0.09769  1.00000 100 GiB 1.0 GiB 1.8 MiB  0 B 1 GiB  99 GiB 1.00 1.00   0     up
 2   hdd 0.09769  1.00000 100 GiB 1.0 GiB 1.8 MiB  0 B 1 GiB  99 GiB 1.00 1.00   0     up
                    TOTAL 300 GiB 3.0 GiB 5.2 MiB  0 B 3 GiB 297 GiB 1.00                 
MIN/MAX VAR: 1.00/1.00  STDDEV: 0
[root@ceph-01 ceph]# ceph osd tree
ID CLASS WEIGHT  TYPE NAME        STATUS REWEIGHT PRI-AFF
-1       0.29306 root default                             
-3       0.09769     host ceph-01                         
 0   hdd 0.09769         osd.0        up  1.00000 1.00000
-5       0.09769     host ceph-02                         
 1   hdd 0.09769         osd.1        up  1.00000 1.00000
-7       0.09769     host ceph-03                         
 2   hdd 0.09769         osd.2        up  1.00000 1.00000
[root@ceph-01 ceph]# ceph osd getmaxosd
max_osd = 3 in epoch 13
```

### 4. 配置删除pool参数

```sh
[root@ceph-01 ceph]# echo mon_allow_pool_delete = true >> /etc/ceph/ceph.conf
[root@ceph-01 ceph]# echo mon_max_pg_per_osd = 2000 >> /etc/ceph/ceph.conf
[root@ceph-01 ceph]# cat /etc/ceph/ceph.conf
[global]
fsid = 3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
mon_initial_members = ceph-01
mon_host = 192.168.1.182
auth_cluster_required = cephx
auth_service_required = cephx
auth_client_required = cephx
public network = 192.168.1.0/24
mon_allow_pool_delete = true
mon_max_pg_per_osd = 2000
# 把配置同步到其他的mon节点，然后重启服务
[root@ceph-01 ceph]# ceph-deploy --overwrite-conf admin ceph-01 ceph-02 ceph-03
# 三台机器都要重启
[root@ceph-01 ceph]# systemctl restart ceph-mon.target
[root@ceph-01 ceph]# systemctl status ceph-mon.target
```

如果要删除pool，如下操作，现在不操作

```sh
[root@ceph-01 ceph]# ceph osd pool delete test_pool test_pool --yes-i-really-reallymena-it
# 再输一次
[root@ceph-01 ceph]# rados rmpool test_pool test_pool --yes-i-really-reallymena-it
```

**以上操作就是ceph集群的搭建过程**

## 三、ceph 文件存储

### 1. 在ceph-01同步配置文件并创建mds

```sh
# 这一步可以省略了，因为上面已经同步过了
[root@ceph-01 ceph]# ceph-deploy --overwrite-conf admin ceph-01 ceph-02 ceph-03

# 直接开始这一步，做3个mds，首先查看信息是没有的
[root@ceph-01 ceph]# ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-01,ceph-02,ceph-03 (age 2h)
    mgr: ceph-01(active, since 13h), standbys: ceph-02, ceph-03
    osd: 3 osds: 3 up (since 13h), 3 in (since 13h)

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   3.0 GiB used, 297 GiB / 300 GiB avail
    pgs:
[root@ceph-01 ceph]# ceph-deploy mds create ceph-01 ceph-02 ceph-03
[root@ceph-01 ceph]# ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-01,ceph-02,ceph-03 (age 2h)
    mgr: ceph-01(active, since 13h), standbys: ceph-02, ceph-03
    mds:  3 up:standby     //已经有信息了
    osd: 3 osds: 3 up (since 13h), 3 in (since 13h)

  task status:

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   3.0 GiB used, 297 GiB / 300 GiB avail
    pgs:
```

### 2. 一个ceph文件系统需要至少两个RADOS存储池，一个用于数据，一个用于元数据

```sh
[root@ceph-01 ceph]# ceph osd pool create cephfs_pool 128
pool 'cephfs_pool' created
[root@ceph-01 ceph]# ceph osd pool create cephfs_metadata 64
pool 'cephfs_metadata' created
[root@ceph-01 ceph]# ceph osd pool ls |grep cephfs
cephfs_pool
cephfs_metadata
```

### 3. 创建文件系统

```sh
[root@ceph-01 ceph]# ceph fs new cephfs cephfs_metadata cephfs_pool
new fs with metadata pool 2 and data pool 1
[root@ceph-01 ceph]# ceph fs ls
name: cephfs, metadata pool: cephfs_metadata, data pools: [cephfs_pool ]
[root@ceph-01 ceph]# ceph mds stat
cephfs:1 {0=ceph-02=up:active} 2 up:standby
```

### 4. 在ceph-02（上面查看时ceph-02是up状态）上创建客户端挂载需要的验证key文件，并传给客户端，ceph默认启用了cephx认证，需要客户端的挂载必须要用用户名和密码验证

```sh
[root@ceph-02 ceph]# ceph-authtool -p /etc/ceph/ceph.client.admin.keyring > /etc/ceph/admin.key
[root@ceph-02 ceph]# ls /etc/ceph/admin.key
/etc/ceph/admin.key
[root@ceph-02 ceph]# cat /etc/ceph/admin.key
AQBG8cVhtBFeGRAAE982roYfnMoXfG6bEXMA7A==
# 拷贝给客户端
[root@ceph-02 ceph]# scp admin.key ceph-client:/root
```

### 5. 部署client客户端节点

```sh
[root@ceph-01 ceph]# ceph-deploy install ceph-client
........................
[ceph-client][DEBUG ] 完毕！
[ceph-client][INFO  ] Running command: ceph --version
[ceph-client][DEBUG ] ceph version 14.2.22 (ca74598065096e6fcbd8433c8779a2be0c889351) nautilus (stable)
# 切换到client节点查看
[root@ceph-client ~]# ceph -v
ceph version 14.2.22 (ca74598065096e6fcbd8433c8779a2be0c889351) nautilus (stable)
# 同步配置文件
[root@ceph-01 ceph]# ceph-deploy --overwrite-conf admin ceph-01 ceph-02 ceph-03 ceph-client
# 切换过去查看
[root@ceph-client ~]# cd /etc/ceph/
[root@ceph-client ceph]# ls
rbdmap
[root@ceph-client ceph]# ll
总用量 12
-rw-------. 1 root root 151 12月 25 14:15 ceph.client.admin.keyring
-rw-r--r--. 1 root root 284 12月 25 14:15 ceph.conf
-rw-r--r--. 1 root root  92 6月  30 06:36 rbdmap
-rw-------. 1 root root   0 12月 25 14:15 tmpv7O5N6
```

第六步：在客户端安装ceph-fuse，并使用ceph-02产生的key文件进行挂载

```sh
[root@ceph-client ceph]# yum -y install ceph-fuse
[root@ceph-client ~]# ls
admin.key  anaconda-ks.cfg
[root@ceph-client ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                 908M     0  908M    0% /dev
tmpfs                    919M     0  919M    0% /dev/shm
tmpfs                    919M  8.7M  911M    1% /run
tmpfs                    919M     0  919M    0% /sys/fs/cgroup
/dev/mapper/centos-root   47G  1.9G   46G    4% /
/dev/vda1               1014M  150M  865M   15% /boot
tmpfs                    184M     0  184M    0% /run/user/0
[root@ceph-client ~]# ll /mnt/
总用量 0
# 地址可以是集群中任意一台的
[root@ceph-client ~]# mount -t ceph 192.168.1.182:6789:/ /mnt/ -o name=admin,secretfile=/root/admin.key
[root@ceph-client ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                 908M     0  908M    0% /dev
tmpfs                    919M     0  919M    0% /dev/shm
tmpfs                    919M  8.7M  911M    1% /run
tmpfs                    919M     0  919M    0% /sys/fs/cgroup
/dev/mapper/centos-root   47G  1.9G   46G    4% /
/dev/vda1               1014M  150M  865M   15% /boot
tmpfs                    184M     0  184M    0% /run/user/0
192.168.1.182:6789:/      94G     0   94G    0% /mnt
# 换另外一台机器测试
[root@ceph-client ~]# umount  /mnt
[root@ceph-client ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                 908M     0  908M    0% /dev
tmpfs                    919M     0  919M    0% /dev/shm
tmpfs                    919M  8.7M  911M    1% /run
tmpfs                    919M     0  919M    0% /sys/fs/cgroup
/dev/mapper/centos-root   47G  1.9G   46G    4% /
/dev/vda1               1014M  150M  865M   15% /boot
tmpfs                    184M     0  184M    0% /run/user/0
[root@ceph-client ~]# mount -t ceph 192.168.1.134:6789:/ /mnt/ -o name=admin,secretfile=/root/admin.key
[root@ceph-client ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                 908M     0  908M    0% /dev
tmpfs                    919M     0  919M    0% /dev/shm
tmpfs                    919M  8.7M  911M    1% /run
tmpfs                    919M     0  919M    0% /sys/fs/cgroup
/dev/mapper/centos-root   47G  1.9G   46G    4% /
/dev/vda1               1014M  150M  865M   15% /boot
tmpfs                    184M     0  184M    0% /run/user/0
192.168.1.134:6789:/      94G     0   94G    0% /mnt

```

### 6. 读写测试

```sh
[root@ceph-client ~]# echo zhenmouren > /mnt/zhen.txt
[root@ceph-client ~]# cat /mnt/zhen.txt
zhenmouren
```

测试多个客户端同时挂载并读写

```sh
[root@ceph-02 ceph]# scp admin.key ceph-03:/root
[root@ceph-03 ~]# mount -t ceph 192.168.1.182:6789:/ /mnt/ -o name=admin,secretfile=/root/admin.key
[root@ceph-03 ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                 908M     0  908M    0% /dev
tmpfs                    919M     0  919M    0% /dev/shm
tmpfs                    919M  8.7M  911M    1% /run
tmpfs                    919M     0  919M    0% /sys/fs/cgroup
/dev/mapper/centos-root   47G  2.2G   45G    5% /
/dev/vda1               1014M  150M  865M   15% /boot
tmpfs                    184M     0  184M    0% /run/user/0
tmpfs                    919M   52K  919M    1% /var/lib/ceph/osd/ceph-2
192.168.1.182:6789:/      94G     0   94G    0% /mnt
[root@ceph-03 ~]# cat /mnt/zhen.txt
zhenmouren
[root@ceph-03 ~]# echo niubi666 >/mnt/tian.txt
[root@ceph-03 ~]# cat /mnt/tian.txt
niubi666
# 切换到client查看
[root@ceph-client ~]# ll /mnt/
总用量 1
-rw-r--r-- 1 root root  9 12月 25 14:29 tian.txt
-rw-r--r-- 1 root root 11 12月 25 14:23 zhen.txt
[root@ceph-client ~]# cat /mnt/zhen.txt
zhenmouren
[root@ceph-client ~]# cat /mnt/tian.txt
niubi666
```

### 7. 删除数据，卸载磁盘

```sh
# 首先在客户端上删除数据，在umount 卸载存储
[root@ceph-client ~]# rm -rf /mnt/*
[root@ceph-client ~]# umount  /mnt
[root@ceph-client ~]# df -h |tail -n 1
tmpfs                    184M     0  184M    0% /run/user/0
# ceph-03也卸载
[root@ceph-03 ~]# umount /mnt
# 停掉所有结点的mds（只有停掉mds才能删除文件和存储）
[root@ceph-01 ~]#  systemctl stop ceph-mds.target
[root@ceph-02 ~]#  systemctl stop ceph-mds.target
[root@ceph-03 ~]#  systemctl stop ceph-mds.target
# 删除文件系统
[root@ceph-01 ceph]# ceph fs ls
name: cephfs, metadata pool: cephfs_metadata, data pools: [cephfs_pool ]
[root@ceph-01 ceph]# ceph fs rm cephfs --yes-i-really-mean-it
[root@ceph-01 ceph]# ceph fs ls
No filesystems enabled
# 删除元数据
[root@ceph-01 ceph]# ceph osd pool delete cephfs_metadata cephfs_metadata --yes-i-really-really-mean-it
pool 'cephfs_metadata' removed
[root@ceph-01 ceph]# ceph osd pool ls
cephfs_pool
# 删除存储池
[root@ceph-01 ceph]# ceph osd pool delete cephfs_pool cephfs_pool --yes-i-really-really-mean-it
pool 'cephfs_pool' removed
[root@ceph-01 ceph]# ceph osd pool ls
[root@ceph-01 ceph]#
```

在启动起来，刚才只是告诉你如何删除

```sh
[root@ceph-01 ceph]# systemctl start ceph-mds.target
[root@ceph-02 ceph]# systemctl start ceph-mds.target
[root@ceph-03 ceph]# systemctl start ceph-mds.target
[root@ceph-01 ceph]# ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-01,ceph-02,ceph-03 (age 4h)
    mgr: ceph-01(active, since 14h), standbys: ceph-02, ceph-03
    mds:  3 up:standby
    osd: 3 osds: 3 up (since 14h), 3 in (since 14h)

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   3.0 GiB used, 297 GiB / 300 GiB avail
    pgs:
```

## 四、ceph块存储

### 1. 在ceph-01节点上同步所有文件（包括client）

```sh
[root@ceph-01 ceph]# ceph-deploy --overwrite-conf admin ceph-01 ceph-02 ceph-03 ceph-client
```

### 2. 简历存储池，并初始化

```sh
[root@ceph-01 ceph]# ceph osd pool create rbd_pool 128
pool 'rbd_pool' created
[root@ceph-01 ceph]# ceph osd pool ls
rbd_pool
[root@ceph-01 ceph]# ceph osd ls
0
1
2
[root@ceph-01 ceph]# rbd pool init rbd_pool
```

### 3. 创建一个存储卷

名为volume1，大小500M

```sh
[root@ceph-01 ceph]# rbd create volume1 --pool rbd_pool --size 500
[root@ceph-01 ceph]# rbd ls rbd_pool
volume1
[root@ceph-01 ceph]# rbd info volume1 -p rbd_pool
rbd image 'volume1':
	size 500 MiB in 125 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 5fe51337474a
	block_name_prefix: rbd_data.5fe51337474a
	format: 2
	features: layering, exclusive-lock, object-map, fast-diff, deep-flatten
	op_features:
	flags:
	create_timestamp: Sat Dec 25 15:29:41 2021
	access_timestamp: Sat Dec 25 15:29:41 2021
	modify_timestamp: Sat Dec 25 15:29:41 2021
```

### 4. 将创建的卷映射成块设备

```sh
# 因为rbd镜像的一些特性，os kernel 并不支持，所以映射报错
[root@ceph-01 ceph]# rbd map rbd_pool/volume1
rbd: sysfs write failed
RBD image feature set mismatch. You can disable features unsupported by the kernel with "rbd feature disable rbd_pool/volume1 object-map fast-diff deep-flatten".
In some cases useful info is found in syslog - try "dmesg | tail".
rbd: map failed: (6) No such device or address
# 解决方法，关闭相关特性，命令上面已经提示
[root@ceph-01 ceph]# rbd feature disable rbd_pool/volume1 object-map fast-diff deep-flatten
[root@ceph-01 ceph]# rbd map rbd_pool/volume1
/dev/rbd0
# 查看映射（取消就是：rbd unmap /dev/rbd0）
[root@ceph-01 ceph]# rbd showmapped
id pool     namespace image   snap device    
0  rbd_pool           volume1 -    /dev/rbd0
```

### 5. 使用块存储

```sh
[root@ceph-01 ceph]# lsblk
NAME                                                                                                  MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sr0                                                                                                    11:0    1 1024M  0 rom  
vda                                                                                                   252:0    0   50G  0 disk
├─vda1                                                                                                252:1    0    1G  0 part /boot
└─vda2                                                                                                252:2    0   49G  0 part
  ├─centos-root                                                                                       253:0    0   47G  0 lvm  /
  └─centos-swap                                                                                       253:1    0    2G  0 lvm  [SWAP]
vdb                                                                                                   252:16   0  100G  0 disk
└─ceph--5293577c--f03b--472b--ab31--74a33931b333-osd--block--9482647f--4929--43e5--9b71--9f457e834406 253:2    0  100G  0 lvm  
rbd0                                                                                                  251:0    0  500M  0 disk
[root@ceph-01 ceph]# mkfs.xfs /dev/rbd0
Discarding blocks...Done.
meta-data=/dev/rbd0              isize=512    agcount=8, agsize=16384 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=128000, imaxpct=25
         =                       sunit=1024   swidth=1024 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=624, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@ceph-01 ceph]#
[root@ceph-01 ceph]# mount /dev/rbd0 /mnt/
[root@ceph-01 ceph]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                 908M     0  908M    0% /dev
tmpfs                    919M     0  919M    0% /dev/shm
tmpfs                    919M  8.7M  911M    1% /run
tmpfs                    919M     0  919M    0% /sys/fs/cgroup
/dev/mapper/centos-root   47G  2.2G   45G    5% /
/dev/vda1               1014M  150M  865M   15% /boot
tmpfs                    184M     0  184M    0% /run/user/0
tmpfs                    919M   52K  919M    1% /var/lib/ceph/osd/ceph-0
/dev/rbd0                498M   26M  473M    6% /mnt
# 测试写入
[root@ceph-01 ceph]# echo YYDS > /mnt/123.txt
[root@ceph-01 ceph]# cat /mnt/123.txt
YYDS
```

### 6. 扩容缩减

扩容

```sh
[root@ceph-01 ceph]# rbd resize --size 800 rbd_pool/volume1
Resizing image: 100% complete...done.
[root@ceph-01 ceph]# df -h |tail -1
/dev/rbd0                498M   26M  473M    6% /mnt
[root@ceph-01 ceph]# df -h |tail -n 1
/dev/rbd0                498M   26M  473M    6% /mnt
[root@ceph-01 ceph]# xfs_growfs -d /mnt/
meta-data=/dev/rbd0              isize=512    agcount=8, agsize=16384 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0 spinodes=0
data     =                       bsize=4096   blocks=128000, imaxpct=25
         =                       sunit=1024   swidth=1024 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal               bsize=4096   blocks=624, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
data blocks changed from 128000 to 204800
[root@ceph-01 ceph]# df -h |tail -n 1
/dev/rbd0                798M   26M  772M    4% /mnt

```

缩减，不能在线缩减，缩减后需要重新格式化在挂载，所以提前备份好数据

```sh
# 缩减回500
[root@ceph-01 ceph]# rbd resize --size 500 rbd_pool/volume1 --allow-shrink
Resizing image: 100% complete...done.
[root@ceph-01 ceph]# rbd resize --size 500 rbd_pool/volume1 --allow-shrink
Resizing image: 100% complete...done.
[root@ceph-01 ceph]# umount /mnt
[root@ceph-01 ceph]# mkfs.xfs -f /dev/rbd0
Discarding blocks...Done.
meta-data=/dev/rbd0              isize=512    agcount=8, agsize=16384 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=128000, imaxpct=25
         =                       sunit=1024   swidth=1024 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=624, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
[root@ceph-01 ceph]# lsblk
NAME                                                                                                  MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sr0                                                                                                    11:0    1 1024M  0 rom  
vda                                                                                                   252:0    0   50G  0 disk
├─vda1                                                                                                252:1    0    1G  0 part /boot
└─vda2                                                                                                252:2    0   49G  0 part
  ├─centos-root                                                                                       253:0    0   47G  0 lvm  /
  └─centos-swap                                                                                       253:1    0    2G  0 lvm  [SWAP]
vdb                                                                                                   252:16   0  100G  0 disk
└─ceph--5293577c--f03b--472b--ab31--74a33931b333-osd--block--9482647f--4929--43e5--9b71--9f457e834406 253:2    0  100G  0 lvm  
rbd0                                                                                                  251:0    0  500M  0 disk
[root@ceph-01 ceph]# mount /dev/rbd0 /mnt/
[root@ceph-01 ceph]# df -h |tail -n 1
/dev/rbd0                498M   26M  473M    6% /mnt
```

### 7. 删除块存储

```sh
[root@ceph-01 ceph]# ceph osd pool delete rbd_pool rbd_pool --yes-i-really-really-mean-it
pool 'rbd_pool' removed
[root@ceph-01 ceph]# ceph osd pool ls
```

## 五、对象存储

### 1. 创建对象存储网关

```sh
[root@ceph-01 ceph]# ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-01,ceph-02,ceph-03 (age 4h)
    mgr: ceph-01(active, since 15h), standbys: ceph-02, ceph-03
    mds:  3 up:standby
    osd: 3 osds: 3 up (since 15h), 3 in (since 15h)

  data:
    pools:   0 pools, 0 pgs
    objects: 0 objects, 0 B
    usage:   3.0 GiB used, 297 GiB / 300 GiB avail
    pgs:
[root@ceph-01 ceph]# ceph-deploy rgw create ceph-01
........................
[ceph_deploy.rgw][INFO  ] The Ceph Object Gateway (RGW) is now running on host ceph-01 and default port 7480
[root@ceph-01 ceph]# ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_OK

  services:
    mon: 3 daemons, quorum ceph-01,ceph-02,ceph-03 (age 4h)
    mgr: ceph-01(active, since 15h), standbys: ceph-02, ceph-03
    mds:  3 up:standby
    osd: 3 osds: 3 up (since 15h), 3 in (since 15h)
    rgw: 1 daemon active (ceph-01)             //已安装好

  task status:

  data:
    pools:   4 pools, 128 pgs
    objects: 105 objects, 1.2 KiB
    usage:   3.0 GiB used, 297 GiB / 300 GiB avail
    pgs:     128 active+clean

  io:
    client:   23 KiB/s rd, 0 B/s wr, 34 op/s rd, 23 op/s wr
[root@ceph-01 ceph]# netstat -lntp |grep 7480
tcp        0      0 0.0.0.0:7480            0.0.0.0:*               LISTEN      26645/radosgw       
tcp6       0      0 :::7480                 :::*                    LISTEN      26645/radosgw
```

![](/images/posts/Linux-Kubernetes/k8s_Persistent/1.png)

### 2. 在客户端测试链接对象网关

```sh
# 创建一个测试用户
[root@ceph-client ~]# radosgw-admin user list
[]
[root@ceph-client ~]# radosgw-admin user create --uid="testuser" --display-name="First User"
以下信息为输出信息，后续可以使用`radosgw-admin user info --uid=testuser`查看
{
    "user_id": "testuser",
    "display_name": "First User",
    "email": "",
    "suspended": 0,
    "max_buckets": 1000,
    "subusers": [],
    "keys": [
        {
            "user": "testuser",
            "access_key": "6TZIL01XLSZ1IFCJ2YBP",
            "secret_key": "t6830tYyU8DxNsDQAHPNbeBqiwDSKrAQTB3Hxlgd"
        }
    ],
    "swift_keys": [],
    "caps": [],
    "op_mask": "read, write, delete",
    "default_placement": "",
    "default_storage_class": "",
    "placement_tags": [],
    "bucket_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "user_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "temp_url_keys": [],
    "type": "rgw",
    "mfa_ids": []
}
[root@ceph-client ~]# radosgw-admin user list
[
    "testuser"
]
```

### 3. python程序进行测试

安装python测试工具

```sh
[root@ceph-client ~]# yum -y install python-boto
```

编写一个python程序进行测试

```sh
[root@ceph-client ~]# cat > s3_test.py <<EOF
import boto
import boto.s3.connection

# 两个key就是上面创建用户所给出的
access_key = '6TZIL01XLSZ1IFCJ2YBP'
secret_key = 't6830tYyU8DxNsDQAHPNbeBqiwDSKrAQTB3Hxlgd'

conn = boto.connect_s3(
       aws_access_key_id = access_key,
       aws_secret_access_key = secret_key,
       host = 'ceph-01', port = 7480,
       is_secure=False, calling_format = boto.s3.connection.OrdinaryCallingFormat(),
       )

bucket = conn.create_bucket('my-new-kucket')
for bucket in conn.get_all_buckets():
        print "{name}".format(
                name = bucket.name,
                created = bucket.creation_date,
)
EOF
[root@ceph-client ceph]# python s3_test.py
my-new-kucket
```

### 4. S3连接ceph对象网关

AmazonS3是一种面向Internet的对象存储服务，我们这里可以使用s3工具连接ceph的对象存储进行测试操作

```sh
[root@ceph-client ceph]# yum -y install s3cmd
[root@ceph-client ceph]# vim /root/.s3cfg
[default]
access_key = 6TZIL01XLSZ1IFCJ2YBP
secret_key = t6830tYyU8DxNsDQAHPNbeBqiwDSKrAQTB3Hxlgd
host_base = 192.168.1.182:7480
host_bucket = 192.168.1.182:7480/%(bucket)
cloudfront_host = 192.168.1.182:7480
use_https = False
```

命令测试

```sh
[root@ceph-client ceph]# s3cmd ls
2021-12-25 08:16  s3://my-new-kucket
# 创建一个桶
[root@ceph-client ceph]# s3cmd mb s3://test_bucket
Bucket 's3://test_bucket/' created
[root@ceph-client ceph]# s3cmd ls
2021-12-25 08:16  s3://my-new-kucket
2021-12-25 08:24  s3://test_bucket
```

上传文件到桶

```sh
[root@ceph-client ceph]# s3cmd put /etc/fstab s3://test_bucket
upload: '/etc/fstab' -> 's3://test_bucket/fstab'  [1 of 1]
 465 of 465   100% in    2s   219.99 B/s  done
```

下载文件到当前目录

```sh
[root@ceph-client ceph]# s3cmd get s3://test_bucket/fstab
download: 's3://test_bucket/fstab' -> './fstab'  [1 of 1]
 465 of 465   100% in    0s    10.29 KB/s  done
[root@ceph-client ceph]# cat fstab

#
# /etc/fstab
# Created by anaconda on Fri Dec 24 18:09:57 2021
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/centos-root /                       xfs     defaults        0 0
UUID=6e25d26e-3e37-4fc6-9183-b24c20e5f947 /boot                   xfs     defaults        0 0
/dev/mapper/centos-swap swap                    swap    defaults        0 0
```

## 六、ceph dashboard

ceph提供了原生的dashboard功能，通过ceph dashboard 完成对 ceph 存储系统可视化监视

**nautilus版本 需要安装ceph-mgr-dashboard**

### 1. 安装

在每个mgr节点

```sh
[root@ceph-01 ceph]# yum -y install ceph-mgr-dashboard
[root@ceph-02 ceph]# yum -y install ceph-mgr-dashboard
[root@ceph-03 ceph]# yum -y install ceph-mgr-dashboard
[root@ceph-01 ceph]# ceph mgr versions
{
    "ceph version 14.2.22 (ca74598065096e6fcbd8433c8779a2be0c889351) nautilus (stable)": 3
}
[root@ceph-01 ceph]# ps -ef |grep ceph-mgr
ceph       27394       1  7 16:31 ?        00:00:02 /usr/bin/ceph-mgr -f --cluster ceph --id ceph-01 --setuser ceph --setgroup ceph
root       27558   23517  0 16:32 pts/2    00:00:00 grep --color=auto ceph-mgr
# 查看帮助模板信息
[root@ceph-01 ceph]# ceph mgr module --help
```

### 2. 开启mgr功能、开启dashboard模块

```sh
[root@ceph-01 ceph]# ceph mgr module enable dashboard
[root@ceph-01 ceph]# ceph mgr module ls |head -n 20
{
    "always_on_modules": [
        "balancer",
        "crash",
        "devicehealth",
        "orchestrator_cli",
        "progress",
        "rbd_support",
        "status",
        "volumes"
    ],
    "enabled_modules": [
        "dashboard",           //模板已存在
        "iostat",
        "restful"
    ],
    "disabled_modules": [
        {
            "name": "alerts",
            "can_run": true,
```

### 3. 自签证书

```sh
[root@ceph-01 ceph]# ceph dashboard create-self-signed-cert
```

### 4. 创建访问控制角色、创建具有管理员角色的用户

```sh
![2](H:\2.png)[root@ceph-01 ceph]# echo admin123 > /root/ceph-password.txt
[root@ceph-01 ceph]# ceph dashboard ac-user-create admin -i /root/ceph-password.txt administrator
{"username": "admin", "lastUpdate": 1640422231, "name": null, "roles": ["administrator"], "password": "$2b$12$m.Mqdxx4lhFQlhdjyQKg0.LMjybyZowyhISyKKdS3qcbkWxWt2y5y", "email": null}
```

显示用户登录信息

```sh
[root@ceph-01 ceph]# ceph dashboard ac-user-show
["admin"]
```

显示角色信息

```sh
[root@ceph-01 ceph]# ceph dashboard ac-role-show
["administrator", "pool-manager", "cephfs-manager", "cluster-manager", "block-manager", "read-only", "rgw-manager", "ganesha-manager"]
```

删除用户就用

```sh
[root@ceph-01 ceph]# ceph dashboard ac-user-delete admin
```

### 5. 在ceph active mgr 节点上配置mgr services

```sh
[root@ceph-01 ceph]# ceph -s |grep mgr
    mgr: ceph-01(active, since 20m), standbys: ceph-02, ceph-03
[root@ceph-01 ceph]# ceph mgr services
{
    "dashboard": "https://ceph-01:8443/"
}
```

![](/images/posts/Linux-Kubernetes/k8s_Persistent/2.png)

![](/images/posts/Linux-Kubernetes/k8s_Persistent/3.png)

### 6. 自定义dashboard的IP地址和端口

```#!/bin/sh
[root@ceph-01 ~]# ceph config set mgr mgr/dashboard/server_addr 192.168.1.134
[root@ceph-01 ~]# ceph config set mgr mgr/dashboard/server_port 8080
[root@ceph-01 ~]# ceph mgr services
{
    "dashboard": "https://ceph-01:8443/"
}
[root@ceph-01 ~]# ceph mgr module disable dashboard
[root@ceph-01 ~]# ceph mgr module enable dashboard
[root@ceph-01 ~]# ceph mgr services
{}
[root@ceph-01 ~]# ceph mgr services
{
    "dashboard": "https://ceph-02:8443/"
}
```

### 7.dashboard启用 RGW ，开启 Object Gateway 管理功能

ceph dashboard 默认安装好以后，没有启用rgw，需要手动启动

**部署 rgw **

全部节点安装，达到高可用

```#!/bin/sh
[root@ceph-01 ~]# cd /etc/ceph/
[root@ceph-01 ceph]# ceph-deploy rgw create ceph-01 ceph-02 ceph-03
[ceph_deploy.conf][DEBUG ] found configuration file at: /root/.cephdeploy.conf
·················
[ceph_deploy.rgw][INFO  ] The Ceph Object Gateway (RGW) is now running on host ceph-03 and default port 7480
```

**创建 rgw 系统用户**

```#!/bin/sh
[root@ceph-01 ceph]# radosgw-admin user create --uid=rgw --display-name=rgw --system
# 以下是输出信息，后期查看也可以用`radosgw-admin user info --uid=rgw`
{
    "user_id": "rgw",
    "display_name": "rgw",
    "email": "",
    "suspended": 0,
    "max_buckets": 1000,
    "subusers": [],
    "keys": [
        {
            "user": "rgw",
            "access_key": "G6WVVEN4J69UG3JNCD19",
            "secret_key": "TVDNkBQLhPXO9A3EBR7bezEglhjCb69k5dfQjZTk"
        }
    ],
    "swift_keys": [],
    "caps": [],
    "op_mask": "read, write, delete",
    "system": "true",
    "default_placement": "",
    "default_storage_class": "",
    "placement_tags": [],
    "bucket_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "user_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "temp_url_keys": [],
    "type": "rgw",
    "mfa_ids": []
}
```

**设置access_key和secret_key**

```#!/bin/sh
# 写入相关值
[root@ceph-01 ceph]# echo G6WVVEN4J69UG3JNCD19 > access_key
[root@ceph-01 ceph]# echo TVDNkBQLhPXO9A3EBR7bezEglhjCb69k5dfQjZTk > secret_key
# 提供dashboard证书
[root@ceph-01 ceph]# ceph dashboard set-rgw-api-access-key -i access_key
Option RGW_API_ACCESS_KEY updated
[root@ceph-01 ceph]# ceph dashboard set-rgw-api-secret-key -i secret_key
Option RGW_API_ACCESS_KEY updated
```

![](/images/posts/Linux-Kubernetes/k8s_Persistent/4.png)

![](/images/posts/Linux-Kubernetes/k8s_Persistent/5.png)

## 七、Prometheus和grafana监控ceph集群

我这里使用的是traefike做的服务暴露，各位可以随意，nodeport也行

### 1. 交付 ingress-traefike

```#!/bin/sh
[root@k8s-cluster-master01 ~]# kubectl create ns ingress-traefik
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/traefike/traefik-crd.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/traefike/traefik-rbac.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/traefike/traefik-config.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/traefike/traefik-ds.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/traefike/traefik-ingress.yaml
```

### 2. 交付 grafana

我这里的pvc用的上面动态nfs的pvc
```#!/bin/sh
[root@k8s-cluster-master01 ~]# kubectl create ns grafana
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/grafana/PVC.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/grafana/dp.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/grafana/svc.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/grafana/rbac.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/grafana/ingress.yaml
```

### 3. 交付 prometheus
```#!/bin/sh
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/prometheus/prometheus-svc.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/prometheus/prometheus-rbac.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/prometheus/prometheus-dep.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/prometheus/prometheus-cfg.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/prometheus/prometheus-ingress.yaml
[root@k8s-cluster-master01 ~]# kubectl apply -f http://blog.tianxiang.love:8080/5-yaml/prometheus/node-exporter.yaml

![](/images/posts/Linux-Kubernetes/k8s_Persistent/6.png)
![](/images/posts/Linux-Kubernetes/k8s_Persistent/7.png)

### 4. ceph mgr 配置Prometheus插件

```#!/bin/sh
[root@ceph-01 ceph]# ceph mgr module enable prometheus
[root@ceph-01 ceph]# ceph mgr module ls |head -n 20
{
    "always_on_modules": [
        "balancer",
        "crash",
        "devicehealth",
        "orchestrator_cli",
        "progress",
        "rbd_support",
        "status",
        "volumes"
    ],
    "enabled_modules": [
        "dashboard",
        "iostat",
        "prometheus",         /////已加载
        "restful"
    ],
    "disabled_modules": [
        {
            "name": "alerts",
# 查看一下mgr管理在哪个节点上
[root@ceph-01 ceph]# ceph -s |grep mgr
    mgr: ceph-01(active, since 2m), standbys: ceph-02, ceph-03
[root@ceph-01 ceph]# netstat -lntp |grep mgr
tcp        0      0 192.168.1.182:6810      0.0.0.0:*               LISTEN      993/ceph-mgr        
tcp        0      0 192.168.1.182:8443      0.0.0.0:*               LISTEN      993/ceph-mgr        
tcp        0      0 192.168.1.182:6811      0.0.0.0:*               LISTEN      993/ceph-mgr        
tcp6       0      0 :::9283                 :::*                    LISTEN      993/ceph-mgr
[root@ceph-01 ceph]# curl 127.0.0.1:9283/metrics |head -n 10
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
# HELP ceph_osd_flag_norebalance OSD Flag norebalance
# TYPE ceph_osd_flag_norebalance untyped
ceph_osd_flag_norebalance 0.0
# HELP ceph_bluestore_kv_final_lat_sum Average kv_finalize thread latency Total
# TYPE ceph_bluestore_kv_final_lat_sum counter
ceph_bluestore_kv_final_lat_sum{ceph_daemon="osd.1"} 0.40369201
ceph_bluestore_kv_final_lat_sum{ceph_daemon="osd.2"} 0.318723148
ceph_bluestore_kv_final_lat_sum{ceph_daemon="osd.0"} 0.417414948
# HELP ceph_paxos_begin_latency_count Latency of begin operation Count
 75  106k   75 81775    0     0  21.5M      0 --:--:-- --:--:-- --:--:-- 25.9M
curl: (23) Failed writing body (8337 != 16384)
```

### 5. 配置Prometheus静态发现

```#!/bin/sh
[root@k8s-cluster-master01 prometheus]# cat prometheus-cfg.yaml
- job_name: 'ceph_cluster'
  static_configs:
  - targets: ['192.168.1.182:9283']
```
![](/images/posts/Linux-Kubernetes/k8s_Persistent/8.png)

```#!/bin/sh
# 重启服务
[root@k8s-cluster-master01 prometheus]# kubectl apply -f prometheus-cfg.yaml
configmap/prometheus-config configured
[root@k8s-cluster-master01 prometheus]# kubectl delete pod -n monitoring prometheus-d7b669486-rmsgr
[root@k8s-cluster-master01 prometheus]# kubectl get pods -n monitoring
NAME                         READY   STATUS        RESTARTS   AGE
node-exporter-298rs          1/1     Running       0          93m
node-exporter-d2tjd          1/1     Running       0          93m
node-exporter-jhvhm          1/1     Running       0          93m
node-exporter-sfd79          1/1     Running       0          93m
prometheus-d7b669486-x2j7w   1/1     Running       0          9s
```
![](/images/posts/Linux-Kubernetes/k8s_Persistent/9.png)

## 八、配置Grafana展示ceph集群

### 1. 添加Prometheus模块

略过

### 2. 添加ceph监控模板

模板地址：https://grafana.com/grafana/dashboards/2842

![](/images/posts/Linux-Kubernetes/k8s_Persistent/10.png)

![](/images/posts/Linux-Kubernetes/k8s_Persistent/11.png)

![](/images/posts/Linux-Kubernetes/k8s_Persistent/12.png)
