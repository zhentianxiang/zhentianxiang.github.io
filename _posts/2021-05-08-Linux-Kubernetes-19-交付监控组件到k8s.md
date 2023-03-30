---
layout: post
title: Linux-Kubernetes-19-交付监控组件到k8s
date: 2021-05-08
tags: 实战-Kubernetes
---

## 1.部署kube-state-metrics

### 1.1.准备kube-state-metrics镜像

用来收集k8s基本状态信息的监控代理（比如多少个master多少个node）

[官方镜像地址](https://quay.io/repository/coreos/kube-state-metrics?tab=tags)

```sh
[root@host0-200 ~]# docker pull zhentianxiang/kube-state-metrics:v1.5.0
v1.5.0: Pulling from coreos/kube-state-metrics
cd784148e348: Pull complete 
f622528a393e: Pull complete 
Digest: sha256:b7a3143bd1eb7130759c9259073b9f239d0eeda09f5210f1cd31f1a530599ea1
Status: Downloaded newer image for quay.io/coreos/kube-state-metrics:v1.5.0
quay.io/coreos/kube-state-metrics:v1.5.0
[root@host0-200 ~]# docker tag zhentianxiang/kube-state-metrics:v1.5.0 harbor.od.com/public/kube-state-metrics:v1.5.0
[root@host0-200 ~]# docker push harbor.od.com/public/kube-state-metrics:v1.5.0 
The push refers to repository [harbor.od.com/public/kube-state-metrics]
5b3c36501a0a: Pushed 
7bff100f35cb: Pushed 
v1.5.0: digest: sha256:16e9a1d63e80c19859fc1e2727ab7819f89aeae5f8ab5c3380860c2f88fe0a58 size: 739
```

### 1.2.准备资源配置清单

```sh
[root@host0-200 ~]# mkdir -pv /data/k8s-yaml/kube-state-metrics && cd /data/k8s-yaml/kube-state-metrics
```

- vim rbac.yaml

```sh
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/cluster-service: "true"
  name: kube-state-metrics
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/cluster-service: "true"
  name: kube-state-metrics
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  - secrets
  - nodes
  - pods
  - services
  - resourcequotas
  - replicationcontrollers
  - limitranges
  - persistentvolumeclaims
  - persistentvolumes
  - namespaces
  - endpoints
  verbs:
  - list
  - watch
- apiGroups:
  - policy
  resources:
  - poddisruptionbudgets
  verbs:
  - list
  - watch
- apiGroups:
  - extensions
  resources:
  - daemonsets
  - deployments
  - replicasets
  verbs:
  - list
  - watch
- apiGroups:
  - apps
  resources:
  - statefulsets
  verbs:
  - list
  - watch
- apiGroups:
  - batch
  resources:
  - cronjobs
  - jobs
  verbs:
  - list
  - watch
- apiGroups:
  - autoscaling
  resources:
  - horizontalpodautoscalers
  verbs:
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/cluster-service: "true"
  name: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: kube-system
```

- vim dp.yaml

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "2"
  labels:
    grafanak8sapp: "true"
    app: kube-state-metrics
  name: kube-state-metrics
  namespace: kube-system
spec:
  selector:
    matchLabels:
      grafanak8sapp: "true"
      app: kube-state-metrics
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        grafanak8sapp: "true"
        app: kube-state-metrics
    spec:
      containers:
      - name: kube-state-metrics
        image: harbor.od.com/public/kube-state-metrics:v1.5.0
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: http-metrics
          protocol: TCP
        readinessProbe:  # 就绪性探针是为了让容器确定已经启动了，才会进行调度流量
          failureThreshold: 3
          httpGet:
            path: /healthz
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 5
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 5
      serviceAccountName: kube-state-metrics
```



### 1.3.应用资源配置清单

```sh
[root@host0-22 ~]#  kubectl apply -f http://k8s-yaml.od.com/kube-state-metrics/rbac.yaml
serviceaccount/kube-state-metrics created
clusterrole.rbac.authorization.k8s.io/kube-state-metrics created
clusterrolebinding.rbac.authorization.k8s.io/kube-state-metrics created
[root@host0-22 ~]#  kubectl apply -f http://k8s-yaml.od.com/kube-state-metrics/dp.yaml
deployment.extensions/kube-state-metrics created
```

### 1.4.检查启动情况

![](/images/posts/Linux-Kubernetes/Prometheus监控/2.png)

```sh
[root@host0-22 ~]# curl 172.7.22.13:8080/healthz
ok[root@host0-22 ~]# 
```

## 2.部署node-exporter

用来收集k8s运算节点的基础信息的（比如内存cpu磁盘使用量、网络IO等）

### 2.1.准备node-exporter镜像

```sh
[root@host0-200 kube-state-metrics]# docker pull zhentianxiang/node-exporter:v0.15.0
v0.15.0: Pulling from prom/node-exporter
Image docker.io/prom/node-exporter:v0.15.0 uses outdated schema1 manifest format. Please upgrade to a schema2 image for better future compatibility. More information at https://docs.docker.com/registry/spec/deprecated-schema-v1/
aa3e9481fcae: Pull complete 
a3ed95caeb02: Pull complete 
afc308b02dc6: Pull complete 
4cafbffc9d4f: Pull complete 
Digest: sha256:a59d1f22610da43490532d5398b3911c90bfa915951d3b3e5c12d3c0bf8771c3
Status: Downloaded newer image for prom/node-exporter:v0.15.0
docker.io/prom/node-exporter:v0.15.0
[root@host0-200 kube-state-metrics]# docker tag zhentianxiang/node-exporter:v0.15.0 harbor.od.com/public/node-exporter:v0.15.0
[root@host0-200 kube-state-metrics]# docker push harbor.od.com/public/node-exporter:v0.15.0
The push refers to repository [harbor.od.com/public/node-exporter]
5f70bf18a086: Mounted from public/pause 
1c7f6350717e: Pushed 
a349adf62fe1: Pushed 
c7300f623e77: Pushed 
v0.15.0: digest: sha256:57d9b335b593e4d0da1477d7c5c05f23d9c3dc6023b3e733deb627076d4596ed size: 1979
[root@host0-200 kube-state-metrics]# mkdir /data/k8s-yaml/node-exporter && cd /data/k8s-yaml/node-exporter
```

### 2.2.准备资源配置清单

- vim ds.yaml

```sh
kind: DaemonSet
apiVersion: extensions/v1beta1
metadata:
  name: node-exporter
  namespace: kube-system
  labels:
    daemon: "node-exporter"
    grafanak8sapp: "true"
spec:
  selector:
    matchLabels:
      daemon: "node-exporter"
      grafanak8sapp: "true"
  template:
    metadata:
      name: node-exporter
      labels:
        daemon: "node-exporter"
        grafanak8sapp: "true"
    spec:
      volumes:
      - name: proc
        hostPath: 
          path: /proc
          type: ""
      - name: sys
        hostPath:
          path: /sys
          type: ""
      containers:
      - name: node-exporter
        image: harbor.od.com/public/node-exporter:v0.15.0
        imagePullPolicy: IfNotPresent
        args:
        - --path.procfs=/host_proc
        - --path.sysfs=/host_sys
        ports:
        - name: node-exporter
          hostPort: 9100
          containerPort: 9100
          protocol: TCP
        volumeMounts:
        - name: sys
          readOnly: true
          mountPath: /host_sys
        - name: proc
          readOnly: true
          mountPath: /host_proc
      hostNetwork: true
```

### 2.3.启动资源配置清单

```sh
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/node-exporter/ds.yaml
```

### 2.4.检查启动情况

```sh
[root@host0-22 ~]# kubectl get pods -n kube-system |grep exporter
node-exporter-wvkjr                     1/1     Running   0          29m
node-exporter-zrvcr                     1/1     Running   0          29m
[root@host0-22 ~]# netstat -lntp |grep 9100
tcp6       0      0 :::9100                 :::*                    LISTEN      27845/node_exporter
[root@host0-22 ~]# curl 127.0.0.1:9100
<html>
			<head><title>Node Exporter</title></head>
			<body>
			<h1>Node Exporter</h1>
			<p><a href="/metrics">Metrics</a></p>
			</body>
			</html>[root@host0-22 ~]#
```

## 3.部署cadvisor

它是用来监控容器内部使用资源的重要工具，直接从容器外部进行探测容器到底消耗了多少资源

通过kubectl进行互相通信索要容器的数据

### 3.1.准备cadvisor镜像

```sh
[root@host0-200 node-exporter]# docker pull zhentianxiang/cadvisor:v0.28.3
v0.28.3: Pulling from google/cadvisor
ab7e51e37a18: Pull complete 
a2dc2f1bce51: Pull complete 
3b017de60d4f: Pull complete 
Digest: sha256:9e347affc725efd3bfe95aa69362cf833aa810f84e6cb9eed1cb65c35216632a
Status: Downloaded newer image for google/cadvisor:v0.28.3
docker.io/google/cadvisor:v0.28.3
[root@host0-200 node-exporter]# docker tag zhentianxiang/cadvisor:v0.28.3 harbor.od.com/public/cadvisor:v0.28.3
[root@host0-200 node-exporter]# docker push harbor.od.com/public/cadvisor:v0.28.3 
The push refers to repository [harbor.od.com/public/cadvisor]
f60e27acaccf: Pushed 
f04a25da66bf: Pushed 
52a5560f4ca0: Pushed 
v0.28.3: digest: sha256:34d9d683086d7f3b9bbdab0d1df4518b230448896fa823f7a6cf75f66d64ebe1 size: 951
```

### 3.2.准备资源配置清单

> 人为影响K8S调度策略的三种方法
>
> - 污点、容忍度方法
>   - 污点：运算节点node上的污点
>   - 容忍度：pod是否能够容忍污点
> - nodeName：让pod运行在指定的node上
> - nodeSelector：通过标签选择器，pod运行在指定一类node上
>
> 举例：kubectl taint node host0-21.hsot.com node-role.kubernetes.io/master=master:NoSchedule

```
[root@host0-200 node-exporter]# mkdir -pv /data/k8s-yaml/cadvisor && cd /data/k8s-yaml/cadvisor
mkdir: 已创建目录 "/data/k8s-yaml/cadvisor"
```

- vim ds.yaml

```sh
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cadvisor
  namespace: kube-system
  labels:
    app: cadvisor
spec:
  selector:
    matchLabels:
      name: cadvisor
  template:
    metadata:
      labels:
        name: cadvisor
    spec:
      hostNetwork: true
      tolerations:  #定义容忍度，其意思 就是你不让我创建pod，我还要创建pod
      - key: node-role.kubernetes.io/master  #这个是污点的key
        effect: NoSchedule  #这个是污点值=我不调度
      containers:
      - name: cadvisor
        image: harbor.od.com/public/cadvisor:v0.28.3
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - name: rootfs
          mountPath: /rootfs
          readOnly: true
        - name: var-run
          mountPath: /var/run
        - name: sys
          mountPath: /sys
          readOnly: true
        - name: docker
          mountPath: /var/lib/docker
          readOnly: true
        ports:
          - name: http
            containerPort: 4194
            protocol: TCP
        readinessProbe:
          tcpSocket:
            port: 4194
          initialDelaySeconds: 5
          periodSeconds: 10
        args:
          - --housekeeping_interval=10s
          - --port=4194
      terminationGracePeriodSeconds: 30
      volumes:
      - name: rootfs
        hostPath:
          path: /
      - name: var-run
        hostPath:
          path: /var/run
      - name: sys
        hostPath:
          path: /sys
      - name: docker
        hostPath:
          path: /data/docker
```

> 我们k8s应该是分为主控节点或逻辑节点，因为我们的架构是主控在同意节点，如果你用kubeadm去部署集群
>
> 部署出来的role=master的节点，同时会加一个taint，保证业务容器不会调度到自己的master上面 
>
> 然后上面设置到的容忍度（tolerations）就是，尽管你自身设置了污点（taint）我也要去部署pod，因为我要监控你的容器消耗的数据

### 3.3.修改运算节点软链接

host0-21、host0-22

```sh
[root@host0-22 ~]# mount -o remount,rw /sys/fs/cgroup/
[root@host0-22 ~]# ll /sys/fs/cgroup/
总用量 0
drwxr-xr-x 7 root root  0 5月   8 19:51 blkio
lrwxrwxrwx 1 root root 11 5月   8 19:50 cpu -> cpu,cpuacct
lrwxrwxrwx 1 root root 11 5月   8 19:50 cpuacct -> cpu,cpuacct
drwxr-xr-x 7 root root  0 5月   8 19:51 cpu,cpuacct
drwxr-xr-x 5 root root  0 5月   8 19:50 cpuset
drwxr-xr-x 7 root root  0 5月   8 19:51 devices
drwxr-xr-x 5 root root  0 5月   8 19:50 freezer
drwxr-xr-x 5 root root  0 5月   8 19:50 hugetlb
drwxr-xr-x 7 root root  0 5月   8 19:51 memory
lrwxrwxrwx 1 root root 16 5月   8 19:50 net_cls -> net_cls,net_prio
drwxr-xr-x 5 root root  0 5月   8 19:50 net_cls,net_prio
lrwxrwxrwx 1 root root 16 5月   8 19:50 net_prio -> net_cls,net_prio
drwxr-xr-x 5 root root  0 5月   8 19:50 perf_event
drwxr-xr-x 7 root root  0 5月   8 19:51 pids
drwxr-xr-x 7 root root  0 5月   8 19:51 systemd
[root@host0-22 ~]# ln -s /sys/fs/cgroup/cpu,cpuacct /sys/fs/cgroup/cpuacct,cpu
[root@host0-22 ~]# ll /sys/fs/cgroup/
总用量 0
drwxr-xr-x 7 root root  0 5月   8 19:51 blkio
lrwxrwxrwx 1 root root 11 5月   8 19:50 cpu -> cpu,cpuacct
lrwxrwxrwx 1 root root 11 5月   8 19:50 cpuacct -> cpu,cpuacct
lrwxrwxrwx 1 root root 26 5月   9 08:48 cpuacct,cpu -> /sys/fs/cgroup/cpu,cpuacct
drwxr-xr-x 7 root root  0 5月   8 19:51 cpu,cpuacct
drwxr-xr-x 5 root root  0 5月   8 19:50 cpuset
drwxr-xr-x 7 root root  0 5月   8 19:51 devices
drwxr-xr-x 5 root root  0 5月   8 19:50 freezer
drwxr-xr-x 5 root root  0 5月   8 19:50 hugetlb
drwxr-xr-x 7 root root  0 5月   8 19:51 memory
lrwxrwxrwx 1 root root 16 5月   8 19:50 net_cls -> net_cls,net_prio
drwxr-xr-x 5 root root  0 5月   8 19:50 net_cls,net_prio
lrwxrwxrwx 1 root root 16 5月   8 19:50 net_prio -> net_cls,net_prio
drwxr-xr-x 5 root root  0 5月   8 19:50 perf_event
drwxr-xr-x 7 root root  0 5月   8 19:51 pids
drwxr-xr-x 7 root root  0 5月   8 19:51 systemd
```

### 3.3.应用资源配置清单

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/cadvisor/ds.yaml
daemonset.apps/cadvisor created
```

### 3.4.检查启动情况

```sh
daemonset.apps/cadvisor created
[root@host0-21 ~]# kubectl get pods -n kube-system |grep cadvisor
cadvisor-9bdst                          1/1     Running   0          20s
cadvisor-dl8bg                          1/1     Running   0          20s
```

## 4.部署blackbox-exporter

帮助我探明业务容器是否存活

### 4.1.准备blackbox-exporter镜像

```sh
[root@host0-200 cadvisor]# docker pull zhentianxiang/blackbox-exporter:v0.15.1
v0.15.1: Pulling from prom/blackbox-exporter
8e674ad76dce: Pull complete 
e77d2419d1c2: Pull complete 
969c24328c68: Pull complete 
d9df4d63dd8a: Pull complete 
Digest: sha256:0ccbb0bb08bbc00f1c765572545e9372a4e4e4dc9bafffb1a962024f61d6d996
Status: Downloaded newer image for prom/blackbox-exporter:v0.15.1
docker.io/prom/blackbox-exporter:v0.15.1
[root@host0-200 cadvisor]# docker tag zhentianxiang/blackbox-exporter:v0.15.1 harbor.od.com/public/blackbox-exporter:v0.15.1
[root@host0-200 cadvisor]# docker push harbor.od.com/public/blackbox-exporter:v0.15.1
The push refers to repository [harbor.od.com/public/blackbox-exporter]
2e93bab0c159: Pushed 
4f2b5ab68d7f: Pushed 
3163e6173fcc: Pushed 
6194458b07fc: Pushed 
v0.15.1: digest: sha256:f7c335cc7898c6023346a0d5fba8566aca4703b69d63be8dc5367476c77cf2c4 size: 1155
```

### 4.2.准备资源配置清单

```sh
[root@host0-200 cadvisor]# mkdir -pv /data/k8s-yaml/blackbox-exporter && cd /data/k8s-yaml/blackbox-exporter
mkdir: 已创建目录 "/data/k8s-yaml/blackbox-exporter"
```

- vim cm.yaml

```
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app: blackbox-exporter
  name: blackbox-exporter
  namespace: kube-system
data:
  blackbox.yml: |-
    modules:
      http_2xx:
        prober: http
        timeout: 2s
        http:
          valid_http_versions: ["HTTP/1.1", "HTTP/2"]
          valid_status_codes: [200,301,302]
          method: GET
          preferred_ip_protocol: "ip4"
      tcp_connect:
        prober: tcp
        timeout: 2s
```

- vim dp.yaml

```sh
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: blackbox-exporter
  namespace: kube-system
  labels:
    app: blackbox-exporter
  annotations:
    deployment.kubernetes.io/revision: 1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: blackbox-exporter
  template:
    metadata:
      labels:
        app: blackbox-exporter
    spec:
      volumes:
      - name: config
        configMap:
          name: blackbox-exporter
          defaultMode: 420
      containers:
      - name: blackbox-exporter
        image: harbor.od.com/public/blackbox-exporter:v0.15.1
        imagePullPolicy: IfNotPresent
        args:
        - --config.file=/etc/blackbox_exporter/blackbox.yml
        - --log.level=info
        - --web.listen-address=:9115
        ports:
        - name: blackbox-port
          containerPort: 9115
          protocol: TCP
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 50Mi
        volumeMounts:
        - name: config
          mountPath: /etc/blackbox_exporter
        readinessProbe:
          tcpSocket:
            port: 9115
          initialDelaySeconds: 5
          timeoutSeconds: 5
          periodSeconds: 10
          successThreshold: 1
          failureThreshold: 3
```

- vim svc.yaml

```sh
kind: Service
apiVersion: v1
metadata:
  name: blackbox-exporter
  namespace: kube-system
spec:
  selector:
    app: blackbox-exporter
  ports:
    - name: blackbox-port
      protocol: TCP
      port: 9115
```

- vim ingress.yaml

```sh
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: blackbox-exporter
  namespace: kube-system
spec:
  rules:
  - host: blackbox.od.com
    http:
      paths:
      - path: /
        backend:
          serviceName: blackbox-exporter
          servicePort: blackbox-port
```

### 4.3.配置named解析

```sh
[root@host0-200 blackbox-exporter]# vim /var/named/od.com.zone 
blackbox           A    10.0.0.10
[root@host0-200 blackbox-exporter]# systemctl restart named
```

### 4.4.应用资源配置清单

```sh
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/blackbox-exporter/cm.yaml
configmap/blackbox-exporter created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/blackbox-exporter/dp.yaml
deployment.extensions/blackbox-exporter created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/blackbox-exporter/svc.yaml
service/blackbox-exporter created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/blackbox-exporter/ingress.yaml
ingress.extensions/blackbox-exporter created
```

### 4.5.检查启动情况

```sh
[root@host0-22 ~]# kubectl get cm -n kube-system |grep blackbox
blackbox-exporter                    1      66s
[root@host0-22 ~]# kubectl get pods -n kube-system |grep blackbox
blackbox-exporter-659fc46b55-czfqj      1/1     Running   0          36s
[root@host0-22 ~]# kubectl get svc -n kube-system |grep blackbox
blackbox-exporter         ClusterIP   192.168.208.59    <none>        9115/TCP                 44s
[root@host0-22 ~]# kubectl get ingress -n kube-system |grep blackbox
blackbox-exporter      blackbox.od.com              80      46s
```

![](/images/posts/Linux-Kubernetes/Prometheus监控/3.png)

