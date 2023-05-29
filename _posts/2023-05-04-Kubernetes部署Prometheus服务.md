---
layout: post
title: 2023-05-04-Kubernetes部署Prometheus服务
date: 2023-05-04
tags: 实战-Kubernetes
music-id: 447926063
---

## 一. kube-state-metrics

`Kube State Metrics` 是一个简单的服务，该服务通过监听 `Kubernetes API` 服务器来生成不同资源的状态的 `Metrics` 数据。它不关注 Kubernetes 节点组件的运行状况，而是关注集群内部各种资源对象 (例如 deployment、node 和 pod) 的运行状况。

`Kube State Metrics` 是直接从 `Kubernetes API` 对象中获取生成的指标数据，这个过程中不会对指标数据进行修改。这样可以确保该组件提供的功能具有与 `Kubernetes API` 对象本身具有相同级别的稳定性。反过来讲，这意味着在某些情况下 `Kube State Metrics` 的 `metrics` 数据可能不会显示与 `Kubectl` 完全相同的值，因为 `Kubectl` 会应用某些启发式方法来显示可理解的消息。`Kube State Metrics` 公开了未经 `Kubernetes API` 修改的原始数据，这样用户可以拥有所需的所有数据，并根据需要执行启发式操作。

由于该组件 Kubernetes 并未与其默认集成在一起，所以需要我们单独部署。

由于 `Kube State Metrics` 组件需要通过与 `kube-apiserver` 连接，并调用相应的接口去获取 `kubernetes` 集群数据，这个过程需要 `Kube State Metrics` 组件拥有一定的权限才能成功执行这些操作。

在 `Kubernetes` 中默认使用 `RBAC` 方式管理权限。所以，我们需要创建相应的 RBAC 资源来提供该组件使用。这里创建 `Kube State Metrics` `RBAC` 文件 **kube-state-metrics-rbac.yaml**，内容如下:

> 这里使用的 Namespace 为 kube-system，如果你不想部署在这个命名空间，请提前修改里面的 Namespace 参数。

### 1. RBAC

```sh
[root@VM-16-9-centos kube-stats-metics]# cat rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    k8s-app: kube-state-metrics
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-state-metrics
  labels:
    k8s-app: kube-state-metrics
rules:
- apiGroups: [""]
  resources: ["configmaps","secrets","nodes","pods",
              "services","resourcequotas",
              "replicationcontrollers","limitranges",
              "persistentvolumeclaims","persistentvolumes",
              "namespaces","endpoints"]
  verbs: ["list","watch"]
- apiGroups: ["extensions"]
  resources: ["daemonsets","deployments","replicasets"]
  verbs: ["list","watch"]
- apiGroups: ["apps"]
  resources: ["statefulsets","daemonsets","deployments","replicasets"]
  verbs: ["list","watch"]
- apiGroups: ["batch"]
  resources: ["cronjobs","jobs"]
  verbs: ["list","watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["list","watch"]
- apiGroups: ["authentication.k8s.io"]
  resources: ["tokenreviews"]
  verbs: ["create"]
- apiGroups: ["authorization.k8s.io"]
  resources: ["subjectaccessreviews"]
  verbs: ["create"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["list","watch"]
- apiGroups: ["certificates.k8s.io"]
  resources: ["certificatesigningrequests"]
  verbs: ["list","watch"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses","volumeattachments"]
  verbs: ["list","watch"]
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["mutatingwebhookconfigurations","validatingwebhookconfigurations"]
  verbs: ["list","watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["networkpolicies","ingresses"]
  verbs: ["list","watch"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-state-metrics
  labels:
    app: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: kube-system
```

### 2. deploy

```sh
[root@VM-16-9-centos kube-stats-metics]# cat deploy.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    k8s-app: kube-state-metrics
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: kube-state-metrics
  template:
    metadata:
      labels:
        k8s-app: kube-state-metrics
    spec:
      serviceAccountName: kube-state-metrics
      containers:
      - name: kube-state-metrics
        image: bitnami/kube-state-metrics:2.0.0
        securityContext:
          runAsUser: 65534
        ports:
        - name: http-metrics    ##用于公开kubernetes的指标数据的端口
          containerPort: 8080
        - name: telemetry       ##用于公开自身kube-state-metrics的指标数据的端口
          containerPort: 8081
        resources:
          limits:
            cpu: 200m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 100Mi
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080
          initialDelaySeconds: 5
          timeoutSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 8081
          initialDelaySeconds: 5
          timeoutSeconds: 5
        volumeMounts:
        - name: host-time
          mountPath: /etc/localtime
          readOnly: true
      volumes:
      - name: host-time
        hostPath:
          path: /etc/localtime
```

### 3. service

```yaml
[root@VM-16-9-centos kube-stats-metics]# cat service.yaml 
apiVersion: v1
kind: Service
metadata:
  name: kube-state-metrics
  namespace: kube-system
  labels:
    k8s-app: kube-state-metrics
    app.kubernetes.io/name: kube-state-metrics   ##不能删除此注解,该注解用于Prometheus自动发现
spec:
  type: ClusterIP
  ports:
  - name: http-metrics
    port: 8080
    targetPort: 8080
  - name: telemetry
    port: 8081
    targetPort: 8081
  selector:
    k8s-app: kube-state-metrics
```

```sh
[root@VM-16-9-centos kube-stats-metics]# kubectl get pods -n kube-system -o wide |grep state
kube-state-metrics-6677cf47b5-w9vvb        1/1     Running   0          2m42s   192.168.157.228   vm-16-9-centos   <none>           <none>
[root@VM-16-9-centos kube-stats-metics]# curl 192.168.157.228:8080/metrics
```

### 4. 配置数据采集

经过上面操作，我们已经在 Kubernetes 中部署了 `Kube State Metrics`。接下来就需要在 `Prometheus` 配置文件中添加 `kube-state-metrics` 指标数据采集配置，配置内容如下所示:

```yaml
- job_name: "kube-state-metrics"
  kubernetes_sd_configs:
  - role: endpoints
    ## 指定kube-state-metrics组件所在的Namespace名称
    namespaces:
      names: ["kube-system"]
  relabel_configs:
  ## 指定从 app.kubernetes.io/name 标签等于 kube-state-metrics 的 service 服务获取指标信息
  - action: keep
    source_labels: [__meta_kubernetes_service_label_app_kubernetes_io_name]
    regex: kube-state-metrics
  ## 下面配置也是为了适配 Grafana Dashboard 模板(编号13105图表)
  - action: labelmap
    regex: __meta_kubernetes_service_label_(.+)
  - action: replace
    source_labels: [__meta_kubernetes_namespace]
    target_label: k8s_namespace
  - action: replace
    source_labels: [__meta_kubernetes_service_name]
    target_label: k8s_sname
```

上面部分参数简介如下:

- **kubernetes_sd_configs:** 设置发现模式为 Kubernetes 动态服务发现。
- **kubernetes_sd_configs.role:** 指定 Kubernetes 的服务发现模式，这里设置为 endpoints 的服务发现模式，该模式下会调用 kube-apiserver 中的接口获取指标数据。并且还限定只获取 kube-state-metrics 所在 Namespace 的空间 kube-system 中的 Endpoints 信息。
- **kubernetes_sd_configs.namespace:** 指定只在配置的 Namespace 中进行 endpoints 服务发现。
- **relabel_configs:** 用于对采集的标签进行重新标记。

KubeStateMetrics 的 `relabel_configs` 配置的作用:

```
## 模块一
- action: keep
  source_labels: [__meta_kubernetes_service_label_app_kubernetes_io_name]
  regex: kube-state-metrics
```

**(1)、模块一**

使用 keep 行为则表示，删除与 regex 表达式不符合全部标签，只保留符合要求的标签。这里原标签 source_labels 的配置的内容为 `__meta_kubernetes_service_label_app_kubernetes_io_name`，对这个标签进行拆分，可以分为:

```
前缀: __meta_kubernetes_service_label_
标签: app_kubernetes_io_name
```

这样拆分后就很容易理解了，意思就是只处理带 `app.kubernetes.io/name` 标签的服务，且标签的值还得与 regex 表达式匹配。

这里这么做的目的是通过 Kubernetes 的 endpoints 类型的服务发现，查找带 `app.kubernetes.io/name` 标签的 `Service`，从该 `Service` 关联 `Endpoints` 的每个 `地址` 与 `端口` 中发现目标。

**cAdvisor**

由于 Kubelet 中已经默认集成 cAdvisor 组件，所以我们无需部署该组件。不过由于监控的需要，我们还需在 `Prometheus` 中将采集 `cAdvisor` 的配置添加进去。

在 `Prometheus` 配置文件中添加 `cAdvisor` 指标数据采集配置，配置内容如下所示:

```yaml
- job_name: 'kubernetes-cadvisor'
  scheme: https
  metrics_path: /metrics/cadvisor
  tls_config:
    ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
  bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
  kubernetes_sd_configs:
  - role: node
  relabel_configs:
  - action: labelmap
    regex: __meta_kubernetes_node_label_(.+)
  - target_label: __address__
    replacement: kubernetes.default.svc:443
  - source_labels: [__meta_kubernetes_node_name]
    target_label: __metrics_path__
    replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor

  ## 下面配置只是用于适配对应的 Grafana Dashboard 图表(这里用编号13105图表)，不同的图表配置不同，不过多介绍
  metric_relabel_configs:
  - source_labels: [instance]
    separator: ;
    regex: (.+)
    target_label: node
    replacement: $1
    action: replace
  - source_labels: [pod_name]
    separator: ;
    regex: (.+)
    target_label: pod
    replacement: $1
    action: replace
  - source_labels: [container_name]
    separator: ;
    regex: (.+)
    target_label: container
    replacement: $1
    action: replace
```

上面部分参数简介如下:

- **kubernetes_sd_configs:** 设置发现模式为 Kubernetes 动态服务发现。
- **kubernetes_sd_configs.role:** 指定 Kubernetes 的服务发现模式，这里设置为 node 的服务发现模式，该模式下会调用 kubelet 中的接口获取指标数据，能够获取到各个 Kubelet 的服务器地址和节点名称等信息。
- **tls_config.ca_file:** 用于指定连接 kube-apiserver 的证书文件。
- **bearer_token_file:** 用于指定连接 kube-apiserver 的鉴权认证的 token 串文件。
- **relabel_configs:** 用于对采集的标签进行重新标记。

**cAdvisor 配置项 relabel_configs 简介**

上面我们在配置中添加了 `relabel_configs` 重标记相关配置内容，这里每个重标记参数的作用都是为了更加方便收集与处理 Kubernetes 集群的监控指标数据。由于这部分配置比较多且繁琐，这里将分块一一为大家解释一下:

```yaml
## 模块一
- action: labelmap
  regex: __meta_kubernetes_node_label_(.+)

## 模块二
- target_label: __address__
  replacement: kubernetes.default.svc:443
- source_labels: [__meta_kubernetes_node_name]
  target_label: __metrics_path__
  replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor
```

**(1)、模块一**

将 regex 表达式中的内容 `__meta_kubernetes_node_label_(.+)` 与获取的所有标签名进行匹配，根据全部匹配成功的标签来创建新标签。新标签的标签名称为 `__meta_kubernetes_node_label_(.+)` 表达式中 `(.+)` 这部分的内容，新标签的值为原标签的值。

例如，获取的标签列表中存在内容为 `__meta_kubernetes_node_label_beta_kubernetes_io_os="linux"` 的标签，这个标签的名称和值分别为:

```
标签名称: "__meta_kubernetes_node_label_beta_kubernetes_io_os"
标签值: "linux"
```

该标签能够与上面配置的 regex 表达式匹配，那么这时，将会创建一个新的标签，该标签名称与值分别为：

```
新标签名称: "beta_kubernetes_io_os"
新标签值: "linux"
```

综上可知，这里这么做的目的是获取 Kubernetes Node 节点的 Label 标签，但是 Kubernetes 给这些标签加了 `__meta_kubernetes_node_label_` 前缀，所以我们需要将这些前缀移除，才能获得真实的 Label 标签。

**(2)、模块二**

在介绍这块配置作用之前，我们先介绍下 cAdvisor 在和 kubernetes 的集成关系。

在 Kubernetes 1.7.3 版本以前，cAdvisor 的 metrics 数据集成在 Kubelet 接口中，在 1.7.3 以后的版本中 cAdvisor 的指标数据被 Kubelet 的 metrics 独立出来了。按新版本的标准配置，Kubelet 中的 cAdvisor 是没有对外开放 4194 端口的。所以，我们只能通过 kube-apiserver 提供的 api 做代理获取监控指标数据，其中:

```sh
## 可以通过下面地址来获取 Kubelet 的指标数据
http://{apiserver的IP地址}:{apiserver的端口}/api/v1/nodes/{节点名称}/proxy/metrics

## 可以通过地址来获取 cAdvisor 的指标数据
http://{apiserver的IP地址}:{apiserver的端口}/api/v1/nodes/{节点名称}/proxy/metrics/cadvisor
```

所以，我们可以通过 kube-apiserver 获取我们想要的 cAdvisor 数据。

在 Kubernets 中的 Default 命名空间中存在 kube-apiserver 的 Service 资源 `kubernetes`，我们在 kubernetes 内部可以使用与该 Service 关联的域名 `kubernetes.default.svc:443` 访问 kube-apiserver 的接口。

介绍了 cAdvisor 和 kubernetes 的集成关系后，那么这里 relabel_configs 配置有什么用呢?我们将其分为两步分别介绍:

- 步骤一，修改指标数据采集地址参数 `address` 为 `kubernetes.default.svc:443`。
- 步骤二，修改指标数据采集地址中的路径参数 `metrics_path` 为 `/api/v1/nodes/${1}/proxy/metrics/cadvisor`，其中 `${1}` 表示 Kubernetes 中每个 Node 的名称。

结合这两步骤，可以知道这俩个配置的作用是拼凑 `http://{apiserver的IP地址}:{apiserver的端口}/api/v1/nodes/{节点名称}/proxy/metrics/cadvisor` 这个地址。

**cAdvisor 重标记作用总结**

综上介绍，我们可以对上面配置进行总结一下，其每步作用分别为:

- ① 去掉前缀，获取 kubernetes 的 node 节点设置的 label 标签。
- ② 修改指标数据采集为 kubernetes 集群内部 kube-apiserver 地址，即 kubernetes.default.svc:443。
- ③ 通过节点 label 标签，获取各个节点名称，拼凑路径 /api/v1/nodes/{节点名称}/proxy/metrics/cadvisor。

有了上面三个步骤，我们就能通过 `http://{apiserver的IP地址}:{apiserver的端口}/api/v1/nodes/{节点名称}/proxy/metrics/cadvisor` 接口地址中获取指 cAdvisor 指标数据了。

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/4.png)



