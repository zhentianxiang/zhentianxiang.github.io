---
layout: post
title: 2024-08-31-Kubernetes部署kubesphere
date: 2024-08-31
tags: 实战-Kubernetes
music-id: 19723756
---

## 一、Kubesphere 部署

### 1. k8s 环境基础环境

```sh
# 1. 清理就环境(可选)
[root@k8s-master01 ~]# kubeadm reset -f
[root@k8s-master01 ~]# rm -rf /etc/kubernetes/ $HOME/.kube/config /var/lib/etcd /var/lib/kubelet /var/lib/dockershim /var/run/kubernetes /var/lib/cni /etc/cni/net.d

# 2. 初始化集群
[root@k8s-master01 k8s]# vim kubeadm-init.conf 

# --- https://v1-17.docs.kubernetes.io/zh/docs/setup/production-environment/tools/kubeadm/control-plane-flags/
# --- kubeadm config print init-defaults --component-configs KubeProxyConfiguration
# --- kubeadm config view
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 0.0.0.0
  bindPort: 6443
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: v1.23.0
controlPlaneEndpoint: "172.16.246.22:6443"
imageRepository: "registry.cn-hangzhou.aliyuncs.com/google_containers"
networking:
  dnsDomain: cluster.local
  podSubnet: 192.18.0.0/16
  serviceSubnet: 10.96.0.0/12

scheduler:
  extraArgs:
    bind-address: "0.0.0.0"
    feature-gates: "ExpandCSIVolumes=true,CSIStorageCapacity=true,RotateKubeletServerCertificate=true,TTLAfterFinished=true"

controllerManager:
  extraArgs:
    bind-address: "0.0.0.0"
  extraArgs:
    feature-gates: "ExpandCSIVolumes=true,CSIStorageCapacity=true,RotateKubeletServerCertificate=true,TTLAfterFinished=true"

apiServer:
  extraArgs:
    feature-gates: "ExpandCSIVolumes=true,CSIStorageCapacity=true,RotateKubeletServerCertificate=true,TTLAfterFinished=true"
    enable-aggregator-routing: "true"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs

[root@k8s-master01 k8s]# kubeadm init --config=kubeadm-init.conf

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join 172.16.246.22:6443 --token llzs49.gulp6f68qpwzwtyg \
	--discovery-token-ca-cert-hash sha256:8e512a033032151a34fe8e7e6ffc657d62585dfff1336b1cac6a364e98380210 \
	--control-plane 

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.16.246.22:6443 --token llzs49.gulp6f68qpwzwtyg \
	--discovery-token-ca-cert-hash sha256:8e512a033032151a34fe8e7e6ffc657d62585dfff1336b1cac6a364e98380210

# 切换到 node 节点初始化加入集群
[root@k8s-node01 ~]# kubeadm join 172.16.246.22:6443 --token llzs49.gulp6f68qpwzwtyg \
	--discovery-token-ca-cert-hash sha256:8e512a033032151a34fe8e7e6ffc657d62585dfff1336b1cac6a364e98380210

# 3. 部署 calico 和 ingress 插件
[root@k8s-master01 k8s]# kubectl apply -f calico-v3.23.5.yaml
[root@k8s-master01 k8s]# kubectl apply -f ingress-nginx-v1.5.1.yaml
[root@k8s-master01 k8s]# kubectl label node k8s-node01 ingress/type=nginx
[root@k8s-master01 k8s]# kubectl get node
NAME           STATUS   ROLES                  AGE    VERSION
k8s-master01   Ready    control-plane,master   3m1s   v1.23.0
k8s-node01     Ready    <none>                 87s    v1.23.0
[root@k8s-master01 k8s]# kubectl get pods -A
NAMESPACE       NAME                                       READY   STATUS      RESTARTS   AGE
ingress-nginx   ingress-nginx-admission-create-qp95d       0/1     Completed   0          47s
ingress-nginx   ingress-nginx-admission-patch-f2gb8        0/1     Completed   1          47s
ingress-nginx   ingress-nginx-controller-snwrn             0/1     Running     0          18s
kube-system     calico-kube-controllers-84985dc8d9-qg9qc   1/1     Running     0          53s
kube-system     calico-node-55vkd                          1/1     Running     0          53s
kube-system     calico-node-ddz2k                          1/1     Running     0          53s
kube-system     coredns-65c54cc984-8lc5t                   1/1     Running     0          2m46s
kube-system     coredns-65c54cc984-tm5x7                   1/1     Running     0          2m46s
kube-system     etcd-k8s-master01                          1/1     Running     10         3m2s
kube-system     kube-apiserver-k8s-master01                1/1     Running     0          3m1s
kube-system     kube-controller-manager-k8s-master01       1/1     Running     0          3m1s
kube-system     kube-proxy-dbjfj                           1/1     Running     0          90s
kube-system     kube-proxy-kdfm9                           1/1     Running     0          2m47s
kube-system     kube-scheduler-k8s-master01                1/1     Running     0          3m1s

# 4. 部署 nfs-provisioner（前提需要你准备好 nfs 服务器）
[root@k8s-master01 nfs-storage]# kubectl apply -f .
storageclass.storage.k8s.io/nfs-provisioner-storage created
deployment.apps/nfs-provisioner created
clusterrole.rbac.authorization.k8s.io/nfs-provisioner-runner created
clusterrolebinding.rbac.authorization.k8s.io/run-nfs-provisioner created
role.rbac.authorization.k8s.io/leader-locking-nfs-provisioner created
rolebinding.rbac.authorization.k8s.io/leader-locking-nfs-provisioner created
serviceaccount/nfs-provisioner created
[root@k8s-master01 etcd-service]# kubectl get sc 
NAME                                PROVISIONER       RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
nfs-provisioner-storage (default)   example.com/nfs   Delete          Immediate           false                  3h19m
# k8s 1.20以后禁用了selfLink，需要在master节点的/etc/kubernetes/manifests/kube-apiserver.yaml 文件添加 - --feature-gates=RemoveSelfLink=false
[root@k8s-master01 nfs-storage]# vim /etc/kubernetes/manifests/kube-apiserver.yaml
[root@k8s-master01 nfs-storage]# mv /etc/kubernetes/manifests/kube-apiserver.yaml .
[root@k8s-master01 nfs-storage]# mv kube-apiserver.yaml /etc/kubernetes/manifests/
[root@k8s-master01 nfs-storage]# kubectl get cs
Warning: v1 ComponentStatus is deprecated in v1.19+
NAME                 STATUS    MESSAGE                         ERROR
controller-manager   Healthy   ok                              
scheduler            Healthy   ok                              
etcd-0               Healthy   {"health":"true","reason":""}
```

