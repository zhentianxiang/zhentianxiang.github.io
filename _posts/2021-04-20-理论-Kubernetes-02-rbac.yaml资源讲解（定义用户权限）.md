---
layout: post
title: 理论-Kubernetes-02-rbac.yaml资源讲解（定义用户权限）
date: 2021-04-20
tags: 理论-Kubernetes
---

## 关于k8s用户权限

- k8s自1.6版本起，默认使用基于角色的控制访问（rbac）
- 相比较于ABAC（基于属性的访问控制）和WebHook等鉴权机制；
  - 对集群中的资源的使用权限实现了完整覆盖
  - 支持权限的动态调整，无需重启api-server

![](/images/posts/Linux-Kubernetes/kubectl命令行工具使用详解/1.png)

- 首先k8s集群对应了一堆资源（pod、server、trafike、dashboard。。。。。），这些资源对应了一组权限【读写、更新、列出、监视。。。】

- 那么这些权限怎么给用户赋权呢，那么我们再k8s里面有两种账户（用户账户、服务账户）（UserAccount ）(ServiceAccount)

- 用户账户最典型的就是kubectl的k8s-node，当时启动kubectl制作了一个kubeconfig配置文件，也叫做kubectl用户账户(k8s-node)的配置文件

![](/images/posts/Linux-Kubernetes/kubectl命令行工具使用详解/2.png)

这个就是kubectl在k8s集群里面的一个用户账户（k8s-node）

---

- 在k8s集群中无法直接给用户附加权限，只能先给相应的用户附加相应的角色，通过角色给用户添加权限，账户什么权限取决于附加的什么角色。
- 在k8s集群中有两种角色，一种叫Role（普通角色），一种叫ClusterRole（集群角色），Role只能应用在某一个特定的名称空间下，比如kube-system空间，然后再这个名称空间下创建（create）了一个某某某资源，指定了-n kube-system，那么它只对这个空间内操作有效。
- 那么在k8s中还有绑定角色【RoleBinding、ClusterRoleBinging】就是把用户绑定到角色下面，从而使角色附有相应的权限。
- 绑定角色操作也是一种资源，它也有对应的yaml文件
- 那么服务账户就是，所有在k8s中运行的pod都必须有一个服务用户（ServiceAccount），如果没有显示指定账户是谁，那么默认就会规定为default。

![](/images/posts/Linux-Kubernetes/kubectl命令行工具使用详解/3.png)

### 1.traefik的rbac.yaml文件

```
apiVersion: v1
kind: ServiceAccount  # 声明了一个服务用户
metadata:
  name: traefik-ingress-controller  # 用户名字叫这个
  namespace: kube-system   # 命名空间为这个
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole  # 生命了一个集群角色
metadata:
  name: traefik-ingress-controller   # 角色名字叫
rules:  # 定义了一系列集群权限
  - apiGroups:  # api组
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
---
kind: ClusterRoleBinding   # 定义集群角色绑定
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata: # 指定要绑定的用户名字
  name: traefik-ingress-controller  # 服务用户的名字
roleRef:  # 指定绑定的角色
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller  # 参考这个角色
subjects: # 指定要绑定的服务用户
- kind: ServiceAccount
  name: traefik-ingress-controller  # 服务用户名字
  namespace: kube-system
```

以上步骤就是：创建账户-定义角色-账户绑定角色

- daemonset.yaml

```
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: traefik-ingress
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress
spec:
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress
        name: traefik-ingress
    spec:
      serviceAccountName: traefik-ingress-controller  #这里就定义了这个pod用的服务用户为上面自定义创建的服务用户
      terminationGracePeriodSeconds: 60
      containers:
      - image: harbor.od.com/public/traefik:v1.7.2
        name: traefik-ingress
        ports:
        - name: controller
          containerPort: 80
          hostPort: 81
        - name: admin-web
          containerPort: 8080
        securityContext:
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        args:
        - --api
        - --kubernetes
        - --logLevel=INFO
        - --insecureskipverify=true
        - --kubernetes.endpoint=https://10.0.0.10:7443
        - --accesslog
        - --accesslog.filepath=/var/log/traefik_access.log
        - --traefiklog
        - --traefiklog.filepath=/var/log/traefik.log
        - --metrics.prometheus
```

### 2.dashboard的rbac.yaml文件

因为我们要给dashboard最高权限，所以不用创建clusterrole集群角色，因为集群中默认有最高权限的cluster-admin，所以直接绑定用现成的就行。

```
apiVersion: v1
kind: ServiceAccount  # 定义服务账户
metadata:
  labels:
    k8s-app: kubernetes-dashboard
    addonmanager.kubernetes.io/mode: Reconcile
  name: kubernetes-dashboard-admin  # 名字叫这个
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding  # 直接做集群角色绑定，和上面提到的用户角色绑定不一样
metadata:  # 指定要绑定用户的名字
  name: kubernetes-dashboard-admin  # 用户名字
  namespace: kube-system  # 指定命名空间
  labels:
    k8s-app: kubernetes-dashboard
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:  # 指定角色
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin  # 因为没有定义角色，所以用的是k8s提供的角色（集群管理员，最高权限）
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard-admin
  namespace: kube-system
```

### 3.授权k8s-node权限

```
[root@host0-11 ~]# vim k8s-node.yaml
apiVersion: rbac.authorization.k8s.io/v1  # 定义资源类型的版本
kind: ClusterRoleBinding   # 定义集群用户和角色绑定
metadata:
  name: k8s-node   # kubectl用户名字
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole   # 定义要绑定集群角色
  name: system:node   # 集群角色名称（默认的k8s角色）
subjects:

- apiGroup: rbac.authorization.k8s.io
  kind: User   # 定义用户绑定角色
  name: k8s-node   # 定义要绑定的用户
```
### 4.查看clusterrole权限

```
[root@host0-11 ~]# kubectl get clusterrole cluster-admin -o yaml
[root@host0-11 ~]# kubectl get clusterrole system:node -o yaml
```
