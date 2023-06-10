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
### 3. 创建存储池

创建kubernetes池给k8s

```sh
[root@ceph-01 ceph]# ceph osd pool create kubernetes 128 128
pool 'kubernetes' created
[root@ceph-01 ceph]# ceph osd pool ls
.rgw.root
default.rgw.control
default.rgw.meta
default.rgw.log
default.rgw.buckets.index
default.rgw.buckets.data
kubernetes
```

### 4. 创建ceph用户，提供给k8s使用

```sh
[root@ceph-01 ceph]# ceph auth get-or-create client.kubernetes mon 'profile rbd' osd 'profile rbd pool=kubernetes' mgr 'profile rbd pool=kubernetes'

[client.kubernetes]
    key = AQBnz11fclrxChAAf8TFw8ROzmr8ifftAHQbTw==
[root@k8s-cluster-master01 ceph]# ceph auth list |grep kubernetes
  installed auth entries:

  client.kubernetes
  	caps: [osd] allow class-read object_prefix rbd_children,allow rwx pool=kubernetes
```
后面的配置需要用到这里的 key，如果忘了可以通过以下命令来获取：
```sh
[root@ceph-01 ceph]# ceph auth get client.kubernetes
exported keyring for client.kubernetes
[client.kubernetes]
	key = AQBnz11fclrxChAAf8TFw8ROzmr8ifftAHQbTw==
	caps mgr = "profile rbd pool=kubernetes"
	caps mon = "profile rbd"
	caps osd = "profile rbd pool=kubernetes"
```
### 5. 创建secret资源

```sh
[root@k8s-cluster-master01～]# mkdir /data/ceph-csi/ -pv
[root@k8s-cluster-master01～]# cd /data/ceph-csi/
[root@k8s-cluster-master01 ceph-csi]# vim csi-rbd-secret.yaml

apiVersion: v1
kind: Secret
metadata:
  name: csi-rbd-secret
  namespace: ceph-csi
stringData:
  userID: kubernetes
  userKey: AQDbrXlk6IF7JxAA/S4vy6Sd3qwOUaE65uN2Jw==
[root@k8s-cluster-master01 ceph-csi]# kubectl create ns ceph-csi
[root@k8s-cluster-master01 ceph-csi]# kubectl apply -f csi-rbd-secret.yaml
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
[root@k8s-cluster-master01 jtpv]# rbd create -p kubernetes -s 10G ceph-image
[root@k8s-cluster-master01 jtpv]# rbd ls -p kubernetes
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
## 二、使用ceph-csi来做RBD模式持久化

### 1.ceph 操作部分

新建 Ceph Pool、新建ceph用户，这里还是用上面已经创建好的kubernetes pool

### 2. 部署 ceph-csi

```sh
[root@k8s-cluster-master01 ceph-csi]# cat > csi-rbd-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: csi-rbd-secret
  namespace: ceph-csi
stringData:
  # ID和key 就是上面创建 ceph 用户那个
  userID: kubernetes
  userKey: AQDbrXlk6IF7JxAA/S4vy6Sd3qwOUaE65uN2Jw==
EOF

# clusterID
[root@ceph-01 ceph]# ceph mon dump

dumped monmap epoch 1
epoch 1
fsid 154c3d17-a9af-4f52-b83e-0fddd5db6e1b
last_changed 2020-09-12 16:16:53.774567
created 2020-09-12 16:16:53.774567
min_mon_release 14 (nautilus)
0: [v2:192.168.110.180:3300/0,v1:192.168.110.180:6789/0] mon.sealos01
1: [v2:192.168.110.181:3300/0,v1:192.168.110.181:6789/0] mon.sealos02
2: [v2:192.168.110.182:3300/0,v1:192.168.110.182:6789/0] mon.sealos03