### 2. 准备部署 kubesphere

[官方文档]: https://kubesphere.io/zh/docs/v3.4/installing-on-kubernetes/on-prem-kubernetes/install-ks-on-linux-airgapped/

```sh
# 1. 执行以下命令下载这两个文件，并将它们传输至您充当任务机的机器
[root@k8s-master01 yaml]# curl -L -O https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/cluster-configuration.yaml
[root@k8s-master01 yaml]# curl -L -O https://github.com/kubesphere/ks-installer/releases/download/v3.4.1/kubesphere-installer.yaml

# 2. 添加自定义私有仓库地址(前提是已经把所需要的镜像都推送进去了)并且是否要启用插件可根据自己需求来开启
# 可以参考我的文件 https://fileserver.tianxiang.love/api/view?file=%2Fdata%2Fzhentianxiang%2FKubernetes-yaml%E8%B5%84%E6%BA%90%E6%96%87%E4%BB%B6%2Fkubesphere-v3.4.1%2Fcluster-configuration.yaml
[root@k8s-master01 yaml]# vim cluster-configuration.yaml
spec:
  persistence:
    storageClass: ""
  authentication:
    jwtSecret: ""
  local_registry: dockerhub.kubekey.local # Add this line manually; make sure you use your own registry address.

# 3. 将 ks-installer 替换为您自己仓库的地址
[root@k8s-master01 yaml]# sed -i "s#^\s*image: kubesphere.*/ks-installer:.*#        image: dockerhub.kubekey.local/kubesphere/ks-installer:v3.4.0#" kubesphere-installer.yaml

# 4. 开始安装
[root@k8s-master01 yaml]# kubectl apply -f kubesphere-installer.yaml
[root@k8s-master01 yaml]# kubectl apply -f cluster-configuration.yaml

# 5. 第一次安装过程较长，如果像我一样把镜像事先下载并推送到私有仓库中则会快一些
[root@k8s-node01 ~]# kubectl -n kubesphere-system logs -l app=ks-installer -f

# 6. 最后执行完
[root@k8s-master01 kubeSphere-3.3.2]# kubectl -n kubesphere-system logs -l app=ks-installer -f
Waiting for all tasks to be completed ...
task alerting status is successful  (1/10)
task network status is successful  (2/10)
task edgeruntime status is successful  (3/10)
task auditing status is successful  (4/10)
task servicemesh status is successful  (5/10)
task logging status is successful  (6/10)
task multicluster status is successful  (7/10)
task openpitrix status is successful  (8/10)
task events status is successful  (9/10)
task monitoring status is successful  (10/10)
**************************************************
Collecting installation results ...
#####################################################
###              Welcome to KubeSphere!           ###
#####################################################

Console: http://172.16.246.22:30880
Account: admin
Password: P@88w0rd
NOTES：
  1. After you log into the console, please check the
     monitoring status of service components in
     "Cluster Management". If any service is not
     ready, please wait patiently until all components 
     are up and running.
  2. Please change the default password after login.

#####################################################
https://kubesphere.io             2024-08-31 13:12:19
#####################################################
```

### 3. 检查所有服务

