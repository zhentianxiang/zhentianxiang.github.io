---
layout: post
title: Linux-Kubernetes-44-Kubernetes持久化存储实战(二)
date: 2021-12-27
tags: 实战-Kubernetes
---

# k8s 连接集群外部ceph集群

> k8s 可以通过两种方式使用ceph做为volume，一个是cephfs一个是rbd
>
> 一个 Ceph 集群仅支持一个 Cephfs
>
> Cephfs方式支持k8s的pv的3种访问模式`ReadWriteOnce` `ReadOnlyMany` `ReadWriteMany`
>
> RBD支持`ReadWriteOnce` `ReadWriteMany`
>
> 注意，访问模式只是能力描述，并不是强制执行的，对于没有按pvc生命的方式使用pv，存储提供者应该负责访问时的运行错误，例如如果设置pvc的访问模式为`ReadOnlyMany` ，pod挂在后依然可以写，如果需要真正的不可以写，申请pvc是需要指定`readonly: true`

## 一、静态pv（rbd）方式的例子

### 1. 配置免密登录

```sh
[root@ceph-01 ceph]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.1.182 ceph-01
192.168.1.134 ceph-02
192.168.1.159 ceph-03
192.168.1.161 ceph-client
192.168.1.171 k8s-cluster-master01
192.168.1.175 k8s-cluster-master02
192.168.1.180 k8s-cluster-master03
192.168.1.181 k8s-cluster-node01
[root@ceph-01 ceph]# ssh-copy-id k8s-cluster-master01
[root@ceph-01 ceph]# ssh-copy-id k8s-cluster-master02
[root@ceph-01 ceph]# ssh-copy-id k8s-cluster-master03
[root@ceph-01 ceph]# ssh-copy-id k8s-cluster-node01
```
### 2. k8s所有节点安装依赖组件

> 注意：安装ceph-common软件包推荐使用软件包源与ceph集群相同的，要的就是软件版本一致

```sh
[root@k8s-cluster-master01 prometheus]# cat /etc/yum.repos.d/ceph.repo
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

安装组件

```sh
[root@k8s-cluster-master01 ~]# yum -y install ceph-common
[root@k8s-cluster-master02 ~]# yum -y install ceph-common
[root@k8s-cluster-master03 ~]# yum -y install ceph-common
```

同步配置文件

```sh
[root@ceph-01 ceph]# ceph-deploy --overwrite-conf admin ceph-01 ceph-02 ceph-03 k8s-cluster-master01 k8s-cluster-master02 k8s-cluster-master03 k8s-cluster-node01
.................
[k8s-cluster-master03][DEBUG ] write cluster configuration to /etc/ceph/{cluster}.conf
# 切换到master01节点查看
[root@k8s-cluster-master01 ceph]# ll
总用量 12
-rw------- 1 root root 151 12月 27 15:12 ceph.client.admin.keyring
-rw-r--r-- 1 root root 284 12月 27 15:12 ceph.conf
-rw-r--r-- 1 root root  92 6月  30 06:36 rbdmap
-rw------- 1 root root   0 12月 27 15:10 tmptLf4l4
```
### 3. 创建存储池并开启rbd功能

创建kube池给k8s

```sh
[root@k8s-cluster-master01 ceph]# ceph osd pool create kube 128 128
pool 'kube' created
[root@k8s-cluster-master01 ceph]# ceph osd pool ls
.rgw.root
default.rgw.control
default.rgw.meta
default.rgw.log
default.rgw.buckets.index
default.rgw.buckets.data
kube
```

### 4. 创建ceph用户，提供给k8s使用

```sh
[root@k8s-cluster-master01 ceph]# ceph auth get-or-create client.kube mon 'allow r' osd 'allow class-read object_prefix rbd_children,allow rwx pool=kube'
[client.kube]
	key = AQD4dslhcn8JDxAAqEnfXOFsqKhAP14ah1CNpA==
  [root@k8s-cluster-master01 ceph]# ceph auth list |grep kube
  installed auth entries:

  client.kube
  	caps: [osd] allow class-read object_prefix rbd_children,allow rwx pool=kube
```

### 5. 创建secret资源

```sh
[root@k8s-cluster-master01 ceph]# ceph auth get-key client.admin | base64
QVFCRzhjVmh0QkZlR1JBQUU5ODJyb1lmbk1vWGZHNmJFWE1BN0E9PQ==
[root@k8s-cluster-master01 ceph]# ceph auth get-key client.kube | base64
QVFENGRzbGhjbjhKRHhBQXFFbmZYT0ZzcUtoQVAxNGFoMUNOcEE9PQ==
[root@k8s-cluster-master01 ceph]# mkdir /home/k8s-data/jtpv
[root@k8s-cluster-master01 ceph]# cd /home/k8s-data/jtpv
[root@k8s-cluster-master01 jtpv]# cat > ceph-admin-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ceph-admin-secret
data:
  key: QVFCRzhjVmh0QkZlR1JBQUU5ODJyb1lmbk1vWGZHNmJFWE1BN0E9PQ==  ##admin的key
type:
  kubernetes.io/rbd
EOF

[root@k8s-cluster-master01 jtpv]# cat > ceph-kube-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ceph-kube-secret
data:
  key: QVFENGRzbGhjbjhKRHhBQXFFbmZYT0ZzcUtoQVAxNGFoMUNOcEE9PQ==  ##kube的key
type:
  kubernetes.io/rbd
```

### 6. 创建pv

```sh
[root@k8s-cluster-master01 jtpv]# cat > pv.yaml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ceph-nginx-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  rbd:
    monitors:
      - 192.168.1.182:6789
      - 192.168.1.134:6789
      - 192.168.1.159:6789
    pool: kube
    image: ceph-image
    user: admin
    secretRef:
      name: ceph-admin-secret
    fsType: ext4
    readOnly: false
  persistentVolumeReclaimPolicy: Retain
EOF
# 创建ceph-image，划分一点空间供pv使用
[root@k8s-cluster-master01 jtpv]# rbd create -p kube -s 10G ceph-image
[root@k8s-cluster-master01 jtpv]# rbd ls -p kube
ceph-image
```

### 7. 创建pvc

```sh
[root@k8s-cluster-master01 jtpv]# cat > pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ceph-nginx-claim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF
```

### 8. 创建pod

```sh
[root@k8s-cluster-master01 jtpv]# cat > pod.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    k8s-app: nginx
spec:
  replicas: 1
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
          claimName: ceph-nginx-claim
      restartPolicy: Always
EOF
```

启动服务，查看服务状态

```sh
[root@k8s-cluster-master01 jtpv]# kubectl apply -f .
secret/ceph-admin-secret created
secret/ceph-kube-secret created
deployment.apps/nginx created
persistentvolume/ceph-nginx-pv created
persistentvolumeclaim/ceph-nginx-claim created
[root@k8s-cluster-master01 jtpv]# kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                      STORAGECLASS       REASON   AGE
ceph-nginx-pv                              10Gi       RWO            Retain           Bound    default/ceph-nginx-claim                               3s
pvc-355f4e54-a02e-4c2a-bcd2-3c574625cdba   10Gi       RWX            Delete           Bound    default/nginx-test-pvc     do-block-storage            24h
pvc-e64e2947-a7c6-4a82-ac6f-d15ff8b5529b   10Gi       RWX            Delete           Bound    loki/loki-pvc              do-block-storage            20h
pvc-e6eb9c4c-a7c1-4d84-8db3-c0573c975e87   10Gi       RWX            Delete           Bound    grafana/grafana-pvc        do-block-storage            23h
[root@k8s-cluster-master01 jtpv]# kubectl get pods
NAME                               READY   STATUS              RESTARTS   AGE
nfs-provisioner-5748f66d67-h5hw9   1/1     Running             0          22h
nginx-57bb58d459-fhn8t             0/1     ContainerCreating   0          15s
[root@k8s-cluster-master01 jtpv]# kubectl get pods
NAME                               READY   STATUS    RESTARTS   AGE
nfs-provisioner-5748f66d67-h5hw9   1/1     Running   0          22h
nginx-57bb58d459-fhn8t             1/1     Running   0          24s
```

查看pod挂载信息

```sh
[root@k8s-cluster-master01 jtpv]# rbd ls -p kube
ceph-image
[root@k8s-cluster-master01 jtpv]# rbd info -p kube ceph-image
rbd image 'ceph-image':
	size 10 GiB in 2560 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: b0d6d8d981f6
	block_name_prefix: rbd_data.b0d6d8d981f6
	format: 2
	features: layering, exclusive-lock
	op_features:
	flags:
	create_timestamp: Mon Dec 27 16:40:03 2021
	access_timestamp: Mon Dec 27 16:40:03 2021
	modify_timestamp: Mon Dec 27 16:40:03 2021