## 二、Node-export


Prometheus Node Exporter 是一个用于监控 Linux 和 Unix 系统的官方插件，它通过公开多种监控指标来帮助了解系统状态和性能，例如 CPU、内存、磁盘、网络等指标。Node Exporter 可以帮助 Prometheus 收集这些指标，并且能够以格式化的形式公开指标数据。

Node Exporter 由多个收集器组成，每个收集器可以收集特定类型的指标。例如，文件系统收集器用于收集有关磁盘和文件系统使用情况的指标，网络收集器用于收集有关网络流量和连接的指标等等。这些指标可以作为 Prometheus 中的目标，用于监控和警报。

Node Exporter 是一个独立的二进制文件，可以在 Linux 和 Unix 系统上运行，可以通过 systemd 或其他进程管理工具运行。Prometheus 通过配置文件或者命令行参数指定 Node Exporter 作为监控目标，Node Exporter 将指标数据暴露在 HTTP 端点上，供 Prometheus 进行采集。

Node Exporter 是 Prometheus 生态系统中非常重要的组件之一，它可以为 Prometheus 提供丰富的系统指标数据，是构建完整监控系统的关键组成部分之一。

### 1. deploy

```sh
[root@VM-16-9-centos node-export]# cat deploy.yaml
apiVersion: v1
kind: Service
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    k8s-app: node-exporter
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 9100
    targetPort: 9100
  selector:
    k8s-app: node-exporter
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: monitoring
  labels:
    k8s-app: node-exporter
spec:
  selector:
    matchLabels:
      k8s-app: node-exporter
  template:
    metadata:
      labels:
        k8s-app: node-exporter
    spec:
      containers:
      - name: node-exporter
        image: prom/node-exporter:v1.1.2
        ports:
        - name: metrics
          containerPort: 9100
        args:
        - "--path.procfs=/host/proc"
        - "--path.sysfs=/host/sys"
        - "--path.rootfs=/host"
        volumeMounts:
        - name: dev
          mountPath: /host/dev
        - name: proc
          mountPath: /host/proc
        - name: sys
          mountPath: /host/sys
        - name: rootfs
          mountPath: /host
        - name: host-time
          mountPath: /etc/localtime
          readOnly: true
      volumes:
        - name: dev
          hostPath:
            path: /dev
        - name: proc
          hostPath:
            path: /proc
        - name: sys
          hostPath:
            path: /sys
        - name: rootfs
          hostPath:
            path: /
        - name: host-time
          hostPath:
            path: /etc/localtime
      hostPID: true
      hostNetwork: true
      tolerations:
      - operator: "Exists"
```

```sh
[root@VM-16-9-centos node-export]# kubectl apply -f node-export.yaml
[root@VM-16-9-centos node-export]# kubectl get pods -n monitoring 
NAME                  READY   STATUS    RESTARTS   AGE
node-exporter-xt7ll   1/1     Running   0          26s
[root@VM-16-9-centos node-export]# curl -kL http://127.0.0.1:9100/metrics
```

### 2. 配置数据采集

```yaml
scrape_configs:
- job_name: 'node-exporter'
  kubernetes_sd_configs:
  - role: node
  relabel_configs:
  - action: replace
    source_labels: [__address__]
    regex: '(.*):10250'
    replacement: '${1}:9100'
    target_label: __address__
```

上面部分参数说明如下:

- **kubernetes_sd_configs:** 设置发现模式为 Kubernetes 动态服务发现。
- **kubernetes_sd_configs.role:** 指定 Kubernetes 的服务发现模式，这里设置为 Node 则表示从 Kubernetes 集群中每个节点发现目标，其默认地址为 Kubelet 地址的 HTTP 端口。
- **relabel_configs:** 用于对采集的标签进行重新标记。

**Prometheus 配置文件中 relabel_configs 参数说明**

上面 Node Exporter 使用的是 `DaemonSet` 方式部署到 `Kubernetes` 集群中的，这种部署方式能够在 Kubernetes 中每个节点里面都部署一个实例，如下图所示:

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/1.png)

如图所示，每个节点上的 `Node Exporter` 都会通过 `9100` 端口和 `/metrics` 接口暴露节点节点监控指标数据。要想采集这些指标数据，我们可以在 `Prometheus` 配置文件中，添加全部的 `Node Exporter` 的 `地址` 与 `端口` 这样的静态配置。

不过配置地址是一件非常繁琐的事情，为什么这么说呢？这是因为在实际使用过程中，我们每当 `Kubernetes` 集群中"新增节点"或"剔除节点"，那么我们就必须手动修改一次 Prometheus 配置，将它们更新。**那么有没有配置一个配置，就能自动采集全部节点信息的配置呢？且能根据节点的变化而变化呢？**

带着问题分析一下如何实现。刚刚讲了 `Node Exporter` 的 `端口` 和 `指标暴露接口` 在每个服务器节点中都是固定的，唯一可能每个节点中不一致的地方就是它们部署的服务器 `IP` 地址，如果我们能够获取它们的服务器 `IP` 地址，再加上 `Node Exporter` 应用的端口号 `9100`，将其拼合在一起就组成 `Node Exporter` 的完整地址，即 `<Kubernetes节点IP>:9100` 的形式。这样我们也就可以在 `Prometheus` 配置文件中动态配置 `Node Exporter` 采集地址了。

不过 `Prometheus` 已经想到这点，其原生就提供了 `Kubernetes` 动态服务发现功能的支持，可以调用 `Kube-ApiServer` 接口获取 `Kubernetes` 集群相关信息。其中服务发现级别可以配置为 `node`，这种级别下的动态服务发现可以获得 `Kubernetes` 集群中的全部 `Kubelet` 信息。要知道在 `Kubernetes` 中，每个节点都是通过 `Kubelet` 与 `Master` 交互进行管控的，所以 `Kubelet` 组件一定在每个节点中都存在。**既然这个 node 服务发现机制能够发现在各个节点中的 Kubelet 信息，那么肯定能够获取 Kubelet 的 IP 地址，由于 Node Exporter 和 Kubelet 在一起，所以获取到 Kubelet IP 地址就相当于获取到 Node Exporter 的 IP 地址了。**

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/2.png)

**到这里还没说 `<relabel_configs>` 标签中配置参数的作用，其中该标签就是用于从 Kubernetes 动态服务发现机制中，得到的标签列表中找到 `__address__` 标签的值，该标签就是 Kubelet 的地址。不过该地址是一个完整地址，所以，我们需要使用 regex 正则表达式来截取标签值中的 `IP` 部分，然后再在加上 `9100` 端口与 `/metrics` 地址 (在 Prometheus 配置中会忽略，因为对于 Prometheus 来说，当不指定采集接口时默认就会从 /metrics 接口获取指标数据)，这样就得到了我们收集指标的 Node Exporter 的完整地址，再将它们写到目标标签 `__address__` 中作为指标数据采集的地址。**

> 啰嗦了这么多，其实说白了通过这个 relabel_configs 重标记的功能获取 Kubernetes 各个节点地址，然后加上 Node Exporter 端口，组成完整采集地址，通过这个地址我们就可以收集我们需要的节点指标数据。

## 三、blackbox-exporter

BlackBox Exporter 是 Prometheus 官方提供的黑盒监控解决方案，允许用户通过 HTTP、HTTPS、DNS、TCP 以及 ICMP 的方式对网络进行探测，这种探测方式常常用于探测一个服务的运行状态，观察服务是否正常运行。