```sh
[root@k8s-master01 kubeSphere-3.3.2]# kubectl get pods -A
NAMESPACE                      NAME                                                      READY   STATUS      RESTARTS      AGE
argocd                         devops-argocd-application-controller-0                    1/1     Running     0             6m12s
argocd                         devops-argocd-applicationset-controller-b94f7f48b-76pq4   1/1     Running     0             6m12s
argocd                         devops-argocd-dex-server-69c4699948-f4wvn                 1/1     Running     0             6m12s
argocd                         devops-argocd-notifications-controller-5f5fdcf88b-hk2zv   1/1     Running     0             6m12s
argocd                         devops-argocd-redis-6d59666fb-zd4bn                       1/1     Running     0             6m12s
argocd                         devops-argocd-repo-server-858957875b-sj9vb                1/1     Running     0             6m12s
argocd                         devops-argocd-server-6fdb4ff7b-wgrm5                      1/1     Running     0             6m12s
ingress-nginx                  ingress-nginx-admission-create-xfzdb                      0/1     Completed   0             15m
ingress-nginx                  ingress-nginx-admission-patch-t6hwd                       0/1     Completed   1             15m
ingress-nginx                  ingress-nginx-controller-4k6jr                            1/1     Running     0             15m
ingress-nginx                  ingress-nginx-controller-sdxg6                            1/1     Running     0             14m
istio-system                   istiod-1-11-2-779879df54-s9vqs                            1/1     Running     0             6m21s
istio-system                   jaeger-collector-999c7688b-j48tt                          1/1     Running     0             5m55s
istio-system                   jaeger-operator-74c49b5b59-lkj9j                          1/1     Running     0             6m8s
istio-system                   jaeger-query-55779db56c-m52m8                             2/2     Running     0             5m48s
istio-system                   kiali-7c7bf74c6f-g7h5c                                    1/1     Running     0             5m31s
istio-system                   kiali-operator-79ccb7f57b-2wmcb                           1/1     Running     0             5m59s
kube-system                    calico-kube-controllers-84985dc8d9-dkxt2                  1/1     Running     0             15m
kube-system                    calico-node-hzwlj                                         1/1     Running     0             15m
kube-system                    calico-node-qmr2f                                         1/1     Running     0             15m
kube-system                    coredns-65c54cc984-7fl5k                                  1/1     Running     0             16m
kube-system                    coredns-65c54cc984-ggmrp                                  1/1     Running     0             16m
kube-system                    etcd-k8s-master01                                         1/1     Running     12            17m
kube-system                    kube-apiserver-k8s-master01                               1/1     Running     0             13m
kube-system                    kube-controller-manager-k8s-master01                      1/1     Running     1 (13m ago)   17m
kube-system                    kube-proxy-4fp4v                                          1/1     Running     0             16m
kube-system                    kube-proxy-cf9fd                                          1/1     Running     0             16m
kube-system                    kube-scheduler-k8s-master01                               1/1     Running     4 (13m ago)   17m
kube-system                    metrics-server-7784d5bc66-rrl7p                           1/1     Running     0             11m
kube-system                    nfs-provisioner-7774ffdc76-dbf8p                          1/1     Running     0             14m
kube-system                    snapshot-controller-0                                     1/1     Running     0             10m
kubeedge                       cloud-iptables-manager-bqcqq                              1/1     Running     0             6m20s
kubeedge                       cloud-iptables-manager-cj5kn                              1/1     Running     0             6m20s
kubeedge                       cloudcore-85fbd49786-h7fn5                                1/1     Running     0             9s
kubeedge                       edgeservice-5796856796-g9j6q                              1/1     Running     0             6m20s
kubesphere-controls-system     default-http-backend-7f96d5bd49-2x5tk                     1/1     Running     0             8m9s
kubesphere-controls-system     kubectl-admin-78fb746969-n5hvl                            1/1     Running     0             3m57s
kubesphere-devops-system       devops-apiserver-86454579c4-pjcm5                         1/1     Running     0             6m7s
kubesphere-devops-system       devops-controller-5674bfb78-9828h                         1/1     Running     0             6m7s
kubesphere-devops-system       devops-jenkins-54b66fdcd8-grvzl                           1/1     Running     0             6m7s
kubesphere-devops-system       s2ioperator-0                                             1/1     Running     0             6m7s
kubesphere-logging-system      elasticsearch-logging-data-0                              1/1     Running     0             9m57s
kubesphere-logging-system      elasticsearch-logging-data-1                              1/1     Running     0             9m5s
kubesphere-logging-system      elasticsearch-logging-discovery-0                         1/1     Running     0             9m57s
kubesphere-logging-system      fluent-bit-2wnbd                                          1/1     Running     0             9m41s
kubesphere-logging-system      fluent-bit-86k9f                                          1/1     Running     0             9m41s
kubesphere-logging-system      fluentbit-operator-7d47bdbd7f-xvj84                       1/1     Running     0             9m46s
kubesphere-logging-system      ks-events-exporter-557875446b-fn96d                       2/2     Running     0             6m24s
kubesphere-logging-system      ks-events-operator-5fc5d5b9f8-z6rtf                       1/1     Running     0             6m30s
kubesphere-logging-system      ks-events-ruler-7d6ccbf96f-q6g22                          2/2     Running     0             6m24s
kubesphere-logging-system      ks-events-ruler-7d6ccbf96f-xpk9z                          2/2     Running     0             6m24s
kubesphere-logging-system      kube-auditing-operator-5d888f885-6xxbm                    1/1     Running     0             6m55s
kubesphere-logging-system      kube-auditing-webhook-deploy-7db44576b6-jpn46             1/1     Running     0             6m52s
kubesphere-logging-system      kube-auditing-webhook-deploy-7db44576b6-sdr79             1/1     Running     0             6m52s
kubesphere-logging-system      logsidecar-injector-deploy-8476f9c759-bf5tl               2/2     Running     0             6m26s
kubesphere-logging-system      logsidecar-injector-deploy-8476f9c759-mbqgm               2/2     Running     0             6m26s
kubesphere-monitoring-system   alertmanager-main-0                                       2/2     Running     0             5m20s
kubesphere-monitoring-system   kube-state-metrics-677c6b87f7-tbnsw                       3/3     Running     0             5m24s
kubesphere-monitoring-system   node-exporter-62c8b                                       2/2     Running     0             5m24s
kubesphere-monitoring-system   node-exporter-6mzjw                                       2/2     Running     0             5m24s
kubesphere-monitoring-system   notification-manager-deployment-7d68c9bf4b-vz8zt          2/2     Running     0             4m58s
kubesphere-monitoring-system   notification-manager-operator-6b4b765b-j5chx              2/2     Running     0             5m8s
kubesphere-monitoring-system   prometheus-k8s-0                                          2/2     Running     0             5m19s
kubesphere-monitoring-system   prometheus-operator-7dd8455bd4-4h442                      2/2     Running     0             5m24s
kubesphere-monitoring-system   thanos-ruler-kubesphere-0                                 2/2     Running     0             5m1s
kubesphere-system              ks-apiserver-7874867959-96mpt                             1/1     Running     0             2m26s
kubesphere-system              ks-console-b795cddc6-wxtsx                                1/1     Running     0             2m26s
kubesphere-system              ks-controller-manager-78fdfcfc5b-6g9t6                    1/1     Running     0             2m26s
kubesphere-system              ks-installer-6dcfdff9dc-xjfdt                             1/1     Running     0             2m26s
kubesphere-system              minio-6bfd485f8f-v8l76                                    1/1     Running     0             2m26s
kubesphere-system              openldap-0                                                1/1     Running     1 (10m ago)   10m
kubesphere-system              openpitrix-import-job-qwpk5                               0/1     Completed   0             7m15s
kubesphere-system              redis-5f5579b997-f2l2x                                    1/1     Running     0             2m26s
weave                          weave-scope-agent-2dg5b                                   1/1     Running     0             7m25s
weave                          weave-scope-agent-csjzt                                   1/1     Running     0             7m25s
weave                          weave-scope-app-7ff666b9d-kzk8x                           1/1     Running     0             7m25s
weave                          weave-scope-cluster-agent-7b9d965499-rngq7                1/1     Running     0             7m25s
```

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/1.png)

