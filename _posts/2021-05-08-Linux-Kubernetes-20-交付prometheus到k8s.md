---
layout: post
title: Linux-Kubernetes-20-交付prometheus到k8s
date: 2021-05-08
tags: 实战-Kubernetes
---

## 部署Prometheus

### 准备Prometheus镜像

[官方地址](https://hub.docker.com/r/prom/prometheus)

```sh
[root@host0-200 blackbox-exporter]# docker pull prom/prometheus:v2.14.0
v2.14.0: Pulling from prom/prometheus
8e674ad76dce: Already exists 
e77d2419d1c2: Already exists 
8674123643f1: Pull complete 
21ee3b79b17a: Pull complete 
d9073bbe10c3: Pull complete 
585b5cbc27c1: Pull complete 
0b174c1d55cf: Pull complete 
a1b4e43b91a7: Pull complete 
31ccb7962a7c: Pull complete 
e247e238102a: Pull complete 
6798557a5ee4: Pull complete 
cbfcb065e0ae: Pull complete 
Digest: sha256:907e20b3b0f8b0a76a33c088fe9827e8edc180e874bd2173c27089eade63d8b8
Status: Downloaded newer image for prom/prometheus:v2.14.0
docker.io/prom/prometheus:v2.14.0
[root@host0-200 blackbox-exporter]# docker tag zhentianxiang/prometheus:v2.14.0 harbor.od.com/infra/prometheus:v2.14.0
[root@host0-200 blackbox-exporter]# docker push harbor.od.com/infra/prometheus:v2.14.0
The push refers to repository [harbor.od.com/public/prometheus]
fca78fb26e9b: Pushed 
ccf6f2fbceef: Pushed 
eb6f7e00328c: Pushed 
5da914e0fc1b: Pushed 
b202797fdad0: Pushed 
39dc7810e736: Pushed 
8a9fe881edcd: Pushed 
5dd8539686e4: Pushed 
5c8b7d3229bc: Pushed 
062d51f001d9: Pushed 
3163e6173fcc: Mounted from public/blackbox-exporter 
6194458b07fc: Mounted from public/blackbox-exporter 
v2.14.0: digest: sha256:3d53ce329b25cc0c1bfc4c03be0496022d81335942e9e0518ded6d50a5e6c638 size: 2824
```

### 准备资源配置清单

```sh
[root@host0-200 blackbox-exporter]# mkdir -pv /data/k8s-yaml/prometheus && cd /data/k8s-yaml/prometheus
```

- vim rbac.yaml

```sh
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/cluster-service: "true"
  name: prometheus
  namespace: infra
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/cluster-service: "true"
  name: prometheus
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs:
  - get
  - list
  - watch
- apiGroups:
  - ""
  resources:
  - configmaps
  verbs:
  - get
- nonResourceURLs:
  - /metrics
  verbs:
  - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/cluster-service: "true"
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: infra
```

- vim dp.yaml

```sh
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "5"
  labels:
    name: prometheus
  name: prometheus
  namespace: infra
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      app: prometheus
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: harbor.od.com/infra/prometheus:v2.14.0
        imagePullPolicy: IfNotPresent
        command:
        - /bin/prometheus
        args:
        - --config.file=/data/etc/prometheus.yml
        - --storage.tsdb.path=/data/prom-db
        - --storage.tsdb.min-block-duration=10m
        - --storage.tsdb.retention=72h
        - --web.enable-lifecycle
        ports:
        - containerPort: 9090
          protocol: TCP
        volumeMounts:
        - mountPath: /data
          name: data
        resources:  #限制容器的资源
          requests:
            cpu: "1000m"
            memory: "1.5Gi"
          limits:  #定义杀死，如果达到了这个值就杀死容器
            cpu: "2000m"
            memory: "3Gi"
      imagePullSecrets:
      - name: harbor
      securityContext:
        runAsUser: 0
      serviceAccountName: prometheus
      volumes:
      - name: data
        nfs:
          server: host0-200
          path: /data/nfs-volume/prometheus
```

- vim svc.yaml

```sh
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: infra
spec:
  ports:
  - port: 9090
    protocol: TCP
    targetPort: 9090
  selector:
    app: prometheus
```

- vim ingress.yaml

```sh
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: traefik
  name: prometheus
  namespace: infra
spec:
  rules:
  - host: prometheus.od.com
    http:
      paths:
      - path: /
        backend:
          serviceName: prometheus
          servicePort: 9090
```

### 准备Prometheus的配置文件

```sh
[root@host0-200 prometheus]# mkdir -pv /data/nfs-volume/prometheus/{etc,prom-db}
mkdir: 已创建目录 "/data/nfs-volume/prometheus"
mkdir: 已创建目录 "/data/nfs-volume/prometheus/etc"
mkdir: 已创建目录 "/data/nfs-volume/prometheus/prom-db"
[root@host0-200 prometheus]# cd /data/nfs-volume/prometheus/etc/
[root@host0-200 etc]# cp /opt/certs/ca.pem .
[root@host0-200 etc]# cp /opt/certs/client.pem .
[root@host0-200 etc]# cp /opt/certs/client-key.pem .
[root@host0-200 etc]# ls
ca.pem  client-key.pem  client.pem
[root@host0-200 etc]# vim prometheus.yml
```

```
global:
  scrape_interval:     15s
  evaluation_interval: 15s
scrape_configs:
- job_name: 'etcd'
  tls_config:
    ca_file: /data/etc/ca.pem
    cert_file: /data/etc/client.pem
    key_file: /data/etc/client-key.pem
  scheme: https
  static_configs:
  - targets:
    - '10.0.0.200:2379'
    - '10.0.0.21:2379'
    - '10.0.0.22:2379'
- job_name: 'kubernetes-apiservers'
  kubernetes_sd_configs:
  - role: endpoints
  scheme: https
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  relabel_configs:
  - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
    action: keep
    regex: default;kubernetes;https
- job_name: 'kubernetes-pods'
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
    action: keep
    regex: true
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
    action: replace
    target_label: __metrics_path__
    regex: (.+)
  - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
    action: replace
    regex: ([^:]+)(?::\d+)?;(\d+)
    replacement: $1:$2
    target_label: __address__
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    action: replace
    target_label: kubernetes_namespace
  - source_labels: [__meta_kubernetes_pod_name]
    action: replace
    target_label: kubernetes_pod_name
- job_name: 'kubernetes-kubelet'
  kubernetes_sd_configs:
  - role: node
  relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_node_label_(.+)
  - source_labels: [__meta_kubernetes_node_name]
    regex: (.+)
    target_label: __address__
    replacement: ${1}:10255
- job_name: 'kubernetes-cadvisor'
  kubernetes_sd_configs:
  - role: node
  relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_node_label_(.+)
  - source_labels: [__meta_kubernetes_node_name]
    regex: (.+)
    target_label: __address__
    replacement: ${1}:4194
- job_name: 'kubernetes-kube-state'
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    action: replace
    target_label: kubernetes_namespace
  - source_labels: [__meta_kubernetes_pod_name]
    action: replace
    target_label: kubernetes_pod_name
  - source_labels: [__meta_kubernetes_pod_label_grafanak8sapp]
    regex: .*true.*
    action: keep
  - source_labels: ['__meta_kubernetes_pod_label_daemon', '__meta_kubernetes_pod_node_name']
    regex: 'node-exporter;(.*)'
    action: replace
    target_label: nodename
- job_name: 'blackbox_http_pod_probe'
  metrics_path: /probe
  kubernetes_sd_configs:
  - role: pod
  params:
    module: [http_2xx]
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_blackbox_scheme]
    action: keep
    regex: http
  - source_labels: [__address__, __meta_kubernetes_pod_annotation_blackbox_port,  __meta_kubernetes_pod_annotation_blackbox_path]
    action: replace
    regex: ([^:]+)(?::\d+)?;(\d+);(.+)
    replacement: $1:$2$3
    target_label: __param_target
  - action: replace
    target_label: __address__
    replacement: blackbox-exporter.kube-system:9115
  - source_labels: [__param_target]
    target_label: instance
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    action: replace
    target_label: kubernetes_namespace
  - source_labels: [__meta_kubernetes_pod_name]
    action: replace
    target_label: kubernetes_pod_name
- job_name: 'blackbox_tcp_pod_probe'
  metrics_path: /probe
  kubernetes_sd_configs:
  - role: pod
  params:
    module: [tcp_connect]
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_blackbox_scheme]
    action: keep
    regex: tcp
  - source_labels: [__address__, __meta_kubernetes_pod_annotation_blackbox_port]
    action: replace
    regex: ([^:]+)(?::\d+)?;(\d+)
    replacement: $1:$2
    target_label: __param_target
  - action: replace
    target_label: __address__
    replacement: blackbox-exporter.kube-system:9115
  - source_labels: [__param_target]
    target_label: instance
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    action: replace
    target_label: kubernetes_namespace
  - source_labels: [__meta_kubernetes_pod_name]
    action: replace
    target_label: kubernetes_pod_name
- job_name: 'traefik'
  kubernetes_sd_configs:
  - role: pod
  relabel_configs:
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scheme]
    action: keep
    regex: traefik
  - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
    action: replace
    target_label: __metrics_path__
    regex: (.+)
  - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
    action: replace
    regex: ([^:]+)(?::\d+)?;(\d+)
    replacement: $1:$2
    target_label: __address__
  - action: labelmap
    regex: __meta_kubernetes_pod_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    action: replace
    target_label: kubernetes_namespace
  - source_labels: [__meta_kubernetes_pod_name]
    action: replace
    target_label: kubernetes_pod_name
```



### 解析域名

```
[root@host0-200 prometheus]# vim /var/named/od.com.zone
prometheus         A    10.0.0.10
[root@host0-200 prometheus]# systemctl restart named
```

### 应用资源配置清单

```sh
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/prometheus/rbac.yaml
serviceaccount/prometheus created
clusterrole.rbac.authorization.k8s.io/prometheus created
clusterrolebinding.rbac.authorization.k8s.io/prometheus created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/prometheus/dp.yaml
deployment.extensions/prometheus created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/prometheus/svc.yaml
service/prometheus created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/prometheus/ingress.yaml
ingress.extensions/prometheus created
```

### 浏览器访问

![](/images/posts/Linux-Kubernetes/Prometheus监控/11.png)