### 1. 什么是白盒与黑盒监控

在监控系统中会经常提到 **白盒监控** 与 **黑盒监控** 两个关键词，这里对这俩关键词进行一下简单解释:

**墨盒监控**

黑盒监控指的是以用户的身份测试服务的运行状态。常见的黑盒监控手段包括 HTTP 探针、TCP 探针、DNS 探测、ICMP 等。黑盒监控常用于检测站点与服务可用性、连通性，以及访问效率等。

**白盒监控**

白盒监控一般指的是我们日常对服务器状态的监控，如服务器资源使用量、容器的运行状态、中间件的稳定情况等一系列比较直观的监控数据，这些都是支撑业务应用稳定运行的基础设施。

通过白盒能监控，可以使我们能够了解系统内部的实际运行状况，而且还可以通过对监控指标数据的观察与分析，可以让我们提前预判服务器可能出现的问题，针对可能出现的问题进行及时修正，避免造成不可预估的损失。

### 3. 白盒监控和黑盒监控的区别

黑盒监控与白盒监控有着很大的不同，俩者的区别主要是，黑盒监控是以故障为主导，当被监控的服务发生故障时，能快速进行预警。而白盒监控则更偏向于主动的和提前预判方式，预测可能发生的故障。

一套完善的监控系统是需要黑盒监控与白盒监控俩者配合同时工作的，白盒监控预判可能存在的潜在问题，而黑盒监控则是快速发现已经发生的问题。

### 4. config

```sh
[root@VM-16-9-centos blackbox-exporter]# cat blackbox-exporter-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: blackbox-exporter
  namespace: monitoring
  labels:
    app: blackbox-exporter
data:
  blackbox.yml: |-
    modules:
      ## ----------- DNS 检测配置 -----------
      dns_tcp:  
        prober: dns
        dns:
          transport_protocol: "tcp"
          preferred_ip_protocol: "ip4"
          query_name: "kubernetes.default.svc.cluster.local" # 用于检测域名可用的网址
          query_type: "A" 
      ## ----------- TCP 检测模块配置 -----------
      tcp_connect:
        prober: tcp
        timeout: 5s
      ## ----------- ICMP 检测配置 -----------
      ping:
        prober: icmp
        timeout: 5s
        icmp:
          preferred_ip_protocol: "ip4"
      ## ----------- HTTP GET 2xx 检测模块配置 -----------
      http_get_2xx:  
        prober: http
        timeout: 10s
        http:
          method: GET
          preferred_ip_protocol: "ip4"
          valid_http_versions: ["HTTP/1.1","HTTP/2"]
          valid_status_codes: [200]           # 验证的HTTP状态码,默认为2xx
          no_follow_redirects: false          # 是否不跟随重定向
      ## ----------- HTTP GET 3xx 检测模块配置 -----------
      http_get_3xx:  
        prober: http
        timeout: 10s
        http:
          method: GET
          preferred_ip_protocol: "ip4"
          valid_http_versions: ["HTTP/1.1","HTTP/2"]
          valid_status_codes: [301,302,304,305,306,307]  # 验证的HTTP状态码,默认为2xx
          no_follow_redirects: false                     # 是否不跟随重定向
      ## ----------- HTTP POST 监测模块 -----------
      http_post_2xx: 
        prober: http
        timeout: 10s
        http:
          method: POST
          preferred_ip_protocol: "ip4"
          valid_http_versions: ["HTTP/1.1", "HTTP/2"]
          #headers:                             # HTTP头设置
          #  Content-Type: application/json
          #body: '{}'                           # 请求体设置
```

### 5. service

```sh
[root@VM-16-9-centos blackbox-exporter]# cat blackbox-exporter-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: blackbox-exporter
  namespace: monitoring
  labels:
    k8s-app: blackbox-exporter
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 9115
    targetPort: 9115
  selector:
    k8s-app: blackbox-exporter
```

### 6. deploy

```sh
[root@VM-16-9-centos blackbox-exporter]# cat blackbox-exporter-deploy.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blackbox-exporter
  namespace: monitoring
  labels:
    k8s-app: blackbox-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: blackbox-exporter
  template:
    metadata:
      labels:
        k8s-app: blackbox-exporter
    spec:
      containers:
      - name: blackbox-exporter
        image: prom/blackbox-exporter:v0.19.0
        args:
        - --config.file=/etc/blackbox_exporter/blackbox.yml
        - --web.listen-address=:9115
        - --log.level=info
        ports:
        - name: http
          containerPort: 9115
        resources:
          limits:
            cpu: 200m
            memory: 256Mi
          requests:
            cpu: 100m
            memory: 50Mi
        livenessProbe:
          tcpSocket:
            port: 9115
          initialDelaySeconds: 5
          timeoutSeconds: 5
          periodSeconds: 10
          successThreshold: 1
          failureThreshold: 3
        readinessProbe:
          tcpSocket:
            port: 9115
          initialDelaySeconds: 5
          timeoutSeconds: 5
          periodSeconds: 10
          successThreshold: 1
          failureThreshold: 3
        volumeMounts:
        - name: config
          mountPath: /etc/blackbox_exporter
        - name: host-time
          mountPath: /etc/localtime
          readOnly: true 
      volumes:
      - name: config
        configMap:
          name: blackbox-exporter
          defaultMode: 420
      - name: host-time
        hostPath:
          path: /etc/localtime
```

### 7. 数据采集

创建 Prometheus 规则，添加使用 **BlackBox Exporter** 探测指定 **DNS** 服务器健康状态的配置，内容如下:

```yaml
################ DNS 服务器监控 ###################
- job_name: "kubernetes-dns"
  metrics_path: /probe
  params:
    ## 配置要使用的模块,要与blackbox exporter配置中的一致
    ## 这里使用DNS模块
    module: [dns_tcp]
  static_configs:
    ## 配置要检测的地址
    - targets:
      - kube-dns.kube-system:53
      - 8.8.4.4:53
      - 8.8.8.8:53
      - 223.5.5.5
  relabel_configs:
    ## 将上面配置的静态DNS服务器地址转换为临时变量 “__param_target”
    - source_labels: [__address__]
      target_label: __param_target
    ## 将 “__param_target” 内容设置为 instance 实例名称
    - source_labels: [__param_target]
      target_label: instance
    ## BlackBox Exporter 的 Service 地址
    - target_label: __address__
      replacement: blackbox-exporter.kube-system:9115
```

创建用于探测 Kubernetes 服务的配置，对那些配置了 `prometheus.io/http-probe: "true"` 标签的 **Kubernetes Service** 资源的健康状态进行探测，配置内容如下:

```yaml
- job_name: "kubernetes-services"
  metrics_path: /probe
  ## 使用HTTP_GET_2xx与HTTP_GET_3XX模块
  params: 
    module:
    - "http_get_2xx"
    - "http_get_3xx"
  ## 使用Kubernetes动态服务发现,且使用Service类型的发现
  kubernetes_sd_configs:
  - role: service
  relabel_configs:
    ## 设置只监测Kubernetes Service中Annotation里配置了注解prometheus.io/http_probe: true的service
  - action: keep
    source_labels: [__meta_kubernetes_service_annotation_prometheus_io_http_probe]
    regex: "true"
  - action: replace
    source_labels: 
    - "__meta_kubernetes_service_name"
    - "__meta_kubernetes_namespace"
    - "__meta_kubernetes_service_annotation_prometheus_io_http_probe_port"
    - "__meta_kubernetes_service_annotation_prometheus_io_http_probe_path"
    target_label: __param_target
    regex: (.+);(.+);(.+);(.+)
    replacement: $1.$2:$3$4
  - target_label: __address__
    replacement: blackbox-exporter.kube-system:9115
  - source_labels: [__param_target]
    target_label: instance
  - action: labelmap
    regex: __meta_kubernetes_service_label_(.+)
  - source_labels: [__meta_kubernetes_namespace]
    target_label: kubernetes_namespace
  - source_labels: [__meta_kubernetes_service_name]
    target_label: kubernetes_name
```