## 二、集成外部 Prometheus 监控

### 1. 注意事项

KubeSphere 3.4.1 已经过认证，可以与以下 Prometheus 堆栈组件搭配使用：

- Prometheus Operator **v0.55.1+**
- Prometheus **v2.34.0+**
- Alertmanager **v0.23.0+**
- kube-state-metrics **v2.5.0**
- node-exporter **v1.3.1**

请确保您的 Prometheus 堆栈组件版本符合上述版本要求，尤其是 **node-exporter** 和 **kube-state-metrics**。

如果只安装了 **Prometheus Operator** 和 **Prometheus**，请您务必安装 **node-exporter** 和 **kube-state-metrics**。**node-exporter** 和 **kube-state-metrics** 是 KubeSphere 正常运行的必要条件。

### 2. 卸载 KubeSphere 的自定义 Prometheus 堆栈

```sh
kubectl -n kubesphere-system exec $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -- kubectl delete -f /kubesphere/kubesphere/prometheus/alertmanager/ 2>/dev/null
kubectl -n kubesphere-system exec $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -- kubectl delete -f /kubesphere/kubesphere/prometheus/devops/ 2>/dev/null
kubectl -n kubesphere-system exec $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -- kubectl delete -f /kubesphere/kubesphere/prometheus/etcd/ 2>/dev/null
kubectl -n kubesphere-system exec $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -- kubectl delete -f /kubesphere/kubesphere/prometheus/grafana/ 2>/dev/null
kubectl -n kubesphere-system exec $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -- kubectl delete -f /kubesphere/kubesphere/prometheus/kube-state-metrics/ 2>/dev/null
kubectl -n kubesphere-system exec $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -- kubectl delete -f /kubesphere/kubesphere/prometheus/node-exporter/ 2>/dev/null
kubectl -n kubesphere-system exec $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -- kubectl delete -f /kubesphere/kubesphere/prometheus/upgrade/ 2>/dev/null
kubectl -n kubesphere-system exec $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -- kubectl delete -f /kubesphere/kubesphere/prometheus/prometheus-rules-v1.16\+.yaml 2>/dev/null
kubectl -n kubesphere-system exec $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -- kubectl delete -f /kubesphere/kubesphere/prometheus/prometheus-rules.yaml 2>/dev/null
kubectl -n kubesphere-system exec $(kubectl get pod -n kubesphere-system -l app=ks-installer -o jsonpath='{.items[0].metadata.name}') -- kubectl delete -f /kubesphere/kubesphere/prometheus/prometheus 2>/dev/null
kubectl delete deploy -n  kubesphere-monitoring-system prometheus-operator
kubectl delete svc -n kubesphere-monitoring-system prometheus-operator
kubectl delete prometheusrules.monitoring.coreos.com -n kubesphere-monitoring-system  prometheus-operator-rules  prometheus-k8s-rules
kubectl delete servicemonitor -n kubesphere-monitoring-system coredns kube-apiserver  kube-controller-manager  kube-scheduler kubelet prometheus-operator
```

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/2.png)

### 3. 安装 kube-prometheus

```sh
# 1. 下载文件
[root@k8s-master01 app]# https://github.com/prometheus-operator/kube-prometheus/tree/release-0.10
[root@k8s-master01 app]# tar xvf v0.10.0.tar.gz
# 2. 修改 grafana 时区
[root@k8s-master01 kube-prometheus-0.10.0]# grep -i timezone manifests/grafana-dashboardDefinitions.yaml
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "browser",
          "timezone": "utc",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
          "timezone": "UTC",
[root@k8s-master01 kube-prometheus-0.10.0]# sed -i 's/UTC/UTC+8/g' manifests/grafana-dashboardDefinitions.yaml
[root@k8s-master01 kube-prometheus-0.10.0]# sed -i 's/utc/utc+8/g' manifests/grafana-dashboardDefinitions.yaml

# 3. 修改 grafana 的变量
[root@k8s-master01 kube-prometheus-0.10.0]# vim manifests/grafana-deployment.yaml
 30       containers:
 31       - image: grafana/grafana:8.3.3
 32         name: grafana
 33         env:
 34         - name: GF_SECURITY_ADMIN_USER
 35           value: "admin"
 36         - name: GF_SECURITY_ADMIN_PASSWORD
 37           value: "password123"
# 4. 修改 grafana 的数据存储卷
 52         volumeMounts:
 53         - mountPath: /var/lib/grafana
 54           name: grafana-storage
 55           readOnly: false
141       volumes:
142       - name: grafana-storage
143         persistentVolumeClaim:
144           claimName: grafana-storage
# 5. 新建 grafana pvc
[root@k8s-master01 kube-prometheus-0.10.0]# vim manifests/grafana-storage.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-storage
  namespace: monitoring
spec:
  storageClassName: nfs-provisioner-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 50G
# 6. 正式安装
[root@k8s-master01 kube-prometheus-0.10.0]# kubectl apply --server-side -f manifests/setup
[root@k8s-master01 kube-prometheus-0.10.0]# kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace=monitoring
[root@k8s-master01 kube-prometheus-0.10.0]# kubectl apply -f manifests/
# 解读
# manifests/setup/目录下是创建monitoring命名空间和创建自定义资源CRD的yaml资源清单文件
# manifests/目录下有大量的yaml文件，这些文件就是用于创建prometheus组件的，如sts/deloyment/servicemonitors/svc/alertmanagers/prometheusrules等待资源文件
# --server-side选项告诉Kubernetes在服务器端执行操作,而不是在客户端,通常用于确保集群状态与配置文件一致
# kubectl wait 命令等待所有CustomResourceDefinition资源在指定的monitoring命名空间中达到Established状态
# 里面的镜像大多数需要爬梯子，docker.hub.com 里面也有对应的版本，大家可以去看一下 bitnami
```