[root@k8s-cluster-master01 ceph-csi]# cat > csi-config-map.yaml <<EOF
---
apiVersion: v1
kind: ConfigMap
data:
  config.json: |-
    [
      {
        "clusterID": "154c3d17-a9af-4f52-b83e-0fddd5db6e1b",
        "monitors": [
          "192.168.110.180:6789",
          "192.168.110.181:6789",
          "192.168.110.182:6789"
        ]
      }
    ]
metadata:
  name: ceph-csi-config
  namespace: ceph-csi
EOF
[root@k8s-cluster-master01 ceph-csi]# cat > csi-provisioner-rbac.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rbd-csi-provisioner
  namespace: ceph-csi

---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-external-provisioner-runner
  namespace: ceph-csi
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "update", "delete", "patch"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims/status"]
    verbs: ["update", "patch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshots"]
    verbs: ["get", "list"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshotcontents"]
    verbs: ["create", "get", "list", "watch", "update", "delete"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshotclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["volumeattachments"]
    verbs: ["get", "list", "watch", "update", "patch"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["csinodes"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["snapshot.storage.k8s.io"]
    resources: ["volumesnapshotcontents/status"]
    verbs: ["update"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-csi-provisioner-role
subjects:
  - kind: ServiceAccount
    name: rbd-csi-provisioner
    namespace: ceph-csi
roleRef:
  kind: ClusterRole
  name: rbd-external-provisioner-runner
  apiGroup: rbac.authorization.k8s.io

---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  # replace with non-default namespace name
  namespace: ceph-csi
  name: rbd-external-provisioner-cfg
rules:
  - apiGroups: [""]
    resources: ["configmaps"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: ["coordination.k8s.io"]
    resources: ["leases"]
    verbs: ["get", "watch", "list", "delete", "update", "create"]

---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-csi-provisioner-role-cfg
  # replace with non-default namespace name
  namespace: ceph-csi
subjects:
  - kind: ServiceAccount
    name: rbd-csi-provisioner
    # replace with non-default namespace name
    namespace: ceph-csi
roleRef:
  kind: Role
  name: rbd-external-provisioner-cfg
  apiGroup: rbac.authorization.k8s.io
EOF
[root@k8s-cluster-master01 ceph-csi]# cat > csi-nodeplugin-rbac.yaml <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rbd-csi-nodeplugin
  namespace: ceph-csi
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-csi-nodeplugin
  namespace: ceph-csi
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rbd-csi-nodeplugin
  namespace: ceph-csi
subjects:
  - kind: ServiceAccount
    name: rbd-csi-nodeplugin
    namespace: ceph-csi
roleRef:
  kind: ClusterRole
  name: rbd-csi-nodeplugin
  apiGroup: rbac.authorization.k8s.io
EOF
[root@k8s-cluster-master01 ceph-csi]# cat > csi-rbdplugin-provisioner.yaml <<EOF
---
kind: Service
apiVersion: v1
metadata:
  name: csi-rbdplugin-provisioner
  namespace: ceph-csi
  labels:
    app: csi-metrics
spec:
  selector:
    app: csi-rbdplugin-provisioner
  ports:
    - name: http-metrics
      port: 8080
      protocol: TCP
      targetPort: 8680

---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: csi-rbdplugin-provisioner
  namespace: ceph-csi
spec:
  replicas: 3
  selector:
    matchLabels:
      app: csi-rbdplugin-provisioner
  template:
    metadata:
      labels:
        app: csi-rbdplugin-provisioner
    spec:
      serviceAccount: rbd-csi-provisioner
      containers:
        - name: csi-provisioner
          image: quay.io/k8scsi/csi-provisioner:v1.6.0
          args:
            - "--csi-address=$(ADDRESS)"
            - "--v=5"
            - "--timeout=150s"
            - "--retry-interval-start=500ms"
            - "--enable-leader-election=true"
            - "--leader-election-type=leases"
            - "--feature-gates=Topology=true"
          env:
            - name: ADDRESS
              value: unix:///csi/csi-provisioner.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
        - name: csi-snapshotter
          image: quay.io/k8scsi/csi-snapshotter:v2.1.0
          args:
            - "--csi-address=$(ADDRESS)"
            - "--v=5"
            - "--timeout=150s"
            - "--leader-election=true"
          env:
            - name: ADDRESS
              value: unix:///csi/csi-provisioner.sock
          imagePullPolicy: "IfNotPresent"
          securityContext:
            privileged: true
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
        - name: csi-attacher
          image: quay.io/k8scsi/csi-attacher:v2.1.1
          args:
            - "--v=5"
            - "--csi-address=$(ADDRESS)"
            - "--leader-election=true"
            - "--retry-interval-start=500ms"
          env:
            - name: ADDRESS
              value: /csi/csi-provisioner.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
        - name: csi-resizer
          image: quay.io/k8scsi/csi-resizer:v0.5.0
          args:
            - "--csi-address=$(ADDRESS)"
            - "--v=5"
            - "--csiTimeout=150s"
            - "--leader-election"
            - "--retry-interval-start=500ms"
          env:
            - name: ADDRESS
              value: unix:///csi/csi-provisioner.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
        - name: csi-rbdplugin
          securityContext:
            privileged: true
            capabilities:
              add: ["SYS_ADMIN"]
          # for stable functionality replace canary with latest release version
          image: quay.io/cephcsi/cephcsi:canary
          args:
            - "--nodeid=$(NODE_ID)"
            - "--type=rbd"
            - "--controllerserver=true"
            - "--endpoint=$(CSI_ENDPOINT)"
            - "--v=5"
            - "--drivername=rbd.csi.ceph.com"
            - "--pidlimit=-1"
            - "--rbdhardmaxclonedepth=8"
            - "--rbdsoftmaxclonedepth=4"
          env:
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: NODE_ID
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: CSI_ENDPOINT
              value: unix:///csi/csi-provisioner.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
            - mountPath: /dev
              name: host-dev
            - mountPath: /sys
              name: host-sys
            - mountPath: /lib/modules
              name: lib-modules
              readOnly: true
            - name: ceph-csi-config
              mountPath: /etc/ceph-csi-config/
            #- name: ceph-csi-encryption-kms-config
            #  mountPath: /etc/ceph-csi-encryption-kms-config/
            - name: keys-tmp-dir
              mountPath: /tmp/csi/keys
        - name: liveness-prometheus
          image: quay.io/cephcsi/cephcsi:canary
          args:
            - "--type=liveness"
            - "--endpoint=$(CSI_ENDPOINT)"
            - "--metricsport=8680"
            - "--metricspath=/metrics"
            - "--polltime=60s"
            - "--timeout=3s"
          env:
            - name: CSI_ENDPOINT
              value: unix:///csi/csi-provisioner.sock
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
          imagePullPolicy: "IfNotPresent"
      volumes:
        - name: host-dev
          hostPath:
            path: /dev
        - name: host-sys
          hostPath:
            path: /sys
        - name: lib-modules
          hostPath:
            path: /lib/modules
        - name: socket-dir
          emptyDir: {
            medium: "Memory"
          }
        - name: ceph-csi-config
          configMap:
            name: ceph-csi-config
        #- name: ceph-csi-encryption-kms-config
        #  configMap:
        #    name: ceph-csi-encryption-kms-config
        - name: keys-tmp-dir
          emptyDir: {
            medium: "Memory"
          }
EOF
[root@k8s-cluster-master01 ceph-csi]# cat > csi-rbdplugin.yaml <<EOF
kind: DaemonSet
apiVersion: apps/v1
metadata:
  name: csi-rbdplugin
  namespace: ceph-csi
spec:
  selector:
    matchLabels:
      app: csi-rbdplugin
  template:
    metadata:
      labels:
        app: csi-rbdplugin
    spec:
      serviceAccount: rbd-csi-nodeplugin
      hostNetwork: true
      hostPID: true
      # to use e.g. Rook orchestrated cluster, and mon FQDN is
      # resolved through k8s service, set dns policy to cluster first
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: driver-registrar
          # This is necessary only for systems with SELinux, where
          # non-privileged sidecar containers cannot access unix domain socket
          # created by privileged CSI driver container.
          securityContext:
            privileged: true
          image: quay.io/k8scsi/csi-node-driver-registrar:v1.3.0
          args:
            - "--v=5"
            - "--csi-address=/csi/csi.sock"
            - "--kubelet-registration-path=/var/lib/kubelet/plugins/rbd.csi.ceph.com/csi.sock"
          env:
            - name: KUBE_NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
            - name: registration-dir
              mountPath: /registration
        - name: csi-rbdplugin
          securityContext:
            privileged: true
            capabilities:
              add: ["SYS_ADMIN"]
            allowPrivilegeEscalation: true
          # for stable functionality replace canary with latest release version
          image: quay.io/cephcsi/cephcsi:canary
          args:
            - "--nodeid=$(NODE_ID)"
            - "--type=rbd"
            - "--nodeserver=true"
            - "--endpoint=$(CSI_ENDPOINT)"
            - "--v=5"
            - "--drivername=rbd.csi.ceph.com"
            # If topology based provisioning is desired, configure required
            # node labels representing the nodes topology domain
            # and pass the label names below, for CSI to consume and advertize
            # its equivalent topology domain
            # - "--domainlabels=failure-domain/region,failure-domain/zone"
          env:
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: NODE_ID
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
            - name: CSI_ENDPOINT
              value: unix:///csi/csi.sock
          imagePullPolicy: "IfNotPresent"
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
            - mountPath: /dev
              name: host-dev
            - mountPath: /sys
              name: host-sys
            - mountPath: /run/mount
              name: host-mount
            - mountPath: /lib/modules
              name: lib-modules
              readOnly: true
            - name: ceph-csi-config
              mountPath: /etc/ceph-csi-config/
            #- name: ceph-csi-encryption-kms-config
            #  mountPath: /etc/ceph-csi-encryption-kms-config/
            - name: plugin-dir
              mountPath: /var/lib/kubelet/plugins
              mountPropagation: "Bidirectional"
            - name: mountpoint-dir
              mountPath: /var/lib/kubelet/pods
              mountPropagation: "Bidirectional"
            - name: keys-tmp-dir
              mountPath: /tmp/csi/keys
        - name: liveness-prometheus
          securityContext:
            privileged: true
          image: quay.io/cephcsi/cephcsi:canary
          args:
            - "--type=liveness"
            - "--endpoint=$(CSI_ENDPOINT)"
            - "--metricsport=8680"
            - "--metricspath=/metrics"
            - "--polltime=60s"
            - "--timeout=3s"
          env:
            - name: CSI_ENDPOINT
              value: unix:///csi/csi.sock
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
          volumeMounts:
            - name: socket-dir
              mountPath: /csi
          imagePullPolicy: "IfNotPresent"
      volumes:
        - name: socket-dir
          hostPath:
            path: /var/lib/kubelet/plugins/rbd.csi.ceph.com
            type: DirectoryOrCreate
        - name: plugin-dir
          hostPath:
            path: /var/lib/kubelet/plugins
            type: Directory
        - name: mountpoint-dir
          hostPath:
            path: /var/lib/kubelet/pods
            type: DirectoryOrCreate
        - name: registration-dir
          hostPath:
            path: /var/lib/kubelet/plugins_registry/
            type: Directory
        - name: host-dev
          hostPath:
            path: /dev
        - name: host-sys
          hostPath:
            path: /sys
        - name: host-mount
          hostPath:
            path: /run/mount
        - name: lib-modules
          hostPath:
            path: /lib/modules
        - name: ceph-csi-config
          configMap:
            name: ceph-csi-config
        #- name: ceph-csi-encryption-kms-config
        #  configMap:
        #    name: ceph-csi-encryption-kms-config
        - name: keys-tmp-dir
          emptyDir: {
            medium: "Memory"
          }
---
# This is a service to expose the liveness metrics
apiVersion: v1
kind: Service
metadata:
  name: csi-metrics-rbdplugin
  namespace: ceph-csi
  labels:
    app: csi-metrics
spec:
  ports:
    - name: http-metrics
      port: 8080
      protocol: TCP
      targetPort: 8680
  selector:
    app: csi-rbdplugin
EOF
[root@k8s-cluster-master01 ceph-csi]# cat > storageclass.yaml <<EOF
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
   name: csi-rbd-sc
provisioner: rbd.csi.ceph.com
parameters:
   clusterID: a3ce96f4-ffff-4144-bbbd-9c7def552f99
   pool: kubernetes
   imageFeatures: layering
   csi.storage.k8s.io/provisioner-secret-name: csi-rbd-secret
   csi.storage.k8s.io/provisioner-secret-namespace: ceph-csi
   csi.storage.k8s.io/controller-expand-secret-name: csi-rbd-secret
   csi.storage.k8s.io/controller-expand-secret-namespace: ceph-csi
   csi.storage.k8s.io/node-stage-secret-name: csi-rbd-secret
   csi.storage.k8s.io/node-stage-secret-namespace: ceph-csi
   csi.storage.k8s.io/fstype: ext4
reclaimPolicy: Delete
allowVolumeExpansion: true
mountOptions:
   - discard
EOF
[root@k8s-cluster-master01 ceph-csi]# cat > pvc.yaml <<EOF
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rbd-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: csi-rbd-sc
EOF
[root@k8s-cluster-master01 ceph-csi]# cat > pod.yaml <<EOF
---
apiVersion: v1
kind: Pod
metadata:
  name: csi-rbd-demo-pod
spec:
  containers:
    - name: web-server
      image: nginx
      volumeMounts:
        - name: mypvc
          mountPath: /var/lib/www/html
  volumes:
    - name: mypvc
      persistentVolumeClaim:
        claimName: rbd-pvc
        readOnly: false
EOF
```
### 2. 提交资源并验证

```sh
[root@k8s-cluster-master01 ceph-csi]# kubectl create ns ceph-csi
[root@k8s-cluster-master01 ceph-csi]# kubectl apply -f .
[root@k8s-cluster-master01 ceph-csi]# kubectl get pvc,pod
```

### 3. 列出 kubernetes pool 中的 rbd images
```sh
[root@ceph-01 ceph]# rbd ls -p kubernetes
csi-vol-d9d011f9-f669-11ea-a3fa-ee21730897e6
[root@ceph-01 ceph]# rbd info csi-vol-d9d011f9-f669-11ea-a3fa-ee21730897e6 -p kubernetes
rbd image 'csi-vol-d9d011f9-f669-11ea-a3fa-ee21730897e6':
	size 1 GiB in 256 objects
	order 22 (4 MiB objects)
	snapshot_count: 0
	id: 8da46585bb36
	block_name_prefix: rbd_data.8da46585bb36
	format: 2
	features: layering
	op_features:
	flags:
	create_timestamp: Mon Sep 14 09:08:27 2020
	access_timestamp: Mon Sep 14 09:08:27 2020
	modify_timestamp: Mon Sep 14 09:08:27 2020
```
可以看到对 image 的特征限制生效了，这里只有 layering。

实际上这个 image 会被挂载到 node 中作为一个块设备，到运行 Pod 的 Node 上可以通过 rbd 命令查看映射信息：
```sh
[root@ceph-01 ceph]# rbd showmapped
id pool       namespace image                                        snap device
0  kubernetes           csi-vol-d9d011f9-f669-11ea-a3fa-ee21730897e6 -    /dev/rbd0
```

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
