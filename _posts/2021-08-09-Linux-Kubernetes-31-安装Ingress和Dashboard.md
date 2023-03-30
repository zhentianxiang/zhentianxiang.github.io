---
layout: post
title: Linux-Kubernetes-31-安装Ingress和Dashboard
date: 2021-08-09
tags: 实战-Kubernetes
---

## 一、Traefik-ingress

### 1. Traefik 2.0介绍

[官方文档](https://docs.traefik.io/v2.0/)

traefik 是一款反向代理、负载均衡服务，使用 golang 实现的。和 nginx 最大的不同是，它支持自动化更新反向代理和负载均衡配置。在微服务架构越来越流行的今天，一个业务恨不得有好几个数据库、后台服务和 webapp，开发团队拥有一款 “智能” 的反向代理服务，为他们简化服务配置。traefik 就是为了解决这个问题而诞生的。

> Traefik 2.2新增的功能如下：

### 2. 部署traefik

> 注：我们这里是将traefik部署在ingress-traefik命名空间，如果你需要部署在其他命名空间，需要更改资源清单，如果你是部署在和我同样的命令空间中，你需要创建该命名空间。

创建命名空间：

```sh
kubectl create ns ingress-traefik
```

Traefik 2.0版本后开始使用CRD来对资源进行管理配置，所以我们需要先创建CRD资源

- traefik-crd.yaml

```sh
## IngressRoute
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressroutes.traefik.containo.us
spec:
  scope: Namespaced
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRoute
    plural: ingressroutes
    singular: ingressroute
---
## IngressRouteTCP
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressroutetcps.traefik.containo.us
spec:
  scope: Namespaced
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRouteTCP
    plural: ingressroutetcps
    singular: ingressroutetcp
---
## Middleware
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: middlewares.traefik.containo.us
spec:
  scope: Namespaced
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: Middleware
    plural: middlewares
    singular: middleware
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: tlsoptions.traefik.containo.us
spec:
  scope: Namespaced
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TLSOption
    plural: tlsoptions
    singular: tlsoption
---
## TraefikService
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: traefikservices.traefik.containo.us
spec:
  scope: Namespaced
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TraefikService
    plural: traefikservices
    singular: traefikservice

---
## TraefikTLSStore
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: tlsstores.traefik.containo.us
spec:
  scope: Namespaced
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: TLSStore
    plural: tlsstores
    singular: tlsstore

---
## IngressRouteUDP
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: ingressrouteudps.traefik.containo.us
spec:
  scope: Namespaced
  group: traefik.containo.us
  version: v1alpha1
  names:
    kind: IngressRouteUDP
    plural: ingressrouteudps
    singular: ingressrouteudp
```

```sh
kubectl apply -f traefik-crd.yaml
```

创建 RBAC 权限

Kubernetes 在 1.6 以后的版本中引入了基于角色的访问控制（RBAC）策略，方便对 Kubernetes 资源和 API 进行细粒度控制。Traefik 需要一定的权限，所以这里提前创建好 Traefik ServiceAccount 并分配一定的权限。

- traefik-rbac.yaml

```sh
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: ingress-traefik
  name: traefik-ingress-controller
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
rules:
  - apiGroups: [""]
    resources: ["services","endpoints","secrets"]
    verbs: ["get","list","watch"]
  - apiGroups: ["extensions"]
    resources: ["ingresses"]
    verbs: ["get","list","watch"]
  - apiGroups: ["extensions"]
    resources: ["ingresses/status"]
    verbs: ["update"]
  - apiGroups: ["traefik.containo.us"]
    resources: ["middlewares"]
    verbs: ["get","list","watch"]
  - apiGroups: ["traefik.containo.us"]
    resources: ["ingressroutes","traefikservices"]
    verbs: ["get","list","watch"]
  - apiGroups: ["traefik.containo.us"]
    resources: ["ingressroutetcps","ingressrouteudps"]
    verbs: ["get","list","watch"]
  - apiGroups: ["traefik.containo.us"]
    resources: ["tlsoptions","tlsstores"]
    verbs: ["get","list","watch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
  - kind: ServiceAccount
    name: traefik-ingress-controller
    namespace: ingress-traefik
```

```sh
kubectl apply -f traefik-rbac.yaml
```
- traefik-config.yaml

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: traefik-config
  namespace: ingress-traefik
data:
  traefik.yaml: |-
    serversTransport:
      insecureSkipVerify: true
    api:
      insecure: true
      dashboard: true
      debug: true
    metrics:
      prometheus: ""
    entryPoints:
      web:
        address: ":80"
      websecure:
        address: ":443"
    providers:
      kubernetesCRD: ""
      kubernetesingress: ""
    log:
      filePath: ""
      level: error
      format: json
    accessLog:
      filePath: ""
      format: json
      bufferingSize: 0
      filters:
        retryAttempts: true
        minDuration: 20
      fields:
        defaultMode: keep
        names:
          ClientUsername: drop
        headers:
          defaultMode: keep
          names:
            User-Agent: redact
            Authorization: drop
            Content-Type: keep
```
```sh
kubectl apply -f traefik-config.yaml
```

设置Label标签

由于使用的Kubernetes DeamonSet方式部署Traefik，所以需要提前给节点设置Label，当程序部署Pod会自动调度到设置 Label的node节点上。

```sh
kubectl label nodes k8s-master IngressProxy=true
```

```sh
[root@k8s-master1 traefik]# kubectl get node --show-labels
NAME         STATUS   ROLES    AGE    VERSION   LABELS
k8s-master   Ready    <none>   6d1h   v1.18.3   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-master,kubernetes.io/os=linux
k8s-node1    Ready    <none>   6d1h   v1.18.3   IngressProxy=true,beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node1,kubernetes.io/os=linux
k8s-node2    Ready    <none>   6d     v1.18.3   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,ingress=true,kubernetes.io/arch=amd64,kubernetes.io/hostname=k8s-node2,kubernetes.io/os=linux
```

Kubernetes 部署 Traefik

按照以前Traefik1.7部署方式，使用DaemonSet类型部署，以便于在多服务器间扩展，使用 hostport 方式占用服务器 80、443 端口，方便流量进入。

- traefik-ds.yaml

```sh
apiVersion: v1
kind: Service
metadata:
  name: traefik
  namespace: ingress-traefik
spec:
  ports:
    - name: web
      port: 80
    - name: websecure
      port: 443
    - name: admin
      port: 8080
  selector:
    app: traefik
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: traefik-ingress-controller
  namespace: ingress-traefik
  labels:
    app: traefik
spec:
  selector:
    matchLabels:
      app: traefik
  template:
    metadata:
      name: traefik
      labels:
        app: traefik
    spec:
      serviceAccountName: traefik-ingress-controller
      terminationGracePeriodSeconds: 1
      containers:
        - image: traefik:2.2.0
          name: traefik-ingress-lb
          ports:
            - name: web
              containerPort: 80
              hostPort: 80           #hostPort方式，将端口暴露到集群节点
            - name: websecure
              containerPort: 443
              hostPort: 443          #hostPort方式，将端口暴露到集群节点
            - name: admin
              containerPort: 8080
          resources:
            limits:
              cpu: 2000m
              memory: 1024Mi
            requests:
              cpu: 1000m
              memory: 1024Mi
          securityContext:
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE
          args:
            - --configfile=/config/traefik.yaml
          volumeMounts:
            - mountPath: "/config"
              name: "config"
      volumes:
        - name: config
          configMap:
            name: traefik-config
      tolerations:              #设置容忍所有污点，防止节点被设置污点
        - operator: "Exists"
      nodeSelector:             #设置node筛选器，在特定label的节点上启动
        IngressProxy: "true"
```

### 3. Traefik 路由规则基础配置（暴露服务）

配置 HTTP 路由规则 （Traefik Dashboard 为例）

Traefik 应用已经部署完成，但是想让外部访问 Kubernetes 内部服务，还需要配置路由规则，这里开启了 Traefik Dashboard 配置，所以首先配置 Traefik Dashboard 看板的路由规则，使外部能够访问 Traefik Dashboard。

- traefik-dashboard-route.yaml

```sh
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard-route
  namespace: ingress-traefik
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`traefik.hyper.com`)
      kind: Rule
      services:
        - name: traefik
          port: 8080