### 4. 检查启动情况

```sh
[root@k8s-master01 kube-prometheus-0.10.0]# kubectl get pods -n monitoring -o wide
NAME                                   READY   STATUS    RESTARTS   AGE    IP              NODE           NOMINATED NODE   READINESS GATES
alertmanager-main-0                    2/2     Running   0          93s    192.18.32.177   k8s-master01   <none>           <none>
alertmanager-main-1                    2/2     Running   0          93s    192.18.85.237   k8s-node01     <none>           <none>
alertmanager-main-2                    2/2     Running   0          93s    192.18.32.178   k8s-master01   <none>           <none>
blackbox-exporter-6b79c4588b-zrpsg     3/3     Running   0          2m7s   192.18.85.232   k8s-node01     <none>           <none>
grafana-5d6d7b8686-zm4vx               1/1     Running   0          2m6s   192.18.85.236   k8s-node01     <none>           <none>
kube-state-metrics-55f67795cd-2gtn5    3/3     Running   0          59s    192.18.32.180   k8s-master01   <none>           <none>
node-exporter-52q5l                    2/2     Running   0          2m4s   172.16.246.22   k8s-master01   <none>           <none>
node-exporter-kbrfn                    2/2     Running   0          2m4s   172.16.246.23   k8s-node01     <none>           <none>
prometheus-adapter-85664b6b74-7mbpx    1/1     Running   0          2m4s   192.18.32.175   k8s-master01   <none>           <none>
prometheus-adapter-85664b6b74-x6p9n    1/1     Running   0          2m4s   192.18.85.234   k8s-node01     <none>           <none>
prometheus-k8s-0                       2/2     Running   0          92s    192.18.32.179   k8s-master01   <none>           <none>
prometheus-k8s-1                       2/2     Running   0          91s    192.18.85.238   k8s-node01     <none>           <none>
prometheus-operator-6dc9f66cb7-57vmb   2/2     Running   0          2m4s   192.18.85.235   k8s-node01     <none>           <none>
```

### 5. 修改 svc 类型

```sh
[root@k8s-master01 kube-prometheus-0.10.0]# kubectl get svc -n monitoring prometheus-k8s -o yaml |sed "s/type: ClusterIP/type: NodePort/g" |kubectl replace -f -
[root@k8s-master01 kube-prometheus-0.10.0]# kubectl get svc -n monitoring grafana -o yaml |sed "s/type: ClusterIP/type: NodePort/g" |kubectl replace -f -
[root@k8s-master01 kube-prometheus-0.10.0]# kubectl get svc -n monitoring alertmanager-main -o yaml |sed "s/type: ClusterIP/type: NodePort/g" |kubectl replace -f -
[root@k8s-master01 kube-prometheus-0.10.0]# kubectl get svc -n monitoring 
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                         AGE
alertmanager-main       NodePort    10.101.61.68     <none>        9093:31941/TCP,8080:31251/TCP   6m7s
alertmanager-operated   ClusterIP   None             <none>        9093/TCP,9094/TCP,9094/UDP      5m33s
blackbox-exporter       ClusterIP   10.110.29.98     <none>        9115/TCP,19115/TCP              6m7s
grafana                 NodePort    10.98.82.127     <none>        3000:32734/TCP                  6m6s
kube-state-metrics      ClusterIP   None             <none>        8443/TCP,9443/TCP               6m4s
node-exporter           ClusterIP   None             <none>        9100/TCP                        6m4s
prometheus-adapter      ClusterIP   10.107.15.118    <none>        443/TCP                         6m4s
prometheus-k8s          NodePort    10.111.203.178   <none>        9090:30070/TCP,8080:32611/TCP   6m4s
prometheus-operated     ClusterIP   None             <none>        9090/TCP                        5m32s
prometheus-operator     ClusterIP   None             <none>        8443/TCP                        6m4s
```

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/3.png)

此时发现有个服务报红色，原因是连接不上，查看发现端口监听地址位本地回环

```sh
[root@k8s-master01 kube-prometheus-0.10.0]# netstat -lntp |grep 10257
tcp        0      0 127.0.0.1:10257         0.0.0.0:*               LISTEN      6689/kube-controlle
[root@k8s-master01 kube-prometheus-0.10.0]# vim /etc/kubernetes/manifests/kube-controller-manager.yaml 

apiVersion: v1
kind: Pod
metadata:
  creationTimestamp: null
  labels:
    component: kube-controller-manager
    tier: control-plane
  name: kube-controller-manager
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-controller-manager
    - --allocate-node-cidrs=true
    - --authentication-kubeconfig=/etc/kubernetes/controller-manager.conf
    - --authorization-kubeconfig=/etc/kubernetes/controller-manager.conf
    - --bind-address=0.0.0.0  # 修改为0.0.0.0
    
[root@k8s-master01 kube-prometheus-0.10.0]# mv /etc/kubernetes/manifests/kube-controller-manager.yaml .
[root@k8s-master01 kube-prometheus-0.10.0]# mv kube-controller-manager.yaml /etc/kubernetes/manifests/
[root@k8s-master01 kube-prometheus-0.10.0]# netstat -lntp |grep kube-controll
tcp6       0      0 :::10257                :::*                    LISTEN      15226/kube-controll
```