这里先部署一个用于测试的 Nginx 应用镜像，部署的 Deployment 资源文件 `nginx-deploy.yaml` 内容如下

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    k8s-app: nginx
  annotations:
    prometheus.io/http-probe: "true"        ### 设置该服务执行HTTP探测
    prometheus.io/http-probe-port: "80"     ### 设置HTTP探测的接口
    prometheus.io/http-probe-path: "/"      ### 设置HTTP探测的地址
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: 80
  selector:
    app: nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  replicas: 1
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
        image: nginx:1.19
        ports:
        - containerPort: 80
```

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/3.png)

## 四、Prometheus

### 1. RBAC

```sh
[root@VM-16-9-centos prometheus]# cat rbac.yaml 
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
  - apiGroups: [""]  # "" indicates the core API group
    resources:
      - nodes
      - nodes/proxy
      - services
      - endpoints
      - pods
    verbs:
      - get
      - watch
      - list
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - watch
      - list
  - nonResourceURLs: ["/metrics"]
    verbs:
      - get

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
  labels:
    app: prometheus

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: monitoring
roleRef:
  kind: ClusterRole
  name: prometheus
  apiGroup: rbac.authorization.k8s.io
```

### 2. service

```sh
[root@VM-16-9-centos prometheus]# cat prometheus-clusterip.yaml 
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  clusterIP: None
  ports:
  - port: 9090
    protocol: TCP
    targetPort: 9090
  selector:
    app: prometheus
```

```sh
[root@VM-16-9-centos prometheus]# cat prometheus-service.yaml 
apiVersion: v1
kind: Service
metadata:
  annotations:
    prometheus.io/http-probe: "true"        ### 开启该服务执行HTTP探测
    prometheus.io/http-probe-port: "9090"     ### 设置HTTP探测的接口
    prometheus.io/http-probe-path: "/-/ready"      ### 设置HTTP探测的地址
    prometheus.io/scrape: "true"      ### 开启prometheus自动发现服务
    prometheus.io/port: "9090"         ### 服务端口
    prometheus.io/scheme: "http"        ### 服务发现方式
    prometheus.io/path: "/metrics"        ### 指标路径
  name: prometheus-service
  namespace: monitoring
spec:
  type: NodePort
  ports:
  - port: 9090
    protocol: TCP
    targetPort: 9090
    nodePort: 31010
  selector:
    app: prometheus
```

### 3. config

```sh
[root@VM-16-9-centos prometheus]# cat prometheus-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server-conf
  labels:
    name: prometheus-server-conf
  namespace: monitoring