```

```sh
kubectl apply -f traefik-dashboard-route.yaml
```

同样一个规则用ingress和Ingress route的写法区别如下

```sh
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-ingress
  namespace: ingress-traefik
  annotations:
    kubernetes.io/ingress.class: traefik
    traefik.frontend.rule.type: PathPrefixStrip  
spec:
  rules:
  - host: traefik.hyper.com
    http:
      paths:
      - path: /
        backend:
          serviceName: traefik
          servicePort: 8080

---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: https
  namespace: ingress-traefik
spec:
  entryPoints:
    - web
  routes:
    - match: Host(`traefik.hyper.com`)
      kind: Rule
      services:
        - name: traefik
          port: 8080
```

> 总结的话
> 就是traefik v1版本用的是ingress，v2版本ingress和Ingress route都能用，他们实际都是k8s的ingress规则的体现，官方也做过说明，参考[ Ingress route介绍](https://docs.traefik.io/providers/kubernetes-crd/)，以及[ ingress介绍](https://docs.traefik.io/providers/kubernetes-ingress/)
> 我个人比较推荐Ingress route的用法，因为不需要加注释，https的证书引用也更加方便

![](/images/posts/Linux-Kubernetes/k8s1.18/1.png)

### 4. 配置https方式访问服务

这里我们创建 Kubernetes 的 Dashboard，它是 基于 Https 协议方式访问，由于它是需要使用 Https 请求，所以我们需要配置 Https 的路由规则并指定证书。

```sh
# 创建自签名证书
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=traefik.hyper.com"