### 6. 配置ETCD监控

对于外置的 etcd 集群，或者以静态 pod 方式启动的 etcd 集群，都不会在 k8s 里创建 service，而 Prometheus 需要根据 service + endpoint 来抓取，因此需要手动创建

> 注意：将 endpoint 中的 IP 替换为真实 IP

```sh
# 1. 创建 service
[root@k8s-master01 etcd-service]# cat > etcd-svc-ep.yaml << EOF
apiVersion: v1
kind: Endpoints
metadata:
  labels:
    app: etcd-prom
  name: etcd-prom
  namespace: kube-system
subsets:
- addresses:
  # etcd 节点 ip，如果有多个可以继续在下面加
  - ip: 172.16.246.22
  ports:
  - name: https-metrics
    port: 2379 # etcd 端口
    protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: etcd-prom
  name: etcd-prom
  namespace: kube-system
spec:
  ports:
  # 记住这个 port-name，后续会用到
  - name: http-metrics
    port: 2379
    protocol: TCP
    targetPort: 2379
  type: ClusterIP
EOF
[root@k8s-master01 etcd-service]# kubectl get svc -n kube-system |grep etcd
etcd-prom                     ClusterIP   10.96.166.56    <none>        2379/TCP                       29s
[root@k8s-master01 etcd-service]# kubectl get endpoints -n kube-system |grep etcd
etcd-prom                     172.16.246.22:2379                                                        33s

# 2. 创建 secret 存储证书
[root@k8s-master01 etcd-service]# kubectl -n monitoring create secret generic kube-etcd-client-certs  \
--from-file=etcd-client-ca.crt=/etc/kubernetes/pki/etcd/ca.crt  \
--from-file=etcd-client.crt=/etc/kubernetes/pki/etcd/healthcheck-client.crt  \
--from-file=etcd-client.key=/etc/kubernetes/pki/etcd/healthcheck-client.key

# 3. 挂载证书到 prometheus 中，53 54 行就是新加的内容
[root@k8s-master01 etcd-service]# kubectl -n monitoring edit prometheus k8s
     49     requests:
     50       memory: 400Mi
     51   ruleNamespaceSelector: {}
     52   ruleSelector: {}
     53   secrets:
     54   - kube-etcd-client-certs
     55   securityContext:
     56     fsGroup: 2000
     57     runAsNonRoot: true
     58     runAsUser: 1000
     59   serviceAccountName: prometheus-k8s
     60   serviceMonitorNamespaceSelector: {}
     61   serviceMonitorSelector: {}
     62   version: 2.32.1

# 4. 检查发现自动重启了，并且已经挂载进去了
[root@k8s-master01 etcd-service]# kubectl -n monitoring get pod  -l app.kubernetes.io/name=prometheus
NAME               READY   STATUS    RESTARTS   AGE
prometheus-k8s-0   2/2     Running   0          53s
prometheus-k8s-1   2/2     Running   0          69s
[root@k8s-master01 etcd-service]# kubectl exec -it -n monitoring prometheus-k8s-0 -- ls /etc/prometheus/secrets/kube-etcd-client-certs
etcd-client-ca.crt  etcd-client.crt     etcd-client.key

# 5. 接下来则是创建一个 ServiceMonitor 对象，让 Prometheus 去采集 etcd 的指标
[root@k8s-master01 etcd-service]# cat > etcd-sm.yaml  <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: kube-etcd
  namespace: monitoring
  labels:
    app: etcd
spec:
  jobLabel: k8s-app
  endpoints:
    - interval: 30s
      port: http-metrics #这个 port 对应 etcd-svc 的 spec.ports.name
      scheme: https
      tlsConfig:
        caFile: /etc/prometheus/secrets/kube-etcd-client-certs/etcd-client-ca.crt
        certFile: /etc/prometheus/secrets/kube-etcd-client-certs/etcd-client.crt
        keyFile: /etc/prometheus/secrets/kube-etcd-client-certs/etcd-client.key
        insecureSkipVerify: true # 关闭证书校验
  selector:
    matchLabels:
      app: etcd-prom # 跟 etcd-svc 的 lables 保持一致
  namespaceSelector:
    matchNames:
    - kube-system
EOF

[root@k8s-master01 etcd-service]# kubectl apply -f etcd-sm.yaml
```

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/4.png)

### 7. 修改 promtheus 与 kubesphere 配置

```sh
# 1. 将 Prometheus 规则评估间隔设置为 1m，与 KubeSphere 3.3.0 的自定义 ServiceMonitor 保持一致。规则评估间隔应大于或等于抓取间隔
[root@k8s-master01 ~]# kubectl -n monitoring patch prometheus k8s --patch '{
  "spec": {
    "evaluationInterval": "1m"
  }
}' --type=merge

# 2. 将 monitoring endpoint 更改为您自己的 Prometheus
[root@k8s-master01 ~]# kubectl edit cm -n kubesphere-system kubesphere-config
     69     monitoring:
     70       endpoint: http://prometheus-operated.monitoring.svc:9090
[root@k8s-master01 ~]# kubectl edit cm -n kubesphere-system kubesphere-config
     90     alerting:
     91       prometheusEndpoint: http://prometheus-operated.monitoring.svc:9090
# 3. 修改 cc 时期集群重启后也能正常使用，否则只修改上面集群重启后会恢复原样
[root@k8s-master01 ~]# kubectl edit cc -n kubesphere-system ks-installer
     49     monitoring:
     50       GPUMonitoring:
     51         enabled: false
     52       endpoint: http://prometheus-operated.monitoring.svc:9090
      
# 4. 重启 KubeSphere APIserver
[root@k8s-master01 ~]# kubectl rollout restart  deploy -n kubesphere-system ks-apiserver
```