# 查看容器内挂载情况
[root@k8s-cluster-master01 jtpv]# kubectl exec -it nginx-57bb58d459-fhn8t ceph-pod -- df -h |grep /dev/rbd0
/dev/rbd0                9.8G   37M  9.7G   1% /usr/share/nginx/html
[root@k8s-cluster-master01 jtpv]# kubectl exec -it nginx-57bb58d459-fhn8t ceph-pod -- df -h
Filesystem               Size  Used Avail Use% Mounted on
overlay                  100G  6.2G   94G   7% /
tmpfs                     64M     0   64M   0% /dev
tmpfs                    7.8G     0  7.8G   0% /sys/fs/cgroup
/dev/mapper/centos-root  100G  6.2G   94G   7% /etc/hosts
shm                       64M     0   64M   0% /dev/shm
/dev/rbd0                9.8G   37M  9.7G   1% /usr/share/nginx/html
tmpfs                    7.8G   12K  7.8G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                    7.8G     0  7.8G   0% /proc/acpi
tmpfs                    7.8G     0  7.8G   0% /proc/scsi
tmpfs                    7.8G     0  7.8G   0% /sys/firmware
```

## 二、动态pv（rbd）方式的例子

动态pv的例子仅供参考，我做实验翻车了。

使用社区种提供的cephfs provisioner 进行动态分配pv

示例：使用ceph （cephfs方式）为k8s提供动态申请pv的功能，ceph提供底层存储功能

**ceph 操作部分**

### 1. cephfs 做持久数据卷

> cephfs方式支持k8s的pv的3种访问模式，ReadWriteOnce 、ReadOnlyMany、ReadWriteMany


在ceph-01节点上同步文件，并创建至少一个mds服务

那这个操作就不做了，因为在前一篇文章中已经做好了

```sh
[root@ceph-01 ceph]# ceph -s
  cluster:
    id:     3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
    health: HEALTH_WARN
            application not enabled on 1 pool(s)

  services:
    mon: 3 daemons, quorum ceph-01,ceph-02,ceph-03 (age 24h)
    mgr: ceph-01(active, since 22h), standbys: ceph-02, ceph-03
    mds:  3 up:standby      //////mds服务正常的
    osd: 3 osds: 3 up (since 24h), 3 in (since 24h)
    rgw: 3 daemons active (ceph-01, ceph-02, ceph-03)

  task status:

  data:
    pools:   7 pools, 320 pgs
    objects: 283 objects, 137 MiB
    usage:   3.4 GiB used, 297 GiB / 300 GiB avail
    pgs:     320 active+clean
```

### 2. 创建 cephfs 资源池

一个 ceph 文件需要两个RADOS存储，一个用于数据，一个用于元数据

```sh
[root@ceph-01 ceph]# ceph osd pool create cephfs-data 128 128
pool 'cephfs-data' created
[root@ceph-01 ceph]# ceph osd pool create cephfs-metadata 128 128
pool 'cephfs-metadata' created
[root@ceph-01 ceph]# ceph osd pool ls |grep cephfs
cephfs-data
cephfs-metadata
```

### 3. 创建 ceph 文件系统，并确认客户端访问的节点

```sh
[root@ceph-01 ceph]# ceph fs new cephfs cephfs-metadata cephfs-data
new fs with metadata pool 12 and data pool 11
[root@ceph-01 ceph]# ceph fs ls
name: cephfs, metadata pool: cephfs-metadata, data pools: [cephfs-data ]
[root@ceph-01 ceph]# ceph mds stat
cephfs:1 {0=ceph-01=up:active} 2 up:standby      //ceph-01为up状态
[root@ceph-01 ceph]# ceph fs status cephfs
cephfs - 0 clients
======
+------+--------+---------+---------------+-------+-------+
| Rank | State  |   MDS   |    Activity   |  dns  |  inos |
+------+--------+---------+---------------+-------+-------+
|  0   | active | ceph-01 | Reqs:    0 /s |   10  |   13  |
+------+--------+---------+---------------+-------+-------+
+-----------------+----------+-------+-------+
|       Pool      |   type   |  used | avail |
+-----------------+----------+-------+-------+
| cephfs-metadata | metadata | 1536k | 93.8G |
|   cephfs-data   |   data   |    0  | 93.8G |
+-----------------+----------+-------+-------+
+-------------+
| Standby MDS |
+-------------+
|   ceph-02   |
|   ceph-03   |
+-------------+
MDS version: ceph version 14.2.22 (ca74598065096e6fcbd8433c8779a2be0c889351) nautilus (stable)
```

**k8s 操作部分**

安装cephfs客户端,所有node节点安装cephfs客户端，主要用来和ceph集群挂载使用。

上面已经安装过了，就不安装了，这里直接就开始动态创建cephfs的pv的过程了

### 1. 准备cephfs-provisioner的资源清单

```sh
[root@k8s-cluster-master01 jtpv]# mkdir /home/k8s-data/cephfs-provisioner
[root@k8s-cluster-master01 jtpv]# cd /home/k8s-data/cephfs-provisioner
[root@k8s-cluster-master01 cephfs-provisioner]# cat > ClusterRole <<EOF
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cephfs-provisioner
  namespace: cephfs
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
    resources: ["services"]
    resourceNames: ["kube-dns","coredns"]
    verbs: ["list", "get"]
EOF
```

```sh
[root@k8s-cluster-master01 cephfs-provisioner]# cat > ClusterRoleBinding <<EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cephfs-provisioner
subjects:
  - kind: ServiceAccount
    name: cephfs-provisioner
    namespace: cephfs
roleRef:
  kind: ClusterRole
  name: cephfs-provisioner
  apiGroup: rbac.authorization.k8s.io
```

```sh
[root@k8s-cluster-master01 cephfs-provisioner]# cat > Role <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cephfs-provisioner
  namespace: cephfs
rules:
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["create", "get", "delete"]
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
EOF
```

```sh
[root@k8s-cluster-master01 cephfs-provisioner]# cat > RoleBinding <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cephfs-provisioner
  namespace: cephfs
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cephfs-provisioner
subjects:
- kind: ServiceAccount
  name: cephfs-provisioner
EOF
```

```sh
[root@k8s-cluster-master01 cephfs-provisioner]# cat > ServiceAccount <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cephfs-provisioner
  namespace: cephfs
EOF
```

```sh
[root@k8s-cluster-master01 cephfs-provisioner]# cat > cephfs-provisioner <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cephfs-provisioner
  namespace: cephfs
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cephfs-provisioner
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: cephfs-provisioner
    spec:
      containers:
      - name: cephfs-provisioner
        image: "quay.io/external_storage/cephfs-provisioner:latest"
        resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 64Mi        
        env:
        - name: PROVISIONER_NAME                # 与storageclass的provisioner参数相同
          value: ceph.com/cephfs
        - name: PROVISIONER_SECRET_NAMESPACE    # 与rbac的namespace相同
          value: cephfs
        command:
        - "/usr/local/bin/cephfs-provisioner"
        args:
        - "-id=cephfs-provisioner-1"
        - "-disable-ceph-namespace-isolation=true"
      serviceAccount: cephfs-provisioner