# 将证书存储到Kubernetes Secret中，新建的k8dash-sa-tls必须与k8dash-route中的tls: secretName一致。
kubectl create secret tls k8dash-sa-tls --key=tls.key --cert=tls.crt -n kube-system
```

```sh
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: k8dash-sa-route
  namespace: ingress-traefik
spec:
  entryPoints:
    - websecure
  tls:
    secretName: k8dash-sa-tls
  routes:
    - match: Host(`traefik.hyper.com`)
      kind: Rule
      services:
        - name: traefik
          port: 8080
```

![](/images/posts/Linux-Kubernetes/k8s1.18/2.png)

## 二、Dashboard控制台

### 1. 部署Dashboard

下载资源清单

```sh
wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
```

修改资源清单

因为我用的是traefi-ingress控制器暴露的服务，所以在service段下面添加如下内容

```sh
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  entryPoints:
    - websecure
  tls:
    secretName: kubernetes-dashboard-certs
  routes:
    - match: Host(`dashboard.hyper.com`)
      kind: Rule
      services:
        - name: kubernetes-dashboard
          port: 443
```

![](/images/posts/Linux-Kubernetes/k8s1.18/3.png)

并且官方提供的资源清单里面的secret证书在有些浏览器中无法访问，所以需要注释掉，然后后期自己添加

```sh
#因为自动生成的证书很多浏览器无法使用，所以我们自己创建，注释掉kubernetes-dashboard-certs对象声明
#apiVersion: v1
#kind: Secret
#metadata:
#  labels:
#    k8s-app: kubernetes-dashboard
#  name: kubernetes-dashboard-certs
#  namespace: kubernetes-dashboard
#type: Opaque
```
```sh
修改token超时时间，以及启用tls
..................
args:
  #- --auto-generate-certificates # 注释掉这个
  - --namespace=kubernetes-dashboard
  - --tls-cert-file=tls.crt
  - --tls-key-file=tls.key
  - --token-ttl=86400
```

![](/images/posts/Linux-Kubernetes/k8s1.18/4.png)

**自签证书**

```sh
# 输入密码123456
[root@VM-16-9-centos dashboard]# openssl genrsa -des3  -out dashboard.key 2048
Generating RSA private key, 2048 bit long modulus
..........+++
............................+++
e is 65537 (0x10001)
Enter pass phrase for dashboard.key:
Verifying - Enter pass phrase for dashboard.key:

# 输入密码123456
[root@VM-16-9-centos dashboard]# openssl rsa -in dashboard.key  -out linuxtian.key
Enter pass phrase for dashboard.key:
writing RSA key
[root@VM-16-9-centos dashboard]# openssl req -new -key linuxtian.key  -out linuxtian.csr  -subj "/C=CN/ST=BJ/L=BJ/O=linuxtian/OU=linuxtian/CN=linuxtian.top/emailAddress=2099637909@linuxtian.top"
[root@VM-16-9-centos dashboard]# openssl x509 -req -days 365 -extfile v3.ext -in linuxtian.csr  -signkey linuxtian.key  -out linuxtian.crt
Signature ok
subject=/C=CN/ST=BJ/L=BJ/O=linuxtian/OU=linuxtian/CN=linuxtian.top/emailAddress=2099637909@linuxtian.top
Getting Private key
[root@VM-16-9-centos dashboard]# kubectl delete secrets -n kubernetes-dashboard kubernetes-dashboard-certs
secret "kubernetes-dashboard-certs" deleted
[root@VM-16-9-centos dashboard]# kubectl create secret generic kubernetes-dashboard-certs --from-file=tls.key=linuxtian.key --from-file=tls.crt=linuxtian.crt -n kubernetes-dashboard
secret/kubernetes-dashboard-certs created
```

### 2. 发布服务并查看状态

```sh
[root@VM-16-9-centos dashboard]# kubectl create -f  recommended.yaml
```

```sh
[root@VM-16-9-centos dashboard]# kubectl get pods -A
```

### 3. 创建dashboard管理员

创建账号


```sh
[root@VM-16-9-centos dashboard]# cat > dashboard-admin.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: dashboard-admin
  namespace: kubernetes-dashboard
EOF
```

绑定用户到集群管理员角色


```sh
[root@VM-16-9-centos dashboard]# cat > dashboard-admin-bind-cluster-role.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dashboard-admin-bind-cluster-role
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: dashboard-admin
  namespace: kubernetes-dashboard
EOF
```
```sh
[root@VM-16-9-centos dashboard]# kubectl create -f dashboard-admin-bind-cluster-role.yaml