此时页面上已经能够显示监控到的数据了，但是还是有一些问题

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/5.png)

```sh
# 6. 修改prometheusrules.monitoring.coreos.com，因为很多指标都是通过record来计算获取
[root@k8s-master01 kubeSphere-3.3.2]# wget https://raw.githubusercontent.com/kubesphere/ks-installer/master/roles/ks-monitor/files/prometheus/kubernetes/kubernetes-prometheusRule.yaml
[root@k8s-master01 kubeSphere-3.3.2]# vim kubernetes-prometheusRule.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    app.kubernetes.io/name: kube-prometheus
    app.kubernetes.io/part-of: kube-prometheus
    prometheus: k8s
    role: alert-rules
  name: prometheus-k8s-rules
  namespace: monitoring    # 修改 namespace
[root@k8s-master01 kubeSphere-3.3.2]# kubectl apply -f kubernetes-prometheusRule.yaml

# 7. 修改添加 ruleSelector 字段来通过 label 筛选告警规则
[root@k8s-master01 kubeSphere-3.3.2]# kubectl -n monitoring edit prometheus k8s 
     53   ruleSelector:
     54     matchLabels:
     55       prometheus: k8s
     56       role: alert-rules
# 8. 重启服务
[root@k8s-master01 kubeSphere-3.3.2]# kubectl rollout restart statefulset -n monitoring prometheus-k8s
```

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/6.png)

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/7.png)

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/8.png)

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/9.png)

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/10.png)

## 三、使用 helm 部署 kube-prometheus-stack

如果使用上面的 Prometheus 最后 kubesphere 面板内存显示有问题的话，可以尝试使用这个

参考[2024-10-29-kubernetes-Helm部署Prometheus集群]()

### 1. 集成 kubesphere

```sg
# 1. 将 Prometheus 规则评估间隔设置为 1m，与 KubeSphere 3.3.0 的自定义 ServiceMonitor 保持一致。规则评估间隔应大于或等于抓取间隔。
[root@k8s-master01 kube-prometheus-stack]# kubectl -n monitoring patch prometheuses.monitoring.coreos.com kube-prometheus-stack-prometheus --patch '{
  "spec": {
    "evaluationInterval": "1m"
  }
}' --type=merge

```

```sh
# 2. 将 monitoring endpoint 更改为您自己的 Prometheus
[root@k8s-master01 kube-prometheus-stack]# kubectl edit cm -n kubesphere-system kubesphere-config      #集群重启后会失效
    monitoring:
      endpoint: http://kube-prometheus-stack-prometheus.monitoring.svc:9090

[root@k8s-master01 kube-prometheus-stack]# kubectl edit cc -n kubesphere-system ks-installer          #集群重启后不会失效
    monitoring:
      endpoint: http://kube-prometheus-stack-prometheus.monitoring.svc:9090

```

```sh
# 3. 运行以下命令，重启 KubeSphere APIserver
[root@k8s-master01 kube-prometheus-stack]# kubectl rollout restart deploy -n kubesphere-system ks-apiserver ks-installer
```

```sh
# 4 . kubesphere的dashboard的图表出不来，记来要修改prometheusrules.monitoring.coreos.com，因为很多指标都是通过record来计算获取
# 获取kube-promethues-stack与promethesrules和servicemonitor的关联label
# 注意：helm 部署的和 yaml 部署 label 的 key value 值可能不一样
[root@k8s-master01 kube-prometheus-stack]# kubectl get prometheus -n monitoring kube-prometheus-stack-prometheus  -o yaml
...........................................
  labels:
    release: kube-prometheus-stack       # 使用此 label 与 promethes 资源 关联
...........................................
  ruleSelector:
    matchLabels:
      release: kube-prometheus-stack     # 使用此 label 与 promethesrules 关联
...........................................
  serviceMonitorSelector:
    matchLabels:
      release: kube-prometheus-stack     # 使用此 label 与 servicemonitor 关联

```

```sh
# 5. 下载kubernetes-prometheusRule.yaml，此与apiserver指标有关
[root@k8s-master01 kube-prometheus-stack]# wget https://raw.githubusercontent.com/kubesphere/ks-installer/master/roles/ks-monitor/files/prometheus/kubernetes/kubernetes-prometheusRule.yaml
```

```sh
# 6. 修改kubernetes-prometheusRule.yaml
[root@k8s-master01 kube-prometheus-stack]# vim kubernetes-prometheusRule.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  labels:
    app.kubernetes.io/name: kube-prometheus
    app.kubernetes.io/part-of: kube-prometheus
    prometheus: k8s
    role: alert-rules
    release: kube-prometheus-stack  # 把上面你看到那个 label 添加进去就行，目的就是 Prometheus 通过相同的 label 来发现 monitoring
  name: prometheus-k8s-rules
  namespace: monitoring  # 修改为 monitoring 命名空间
```

```sh
# 7. 应用 kubernetes-prometheusRule.yaml kubesphere 需要这个里面提供的监控规则
[root@k8s-master01 kube-prometheus-stack]# kubectl apply -f kubernetes-prometheusRule.yaml
```

