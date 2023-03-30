---
layout: post
title: Linux-Kubernetes-23-部署炫酷的dashboard工具grafana
date: 2021-05-10
tags: 实战-Kubernetes
---

## 部署炫酷的dashboard工具grafana

[官方模板](https://grafana.com/grafana/dashboards)

常用监控模板大全

**第一部分**

> 监控容器：3146、8685、10000、8588、315

**第二部分**

> 监控物理机：8919、9276、13105(强烈推荐)

**第三部分**

> 监控协议http/icmp/tcp/dns：9965

### 1.准备镜像

```sh
[root@host0-200 etc]# docker pull grafana/grafana:5.4.2
5.4.2: Pulling from grafana/grafana
a5a6f2f73cd8: Pull complete 
08e6195c0f29: Pull complete 
b7bd3a2a524c: Pull complete 
d3421658103b: Pull complete 
cd7c84229877: Pull complete 
49917e11f039: Pull complete 
Digest: sha256:b9a31857e86e9cf43552605bd7f3c990c123f8792ab6bea8f499db1a1bdb7d53
Status: Downloaded newer image for grafana/grafana:5.4.2
docker.io/grafana/grafana:5.4.2
[root@host0-200 grafana]# docker tag 6f18ddf9e552 harbor.od.com/infra/grafana:v5.4.2
[root@host0-200 grafana]# docker push harbor.od.com/infra/grafana:v5.4.2
The push refers to repository [harbor.od.com/infra/grafana]
8e6f0f1fe3f4: Pushed 
f8bf0b7b071d: Pushed 
5dde66caf2d2: Pushed 
5c8801473422: Pushed 
11f89658f27f: Pushed 
ef68f6734aa4: Pushed 
v5.4.2: digest: sha256:b9a31857e86e9cf43552605bd7f3c990c123f8792ab6bea8f499db1a1bdb7d53 size: 1576
```

### 2.准备资源配置清单

```sh
[root@host0-200 ~]# mkdir -pv /data/k8s-yaml/grafana && cd /data/k8s-yaml/grafana
mkdir: 已创建目录 "/data/k8s-yaml/grafana"
```

- vim rbac.yaml

```sh
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/cluster-service: "true"
  name: grafana
rules:
- apiGroups:
  - "*"
  resources:
  - namespaces
  - deployments
  - pods
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/cluster-service: "true"
  name: grafana
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: grafana
subjects:
- kind: User
  name: k8s-node
```

- vim svc.yaml

```sh
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: infra
spec:
  ports:
  - port: 3000
    protocol: TCP
    targetPort: 3000
  selector:
    app: grafana
```



- vim dp.yaml

```sh
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: grafana
    name: grafana
  name: grafana
  namespace: infra
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 7
  selector:
    matchLabels:
      name: grafana
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: grafana
        name: grafana
    spec:
      containers:
      - name: grafana
        image: harbor.od.com/infra/grafana:v5.4.2
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3000
          protocol: TCP
        volumeMounts:
        - mountPath: /var/lib/grafana
          name: data
      imagePullSecrets:
      - name: harbor
      securityContext:
        runAsUser: 0
      volumes:
      - nfs:
          server: host0-200
          path: /data/nfs-volume/grafana
        name: data
```

```sh
[root@host0-200 ~]# mkdir -pv /data/nfs-volume/grafana
```

- vim ingress.yaml

```sh
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: grafana
  namespace: infra
spec:
  rules:
  - host: grafana.od.com
    http:
      paths:
      - path: /
        backend:
          serviceName: grafana
          servicePort: 3000
```

### 3.配置named解析

```sh
[root@host0-200 grafana]# vim /var/named/od.com.zone 
grafana            A    10.0.0.10
[root@host0-200 grafana]# systemctl restart named
```

### 4.应用资源配置清单

```sh
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/grafana/rbac.yaml
clusterrole.rbac.authorization.k8s.io/grafana created
clusterrolebinding.rbac.authorization.k8s.io/grafana created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/grafana/dp.yaml
deployment.extensions/grafana created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/grafana/svc.yaml
service/grafana created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/grafana/ingress.yaml
ingress.extensions/grafana created
```

### 5.简易初始配置

![](/images/posts/Linux-Kubernetes/Prometheus监控/31.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/32.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/33.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/34.png)

### 6.安装插件

- 第一种安装方法

```sh
#安装以下插件
grafana-cli plugins install grafana-kubernetes-app
grafana-cli plugins install grafana-clock-panel
grafana-cli plugins install grafana-piechart-panel
grafana-cli plugins install briangann-gauge-panel
grafana-cli plugins install natel-discrete-panel
```

```sh
[root@host0-21 ~]# kubectl exec -it -n infra grafana-5d666f9f87-xmprz -- bash
root@grafana-5d666f9f87-xmprz:/usr/share/grafana# grafana-cli plugins install grafana-kubernetes-app
installing grafana-kubernetes-app @ 1.0.1
from url: https://grafana.com/api/plugins/grafana-kubernetes-app/versions/1.0.1/download
into: /var/lib/grafana/plugins

✔ Installed grafana-kubernetes-app successfully 

Restart grafana after installing plugins . <service grafana-server restart>

root@grafana-5d666f9f87-xmprz:/usr/share/grafana# 
```

- 第二种安装方法

> 首先浏览器下载插件，然后上传到服务器
>
> [briangann-gauge-panel](https://grafana.com/api/plugins/briangann-gauge-panel/versions/0.0.6/download)
>
> [grafana-clock-panel](https://grafana.com/api/plugins/grafana-clock-panel/versions/1.0.3/download)
>
> [grafana-kubernetes-app](https://grafana.com/api/plugins/grafana-kubernetes-app/versions/1.0.1/download)
>
> [grafana-piechart-panel](https://grafana.com/api/plugins/grafana-piechart-panel/versions/1.6.1/download)
>
> [natel-discrete-panel](https://grafana.com/api/plugins/natel-discrete-panel/versions/0.1.0/download)

```sh
[root@host0-200 plugins]# pwd
/data/nfs-volume/grafana/plugins
[root@host0-200 plugins]# ll
总用量 4
drwxr-xr-x 4 root root  253 5月  10 02:43 briangann-gauge-panel
drwxr-xr-x 8 root root 4096 5月  10 02:42 grafana-clock-panel
drwxr-xr-x 4 root root  198 5月  10 02:41 grafana-kubernetes-app
drwxr-xr-x 4 root root  277 5月  10 02:47 grafana-piechart-panel
drwxr-xr-x 5 root root  216 5月  10 02:48 natel-discrete-panel
```

以此安装完之后在重启以下容器

重新登陆grafana

![](/images/posts/Linux-Kubernetes/Prometheus监控/32.png)