EOF
```

```sh
[root@k8s-cluster-master01 cephfs-provisioner]# cat > storageclass <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: cephfs-provisioner-sc
   namespace: cephfs
provisioner: ceph.com/cephfs
#volumeBindingMode: WaitForFirstConsumer
parameters:
  monitors: 192.168.1.182:6789,192.168.1.134:6789,192.168.1.159:6789
  adminId: admin
  adminSecretName: ceph-admin-secret
  adminSecretNamespace: "cephfs"
  claimRoot: /pvc-volumes
EOF
```

### 2. 创建ceph-admin-secret

```sh
[root@k8s-cluster-master01 cephfs-provisioner]# ceph auth get-key client.admin |base64
QVFCRzhjVmh0QkZlR1JBQUU5ODJyb1lmbk1vWGZHNmJFWE1BN0E9PQ==
[root@k8s-cluster-master01 cephfs-provisioner]# cat > ceph-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ceph-admin-secret
  namespace: cephfs
data:
  key: QVFCRzhjVmh0QkZlR1JBQUU5ODJyb1lmbk1vWGZHNmJFWE1BN0E9PQ==
```

```sh
[root@k8s-cluster-master01 cephfs-provisioner]# kubectl create ns cephfs
namespace/cephfs created
[root@k8s-cluster-master01 cephfs-provisioner]# kubectl apply -f .
clusterrole.rbac.authorization.k8s.io/cephfs-provisioner created
clusterrolebinding.rbac.authorization.k8s.io/cephfs-provisioner created
role.rbac.authorization.k8s.io/cephfs-provisioner created
rolebinding.rbac.authorization.k8s.io/cephfs-provisioner created
serviceaccount/cephfs-provisioner created
secret/ceph-admin-secret created
deployment.apps/cephfs-provisioner created
storageclass.storage.k8s.io/cephfs-provisioner-sc created
```

查看服务启动状态

```sh
[root@k8s-cluster-master01 cephfs-provisioner]# kubectl get pods -n cephfs
NAME                                  READY   STATUS    RESTARTS   AGE
cephfs-provisioner-59c85d5789-jbsgr   1/1     Running   0          2m6s
```

测试pod动态pv创建

```sh
[root@k8s-cluster-master01 cephfs-provisioner]# mkdir test-pod
[root@k8s-cluster-master01 cephfs-provisioner]# cd test-pod/
[root@k8s-cluster-master01 test-pod]# cat > pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cephfs-nginx-pvc
  namespace: cephfs
spec:
  storageClassName: cephfs-provisioner-sc
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
EOF
```

```sh
[root@k8s-cluster-master01 test-pod]# cat > cephfs-nginx.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cephfs-nginx
  namespace: cephfs
  labels:
    k8s-app: cephfs-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: cephfs-nginx
  template:
    metadata:
      labels:
        k8s-app: cephfs-nginx
    spec:
      containers:
      - name: cephfs-nginx
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
          claimName: cephfs-nginx-pvc
      restartPolicy: Always
EOF
```

启动服务，查看状态

```sh
[root@k8s-cluster-master01 test-pod]# kubectl get pods -n cephfs
NAME                                  READY   STATUS    RESTARTS   AGE
cephfs-nginx-5487d94699-84ksf         0/1     Pending   0          4s
cephfs-provisioner-59c85d5789-d2p2n   1/1     Running   0          2m32s
[root@k8s-cluster-master01 test-pod]# kubectl describe pod -n cephfs cephfs-nginx-5487d94699-84ksf
...........
Events:
  Type     Reason            Age                From               Message
  ----     ------            ----               ----               -------
  Warning  FailedScheduling  11s (x3 over 13s)  default-scheduler  0/4 nodes are available: 4 pod has unbound immediate PersistentVolumeClaims.
# 查看pvc状态
[root@k8s-cluster-master01 test-pod]# kubectl get pvc -n cephfs
NAME               STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS            AGE
cephfs-nginx-pvc   Pending                                      cephfs-provisioner-sc   45s
[root@k8s-cluster-master01 test-pod]# kubectl describe pvc -n cephfs cephfs-nginx-pvc
................................
Events:
  Type     Reason                Age                From                                                                                      Message
  ----     ------                ----               ----                                                                                      -------
  Warning  ProvisioningFailed    30s (x2 over 49s)  ceph.com/cephfs_cephfs-provisioner-59c85d5789-d2p2n_2420af4e-67a9-11ec-ae3c-f2d920d01b1e  failed to provision volume with StorageClass "cephfs-provisioner-sc": exit status 1
  Normal   ExternalProvisioning  14s (x5 over 52s)  persistentvolume-controller                                                               waiting for a volume to be created, either by external provisioner "ceph.com/cephfs" or manually created by system administrator
  Normal   Provisioning          0s (x3 over 52s)   ceph.com/cephfs_cephfs-provisioner-59c85d5789-d2p2n_2420af4e-67a9-11ec-ae3c-f2d920d01b1e  External provisioner is provisioning volume for claim "cephfs/cephfs-nginx-pvc"
```

发现pvc创建报错了，至于为什么报错我实在整不明白了，手动用ceph-client去挂载cepffs文件系统是没问题的，包括用k8s节点去挂载也是没问题的

```sh
# ceph-client
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
# k8s-cluster-master01
[root@k8s-cluster-master01 test-pod]# yum -y install ceph-fuse
[root@k8s-cluster-master01 test-pod]# scp 192.168.1.161:/root/admin.key /root
[root@k8s-cluster-master01 test-pod]# mount -t ceph 192.168.1.182:6789:/ /mnt/ -o name=admin,secretfile=/root/admin.key
[root@k8s-cluster-master01 test-pod]# df -h |tail -n 1
192.168.1.182:6789:/                                                                         94G     0   94G    0% /mnt
```

## 三、使用ceph-csi来做持久化

### 1.ceph 操作部分

三个管理节点上必须有一个mds服务，上面已经安装过了，这里就不安装了，这里直接就创建存储池和文件系统了

```sh
[root@ceph-01 ceph]# ceph-deploy --overwrite-conf admin ceph-01 ceph-02 ceph-03
[root@ceph-01 ceph]#  ceph osd pool create fs_data 128 128
pool 'fs_data' created
[root@ceph-01 ceph]#  ceph osd pool create fs_metadata 128 128
pool 'fs_metadata' created
[root@ceph-01 ceph]# ceph fs new cephfs fs_metadata fs_data
new fs with metadata pool 16 and data pool 15
[root@ceph-01 ceph]# ceph fs ls
name: cephfs, metadata pool: fs_metadata, data pools: [fs_data ]
```

获取集群信息和查看admin用户key密钥

```#!/bin/sh
[root@ceph-01 ceph]# ceph mon dump
epoch 3
fsid 3d4f8107-0cf0-4094-873e-e5ef3f33ffd4
last_changed 2021-12-25 00:28:02.284521
created 2021-12-25 00:11:49.833412
min_mon_release 14 (nautilus)
0: [v2:192.168.1.182:3300/0,v1:192.168.1.182:6789/0] mon.ceph-01
1: [v2:192.168.1.134:3300/0,v1:192.168.1.134:6789/0] mon.ceph-02
2: [v2:192.168.1.159:3300/0,v1:192.168.1.159:6789/0] mon.ceph-03
dumped monmap epoch 3
[root@ceph-01 ceph]# ceph auth  get client.admin
[client.admin]
	key = AQBG8cVhtBFeGRAAE982roYfnMoXfG6bEXMA7A==
	caps mds = "allow *"
	caps mgr = "allow *"
	caps mon = "allow *"
	caps osd = "allow *"