```sh
# 8.  kube-prometheus-stack-node.rules 会与 kubernetes-prometheusRule.yaml 中的 ’node_namespace_pod:kube_pod_info:'和node:node_num_cpu:sum 冲突
[root@k8s-master01 kube-prometheus-stack]# kubectl edit prometheusrules.monitoring.coreos.com -n monitoring kube-prometheus-stack-node.rules
#删除以下内容
    - expr: |-
        topk by(cluster, namespace, pod) (1,
          max by (cluster, node, namespace, pod) (
            label_replace(kube_pod_info{job="kube-state-metrics",node!=""}, "pod", "$1", "pod", "(.*)")
        ))
      record: 'node_namespace_pod:kube_pod_info:'
    - expr: |-
        count by (cluster, node) (sum by (node, cpu) (
          node_cpu_seconds_total{job="node-exporter"}
        * on (namespace, pod) group_left(node)
          topk by(namespace, pod) (1, node_namespace_pod:kube_pod_info:)
        ))
      record: node:node_num_cpu:sum
```

```sh
# 10. 最后重启一下所有服务
[root@k8s-master01 kube-prometheus-stack]# kubectl delete pods -n kubesphere-system --all
```

![](/images/posts/Kubesphere/2024-08-31-Kubernetes部署kubesphere/12.png)

## 四、常见问题

### 1. s2ioperator 证书失效问题

kubesphere 3.4.1 之前的版本会有问题

```sh
"Error from server (InternalError): Internal error occurred: failed calling webhook \"s2ibuildertemplate.kb.io\": failed to call webhook: Post \"https://webhook-server-service.kubesphere-devops-system.svc:443/validate-devops-kubesphere-io-v1alpha1-s2ibuildertemplate?timeout=10s\": x509: certificate has expired or is not yet valid: current time 2024-08-31T08:24:54Z is after 2024-02-14T06:08:48Z",
```

[**update-s2i-cert.sh**](https://github.com/kubesphere/ks-devops/releases/download/v3.4.1-231116/update-s2i-cert.tar.gz)

点击上面链接，下载更新 S2I 服务证书的压缩包，上传到任一可以访问 k8s 集群的节点，然后在此节点上执行下面三步：

1. 把上传的压缩包解压
2. 进入解压后的目录
3. 执行更新证书的脚本 **./update-s2i-cert.sh**

```sh
# 上传压缩包到可访问 k8s 集群的节点
...
# 解压缩
$ tar -zxvf update-s2i-cert.tar.gz
update-s2i-cert/
update-s2i-cert/config/
update-s2i-cert/config/certs/
update-s2i-cert/config/certs/server.crt
update-s2i-cert/config/certs/ca.crt
update-s2i-cert/config/certs/server.key
update-s2i-cert/update-s2i-cert.sh
 
# 执行更新证书脚本
$ cd update-s2i-cert
$ ./update-s2i-cert.sh
Update Secret: s2i-webhook-server-cert..
secret/s2i-webhook-server-cert patched
Update ValidatingWebhookConfiguration validating-webhook-configuration..
validatingwebhookconfiguration.admissionregistration.k8s.io/validating-webhook-configuration patched
Update MutatingWebhookConfiguration mutating-webhook-configuration..
mutatingwebhookconfiguration.admissionregistration.k8s.io/mutating-webhook-configuration patched
Restart s2ioperator server..
statefulset.apps/s2ioperator restarted
Done.
...
```

### 2.   ks-installer 控制器无法启动报错

安装了可插拔 Service Mesh 组件后又卸载导致重新安装 ks-installer 控制器无法启动报错

**报错日志：**

`kubectl -n kube-system logs -l app=component=kube-controller-manager -f `

`failed with Internal error occurred: failed calling webhook "rev.object.sidecar-injector.istio.io"`

**解决如下：**

```sh
$ kubectl get ValidatingWebhookConfiguration
$ kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io istio-validator-1-14-6-istio-system 
$ kubectl delete validatingwebhookconfigurations.admissionregistration.k8s.io istiod-default-validator
$ kubectl get MutatingWebhookConfiguration
$ kubectl delete mutatingwebhookconfigurations.admissionregistration.k8s.io istio-revision-tag-default istio-sidecar-injector-1-14-6
```

### 3. ks-controller 连接超时

安装过程中日志报错提示`Post \"https://ks-controller-manager.kubesphere-system.svc:443/validate-email-iam-kubesphere-io-v1alpha2?timeout=30`

**解决如下：**

```sh
$ kubectl edit validatingwebhookconfigurations users.iam.kubesphere.io
找到 failurePolicy 将Fail改为 Ignore 后重启 ks-installer ，待安装完成后再改回 Fail
```

### 4. 监控 ETCD 报错问题

安装过程中日志报错提示`The Endpoints \"etcd\" is invalid: \n* subsets[0].addresses[0].ip: Invalid value: \"localhost\": must be a valid IP address`

**解决如下：**

```sh
# 修改etcd的localhost地址为你的etcd所在节点的IP地址
# 如果有多个地址则使用“，”分割开，如：endpointIps: 172.16.246.22,172.16.246.23,172.16.246.24
$ kubectl edit cc ks-installer -n kubesphere-system

# 顺便一同把配置文件也修改了
$ vim cluster-configuration.yaml
  etcd:
    monitoring: true       # Enable or disable etcd monitoring dashboard installation. You have to create a Secret for etcd before you enable it.
    endpointIps: 172.16.246.22  # etcd cluster EndpointIps. It can be a bunch of IPs here.
    port: 2379              # etcd port.
    tlsEnable: true
```

### 5. 自定义监控面板报错

界面点击自定义监控面板提示：no matches for kind "ClusterDashboard" in version "monitoring.kubesphere.io/v1alpha2"

**解决如下：**

```sh
# 由于之前可能监控系统安装失败了，所以导致 CRD 资源注册有问题
$ kubectl rollout restart deployment -n kubesphere-system ks-apiserver

$ kubectl -n kubesphere-system logs -l app=ks-apiserver -f
```