[root@VM-16-9-centos dashboard]# kubectl create -f dashboard-admin.yaml
```


查看token

```sh
[root@VM-16-9-centos dashboard]# kubectl get secrets -n kubernetes-dashboard `kubectl get secrets -n kubernetes-dashboard |grep admin |awk '{print $1}'` -o yaml |grep token:|sed '$d'|awk '{print $2}' |base64 -d
eyJhbGciOiJSUzI1NiIsImtpZCI6Ii01cFhPRnNNV19GS1pHYnh5SzBiWFgwRkN1cjQ4UkxOUHlvMUp2QWlCQWMifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlcm5ldGVzLWRhc2hib2FyZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkYXNoYm9hcmQtYWRtaW4tdG9rZW4teHZkaGQiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGFzaGJvYXJkLWFkbWluIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiNDg5MDkyNWEtNjg2Zi00YTJlLWE3OGUtM2NlMjQ1MTc2YTYwIiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmVybmV0ZXMtZGFzaGJvYXJkOmRhc2hib2FyZC1hZG1pbiJ9.SOZA6R1Hor3AhzhiD4Aoj4IMXEoxaqvb8j5H6bQJn6nN2hq1PVFYgKAY2LLqax6gbxI7R_1qCyDLVbQwrbhlIHY6ozTkCTH7qKHuJyzRracos4y-zdnjG8wNM6rMM9NpxwjeFpwkGiwM5atKC9KmWS-comL8qG-rpahZgOU9lZ1BdQ2r7ibAaQIlc4iFQA9WqY7C150kZg1CZ4C8f1uf95czj86-8_Tp6LbPNy2SVkFaNohgXQUk98_ebPAlACQt3AE2Xdd5WFwctdVB6DusvBiwcs1frYJvg8l8EXEXw3tPBrkneBA0WTWbHeTLLVQMS7R64UxNuk4Jgad76jG3kQ[root@master01 tasks]#
```
也可以制作config文件来登录dashboard
```sh
[root@VM-16-9-centos dashboard]# kubectl get secrets -n kubernetes-dashboard
NAME                               TYPE                                  DATA   AGE
dashboard-admin-token-n88mf        kubernetes.io/service-account-token   3      92m
default-token-5mxq6                kubernetes.io/service-account-token   3      96m
kubernetes-dashboard-certs         Opaque                                2      96m
kubernetes-dashboard-csrf          Opaque                                1      92m
kubernetes-dashboard-key-holder    Opaque                                2      92m
kubernetes-dashboard-token-d445c   kubernetes.io/service-account-token   3      92m
[root@VM-16-9-centos dashboard]# DASH_TOCKEN=$(kubectl -n kubernetes-dashboard  get  secret  dashboard-admin-token-n88mf  -o jsonpath={.data.token} |base64 -d)
[root@VM-16-9-centos dashboard]# kubectl config set-cluster kubernetes --server=192.168.1.115:6443 --kubeconfig=/usr/local/src/dashbord-admin.conf
Cluster "kubernetes" set.
[root@VM-16-9-centos dashboard]# kubectl config set-credentials dashboard-admin --token=$DASH_TOCKEN --kubeconfig=/usr/local/src/dashbord-admin.conf
User "dashboard-admin" set.
[root@VM-16-9-centos dashboard]# kubectl config set-context dashboard-admin@kubernetes --cluster=kubernetes --user=dashboard-admin --kubeconfig=/usr/local/src/dashbord-admin.conf
Context "dashboard-admin@kubernetes" created.
[root@VM-16-9-centos dashboard]# kubectl config use-context dashboard-admin@kubernetes --kubeconfig=/usr/local/src/dashbord-admin.conf
Switched to context "dashboard-admin@kubernetes".
[root@VM-16-9-centos dashboard]# sz /usr/local/src/dashbord-admin.conf
```

![](/images/posts/Linux-Kubernetes/k8s1.18/5.png)

![](/images/posts/Linux-Kubernetes/k8s1.18/6.png)

因为没有安装metrics-server所以Pods的CPU、内存情况是看不到的

### 4. 安装metrics-server

> 注意：heapster已经被metrics-server取代

```sh
wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.3.6/components.yaml
```

修改资源清单

```shell
template:
    metadata:
      name: metrics-server
      labels:
        k8s-app: metrics-server
    spec:
      serviceAccountName: metrics-server
      volumes:
      # mount in tmp so we can safely use from-scratch images and/or read-only containers
      - name: tmp-dir
        emptyDir: {}
      containers:
      - name: metrics-server
        image: mirrorgooglecontainers/metrics-server-amd64:v0.3.6  #修改一下镜像地址
        imagePullPolicy: IfNotPresent
        args:
          - --cert-dir=/tmp
          - --secure-port=4443
          - --kubelet-preferred-address-types=InternalIP #添加
          - --kubelet-insecure-tls #添加
        ports:
        - name: main-port
          containerPort: 4443

```

![](/images/posts/Linux-Kubernetes/k8s1.18/7.png)

修改 Kubernetes apiserver 启动参数

```sh
vim /etc/kubernetes/manifests/kube-apiserver.yaml
#在kube-apiserver项中添加如下配置选项 修改后apiserver会自动重启
--enable-aggregator-routing=true

#安装
kubectl create -f components.yaml