exported keyring for client.admin
```

### 2. k8s操作部分

所有节点安装 ceph-common，已经安装过了，这里就不安装了

部署cephfs csi

```#!/bin/sh
[root@k8s-cluster-master01 ~]# git clone https://github.com/ceph/ceph-csi.git
Cloning into 'ceph-csi'...
remote: Enumerating objects: 85360, done.
remote: Counting objects: 100% (332/332), done.
remote: Compressing objects: 100% (169/169), done.
Receiving objects:  29% (25256/85360), 22.45 MiB | 159.00 KiB/s
[root@k8s-cluster-master01 ~]# cd ceph-csi/deploy/cephfs/kubernetes
[root@k8s-cluster-master01 kubernetes]# mkdir cephfs
[root@k8s-cluster-master01 kubernetes]# mkdir rbd
[root@k8s-cluster-master01 kubernetes]# cp *.yaml cephfs/
[root@k8s-cluster-master01 kubernetes]# cd cephfs/
# 这里修改一下csi-config-map.yaml
[root@k8s-cluster-master01 cephfs]# ls
csi-cephfsplugin-provisioner.yaml  csi-config-map.yaml  csi-nodeplugin-psp.yaml   csi-provisioner-psp.yaml
csi-cephfsplugin.yaml              csidriver.yaml       csi-nodeplugin-rbac.yaml  csi-provisioner-rbac.yaml
[root@k8s-cluster-master01 cephfs]# cat csi-config-map.yaml
---
apiVersion: v1
kind: ConfigMap
data:
  config.json: |-
    [
      {
        "clusterID": "3d4f8107-0cf0-4094-873e-e5ef3f33ffd4",
        "monitors": [
          "192.168.1.182:6789,192.168.1.134:6789,192.168.1.159:6789"
        ]
      }
    ]
metadata:
  name: ceph-csi-config
```

部署cephfs相关的csi组件

```#!/bin/sh
# 修改镜像名称，不然无法拉取下来
[root@k8s-cluster-master01 cephfs]# cat csi-cephfsplugin-provisioner.yaml |grep sig-storage
          image: k8s.gcr.io/sig-storage/csi-provisioner:v3.0.0
          image: k8s.gcr.io/sig-storage/csi-resizer:v1.3.0
          image: k8s.gcr.io/sig-storage/csi-snapshotter:v4.2.0
          image: k8s.gcr.io/sig-storage/csi-attacher:v3.3.0
