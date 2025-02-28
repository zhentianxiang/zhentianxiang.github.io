---
layout: post
title: 云原生第一期-01-部署Kubersphere容器调度平台
date: 2022-05-29
tags: Kubesphere
music-id: 1971107237
---

## 一、简介

[KubeSphere](https://kubesphere.io/) 是在目前主流容器调度平台 [Kubernetes](https://kubernetes.io/) 之上构建的企业级分布式多租户容器平台，提供简单易用的操作界面以及向导式操作方式，在降低用户使用容器调度平台学习成本的同时，极大减轻开发、测试、运维的日常工作的复杂度，旨在解决 Kubernetes 本身存在的存储、网络、安全和易用性等痛点。除此之外，平台已经整合并优化了多个适用于容器场景的功能模块，以完整的解决方案帮助企业轻松应对敏捷开发与自动化运维、微服务治理、多租户管理、工作负载和集群管理、服务与网络管理、应用编排与管理、镜像仓库管理和存储管理等业务场景。

相比较易捷版，KubeSphere 高级版提供企业级容器应用管理服务，支持更强大的功能和灵活的配置，满足企业复杂的业务需求。比如支持 Master 和 etcd 节点高可用、可视化 CI/CD 流水线、多维度监控告警日志、多租户管理、LDAP 集成、新增支持 HPA (水平自动伸缩) 、容器健康检查以及 Secrets、ConfigMaps 的配置管理等功能，新增微服务治理、灰度发布、s2i、代码质量检查等，后续还将提供和支持多集群管理、大数据、人工智能等更为复杂的业务场景。

具体详细介绍可以去官方网站进行阅读，或者各大浏览器上直接搜索关于kubesphere的使用

## 二、安装部署

### 1. 准备工作

您可以在虚拟机和裸机上安装 KubeSphere，并同时配置 Kubernetes。另外，只要 Kubernetes 集群满足以下前提条件，那么您也可以在云托管和本地 Kubernetes 集群上部署 KubeSphere。

如需在 Kubernetes 上安装 KubeSphere v3.2.0，您的 Kubernetes 版本必须为：v1.19.x，v1.20.x，v1.21.x 或 v1.22.x（实验性支持）。
可用 CPU > 1 核；内存 > 2 G。
Kubernetes 集群已配置默认 StorageClass（请使用 kubectl get sc 进行确认）。
使用 --cluster-signing-cert-file 和 --cluster-signing-key-file 参数启动集群时，kube-apiserver 将启用 CSR 签名功能。请参见 RKE [安装问题](https://github.com/kubesphere/kubesphere/issues/1925#issuecomment-591698309)。

#### 1.1 预检查

在集群节点中运行 kubectl version，确保 Kubernetes 版本可兼容。输出如下所示：

```sh
[root@kubesphere ~]#  kubectl version
Client Version: version.Info{Major:"1", Minor:"19", GitVersion:"v1.19.8", GitCommit:"fd5d41537aee486160ad9b5356a9d82363273721", GitTreeState:"clean", BuildDate:"2021-02-17T12:41:51Z", GoVersion:"go1.15.8", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"19", GitVersion:"v1.19.8", GitCommit:"fd5d41537aee486160ad9b5356a9d82363273721", GitTreeState:"clean", BuildDate:"2021-02-17T12:33:08Z", GoVersion:"go1.15.8", Compiler:"gc", Platform:"linux/amd64"}
```
> 请注意 Server Version 这一行。如果 GitVersion 显示为旧版本，则需要先升级 Kubernetes。

检查集群中的可用资源是否满足最低要求。

```sh
[root@kubesphere ~]#  free -g
            total        used        free      shared  buff/cache   available
Mem:              16          4          10           0           3           2
Swap:             0           0           0
```

检查集群中是否有默认 StorageClass（准备默认 StorageClass 是安装 KubeSphere 的前提条件）。

```sh
[root@kubesphere ~]#  kubectl get sc
NAME                      PROVISIONER               AGE
glusterfs (default)       kubernetes.io/glusterfs   3d4h
```

如果没有默认的存储，如下步骤为创建方式。

```sh
[root@kubesphere ~]#  yum install -y nfs-utils

[root@kubesphere ~]#  systemctl start nfs

[root@kubesphere ~]#  systemctl enable nfs
```

创建一个nfs共享目录

> 注意：准备nfs环境的时候，`/etc/exports`配置文件中，如：`/home/volume_nfs 192.168.1.20(rw,no_root_squash)`地址和后面的()不能有空格，否则pod创建报错`read-only file system`，还有一点就是，我这次的实验环境是3台机器，所以其他两台机去需要挂在nfs存储，以免pod在不同节点运行的时候进行nfs挂载找不到目录而报错
>
> 但是，这是仅限于创建nfs存储类型的pvc这样使用，如果想要手动mount -t nfs ，就必须要有空格，此时可以写两行内容，一行有空格一行没空格

```shell
[root@kubesphere ~]#  mkdir /home/volume_nfs

[root@kubesphere ~]#  vim /etc/exports

/home/volume_nfs 192.168.1.194(rw,no_root_squash)

[root@kubesphere ~]#  exportfs -arv

[root@kubesphere ~]#  systemctl restart nfs
```

**准备nfs-provisioner**

```sh
## 创建了一个存储类
[root@kubesphere ~]# cat  > nfs-client-provisioner.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: k8s-sigs.io/nfs-subdir-external-provisioner
parameters:
  archiveOnDelete: "true"  ## 删除pv的时候，pv的内容是否要备份

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-client-provisioner
  labels:
    app: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: registry.cn-hangzhou.aliyuncs.com/lfy_k8s_images/nfs-subdir-external-provisioner:v4.0.2
          # resources:
          #    limits:
          #      cpu: 10m
          #    requests:
          #      cpu: 10m
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: k8s-sigs.io/nfs-subdir-external-provisioner
            - name: NFS_SERVER
              value: 192.168.1.194 ## 指定自己nfs服务器地址
            - name: NFS_PATH  
              value: /home/volume_nfs  ## nfs服务器共享的目录
      volumes:
        - name: nfs-client-root
          nfs:
            server: 192.168.1.194
            path: /home/volume_nfs
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
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
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
  # replace with namespace where provisioner is deployed
  namespace: default
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF
```

```sh
[root@kubesphere ~]# kubectl apply -f nfs-client-provisioner.yaml
[root@kubesphere ~]# kubectl get sc
NAME                    PROVISIONER                                   RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-storage (default)   k8s-sigs.io/nfs-subdir-external-provisioner   Delete          Immediate           false                  8m45s
```

```sh
# 如果get查看不是default，那么需要修改kube-apiserver.yaml文件
[root@kubesphere ~]#  vim /etc/kubernetes/manifests/kube-apiserver.yaml
............
- --enable-admission-plugins=NodeRestriction,DefaultStorageClass
```
如果 Kubernetes 集群环境满足上述所有要求，那么您就可以在现有的 Kubernetes 集群上部署 KubeSphere 了。

### 2. 开始部署Kubesphere

由于所部署的服务很多，每个pod都会依次运行，所以等待时间稍微有点长

官方文档：https://v3-2.docs.kubesphere.io/zh/docs/

```sh
kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.2.0/kubesphere-installer.yaml

kubectl apply -f https://github.com/kubesphere/ks-installer/releases/download/v3.2.0/cluster-configuration.yaml
```

如果文件拉去不下来，可以使用我自己提前准备好的，根据情况自己修改是否要开启的配置

```sh
wget http://blog.tianxiang.love/data/kubesphere-3.2.0/cluster-configuration.yaml
wget http://blog.tianxiang.love/data/kubesphere-3.2.0/kubesphere-installer.yaml
```

查看安装日志

```sh
[root@kubesphere ~]# kubectl logs -n kubesphere-system $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -f
```

查看pod运行状态

```sh
# 因为我这里是1个master和2个node节点，所以看起来pod比较多
[root@kubesphere ~]# kubectl get pods -A -o wide
NAMESPACE                      NAME                                               READY   STATUS    RESTARTS   AGE     IP              NODE         NOMINATED NODE   READINESS GATES
default                        nfs-provisioner-65b88dd6cb-l6xnq                   1/1     Running   0          82m     10.100.85.203   k8s-node01   <none>           <none>
kube-system                    calico-kube-controllers-659bd7879c-s2v44           1/1     Running   0          4h2m    10.100.148.66   kubesphere   <none>           <none>
kube-system                    calico-node-kmlnh                                  1/1     Running   0          4h2m    192.168.1.194   kubesphere   <none>           <none>
kube-system                    calico-node-p85hw                                  1/1     Running   0          3h51m   192.168.1.158   k8s-node01   <none>           <none>
kube-system                    calico-node-pzfnc                                  1/1     Running   0          3h51m   192.168.1.186   k8s-node02   <none>           <none>
kube-system                    coredns-6c76c8bb89-b2xfv                           1/1     Running   0          4h3m    10.100.148.67   kubesphere   <none>           <none>
kube-system                    coredns-6c76c8bb89-c5vzw                           1/1     Running   0          4h3m    10.100.148.65   kubesphere   <none>           <none>
kube-system                    etcd-kubesphere                                    1/1     Running   0          4h3m    192.168.1.194   kubesphere   <none>           <none>
kube-system                    kube-apiserver-kubesphere                          1/1     Running   0          95m     192.168.1.194   kubesphere   <none>           <none>
kube-system                    kube-controller-manager-kubesphere                 1/1     Running   3          4h3m    192.168.1.194   kubesphere   <none>           <none>
kube-system                    kube-proxy-f88zb                                   1/1     Running   0          3h51m   192.168.1.158   k8s-node01   <none>           <none>
kube-system                    kube-proxy-vn89n                                   1/1     Running   0          4h3m    192.168.1.194   kubesphere   <none>           <none>
kube-system                    kube-proxy-wv79v                                   1/1     Running   0          3h51m   192.168.1.186   k8s-node02   <none>           <none>
kube-system                    kube-scheduler-kubesphere                          1/1     Running   4          4h3m    192.168.1.194   kubesphere   <none>           <none>
kube-system                    metrics-server-766c96f6fb-xcf4p                    1/1     Running   0          92m     10.100.58.198   k8s-node02   <none>           <none>
kube-system                    snapshot-controller-0                              1/1     Running   0          152m    10.100.58.193   k8s-node02   <none>           <none>
kubernetes-dashboard           dashboard-metrics-scraper-7b59f7d4df-4qvj8         1/1     Running   0          107m    10.100.85.202   k8s-node01   <none>           <none>
kubernetes-dashboard           kubernetes-dashboard-77c9766b-zx8z9                1/1     Running   0          43m     10.100.58.200   k8s-node02   <none>           <none>
kubesphere-controls-system     default-http-backend-76d9fb4bb7-54xq9              1/1     Running   0          151m    10.100.85.194   k8s-node01   <none>           <none>
kubesphere-controls-system     kubectl-admin-69b8ff6d54-sj2xp                     1/1     Running   0          144m    10.100.85.200   k8s-node01   <none>           <none>
kubesphere-monitoring-system   alertmanager-main-0                                2/2     Running   0          147m    10.100.85.196   k8s-node01   <none>           <none>
kubesphere-monitoring-system   alertmanager-main-1                                2/2     Running   0          147m    10.100.58.195   k8s-node02   <none>           <none>
kubesphere-monitoring-system   alertmanager-main-2                                2/2     Running   0          147m    10.100.148.69   kubesphere   <none>           <none>
kubesphere-monitoring-system   kube-state-metrics-5547ddd4cc-t5lff                3/3     Running   0          147m    10.100.58.194   k8s-node02   <none>           <none>
kubesphere-monitoring-system   node-exporter-77jd9                                2/2     Running   0          147m    192.168.1.186   k8s-node02   <none>           <none>
kubesphere-monitoring-system   node-exporter-8j4hm                                2/2     Running   0          147m    192.168.1.158   k8s-node01   <none>           <none>
kubesphere-monitoring-system   node-exporter-smtrj                                2/2     Running   0          147m    192.168.1.194   kubesphere   <none>           <none>
kubesphere-monitoring-system   notification-manager-deployment-78664576cb-fhqhd   2/2     Running   0          143m    10.100.58.196   k8s-node02   <none>           <none>
kubesphere-monitoring-system   notification-manager-deployment-78664576cb-v6sbl   2/2     Running   0          143m    10.100.85.201   k8s-node01   <none>           <none>
kubesphere-monitoring-system   notification-manager-operator-7d44854f54-s77xl     2/2     Running   2          146m    10.100.85.197   k8s-node01   <none>           <none>
kubesphere-monitoring-system   prometheus-k8s-0                                   2/2     Running   1          65m     10.100.58.199   k8s-node02   <none>           <none>
kubesphere-monitoring-system   prometheus-k8s-1                                   2/2     Running   1          65m     10.100.85.204   k8s-node01   <none>           <none>
kubesphere-monitoring-system   prometheus-operator-5c5db79546-pnvbm               2/2     Running   0          147m    10.100.85.195   k8s-node01   <none>           <none>
kubesphere-system              ks-apiserver-8465444f86-x8dhv                      1/1     Running   0          145m    10.100.148.70   kubesphere   <none>           <none>
kubesphere-system              ks-console-648d747bb-9tktc                         1/1     Running   0          151m    10.100.148.68   kubesphere   <none>           <none>
kubesphere-system              ks-controller-manager-9d8854fd8-5s9vp              1/1     Running   1          145m    10.100.148.71   kubesphere   <none>           <none>
kubesphere-system              ks-installer-7fbc5d568f-gm5pn                      1/1     Running   0          154m    10.100.85.193   k8s-node01   <none>           <none>
```

如果prometheus-k8s服务一直处于创建中，则查看pod详细提示缺少 `secret "kube-etcd-client-certs" not found`

```sh
[root@kubesphere ~]# kubectl -n kubesphere-monitoring-system create secret generic kube-etcd-client-certs  \
--from-file=etcd-client-ca.crt=/etc/kubernetes/pki/etcd/ca.crt  \
--from-file=etcd-client.crt=/etc/kubernetes/pki/etcd/healthcheck-client.crt  \
--from-file=etcd-client.key=/etc/kubernetes/pki/etcd/healthcheck-client.key
```

使用 kubectl get pod --all-namespaces 查看所有 Pod 是否在 KubeSphere 的相关命名空间中正常运行。如果是，请通过以下命令检查控制台的端口（默认为 30880）：

```sh
[root@kubesphere ~]# kubectl get svc/ks-console -n kubesphere-system
NAME         TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)        AGE
ks-console   NodePort   10.97.0.147   <none>        80:30880/TCP   155m
```

### 3. 登录控制台

确保在安全组中打开了端口 30880，并通过 NodePort (IP:30880) 使用默认帐户和密码 (admin/P@88w0rd) 访问 Web 控制台。

![](/images/posts/Kubesphere/云原生第一期-01-部署Kubersphere容器调度平台/1.png)
![](/images/posts/Kubesphere/云原生第一期-01-部署Kubersphere容器调度平台/2.png)
![](/images/posts/Kubesphere/云原生第一期-01-部署Kubersphere容器调度平台/3.png)


## 三、Nginx 反向代理 kubesphere

### 1. 安装 nginx

```sh
[root@kubesphere ~]# yum -y install nginx nginx-all-modules
[root@kubesphere ~]# systemctl enable nginx --now
```

### 2. 配置代理

```sh
[root@kubesphere ~]# vim /etc/nginx/nginx.conf

# 在 http 段添加如下

map $http_upgrade $connection_upgrade {
default upgrade;
''      close;
}

upstream ks-console {
    server 192.168.1.194:30880 weight=1 max_fails=2 fail_timeout=30s;
}


[root@kubesphere ~]# vim /etc/nginx/conf.d/ks-console.conf

server {
    listen 80;
    server_name ks-console.linuxtian.top;
    access_log  /var/log/nginx/ks-console/access.log main;


      location / {
        proxy_redirect     off;
        proxy_set_header   Host             $host;
        proxy_set_header   X-Real-IP        $remote_addr;
        proxy_set_header   X-Forwarded-For  $proxy_add_x_forwarded_for;
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
        proxy_max_temp_file_size 0;
        proxy_connect_timeout      90;
        proxy_send_timeout         90;
        proxy_read_timeout         90;
        proxy_buffer_size          4k;
        proxy_buffers              4 32k;
        proxy_busy_buffers_size    64k;
        proxy_temp_file_write_size 64k;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_pass http://ks-console;
         }
}
```
