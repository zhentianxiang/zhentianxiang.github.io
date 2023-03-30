---
layout: post
title: 理论-Kubernetes-10-Kubernetes其它操作知识点
date: 2021-11-05
tags: 理论-Kubernetes
---

### 1. 调整k8s默认端口范围

```sh
[root@k8s-master ~]# vim /etc/kubernetes/manifests/kube-apiserver.yaml
...................
- --proxy-client-cert-file=/etc/kubernetes/pki/front-proxy-client.crt
- --proxy-client-key-file=/etc/kubernetes/pki/front-proxy-client.key
- --requestheader-allowed-names=front-proxy-client
- --requestheader-client-ca-file=/etc/kubernetes/pki/front-proxy-ca.crt
- --requestheader-extra-headers-prefix=X-Remote-Extra-
- --requestheader-group-headers=X-Remote-Group
- --requestheader-username-headers=X-Remote-User
- --secure-port=6443
- --service-account-key-file=/etc/kubernetes/pki/sa.pub
- --service-cluster-ip-range=10.96.0.0/12
- --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
- --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
- --service-node-port-range=1-65535  ###添加此行内容
...........................
```

### 2. 开启默认StorageClass

以下仅仅是配置了一个默认的Storage Class，要想配合pvc的使用，还需要配置后端存储。

如：利用nfs来作为后端存储

可以参考这一章内容 https://blog.linuxtian.top/2021/08/Linux-Kubernetes-34-交付EFK到K8S

```sh
[root@k8s-master ~]# vim /etc/kubernetes/manifests/kube-apiserver.yaml
......................
- --service-cluster-ip-range=10.96.0.0/12
- --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
- --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
- --service-node-port-range=1-65535
- --enable-admission-plugins=NodeRestriction,DefaultStorageClass  ###添加此行内容
```
编辑一个storage class
```sh
[root@k8s-master ~]# vim /etc/kubernetes/manifests/defaultclass01.yaml
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: do-block-storage
  annotations:
    storageclass.beta.kubernetes.io/is-default-class: "true"
provisioner: example.com/nfs
parameters:
  type: pd-ssd
[root@k8s-master ~]# kubectl apply -f /etc/kubernetes/manifests/defaultclass01.yaml
通过kubectl create命令创建成功后，查看StorageClass列表，可以看到名为gold的StorageClass被标记为default
[root@k8s-master ~]# kubectl get sc
NAME                         PROVISIONER       RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
do-block-storage (default)   example.com/nfs   Delete          Immediate           false                  29m
```

### 3. 修改kubelet工作目录

用为像docker和kubelet默认的工作目录目录在/var/lib/下面，后期工作中可能会遇到磁盘空间不足导致集群出问题，因此我们在初始化集群初期可以修改kubelet的工作目录

根据 /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf 加载文件，只需要修改 /etc/sysconfig/kubelet 即可。
```sh
[root@k8s-master ~]# vim /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--root-dir=/data/k8s/lib/kubelet"

[root@k8s-master ~]# systemctl daemon-reload
[root@k8s-master ~]# systemctl restart kubelet
```

### 4. 维护节点

停止节点调度

```sh
[root@VM-16-9-centos ~]# kubectl cordon vm-16-9-centos
[root@VM-16-9-centos ~]# kubectl get node
NAME             STATUS                      ROLES                  AGE   VERSION
vm-16-9-centos   Ready,SchedulingDisabled    control-plane,master   75d   v1.20.1
```

如果想要取消不可调度，恢复到集群，可以使用 uncordon 命令

```sh
[root@VM-16-9-centos ~]# kubectl uncordon vm-16-9-centos
[root@VM-16-9-centos ~]# kubectl get node
NAME             STATUS   ROLES                  AGE   VERSION
vm-16-9-centos   Ready    control-plane,master   75d   v1.20.1
```

驱逐该节点上的pod，该命令操作，会先驱逐 Node 上的 pod 资源到其他节点重新创建。接着，将节点调为 SchedulingDisabled 不可调度状态。

```sh
# --ignore-daemonsets 不驱逐 daemonset 控制器的 pod
# --delete-emptydir-data 删除pod所在节点的临时数据，默认为 /var/lib/kubelet/pods/.......
[root@VM-16-9-centos ~]# kubectl drain vm-14-debian --ignore-daemonsets --delete-emptydir-data
```

### 5. 强制删除 pod

强制删除 Terminating 状态的 pod

```sh
[root@dqynj139130 ~]# kubectl get pods -n harbor -o wide
NAME                                 READY   STATUS        RESTARTS   AGE    IP              NODE          NOMINATED NODE   READINESS GATES
harbor-core-7457dc7d9b-q64l7         1/1     Running       0          23d    10.96.233.91    dqynj139125   <none>           <none>
harbor-core-7457dc7d9b-rc8hl         1/1     Running       0          23d    10.96.220.242   dqynj139132   <none>           <none>
harbor-core-7457dc7d9b-spccl         1/1     Running       0          22d    10.96.210.87    dqynj139126   <none>           <none>
harbor-jobservice-6469cc577d-56dkj   1/1     Running       0          5d7h   10.96.118.159   dqynj139130   <none>           <none>
harbor-jobservice-6469cc577d-8vw8j   0/1     Terminating   0          9d     10.96.118.129   dqynj139130   <none>           <none>
harbor-jobservice-6469cc577d-8w6lx   1/1     Running       0          5d7h   10.96.233.109   dqynj139125   <none>           <none>
harbor-jobservice-6469cc577d-q5z9c   1/1     Running       0          5d7h   10.96.210.123   dqynj139126   <none>           <none>

[root@dqynj139130 ~]# kubectl delete pods -n harbor harbor-jobservice-6469cc577d-8vw8j --force --grace-period=0
[root@dqynj139130 ~]# kubectl get pods -n harbor -o wide
NAME                                 READY   STATUS        RESTARTS   AGE    IP              NODE          NOMINATED NODE   READINESS GATES
harbor-core-7457dc7d9b-q64l7         1/1     Running       0          23d    10.96.233.91    dqynj139125   <none>           <none>
harbor-core-7457dc7d9b-rc8hl         1/1     Running       0          23d    10.96.220.242   dqynj139132   <none>           <none>
harbor-core-7457dc7d9b-spccl         1/1     Running       0          22d    10.96.210.87    dqynj139126   <none>           <none>
harbor-jobservice-6469cc577d-56dkj   1/1     Running       0          5d7h   10.96.118.159   dqynj139130   <none>           <none>
harbor-jobservice-6469cc577d-8w6lx   1/1     Running       0          5d7h   10.96.233.109   dqynj139125   <none>           <none>
harbor-jobservice-6469cc577d-q5z9c   1/1     Running       0          5d7h   10.96.210.123   dqynj139126   <none>           <none>
```