```

我这里翻车了，就不演示了，看下面的吧


## 四、搭建 Glusterfs(集群)

实验环境规划

| 机器名称     | IP地址        | 配置 |
| ------------ | ------------- | ---- |
| glusterfs-01 | 192.168.1.187 | 2H4G |
| glusterfs-02 | 192.168.1.189 | 2H4G |
| glusterfs-03 | 192.168.1.190 | 2H4G |
| glusterfs-04 | 192.168.1.131 | 2H4G |

### 1. 配置基础环境

四台机器均配置

```sh
[root@storage1 ~]# yum -y install centos-release-gluster
[root@storage2 ~]# yum -y install centos-release-gluster
[root@storage3 ~]# yum -y install centos-release-gluster
[root@storage4 ~]# yum -y install centos-release-gluster
```

配置host解析，四台机器均操作

```sh
[root@storage1 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.1.187 storage1
192.168.1.189 storage2
192.168.1.190 storage3
192.168.1.113 storage4
```

安装服务端

```sh
[root@storage1 ~]# yum -y install glusterfs-server
[root@storage2 ~]# yum -y install glusterfs-server
[root@storage3 ~]# yum -y install glusterfs-server
[root@storage4 ~]# yum -y install glusterfs-server
```

启动服务,没给机器上都启动

```sh
[root@storage1 ~]# systemctl enable glusterd.service
Created symlink from /etc/systemd/system/multi-user.target.wants/glusterd.service to /usr/lib/systemd/system/glusterd.service.
[root@storage1 ~]# systemctl start glusterd
[root@storage1 ~]# systemctl status glusterd
● glusterd.service - GlusterFS, a clustered file-system server
   Loaded: loaded (/usr/lib/systemd/system/glusterd.service; enabled; vendor preset: disabled)
   Active: active (running) since 三 2021-12-29 14:29:28 CST; 49s ago
     Docs: man:glusterd(8)
  Process: 12099 ExecStart=/usr/sbin/glusterd -p /var/run/glusterd.pid --log-level $LOG_LEVEL $GLUSTERD_OPTIONS (code=exited, status=0/SUCCESS)
 Main PID: 12100 (glusterd)
   CGroup: /system.slice/glusterd.service
           └─12100 /usr/sbin/glusterd -p /var/run/glusterd.pid --log-level INFO

12月 29 14:29:28 glusterfs-01 systemd[1]: Starting GlusterFS, a clustered file-system server...
12月 29 14:29:28 glusterfs-01 systemd[1]: Started GlusterFS, a clustered file-system server.
```

连接集群，在机器1上操作即可

```sh
[root@storage1 ~]# gluster peer probe storage2
peer probe: success
[root@storage1 ~]# gluster peer probe storage3
peer probe: success
[root@storage1 ~]# gluster peer probe storage4
peer probe: success
[root@storage1 ~]# gluster peer status
Number of Peers: 3

Hostname: storage2
Uuid: 2c443395-016e-48ff-9b74-675540a8a0bf
State: Peer in Cluster (Connected)

Hostname: storage3
Uuid: 634d1654-1460-4d38-aad2-102f5bcb1285
State: Peer in Cluster (Connected)

Hostname: storage4
Uuid: aa3d121c-6e67-4b4e-8d60-b2d8cc7026c1
State: Peer in Cluster (Connected)
```

准备storage存储目录（可以使用但分区，也可以使用根分区）

我这里使用单独的分区，其他机器也要分区，挂载目录

```sh
[root@storage1 ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sr0              11:0    1 1024M  0 rom  
vda             252:0    0   50G  0 disk
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0   49G  0 part
  ├─centos-root 253:0    0   47G  0 lvm  /
  └─centos-swap 253:1    0    2G  0 lvm  [SWAP]
vdb             252:16   0  100G  0 disk
[root@storage1 ~]# fdisk /dev/vdb
欢迎使用 fdisk (util-linux 2.23.2)。

更改将停留在内存中，直到您决定将更改写入磁盘。
使用写入命令前请三思。

Device does not contain a recognized partition table
使用磁盘标识符 0x11d18ec8 创建新的 DOS 磁盘标签。

命令(输入 m 获取帮助)：n
Partition type:
   p   primary (0 primary, 0 extended, 4 free)
   e   extended
Select (default p): p
分区号 (1-4，默认 1)：1
起始 扇区 (2048-209715199，默认为 2048)：
将使用默认值 2048
Last 扇区, +扇区 or +size{K,M,G} (2048-209715199，默认为 209715199)：
将使用默认值 209715199
分区 1 已设置为 Linux 类型，大小设为 100 GiB

命令(输入 m 获取帮助)：w
The partition table has been altered!

Calling ioctl() to re-read partition table.
正在同步磁盘。
[root@storage1 ~]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sr0              11:0    1 1024M  0 rom  
vda             252:0    0   50G  0 disk
├─vda1          252:1    0    1G  0 part /boot
└─vda2          252:2    0   49G  0 part
  ├─centos-root 253:0    0   47G  0 lvm  /
  └─centos-swap 253:1    0    2G  0 lvm  [SWAP]
vdb             252:16   0  100G  0 disk
└─vdb1          252:17   0  100G  0 part
[root@storage1 ~]# mkfs.xfs /dev/vdb1
meta-data=/dev/vdb1              isize=512    agcount=4, agsize=6553536 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=26214144, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=12799, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0
```
创建一个存储目录，将目录挂载到分区上

```sh
[root@storage1 ~]# mkdir -pv /data/gv0
mkdir: 已创建目录 "/data"
mkdir: 已创建目录 "/data/gv0"
[root@storage1 ~]# mount /dev/vdb1 /data/
[root@storage1 ~]# df -h
文件系统                 容量  已用  可用 已用% 挂载点
devtmpfs                 908M     0  908M    0% /dev
tmpfs                    919M     0  919M    0% /dev/shm
tmpfs                    919M  8.6M  911M    1% /run
tmpfs                    919M     0  919M    0% /sys/fs/cgroup
/dev/mapper/centos-root   47G  1.6G   46G    4% /
/dev/vda1               1014M  150M  865M   15% /boot
tmpfs                    184M     0  184M    0% /run/user/0
/dev/vdb1                100G   33M  100G    1% /data/
```

### 2. replica 模式

```sh
[root@storage1 ~]# gluster volume create gv0 replica 4 storage1:/data/vg0 storage2:/data/vg0 storage3:/data/vg0 storage4:/data/vg0 force
volume create: gv0: success: please start the volume to access data
[root@storage1 ~]# gluster volume list
gv0
[root@storage1 ~]# gluster volume start gv0
volume start: gv0: success
[root@storage1 ~]# gluster volume status gv0
Status of volume: gv0
Gluster process                             TCP Port  RDMA Port  Online  Pid
------------------------------------------------------------------------------
Brick storage1:/data/vg0                    49152     0          Y       14551
Brick storage2:/data/vg0                    49152     0          Y       13973
Brick storage3:/data/vg0                    49152     0          Y       13650
Brick storage4:/data/vg0                    49152     0          Y       13286
Self-heal Daemon on localhost               N/A       N/A        Y       14568
Self-heal Daemon on storage2                N/A       N/A        Y       13990
Self-heal Daemon on storage3                N/A       N/A        Y       13667
Self-heal Daemon on storage4                N/A       N/A        Y       13303

Task Status of Volume gv0
------------------------------------------------------------------------------
There are no active volume tasks

[root@storage1 ~]# gluster volume info gv0

Volume Name: gv0
Type: Replicate
Volume ID: d4993c82-13d5-4987-9a6b-3a123bc0621e
Status: Started
Snapshot Count: 0
Number of Bricks: 1 x 4 = 4
Transport-type: tcp
Bricks:
Brick1: storage1:/data/vg0
Brick2: storage2:/data/vg0
Brick3: storage3:/data/vg0
Brick4: storage4:/data/vg0
Options Reconfigured:
cluster.granular-entry-heal: on
storage.fips-mode-rchecksum: on
transport.address-family: inet
nfs.disable: on
performance.client-io-threads: off
```

**客户端读写测试**

我这里使用的是storage2机器当中的客户端

```sh
[root@storage2 ~]# yum install -y glusterfs glusterfs-fuse
已加载插件：fastestmirror
Loading mirror speeds from cached hostfile
 * centos-gluster9: mirrors.bfsu.edu.cn
软件包 glusterfs-9.4-1.el7.x86_64 已安装并且是最新版本
软件包 glusterfs-fuse-9.4-1.el7.x86_64 已安装并且是最新版本
无须任何处理
[root@storage2 ~]# mkdir /test1
[root@storage2 ~]# mount -t glusterfs storage1:/gv0 /test1/
[root@storage2 ~]# df -h |tail -n 1
storage1:/gv0            100G  1.1G   99G    2% /test1
```

在客户端使用过dd命令往目录里面写文件，然后查看storage服务器上的分布情况

```sh
[root@storage2 ~]# dd if=/dev/zero of=/test1/file1 bs=1M count=100
记录了100+0 的读入
记录了100+0 的写出
104857600字节(105 MB)已复制，0.55938 秒，187 MB/秒
# 继续在storage3机器上测试
[root@storage3 ~]# mount /dev/vdb1 /data/gv0/
[root@storage3 ~]# vim /etc/hosts
[root@storage3 ~]# mkdir /test2
[root@storage3 ~]# mount -t glusterfs storage1:/gv0 /test2/
[root@storage3 ~]# df -h |tail -n 1
storage1:/gv0            100G  1.1G   99G    2% /test2
[root@storage3 ~]# dd if=/dev/zero of=/test2/file2 bs=1M count=100
记录了100+0 的读入
记录了100+0 的写出
104857600字节(105 MB)已复制，0.483282 秒，217 MB/秒

```

### 3. distributed 模式

每个服务端下载都创建一个gv1目录

```sh
[root@storage1 ~]# mkdir -pv /data/gv1
mkdir: 已创建目录 "/data/gv1"
[root@storage2 ~]# mkdir -pv /data/gv1
mkdir: 已创建目录 "/data/gv1"
[root@storage3 ~]# mkdir -pv /data/gv1
mkdir: 已创建目录 "/data/gv1"
[root@storage4 ~]# mkdir -pv /data/gv1
mkdir: 已创建目录 "/data/gv1"
```

创建数据卷

```sh
[root@storage1 ~]# gluster volume create gv1 storage1:/data/vg1 storage2:/data/vg1 storage3:/data/vg1 storage4:/data/vg1 force
volume create: gv1: success: please start the volume to access data
[root@storage1 ~]# gluster volume start gv1
volume start: gv1: success
[root@storage1 ~]# gluster volume status gv1
Status of volume: gv1
Gluster process                             TCP Port  RDMA Port  Online  Pid
------------------------------------------------------------------------------
Brick storage1:/data/vg1                    49153     0          Y       12970
Brick storage2:/data/vg1                    49153     0          Y       12549
Brick storage3:/data/vg1                    49153     0          Y       12500
Brick storage4:/data/vg1                    49153     0          Y       2207

Task Status of Volume gv1
------------------------------------------------------------------------------
There are no active volume tasks

[root@storage1 ~]# gluster volume info gv1

Volume Name: gv1
Type: Distribute
Volume ID: 022bf9ab-0c93-430b-9be9-dcb478548a57
Status: Started
Snapshot Count: 0
Number of Bricks: 4
Transport-type: tcp
Bricks:
Brick1: storage1:/data/vg1
Brick2: storage2:/data/vg1
Brick3: storage3:/data/vg1
Brick4: storage4:/data/vg1
Options Reconfigured:
storage.fips-mode-rchecksum: on
transport.address-family: inet
nfs.disable: on
```

**客户端挂载**

挂载gv1

```sh
[root@storage2 ~]# mkdir /test3
[root@storage2 ~]# mount -t glusterfs storage1:/gv1 /test3/
[root@storage2 ~]# df -h |tail -n 1
storage2:/gv1            400G  4.2G  396G    2% /test3
```

> 读写测试结果就是：写满一个存储后，再写第二个，顺序随机

### 4. distributed-replica 模式

```sh
[root@storage1 ~]# mkdir -pv /data/gv2
mkdir: 已创建目录 "/data/gv2"
[root@storage2 ~]# mkdir -pv /data/gv2
mkdir: 已创建目录 "/data/gv2"
[root@storage3 ~]# mkdir -pv /data/gv2
mkdir: 已创建目录 "/data/gv2"
[root@storage4 ~]# mkdir -pv /data/gv2
mkdir: 已创建目录 "/data/gv2"
```

创建数据卷

```sh
[root@storage1 ~]# gluster volume create gv2 replica 2  storage1:/data/vg2 storage2:/data/vg2 storage3:/data/vg2 storage4:/data/vg2 force
volume create: gv2: success: please start the volume to access data
[root@storage1 ~]# gluster volume start gv2
volume start: gv2: success
[root@storage1 ~]# gluster volume status gv2
Status of volume: gv2
Gluster process                             TCP Port  RDMA Port  Online  Pid
------------------------------------------------------------------------------
Brick storage1:/data/vg2                    49154     0          Y       13239
Brick storage2:/data/vg2                    49154     0          Y       13141
Brick storage3:/data/vg2                    49154     0          Y       12821
Brick storage4:/data/vg2                    49154     0          Y       2410
Self-heal Daemon on localhost               N/A       N/A        Y       12493
Self-heal Daemon on storage2                N/A       N/A        Y       12186
Self-heal Daemon on storage4                N/A       N/A        Y       1979
Self-heal Daemon on storage3                N/A       N/A        Y       1944

Task Status of Volume gv2
------------------------------------------------------------------------------
There are no active volume tasks

[root@storage1 ~]# gluster volume info gv2

Volume Name: gv2
Type: Distributed-Replicate
Volume ID: 4daae097-2ad1-40b8-b113-d55665dde27d
Status: Started
Snapshot Count: 0
Number of Bricks: 2 x 2 = 4
Transport-type: tcp
Bricks:
Brick1: storage1:/data/vg2
Brick2: storage2:/data/vg2
Brick3: storage3:/data/vg2
Brick4: storage4:/data/vg2
Options Reconfigured:
cluster.granular-entry-heal: on
storage.fips-mode-rchecksum: on
transport.address-family: inet
nfs.disable: on
performance.client-io-threads: off
```

**读写测试**
```sh
[root@storage2 ~]# mkdir /test4
[root@storage2 ~]# mount -t glusterfs storage2:/gv1 /test4/
[root@storage2 ~]# df -h |tail -n 1
storage2:/gv2            200G  2.1G  198G    2% /test4
```

> 读写测试结果：4个存储先写其中2个（并在这两个存储里面存储 镜像），写满这两个后，再按着相同方式写另外两个，类似于raid0模式的硬盘存储

### 5. disperse 模式

```sh
[root@storage1 ~]# mkdir /data/gv3
[root@storage2 ~]# mkdir /data/gv3
[root@storage3 ~]# mkdir /data/gv3
[root@storage4 ~]# mkdir /data/gv3
```

创建数据卷

```sh
[root@storage1 ~]# gluster volume create gv3 disperse 4  storage1:/data/vg3 storage2:/data/vg3 storage3:/data/vg3 storage4:/data/vg3 force
There isn't an optimal redundancy value for this configuration. Do you want to create the volume with redundancy 1 ? (y/n) y
volume create: gv3: success: please start the volume to access data
[root@storage1 ~]# gluster volume start gv3
volume start: gv3: success
[root@storage1 ~]# gluster volume status gv3
Status of volume: gv3
Gluster process                             TCP Port  RDMA Port  Online  Pid
------------------------------------------------------------------------------
Brick storage1:/data/vg3                    49155     0          Y       13472
Brick storage2:/data/vg3                    49155     0          Y       13431
Brick storage3:/data/vg3                    49155     0          Y       13020
Brick storage4:/data/vg3                    49155     0          Y       12848
Self-heal Daemon on localhost               N/A       N/A        Y       12493
Self-heal Daemon on storage2                N/A       N/A        Y       12186
Self-heal Daemon on storage4                N/A       N/A        Y       1979
Self-heal Daemon on storage3                N/A       N/A        Y       1944

Task Status of Volume gv3
------------------------------------------------------------------------------
There are no active volume tasks

[root@storage1 ~]# gluster volume info gv3

Volume Name: gv3
Type: Disperse
Volume ID: f6eecff9-9eaf-4907-8ddd-5cd4ac0d1783
Status: Started
Snapshot Count: 0
Number of Bricks: 1 x (3 + 1) = 4          这里看到冗余数据为1
Transport-type: tcp
Bricks:
Brick1: storage1:/data/vg3
Brick2: storage2:/data/vg3
Brick3: storage3:/data/vg3
Brick4: storage4:/data/vg3
Options Reconfigured:
storage.fips-mode-rchecksum: on
transport.address-family: inet
nfs.disable: on
```

读写测试

```#!/bin/sh
[root@storage2 ~]# mkdir /test5
[root@storage2 ~]# mount -t glusterfs storage1:/gv3 /test5/
[root@storage2 ~]# df -h |tail -n 1
storage1:/gv3            300G  3.1G  297G    2% /test5
[root@storage2 ~]# dd if=/dev/zero of=/test5/file1 bs=1M count=1024
记录了1024+0 的读入
记录了1024+0 的写出
1073741824字节(1.1 GB)已复制，4.60404 秒，233 MB/秒
```
查看写入数据大小信息

```#!/bin/sh
[root@storage1 ~]# cd /data/vg3/
[root@storage1 vg3]# ls
file1
[root@storage1 vg3]# du -sh
387M	.
[root@storage2 vg3]# du -sh
387M	.
[root@storage3 vg3]# du -sh
342M	.
[root@storage4 vg3]# du -sh
387M	.
```
> 读写测试结果：写1024M，每个存储服务器上占387M左右，因为4个存储1个为冗余，和raid5功能一样

### 6. 配置k8s 使用 glusterfs 持久化存储

因为glusterfs又是一个文件系统，而上面的ceph也是一个文件系统，一个系统中不能出现多个，需要把上面的ceph相关的东西清空，然后我这里删除不干净，就直接添加了一个新的节点，然后让pod启动到新的节点上
```#!/bin/sh
[root@k8s-cluster-node02 ~]# yum install -y glusterfs glusterfs-fuse
```

创建 glusterfs的endpoints

```#!/bin/sh
[root@k8s-cluster-master01 glusterfs]# cat > glusterfs-cluster.yaml <<EOF
apiVersion: v1
kind: Endpoints
metadata:
  name: glusterfs-cluster
  namespace: default
subsets:
- addresses:
  - ip: 192.168.1.187
  - ip: 192.168.1.189
  - ip: 192.168.1.190
  - ip: 192.168.1.113
  ports:
  - port: 49152
    protocol: TCP
EOF
[root@k8s-cluster-master01 glusterfs]# kubectl get endpoints |grep glus
glusterfs-cluster              192.168.1.187:49152,192.168.1.189:49152,192.168.1.190:49152 + 1 more...   22s
```

创建pv

```#!/bin/sh
[root@k8s-cluster-master01 glusterfs]# cat > nginx-gluster-pv.yaml <<EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nginx-glusterfs-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  glusterfs:
    endpoints: glusterfs-cluster
    path: gv1  #上面创建的存储卷
    readOnly: false
EOF
```

创建pvc

```#!/bin/sh
[root@k8s-cluster-master01 glusterfs]# cat > nginx-gluster-pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-glusterfs-pvc
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
EOF
```

创建测试pod

```#!/bin/sh
[root@k8s-cluster-master01 glusterfs]# cat > nginx.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      name: nginx
  template:
    metadata:
      labels:
        name: nginx
    spec:
      nodeName: k8s-cluster-node02
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
          volumeMounts:
            - name: nginxglusterfs
              mountPath: "/usr/share/nginx/html"
			volumes:
      - name: nginxglusterfs
        persistentVolumeClaim:
          claimName: nginx-glusterfs-pvc
EOF
```
查看pod启动状态
```#!/bin/sh
[root@k8s-cluster-master01 glusterfs]# kubectl get pods -o wide
NAME                               READY   STATUS    RESTARTS   AGE     IP               NODE                 NOMINATED NODE   READINESS GATES
nfs-provisioner-5748f66d67-mxkq6   1/1     Running   2          5d18h   10.244.180.204   k8s-cluster-node01   <none>           <none>
nginx-deployment-6fd4ccd94-lh254   1/1     Running   0          24s     10.244.161.3     k8s-cluster-node02   <none>           <none>
[root@k8s-cluster-master01 glusterfs]# kubectl exec -it nginx-deployment-6fd4ccd94-lh254 bash
kubectl exec [POD] [COMMAND] is DEPRECATED and will be removed in a future version. Use kubectl kubectl exec [POD] -- [COMMAND] instead.
root@nginx-deployment-6fd4ccd94-lh254:/# df -h
Filesystem               Size  Used Avail Use% Mounted on
overlay                  100G  3.4G   96G   4% /
tmpfs                     64M     0   64M   0% /dev
tmpfs                    3.9G     0  3.9G   0% /sys/fs/cgroup
/dev/mapper/centos-root  100G  3.4G   96G   4% /etc/hosts
shm                       64M     0   64M   0% /dev/shm
192.168.1.189:gv1        100G  1.4G   99G   2% /usr/share/nginx/html
tmpfs                    3.9G   12K  3.9G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                    3.9G     0  3.9G   0% /proc/acpi
tmpfs                    3.9G     0  3.9G   0% /proc/scsi
tmpfs                    3.9G     0  3.9G   0% /sys/firmware
```

或者不使用pv和pvc

```#!/bin/sh
[root@k8s-cluster-master01 glusterfs]# cat > nginx.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment-2
spec:
  replicas: 1
  selector:
    matchLabels:
      name: nginx-2
  template:
    metadata:
      labels:
        name: nginx-2
    spec:
      nodeName: k8s-cluster-node02
      containers:
        - name: nginx-2
          image: nginx:latest
          ports:
            - containerPort: 80
          volumeMounts:
            - name: nginxglusterfs
              mountPath: "/usr/share/nginx/html"
      volumes:
      - name: nginxglusterfs
        glusterfs:
          endpoints: glusterfs-cluster
          path: gv0
          readOnly: false
EOF
[root@k8s-cluster-master01 glusterfs]# kubectl apply -f nginx.yaml
deployment.apps/nginx-deployment-2 created
[root@k8s-cluster-master01 glusterfs]# kubectl get pods
NAME                                  READY   STATUS    RESTARTS   AGE
nfs-provisioner-5748f66d67-mxkq6      1/1     Running   3          5d21h
nginx-deployment-2-85b8b47888-4v4mx   1/1     Running   0          5m27s
nginx-deployment-6fd4ccd94-n7hvw      1/1     Running   0          47m
```

## 五、k8s交付使用rook-ceph

### 1. rook 介绍

rook是一个自我管理的分布式存储编排系统，它本身并不是存储系统，在存储和k8s之间搭建了一个桥梁，使存储系统的搭建或者维护变得特别简单，Rook将分布式存储系统转变为自我管理、自我扩展、自我修复的存储服务。它让一些存储的操作，比如部署、配置、扩容、升级、迁移、灾难恢复、监视和资源管理变得自动化，无需人工处理。并且Rook支持cSsl，可以利用CSI做一些Pvc的快照、扩容等操作。

![](/images/posts/Kubesphere/Kubernetes持久化存储实战/rook架构.png)

**各个组件说明**

- Operator：Rook控制端，监控存储守护进程，确保存储集群的健康

- Agent：在每个存储节点创建，配置了FlexVolume插件和Kubernetes 的存储卷控制框架（CSI）进行集成

- OSD：提供存储，每块硬盘可以看做一个osd

- Mon：监控ceph集群的存储情况，记录集群的拓扑，数据存储的位置信息

- MDS：负责跟踪文件存储的层次结构

- RGW：Rest API结构，提供对象存储接口

- MGR：为外界提供统一入

### 2. rook 部署

实验环境为三台机器，一台master两台node

```#!/bin/sh
[root@k8s ~]# kubectl get node --show-labels
NAME         STATUS   ROLES                  AGE     VERSION   LABELS
k8s-node01   Ready    <none>                 2d17h   v1.22.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node01,kubernetes.io/os=linux
k8s-node02   Ready    <none>                 2d17h   v1.20.1   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node02,kubernetes.io/os=linux
k8s.com      Ready    control-plane,master   2d19h   v1.20.1   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s.com,kubernetes.io/os=linux,node-role.kubernetes.io/control-plane=,node-role.kubernetes.io/master=
```

垃取rook相关文件: git clone --single-branch --branch v1.3.11 https://github.com/rook/rook.git

官方地址：https://rook.io/docs/rook/v1.3/ceph-quickstart.html

```#!/bin/sh
[root@k8s ~]# cd /data/rook/
[root@k8s rook]# ls
ADOPTERS.md  cmd                 CONTRIBUTING.md  Documentation  GOVERNANCE.md  Jenkinsfile  OWNERS.md               README.md    tests
build        CODE_OF_CONDUCT.md  DCO              go.mod         images         LICENSE      PendingReleaseNotes.md  ROADMAP.md
cluster      CODE-OWNERS         design           go.sum         INSTALL.md     Makefile     pkg                     SECURITY.md
[root@k8s rook]# cd cluster/examples/kubernetes/ceph/
[root@k8s ceph]# kubectl apply -f common.yaml
[root@k8s ceph]# kubectl apply -f operator.yaml  # 服务起来之后在apply 下面的
```

修改配置 cluster 内容

```#!/bin/sh
153   storage: # cluster level storage configuration and selection
154     useAllNodes: false
155     useAllDevices: false

164 # nodes below will be used as storage resources.  Each node's 'name' field should match their 'kubernetes.io/hostname' label.
165     nodes:
166     - name: "k8s-node01"
167       devices: # specific devices to use for storage can be specified for each node
168       - name: "sdb"      # 该节点提前准备好一块裸盘，用于ceph的共享存储
169     - name: "k8s-node02"
170       directories:
171       - path: "/data/ceph"  # 该节点提前准备好目录，用于ceph的共享存储
```

创建集群
```sh
[root@k8s ceph]# kubectl apply -f cluster.yaml
```

查看集群启动情况

```sh
[root@k8s ceph]# kubectl get pods -n rook-ceph
NAME                                                   READY   STATUS      RESTARTS   AGE
csi-cephfsplugin-bgtwv                                 3/3     Running     0          2d17h
csi-cephfsplugin-provisioner-7bc4f59b6f-mb74k          5/5     Running     0          2d17h
csi-cephfsplugin-provisioner-7bc4f59b6f-z64fn          5/5     Running     0          2d17h
csi-cephfsplugin-whhq6                                 3/3     Running     0          2d17h
csi-cephfsplugin-x5f6c                                 3/3     Running     0          2d17h
csi-rbdplugin-4rcqt                                    3/3     Running     0          2d17h
csi-rbdplugin-pklzd                                    3/3     Running     0          2d17h
csi-rbdplugin-provisioner-6bd7bbb77-4cjx2              6/6     Running     0          2d17h
csi-rbdplugin-provisioner-6bd7bbb77-xzkwf              6/6     Running     0          2d17h
csi-rbdplugin-x2rg6                                    3/3     Running     0          2d17h
rook-ceph-crashcollector-k8s-node01-69b44c4b65-4wt5v   1/1     Running     0          2d17h
rook-ceph-crashcollector-k8s-node02-5c6f5dc5d6-k92rc   1/1     Running     0          2d17h
rook-ceph-crashcollector-k8s.com-666c887cdb-66m46      1/1     Running     0          2d17h
rook-ceph-mgr-a-fdfbc5d84-sm9c9                        1/1     Running     0          2d17h
rook-ceph-mon-a-f8f86f595-zh9xq                        1/1     Running     0          2d17h
rook-ceph-mon-b-7b6c99f87c-dp6x6                       1/1     Running     0          2d17h
rook-ceph-mon-c-7698f7fd46-ww8k8                       1/1     Running     0          2d17h
rook-ceph-operator-77f8f68699-r6ckx                    1/1     Running     0          2d18h
rook-ceph-osd-0-844986c94f-97t2v                       1/1     Running     0          2d17h
rook-ceph-osd-prepare-k8s-node01-7g8gj                 0/1     Completed   0          2d17h
rook-ceph-osd-prepare-k8s-node02-ng6nf                 0/1     Completed   0          2d17h
rook-discover-6vdg2                                    1/1     Running     0          2d18h
rook-discover-bgnsw                                    1/1     Running     0          2d18h
rook-discover-tznrb                                    1/1     Running     0          2d18h
```

### 3. 部署 storageclass

官方地址：https://rook.io/docs/rook/v1.3/ceph-block.html

```sh
[root@k8s ceph]# cd /data/block-storage/
[root@k8s block-storage]# ls
ceph-block-pool.yaml  ceph-block-sc.yaml
[root@k8s block-storage]# cat ceph-block-pool.yaml
apiVersion: ceph.rook.io/v1
kind: CephBlockPool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
# 副本融灾机制,有host、osd等
  failureDomain: host
  replicated:
# 副本数量
    size: 3
```

```sh
[root@k8s block-storage]# cat ceph-block-sc.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: rook-ceph-block
# Change "rook-ceph" provisioner prefix to match the operator namespace if needed
provisioner: rook-ceph.rbd.csi.ceph.com
parameters:
    # clusterID is the namespace where the rook cluster is running
    clusterID: rook-ceph
    # Ceph pool into which the RBD image shall be created
    pool: replicapool

    # RBD image format. Defaults to "2".
    imageFormat: "2"

    # RBD image features. Available for imageFormat: "2". CSI RBD currently supports only `layering` feature.
    imageFeatures: layering

    # The secrets contain Ceph admin credentials.
    csi.storage.k8s.io/provisioner-secret-name: rook-csi-rbd-provisioner
    csi.storage.k8s.io/provisioner-secret-namespace: rook-ceph
    csi.storage.k8s.io/node-stage-secret-name: rook-csi-rbd-node
    csi.storage.k8s.io/node-stage-secret-namespace: rook-ceph

    # Specify the filesystem type of the volume. If not specified, csi-provisioner
    # will set default as `ext4`. Note that `xfs` is not recommended due to potential deadlock
    # in hyperconverged settings where the volume is mounted on the same node as the osds.
    csi.storage.k8s.io/fstype: xfs

# Delete the rbd volume when a PVC is deleted
reclaimPolicy: Delete
```

```sh
[root@k8s block-storage]# kubectl apply -f .
[root@k8s block-storage]# kubectl get CephBlockPool -n rook-ceph
NAME          AGE
replicapool   2d17h
[root@k8s block-storage]# kubectl get sc
NAME              PROVISIONER                  RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
rook-ceph-block   rook-ceph.rbd.csi.ceph.com   Delete          Immediate           false                  2d17h
```

### 4. volumeClaimTemplates 调用pv

volumeClaimTemplates 仅限于 statefulset资源下使用

```sh
[root@k8s nginx-StatefulSet]# cat nginx-StatefulSet.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nginx
  namespace: nginx
spec:
  serviceName: "nginx-service"
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        volumeMounts:
          - name: nginx-pvc
            mountPath: "/mnt"
  volumeClaimTemplates:
  - metadata:
      name: nginx-pvc
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: rook-ceph-block
      resources:
        requests:
          storage: 2Gi
[root@k8s nginx-StatefulSet]# kubectl apply -f nginx-StatefulSet.yaml
[root@k8s nginx-StatefulSet]# kubectl get pods -n nginx
NAME      READY   STATUS    RESTARTS   AGE
nginx-0   1/1     Running   0          2m44s
nginx-1   1/1     Running   0          2m
nginx-2   1/1     Running   0          88s
[root@k8s nginx-StatefulSet]# kubectl get pvc -n nginx
NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
nginx-pvc-nginx-0   Bound    pvc-e368823e-53ca-497b-93e5-f027f5205cfe   2Gi        RWO            rook-ceph-block   104s
nginx-pvc-nginx-1   Bound    pvc-0c3102f2-3d35-48eb-8ad1-afe3287d3af6   2Gi        RWO            rook-ceph-block   60s
nginx-pvc-nginx-2   Bound    pvc-e845c171-74b4-470b-9620-c071b9c74b50   2Gi        RWO            rook-ceph-block   28s
```

测试进入容器挂载目录下创建目录

```sh
[root@k8s nginx-StatefulSet]# kubectl exec -it -n nginx nginx-0 -- bash
root@nginx-0:/# df -h   
Filesystem               Size  Used Avail Use% Mounted on
overlay                   48G  7.8G   40G  17% /
tmpfs                     64M     0   64M   0% /dev
tmpfs                    3.9G     0  3.9G   0% /sys/fs/cgroup
/dev/rbd0                2.0G   33M  2.0G   2% /mnt
/dev/mapper/centos-root   48G  7.8G   40G  17% /etc/hosts
shm                       64M     0   64M   0% /dev/shm
tmpfs                    3.9G   12K  3.9G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                    3.9G     0  3.9G   0% /proc/acpi
tmpfs                    3.9G     0  3.9G   0% /proc/scsi
tmpfs                    3.9G     0  3.9G   0% /sys/firmware
root@nginx-0:/# mkdir /mnt/hello
root@nginx-0:/# touch /mnt/hello/hello-world
root@nginx-0:/#
exit

# 进入其他容器查看没有数据，因为每个不同的pod所用的pvc也是单独的，这就是statefulset
[root@k8s nginx-StatefulSet]# kubectl exec -it -n nginx nginx-1 -- bash
root@nginx-1:/# ls /mnt/
```


### 5. 手动创建 pvc 动态调用 pv

```sh
[root@k8s nginx-StatefulSet]# cat nginx-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-pvc
  namespace: nginx
  annotations:
    volume.beta.kubernetes.io/storage-class: "rook-ceph-block"
spec:
  # storageClassName: rook-ceph-block
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2G
```

```sh
[root@k8s nginx-StatefulSet]# cat nginx-deploy.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deploy
  namespace: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx-deploy
  template:
    metadata:
      labels:
        app: nginx-deploy
    spec:
      containers:
      - name: nginx-deploy
        image: nginx:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        volumeMounts:
          - name: nginx-deploy-pvc
            mountPath: "/mnt"
      volumes:
      - name: nginx-deploy-pvc
        persistentVolumeClaim:
          claimName: nginx-pvc
      restartPolicy: Always
```

```sh
[root@k8s nginx-StatefulSet]# kubectl apply -f nginx-pvc.yaml
[root@k8s nginx-StatefulSet]# kubectl apply -f nginx-deploy.yml
```

```sh
[root@k8s nginx-StatefulSet]# kubectl get pods -n nginx
NAME                           READY   STATUS    RESTARTS   AGE
nginx-0                        1/1     Running   0          9m46s
nginx-1                        1/1     Running   0          9m2s
nginx-2                        1/1     Running   0          8m30s
nginx-deploy-8bc684865-5ct6q   1/1     Running   0          14s
nginx-deploy-8bc684865-hz64t   1/1     Running   0          14s
nginx-deploy-8bc684865-s77rb   1/1     Running   0          14s
[root@k8s nginx-StatefulSet]# kubectl get pvc -n nginx
NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      AGE
nginx-pvc           Bound    pvc-45bfc452-a074-4f02-a375-402493fda31a   2Gi        RWO            rook-ceph-block   59s
nginx-pvc-nginx-0   Bound    pvc-e368823e-53ca-497b-93e5-f027f5205cfe   2Gi        RWO            rook-ceph-block   10m
nginx-pvc-nginx-1   Bound    pvc-0c3102f2-3d35-48eb-8ad1-afe3287d3af6   2Gi        RWO            rook-ceph-block   9m21s
nginx-pvc-nginx-2   Bound    pvc-e845c171-74b4-470b-9620-c071b9c74b50   2Gi        RWO            rook-ceph-block   8m49s
```

测试进入容器挂载目录下创建目录

```sh
[root@k8s nginx-StatefulSet]# kubectl exec -it -n nginx nginx-deploy-8bc684865-s77rb -- bash
root@nginx-deploy-8bc684865-s77rb:/# df -h
Filesystem               Size  Used Avail Use% Mounted on
overlay                   48G  7.8G   40G  17% /
tmpfs                     64M     0   64M   0% /dev
tmpfs                    3.9G     0  3.9G   0% /sys/fs/cgroup
/dev/rbd2                2.0G   33M  2.0G   2% /mnt
/dev/mapper/centos-root   48G  7.8G   40G  17% /etc/hosts
shm                       64M     0   64M   0% /dev/shm
tmpfs                    3.9G   12K  3.9G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs                    3.9G     0  3.9G   0% /proc/acpi
tmpfs                    3.9G     0  3.9G   0% /proc/scsi
tmpfs                    3.9G     0  3.9G   0% /sys/firmware
root@nginx-deploy-8bc684865-s77rb:/# mkdir  /mnt/hello
root@nginx-deploy-8bc684865-s77rb:/# touch /mnt/hello-world

# 切换到其他容器，查看存储是所有pod共享使用的，这就是deployment使用动态pvc调用pv的样子

[root@k8s nginx-StatefulSet]# kubectl exec -it -n nginx nginx-deploy-8bc684865-hz64t -- bash
root@nginx-deploy-8bc684865-hz64t:/# ls /mnt/hello/hello-world
/mnt/hello/hello-world
```