data:
  # 新增告警规则文件,可以参考: https://prometheus.io/docs/alerting/latest/notification_examples/
  test-rule.yml: |
    groups:
    - name: Instances
      rules:
      - alert: InstanceDown
        expr: up == 0
        for: 5m
        labels:
          severity: page
        annotations:
          description: ' of job  has been down for more than 5 minutes.'
          summary: 'Instance  down'

  prometheus.yml: |
    global:
      scrape_interval:     15s
      evaluation_interval: 15s 
    alerting:
      alertmanagers:
      - static_configs:
        - targets:
          - alertmanager-nodeport.monitoring:9093
    rule_files:
      - /etc/prometheus/*-rule.yml
    scrape_configs:
      #- job_name: 'prometheus'
        #static_configs:
          #- targets: ['prometheus-service.monitoring:9090']
          
      #- job_name: 'grafana'
        #static_configs:
          #- targets:
              #- 'grafana-service.monitoring:3000'

      - job_name: "kubernetes-etcd"
        scheme: https
        tls_config:
          ca_file: /certs/ca.crt
          cert_file: /certs/healthcheck-client.crt
          key_file: /certs/healthcheck-client.key
          insecure_skip_verify: false
        kubernetes_sd_configs:
        - role: endpoints
          namespaces:
            names: ["kube-system"]
        relabel_configs:
        - action: keep
          source_labels: [__meta_kubernetes_service_label_app_kubernetes_io_name]
          regex: etcd

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

      - job_name: 'kubernetes-nodes'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics

      - job_name: 'kubernetes-cadvisor'
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
        - target_label: __address__
          replacement: kubernetes.default.svc:443
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          target_label: __metrics_path__
          replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor

        ## 下面配置只是用于适配对应的 Grafana Dashboard 图表(这里用编号13105图表)，不同的图表配置不同，不过多介绍
        metric_relabel_configs:
        - source_labels: [instance]
          separator: ;
          regex: (.+)
          target_label: node
          replacement: $1
          action: replace
        - source_labels: [pod_name]
          separator: ;
          regex: (.+)
          target_label: pod
          replacement: $1
          action: replace
        - source_labels: [container_name]
          separator: ;
          regex: (.+)
          target_label: container
          replacement: $1
          action: replace

      - job_name: 'kubernetes-service-endpoints'
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrape]
          action: keep
          regex: true
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scheme]
          action: replace
          target_label: __scheme__
          regex: (https?)
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
          action: replace
          target_label: __address__
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          action: replace
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_service_name]
          action: replace
          target_label: kubernetes_service_name
        - source_labels: [__address__]
          action: replace
          target_label: instance
          regex: (.+):(.+)

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

      - job_name: 'node-exporter'
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - action: replace
          source_labels: [__address__]
          regex: '(.*):10250'
          replacement: '${1}:9100'
          target_label: __address__

      - job_name: "kubernetes-dns"
        metrics_path: /probe
        params:
          ## 配置要使用的模块,要与blackbox exporter配置中的一致
          ## 这里使用DNS模块
          module: [dns_tcp]
        static_configs:
          ## 配置要检测的地址
          - targets:
            - kube-dns.kube-system:53
            - 8.8.4.4:53
            - 8.8.8.8:53
            - 223.5.5.5
        relabel_configs:
          ## 将上面配置的静态DNS服务器地址转换为临时变量 “__param_target”
          - source_labels: [__address__]
            target_label: __param_target
          ## 将 “__param_target” 内容设置为 instance 实例名称
          - source_labels: [__param_target]
            target_label: instance
          ## BlackBox Exporter 的 Service 地址
          - target_label: __address__
            replacement: blackbox-exporter.kube-system:9115

      - job_name: "kubernetes-services"
        metrics_path: /probe
        ## 使用HTTP_GET_2xx与HTTP_GET_3XX模块
        params: 
          module:
          - "http_get_2xx"
          - "http_get_3xx"
        ## 使用Kubernetes动态服务发现,且使用Service类型的发现
        kubernetes_sd_configs:
        - role: service
        relabel_configs:
          ## 设置只监测Kubernetes Service中Annotation里配置了注解prometheus.io/http_probe: true的service
        - action: keep
          source_labels: [__meta_kubernetes_service_annotation_prometheus_io_http_probe]
          regex: "true"
        - action: replace
          source_labels: 
          - "__meta_kubernetes_service_name"
          - "__meta_kubernetes_namespace"
          - "__meta_kubernetes_service_annotation_prometheus_io_http_probe_port"
          - "__meta_kubernetes_service_annotation_prometheus_io_http_probe_path"
          target_label: __param_target
          regex: (.+);(.+);(.+);(.+)
          replacement: $1.$2:$3$4
        - target_label: __address__
          replacement: blackbox-exporter.kube-system:9115
        - source_labels: [__param_target]
          target_label: instance
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - source_labels: [__meta_kubernetes_namespace]
          target_label: kubernetes_namespace
        - source_labels: [__meta_kubernetes_service_name]
          target_label: kubernetes_service_name

      - job_name: "kube-state-metrics"
        kubernetes_sd_configs:
        - role: endpoints
          ## 指定kube-state-metrics组件所在的Namespace名称
          namespaces:
            names: ["kube-system"]
        relabel_configs:
        ## 指定从 app.kubernetes.io/name 标签等于 kube-state-metrics 的 service 服务获取指标信息
        - action: keep
          source_labels: [__meta_kubernetes_service_label_app_kubernetes_io_name]
          regex: kube-state-metrics
        ## 下面配置也是为了适配 Grafana Dashboard 模板(编号13105图表)
        - action: labelmap
          regex: __meta_kubernetes_service_label_(.+)
        - action: replace
          source_labels: [__meta_kubernetes_namespace]
          target_label: k8s_namespace
        - action: replace
          source_labels: [__meta_kubernetes_service_name]
          target_label: kubernetes_service_name
```

### 4. StatefulSet

```sh
[root@VM-16-9-centos prometheus]# cat prometheus-state.yaml 
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: prometheus
  namespace: monitoring
spec:
  serviceName: prometheus
  replicas: 3
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.24.1
        imagePullPolicy: IfNotPresent
        args:
        - "--config.file=/etc/prometheus/prometheus.yml" # 配置文件所在地址，这个地址是相对于容器内部而言的
        - "--storage.tsdb.path=/prometheus"  # 指定tsdb数据路径
        - "--storage.tsdb.retention.time=10d" # 指定删除旧数据的时间。默认为 15d
        - "--web.enable-admin-api"  # 控制对admin HTTP API的访问，其中包括删除时间序列等功能
        - "--web.enable-lifecycle"  # 支持热更新，直接执行localhost:9090/-/reload立即生效
        - "--web.console.libraries=/etc/prometheus/console_libraries"  # 指定控制台组件依赖的存储路径
        - "--web.console.templates=/etc/prometheus/consoles"     # 指定控制台模板的存储路径
        ports:
        - containerPort: 9090
          protocol: TCP
        resources: 
          requests:
            cpu: "100m"
            memory: "512Mi"
          limits:
            cpu: "2000m"
            memory: "2Gi"
        securityContext:
          runAsUser: 0
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9090
          initialDelaySeconds: 5
          timeoutSeconds: 10
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9090
          initialDelaySeconds: 30
          timeoutSeconds: 30
        securityContext:
          runAsUser: 0
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: data
          mountPath: /prometheus
        - name: etcd-certs            #### 将ETCD证书的ConfigMap挂进Prometheus容器 
          readOnly: true
          mountPath: /certs
        - name: host-time
          mountPath: /etc/localtime
          readOnly: true
      - name: configmap-reload
        image: zhentianxiang/configmap-reload:v0.7.1
        args:
        - "--volume-dir=/etc/config"
        - "--webhook-url=http://localhost:9090/-/reload"
        resources:
          limits:
            cpu: 100m
            memory: 100Mi
          requests:
            cpu: 10m
            memory: 10Mi
        volumeMounts:
        - name: config
          mountPath: /etc/config
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: prometheus-server-conf
      - name: etcd-certs
        secret:      
          secretName: etcd-certs
      - name: host-time
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: data
      labels:
        app: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: nfs-provisioner-storage
      resources:
        requests:
          storage: 10Gi
```

### 5. ETCD 服务代理到 Kubernetes 集群

实现 Prometheus 第一步，我们首先需要创建 ETCD 的 Service 和 Endpoints 资源，将 ETCD 代理到 Kubernetes 集群内部，然后给 ETCD Service 添加指定 labels 标签 app.kubernetes.io/name: etcd，这样后续 Prometheus 会通过 Kubernetes 服务发现机制，查找到带有此标签的 Service 关联的应用列表。

将 ETCD 代理到 Kubernetes 的 Endpoints 和 Service 资源配置文件 etcd-proxy.yaml 内容如下:

```sh
[root@VM-16-9-centos prometheus]# cat etcd-proxy.yaml
apiVersion: v1
kind: Service
metadata:
  name: etcd-k8s
  namespace: kube-system
  labels:
    k8s-app: etcd                 ## Kubernetes 会根据该标签和 Endpoints 资源关联
    app.kubernetes.io/name: etcd  ## Prometheus 会根据该标签服务发现到该服务
spec:
  type: ClusterIP
  clusterIP: None                 ## 设置为 None,不分配 Service IP
  ports:
  - name: port
    port: 2379
    protocol: TCP
---
apiVersion: v1
kind: Endpoints
metadata:
  name: etcd-k8s
  namespace: kube-system
  labels:
    k8s-app: etcd
subsets:
- addresses:                      ## 代理的应用IP地址列表
  - ip: 10.0.16.9
  ports:
  - port: 2379
```

```sh
[root@VM-16-9-centos prometheus]# kubectl create secret generic etcd-certs   --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.crt   --from-file=/etc/kubernetes/pki/etcd/healthcheck-client.key   --from-file=/etc/kubernetes/pki/etcd/ca.crt   -n monitoring
[root@VM-16-9-centos prometheus]# kubectl apply -f .
[root@VM-16-9-centos prometheus]# kubectl get pods -n monitoring 
NAME                  READY   STATUS    RESTARTS   AGE
node-exporter-qckcq   1/1     Running   0          94m
prometheus-0          1/1     Running   0          141m
prometheus-1          1/1     Running   0          140m
prometheus-2          1/1     Running   0          142m
```

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/5.png)

## 五、Grafana

### 1. state

```sh
[root@VM-16-9-centos grafana]# cat gragana-state.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: grafana
  namespace: monitoring
spec:
  serviceName: grafana
  replicas: 2
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      securityContext:
        fsGroup: 472
        supplementalGroups:
          - 0
      containers:
        - name: grafana
          image: grafana/grafana:8.4.4
          imagePullPolicy: IfNotPresent
          env:
          - name: GF_SECURITY_ADMIN_USER
            value: "admin"
          - name: GF_SECURITY_ADMIN_PASSWORD
            value: "password123"
          ports:
            - containerPort: 3000
              name: http-grafana
              protocol: TCP
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /robots.txt
              port: 3000
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 30
            successThreshold: 1
            timeoutSeconds: 2
          livenessProbe:
            failureThreshold: 3
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            tcpSocket:
              port: 3000
            timeoutSeconds: 1
          resources:
            requests:
              cpu: "250m"
              memory: "750Mi"
            limits:
              cpu: "1000m"
              memory: "2Gi"
          volumeMounts:
            - mountPath: /var/lib/grafana
              name: grafana-data
            - name: host-time
              mountPath: /etc/localtime
              readOnly: true
      volumes:
      - name: host-time
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: grafana-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: nfs-provisioner-storage
      resources:
        requests:
          storage: 10Gi
```

### 2. service

```sh
[root@VM-16-9-centos grafana]# cat gragana-clusterip.yaml 
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  clusterIP: None
  ports:
  - port: 3000
    protocol: TCP
    targetPort: 3000
  selector:
    app: grafana
```

```sh
[root@VM-16-9-centos grafana]# cat gragana-service.yaml 
apiVersion: v1
kind: Service
metadata:
  annotations:
    prometheus.io/http-probe: "true"        ### 设置该服务执行HTTP探测
    prometheus.io/http-probe-port: "3000"     ### 设置HTTP探测的接口
    prometheus.io/http-probe-path: "/robots.txt"      ### 设置HTTP探测的地址
    prometheus.io/scrape: "true"      ### 开启prometheus自动发现服务
    prometheus.io/port: "3000"         ### 服务端口
    prometheus.io/scheme: "http"        ### 服务发现方式
    prometheus.io/path: "/metrics"        ### 指标路径
  name: grafana-service
  namespace: monitoring
spec:
  type: NodePort
  ports:
  - port: 3000
    protocol: TCP
    targetPort: 3000
    nodePort: 30300
  selector:
    app: grafana
```

```sh
[root@VM-16-9-centos grafana]# kubectl get pods -n monitoring 
NAME                  READY   STATUS    RESTARTS   AGE
cadvisor-8zf2q        1/1     Running   0          5d23h
grafana-0             1/1     Running   0          112m
grafana-1             1/1     Running   0          110m
node-exporter-qckcq   1/1     Running   0          98m
prometheus-0          1/1     Running   0          145m
prometheus-1          1/1     Running   0          145m
prometheus-2          1/1     Running   0          145m
```

## 六、Alter manager

AlertManager 是一个专门用于实现告警的工具，可以实现接收 Prometheus 或其它应用发出的告警信息，并且可以对这些告警信息进行 **分组**、**抑制** 以及 **静默** 等操作，然后通过 **路由** 的方式，根据不同的告警规则配置，分发到不同的告警路由策略中。

除此之外，AlertManager 还支持 "邮件"、"企业微信"、"Slack"、"WebHook" 等多种方式发送告警信息，并且其中 WebHook 这种方式可以将告警信息转发到我们自定义的应用中，使我们可以对告警信息进行处理，所以使用 AlertManager 进行告警，非常方便灵活、简单易用。

AlertManager 常用的功能主要有:

- **抑制:** 抑制是一种机制，指的是当某一告警信息发送后，可以停止由此告警引发的其它告警，避免相同的告警信息重复发送。
- **静默:** 静默也是一种机制，指的是依据设置的标签，对告警行为进行静默处理。如果 AlertManager 接收到的告警符合静默配置，则 Alertmanager 就不会发送该告警通知。
- **发送告警:** 支持配置多种告警规则，可以根据不同的路由配置，采用不同的告警方式发送告警通知。
- **告警分组:** 分组机制可以将详细的告警信息合并成一个通知。在某些情况下，如系统宕机导致大量的告警被同时触发，在这种情况下分组机制可以将这些被触发的告警信息合并为一个告警通知，从而避免一次性发送大量且属于相同问题的告警，导致无法对问题进行快速定位。

其中 Prometheus 和 AlertManager 的关系如下图所示:

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/6.png)

### 1. config

```sh
[root@VM-16-9-centos altermanager]# cat alertmanager-config.yaml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |-
    global:
      ## 持续多少时间没有触发告警,则认为处于告警问题已经解决状态的时间
      resolve_timeout: 5m
      ## 配置邮件发送信息
      smtp_smarthost: 'smtp.qq.com:25'
      smtp_from: '2099637909@qq.com'
      smtp_auth_username: '2099637909@qq.com'
      smtp_auth_password: 'plttbwepeuindjca'
      smtp_require_tls: false
    # 所有报警信息进入后的根路由，用来设置报警的分发策略
    route:
      ## 这里的标签列表是接收到报警信息后的重新分组标签,例如接收到的报警信息里面有许多具有 cluster=A 这样的标签,可以根据这些标签,将告警信息批量聚合到一个分组里面中
      group_by: ['alertname', 'cluster']
      ## 当一个新的报警分组被创建后,需要等待至少group_wait时间来初始化通知,这种方式可以确保能有足够的时间为同一分组来汇入尽可能多的告警信息,然后将这些汇集的告警信息一次性触发
      group_wait: 30s
      ## 当第一个报警发送后，等待 group_interval 时间来发送新的一组报警信息
      group_interval: 5m
      ## 如果一个报警信息已经发送成功了,则需要等待 repeat_interval 时间才能重新发送
      repeat_interval: 5m
      ## 配置默认的路由规则
      receiver: default
      ## 配置子路由规则,如果一个告警没有被任何一个子路由规则匹配，就会使用default配置
      #routes:
      #- receiver: webhook
      #  group_wait: 10s
      #  match:
      #    team: node
    receivers:
    - name: 'default'
      email_configs:
      - to: '2099637909@qq.com'
        send_resolved: true
```

### 2. state

```sh
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: alertmanager
  namespace: monitoring
  labels:
    k8s-app: alertmanager
spec:
  serviceName: alertmanager
  replicas: 2
  selector:
    matchLabels:
      k8s-app: alertmanager
  template:
    metadata:
      labels:
        k8s-app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:v0.24.0
        ports:
        - name: http
          containerPort: 9093
        args:
        ## 指定容器中AlertManager配置文件存放地址 (Docker容器中的绝对位置)
        - "--config.file=/etc/alertmanager/alertmanager.yml"
        ## 指定AlertManager管理界面地址，用于在发生的告警信息中,附加AlertManager告警信息页面地址，因为用的nginx做的虚拟主机
        - "--web.external-url=http://alert.linuxtian.top"  
        ## 指定监听的地址及端口
        - '--cluster.advertise-address=0.0.0.0:9093'
        ## 指定数据存储位置 (Docker容器中的绝对位置)
        - "--storage.path=/alertmanager"
        resources:
          limits:
            cpu: 1000m
            memory: 512Mi
          requests:
            cpu: 1000m
            memory: 512Mi
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9093
          initialDelaySeconds: 5
          timeoutSeconds: 10
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9093
          initialDelaySeconds: 30
          timeoutSeconds: 30
        volumeMounts:
        - name: data
          mountPath: /alertmanager 
        - name: config
          mountPath: /etc/alertmanager
      - name: configmap-reload
        image: zhentianxiang/configmap-reload:v0.7.1
        args:
        - "--volume-dir=/etc/config"
        - "--webhook-url=http://localhost:9093/-/reload"
        resources:
          limits:
            cpu: 100m
            memory: 100Mi
          requests:
            cpu: 100m
            memory: 100Mi
        volumeMounts:
        - name: config
          mountPath: /etc/config
          readOnly: true
        - name: host-time
          mountPath: /etc/localtime
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: alertmanager-config
      - name: host-time
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: nfs-provisioner-storage
      resources:
        requests:
          storage: 10Gi
```

### 2. service.yaml

```sh
[root@VM-16-9-centos altermanager]# cat alertmanager-service.yaml
apiVersion: v1
kind: Service
metadata:
metadata:
  annotations:
    prometheus.io/http-probe: "true"        ### 设置该服务执行HTTP探测
    prometheus.io/http-probe-port: "9093"     ### 设置HTTP探测的接口
    prometheus.io/http-probe-path: "/-/ready"      ### 设置HTTP探测的地址
    prometheus.io/scrape: "true"      ### 开启prometheus自动发现服务
    prometheus.io/port: "9093"         ### 服务端口
    prometheus.io/scheme: "http"        ### 服务发现方式
    prometheus.io/path: "/metrics"        ### 指标路径
  name: alertmanager-nodeport
  namespace: monitoring
  labels:
    k8s-app: alertmanager
spec:
  type: NodePort
  ports:
  - name: http
    port: 9093
    targetPort: 9093
    nodePort: 30903
  selector:
    k8s-app: alertmanager
```

```sh
[root@VM-16-9-centos altermanager]# cat alertmanager-clusterip.yaml
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: monitoring
  labels:
    k8s-app: alertmanager
spec:
  clusterIP: None
  ports:
  - name: http
    port: 9093
    targetPort: 9093
  selector:
    k8s-app: alertmanager
```

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/7.png)

### 3. Prometheus 配置 AlertManager 配置和 Rules 告警规则

本人部署的 Prometheus 是完全按照之前写的 [Kubernetes 部署 Prometheus](http://www.mydlq.club/article/110/) 文章进行部署的，在那篇文章中使用了 ConfigMap 资源存储 Prometheus 配置文件，所以这里需要对 Prometheus 配置文件进行改动，就需要修改 ConfigMap 资源文件 `prometheus-config.yaml`，改动内容如下:

- (1) 添加 AlertManager 服务器地址；
- (2) 指定告警规则文件路径位置；
- (3) 添加 Prometheus 中触发告警的告警规则；

**prometheus-config.yaml**

```sh
[root@VM-16-9-centos prometheus]# cat cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server-conf
  labels:
    name: prometheus-server-conf
  namespace: monitoring
data:
  prometheus.yml: |
    # my global config
    global:
      scrape_interval:     15s  # Set the scrape interval to every 15 seconds. Default is every 1 minute.
      evaluation_interval: 15s  # Evaluate rules every 15 seconds. The default is every 1 minute.
      # scrape_timeout is set to the global default (10s).

    # Alertmanager 服务器地址
    alerting:
      alertmanagers:
      - static_configs:
        - targets:
          - alertmanager-nodeport.monitoring:9093

    # 告警配置规则
    rule_files:
    - /etc/prometheus/rules/*-rules.yml
```

编写rules告警规则
```sh
[root@VM-16-9-centos prometheus]# vim prometheus-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-rules-conf
  labels:
    name: prometheus-rules-conf
  namespace: monitoring
data:
  # 新增告警规则文件,可以参考: https://prometheus.io/docs/alerting/latest/notification_examples/
  Node-rules.yml: |
    groups:
      - name: Node-rules
        rules:
          - alert: CPU使用率大于80%告警规则
            expr: 100 * (1 - avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])))> 80
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: "监测到高CPU使用率"
              description: "最近 1 分钟{{ $labels.instance }}的平均 CPU 使用率超过 80% , 当前使用率{{ $value }}%"

          - alert: CPU负载大于80%告警规则
            expr: 100 * (avg by (instance) (irate(node_load1[5m]))) > 80
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: "监测到高CPU负载"
              description: "最近 1 分钟{{ $labels.instance }}的平均 CPU 负载超过 80% , 当前负载{{ $value }}%"

          - alert: 内存使用率大于90%告警规则
            expr: 100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) > 90
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: "监测到节点内存高使用率"
              description: "最近 1 分钟{{ $labels.instance }}的内存使用率超过 90% , 当前使用率{{ $value }}%"

          - alert: 磁盘使用率大于80%告警规则
            expr: round(100-(node_filesystem_free_bytes{fstype=~"ext4|xfs"}/node_filesystem_size_bytes {fstype=~"ext4|xfs"}*100)) > 80
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: "检测到节点磁盘高使用率"
              description: "最近 1 分钟{{ $labels.instance }}的磁盘使用率超过 80% , 当前已使用{{ $value }}G"


          - alert: "IO使用率过高"
            expr: 100-(avg(irate(node_disk_io_time_seconds_total[1m])) by(instance)* 100) < 60
            for: 15s
            labels:
              severity: warning
            annotations:
              summary: "IO使用率过高"
              description: "当前使用率{{ $value }}%"
        
          - alert: "网络流出速率过高"
            expr: round(irate(node_network_receive_bytes_total{instance!~"data.*",device!~'tap.*|veth.*|br.*|docker.*|vir.*|lo.*|vnet.*'}[1m])/1024) > 2048
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: "网络流出速率过高"
              description: "当前速率{{ $value }}KB/s"
        
          - alert: "会话链接数过高"
            expr: node_netstat_Tcp_CurrEstab > 500
            for: 1m
            labels:
              severity: warning
            annotations:
              summary: "当前会话连接数过高"
              description: "当前连接数{{ $value }}"
```

修改 prometheus 启动配置文件，新加 volume 挂载

```sh
[root@VM-16-9-centos prometheus]# vim prometheus-state.yaml
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: rules         #### 挂载 rules 告警配置文件
          mountPath: /etc/prometheus/rules
      volumes:
      - name: config
        configMap:
          name: prometheus-server-conf
      - name: rules       #### 挂载 rules 告警配置文件
        configMap:
          name: prometheus-rules-conf
```

提交 rules configmap 和重新提交 prometheus

```sh
[root@VM-16-9-centos prometheus]# kubectl apply -f prometheus-rules.yaml
[root@VM-16-9-centos prometheus]# kubectl apply -f prometheus-state.yaml
```


![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/8.png)

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/9.png)

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/10.png)

通过以上三个页面，就可以判断规则已经生效，不过需要提前说明的是，由于上面设置的告警规则中的告警条件为 `up == 0`，意思就是当全部 Prometheus 监控的应用健康状态都为 `0` 不健康状态时才会触发告警。

但是又因为上面 Prometheus 配置文件中设置了监控 Prometheus 自身，而 Prometheus 正常运行时指标 `up` 的值至少为 `1`，即 `up > 0`，所以告警状态从始至终都为没有触发告警的 `inactive` 状态。

### 4. 修改 Prometheus 告警规则配置

为了方便触发 Prometheus 中的告警规则，所以我们将上面配置的告警规则中的 `up == 0` 修改为 `up > 0`，确保现有 Prometheus 中的指标值能够触发告警，修改后的 Prometheus 配置文件如下:

- **prometheus-config.yaml**

```sh
[root@VM-16-9-centos prometheus]# cat prometheus-config.yaml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-server-conf
  labels:
    name: prometheus-server-conf
  namespace: monitoring
data:
  # 新增告警规则文件,可以参考: https://prometheus.io/docs/alerting/latest/notification_examples/
  test-rule.yml: |
    groups:
    - name: Instances
      # 将 up == 0 修改为 up > 0，如下:
      rules:
      - alert: InstanceDown
        expr: up > 0
        for: 5m
        labels:
          severity: page
        annotations:
          description: '{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 5 minutes.'
          summary: 'Instance {{ $labels.instance }} down'
```

```sh
# 使用热加载服务
[root@VM-16-9-centos prometheus]# curl -X POST 10.99.50.208:9090/-/reload
```

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/11.png)

然后进行等待，如果 Prometheus 中的指标 `up > 0` 值在5分钟内持续成立，那么配置的告警规则状态将变为 `FIRING`，如下图所示:

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/12.png)

看到上图中的这条信息，则说明 AlertManager 已经成功发送告警信息，所以我们查看配置的接收者的邮箱，是否成功接收到告警邮件。

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/13.png)

查看邮箱

![](/images/posts/Linux-Kubernetes/Kubernetes部署Prometheus服务/14.png)