#1-2分钟后查看结果
kubectl top nodes
```

![](/images/posts/Linux-Kubernetes/k8s1.18/8.png)


## 三、安装 ingress-nginx

### 1. 介绍

> - ingress 介绍
>
> Service是基于四层TCP和UDP协议转发的，而Ingress可以基于七层的HTTP和HTTPS协议转发，可以通过域名和路径
> 来访问服务
>
> Ingress-Nginx github 地址：https://github.com/kubernetes/ingress-nginx
> Ingress-Nginx 官方网站：https://kubernetes.github.io/ingress-nginx/
>
> - k8s 对外暴露方式
>
> K8s集群对外暴露服务的方式目前只有三种：
> Loadblancer；Nodeport；ingress
> 前两种熟悉起来比较快，而且使用起来也比较方便，在此就不进行介绍了。
>
> - ingress由两部分组成：
>
> ingress controller：将新加入的Ingress转化成Nginx的配置文件并使之生效
> ingress服务：将Nginx的配置抽象成一个Ingress对象，每添加一个新的服务只需写一个新的Ingress的yaml文件即可
> 其中ingress controller目前主要有两种：基于nginx服务的ingress controller和基于traefik的ingress controller。
> 而其中traefik的ingress controller，目前支持http和https协议。



### 2. ingress-nginx的安装

```sh
# 下载yaml资源，如果官方的不能下载，可以使用这个 https://blog.linuxtian.top/data/nginx-ingress/k8s-v1.20.1/deploy.yaml

$ wget https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.47.0/deploy/static/provider/baremetal/deploy.yaml

```

```sh

# 修改以及添加一些配置

$ vim deploy.yaml

# Source: ingress-nginx/templates/controller-deployment.yaml
apiVersion: apps/v1
kind: DaemonSet      # 修改为 DaemonSet
...............
    spec:
      hostNetwork: true   # 添加
      nodeSelector:        # 添加
        kubernetes.io/os: linux  # 修改这个为 ingress/type: nginx
      dnsPolicy: ClusterFirst
      containers:
        - name: controller
          image: registry.cn-hangzhou.aliyuncs.com/lfy_k8s_images/ingress-nginx-controller:v0.46.0  # 修改为此镜像
          imagePullPolicy: IfNotPresent
..............
```

```sh
# 交付资源倒集群

$ kubectl label nodes k8s-master ingress/type=nginx
$ kubectl apply -f deploy.yaml

```

```sh
# 检查安装的结果

$ kubectl get pod,svc -n ingress-nginx
```

### 3. ingress-nginx的测试

```sh
$ vim ingress-test.yaml

apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-server
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-server
  template:
    metadata:
      labels:
        app: hello-server
    spec:
      containers:
      - name: hello-server
        image: registry.cn-hangzhou.aliyuncs.com/lfy_k8s_images/hello-server
        ports:
        - containerPort: 9000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx-demo
  name: nginx-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx-demo
  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - image: nginx
        name: nginx
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx-demo
  name: nginx-demo
spec:
  selector:
    app: nginx-demo
  ports:
  - port: 8000
    protocol: TCP
    targetPort: 80
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: hello-server
  name: hello-server
spec:
  selector:
    app: hello-server
  ports:
  - port: 8000
    protocol: TCP
    targetPort: 9000
```

提交资源

```sh
$ kubecl apply -f ingress-test.yaml

$ kubectl get pod,svc
```

配置 ingress 资源

```sh
apiVersion: networking.k8s.io/v1
kind: Ingress  
metadata:
  name: ingress-host-bar
spec:
  ingressClassName: nginx
  rules:
  - host: "hello.flyfish.com"
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: hello-server
            port:
              number: 8000
  - host: "demo.flyfish.com"
    http:
      paths:
      - pathType: Prefix
        path: "/"  # 把请求会转给下面的服务，下面的服务一定要能处理这个路径，不能处理就是404
        backend:
          service:
            name: nginx-demo  ## java，比如使用路径重写，去掉前缀nginx
            port:
              number: 8000
```

```sh
kubectl apply -f ingress-web.yaml
kubectl get ing
```

### 4. 使用 ingress-nginx 代理 dashboard

```sh
[root@VM-16-9-centos dashboard]# cat ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kube-dashboard-ingress
  namespace: kubernetes-dashboard
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - kube-dashboard.linuxtian.top
    secretName: kubernetes-dashboard-certs
  rules:
  - host: kube-dashboard.linuxtian.top
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 443
```
