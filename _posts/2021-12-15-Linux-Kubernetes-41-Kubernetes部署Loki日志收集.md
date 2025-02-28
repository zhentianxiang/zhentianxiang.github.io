---
layout: post
title: Linux-Kubernetes-41-Kubernetes部署Loki日志收集
date: 2021-12-15
tags: 实战-Kubernetes
---

Loki是受Prometheus启发由Grafana Labs团队开源的水平可扩展，高度可用的多租户日志聚合系统。 开发语言: Google Go。它的设计具有很高的成本效益，并且易于操作。使用标签来作为索引，而不是对全文进行检索，也就是说，你通过这些标签既可以查询日志的内容也可以查询到监控的数据签，极大地降低了日志索引的存储。系统架构十分简单，由以下3个部分组成 ：
1.Loki 是主服务器，负责存储日志和处理查询 。
2.promtail 是代理，负责收集日志并将其发送给 loki 。
3.Grafana 用于 UI 展示。

## 一、Loki与ELK/EFK对比

ELK
优势：
- 功能丰富，允许复杂的操作
劣势：
- 主流的ELK（全文检索）或者EFK比较重
- ES复杂的搜索功能很多都用不上 规模复杂，资源占用高，操作苦难，大多数查询只关注一定时间范围和一些简单的参数（如host、service等）
- Kibana和Grafana之间切换，影响用户体验
- 倒排索引的切分和共享的成本较高

Loki
- 最小化度量和日志的切换成本，有助于减少异常事件的响应时间和提高用户的体验
- 在查询语言的易操作性和复杂性之间可以达到一个权衡
- 更具成本效益

## 二、Loki的架构

![](/images/posts/Linux-Kubernetes/k8s_loki/1.png)

> promtail收集并将日志发送给loki的 Distributor 组件
Distributor会对接收到的日志流进行正确性校验，并将验证后的日志分批并行发送到Ingester
Ingester 接受日志流并构建数据块，压缩后存放到所连接的存储后端
Querier 收到HTTP查询请求，并将请求发送至Ingester 用以获取内存数据 ，Ingester 收到请求后返回符合条件的数据 ；
如果 Ingester 没有返回数据，Querier 会从后端存储加载数据并遍历去重执行查询 ，通过HTTP返回查询结果

## 三、Loki在K8s中部署

### 1. 准备storageclass做持久化存储

过程略过，可以参考之前的nfs-provisioner，这篇文章有教你如何做持久化存储：http://blog.tianxiang.love/2021/08Linux-Kubernetes-34-交付EFK到K8S/

### 2. 准备Rbac.yaml

```yaml
[root@k8s-kubersphere loki]# cat > Rbac.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: loki
  namespace: loki
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: Role
metadata:
  name: loki
  namespace: loki
rules:
  - apiGroups:
    - extensions
    resourceNames:
    - loki
    resources:
    - podsecuritypolicies
    verbs:
    - use
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: RoleBinding
metadata:
  name: loki
  namespace: loki
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: loki
subjects:
- kind: ServiceAccount
  name: loki
EOF
```

### 3. 准备ConfigMap.yaml

```yaml
[root@k8s-kubersphere loki]# cat > ConfigMap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki
  namespace: loki
  labels:
    app: loki
data:
  loki.yaml: |
    auth_enabled: false
    ingester:
      chunk_idle_period: 3m      # 如果块没有达到最大的块大小，那么在刷新之前，块应该在内存中不更新多长时间
      chunk_block_size: 262144
      chunk_retain_period: 1m      # 块刷新后应该在内存中保留多长时间
      max_transfer_retries: 0      # Number of times to try and transfer chunks when leaving before falling back to flushing to the store. Zero = no transfers are done.
      lifecycler:       #配置ingester的生命周期，以及在哪里注册以进行发现
        ring:
          kvstore:
            store: inmemory      # 用于ring的后端存储，支持consul、etcd、inmemory
          replication_factor: 1      # 写入和读取的ingesters数量，至少为1（为了冗余和弹性，默认情况下为3）
    limits_config:
      enforce_metric_name: false
      reject_old_samples: true      # 旧样品是否会被拒绝
      reject_old_samples_max_age: 168h      # 拒绝旧样本的最大时限
      ingestion_rate_mb: 10    # 每个用户每秒的采样率限制
      ingestion_burst_size_mb: 20    # 每个用户允许的采样突发大小
    schema_config:      # 配置从特定时间段开始应该使用哪些索引模式
      configs:
      - from: 2020-10-24      # 创建索引的日期。如果这是唯一的schema_config，则使用过去的日期，否则使用希望切换模式时的日期
        store: boltdb-shipper      # 索引使用哪个存储，如：cassandra, bigtable, dynamodb，或boltdb
        object_store: filesystem      # 用于块的存储，如：gcs, s3， inmemory, filesystem, cassandra，如果省略，默认值与store相同
        schema: v11
        index:      # 配置如何更新和存储索引
          prefix: index_      # 所有周期表的前缀
          period: 24h      # 表周期
    server:
      http_listen_port: 3100
    storage_config:      # 为索引和块配置一个或多个存储
      boltdb_shipper:
        active_index_directory: /data/loki/boltdb-shipper-active
        cache_location: /data/loki/boltdb-shipper-cache
        cache_ttl: 24h         
        shared_store: filesystem
      filesystem:
        directory: /data/loki/chunks
    chunk_store_config:      # 配置如何缓存块，以及在将它们保存到存储之前等待多长时间
      max_look_back_period: 0s      #限制查询数据的时间，默认是禁用的，这个值应该小于或等于table_manager.retention_period中的值
    table_manager:
      retention_deletes_enabled: false      # 日志保留周期开关，用于表保留删除
      retention_period: 0s       # 日志保留周期，保留期必须是索引/块的倍数
    compactor:
      working_directory: /data/loki/boltdb-shipper-compactor
      shared_store: filesystem
EOF
```

### 4. 准备Statefulsets.yaml

```yaml
[root@k8s-kubersphere loki]# cat > Statefulsets.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: loki
  namespace: loki
  labels:
    app: loki
    release: loki
spec:
  type: NodePort
  ports:
    - port: 3100
      protocol: TCP
      name: http-metrics
      targetPort: http-metrics
      nodePort: 30201
  selector:
    app: loki
    release: loki
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: loki
  namespace: loki
  labels:
    app: loki
    release: loki
spec:
  podManagementPolicy: OrderedReady
  replicas: 1
  selector:
    matchLabels:
      app: loki
      release: loki
  serviceName: loki
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: loki
        release: loki
    spec:
      serviceAccountName: loki
      initContainers:
      - name: chmod-data
        image: busybox:1.28.4
        imagePullPolicy: IfNotPresent
        command: ["chmod","-R","777","/loki/data"]
        volumeMounts:
        - name: storage
          mountPath: /loki/data
      containers:
        - name: loki
          image: grafana/loki:2.9.6
          imagePullPolicy: IfNotPresent
          args:
            - -config.file=/etc/loki/loki.yaml
          volumeMounts:
            - name: config
              mountPath: /etc/loki
            - name: storage
              mountPath: /data
            - name: wal
              mountPath: /wal
          ports:
            - name: http-metrics
              containerPort: 3100
              protocol: TCP
          livenessProbe:
            httpGet: 
              path: /ready
              port: http-metrics
              scheme: HTTP
            initialDelaySeconds: 45
          readinessProbe:
            httpGet: 
              path: /ready
              port: http-metrics
              scheme: HTTP
            initialDelaySeconds: 45
          securityContext:
            readOnlyRootFilesystem: true
      terminationGracePeriodSeconds: 4800
      volumes:
        - name: config
          configMap:
            name: loki
        - name: wal
          emptyDir: {}
  volumeClaimTemplates:
  - metadata:
      name: storage
      labels:
        app: loki
        release: loki
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: nfs-provisioner-storage
      resources:
        requests:
          storage: 100Gi
EOF
```

### 5.准备service.yaml

```yaml
[root@k8s-kubersphere loki]# cat > service.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: loki
  namespace: loki
  labels:
    app: loki
    release: loki
spec:
  ports:
  - name: http-metrics
    port: 3100
    protocol: TCP
    targetPort: 3100
#    nodePort: 32001
  type: NodePort  
  selector:
    app: loki
    release: loki
---
apiVersion: v1
kind: Service
metadata:
  name: loki-headless
  namespace: loki
  labels:
    app: loki
    release: loki
spec:
  clusterIP: None
  ports:
  - name: http-metrics
    port: 3100
    protocol: TCP
    targetPort: http-metrics
  selector:
    app: loki
    release: loki
EOF
```

```sh
[root@k8s-master01 loki]# kubectl get svc -n loki 
NAME            TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
loki            NodePort    10.111.200.188   <none>        3100:30201/TCP   113m
loki-headless   ClusterIP   None             <none>        3100/TCP         122m
```

## 四、部署promtail

### 1. 准备ConfigMap.yaml

```yaml
[root@k8s-kubersphere promtail]# cat > ConfigMap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-promtail
  namespace: loki
  labels:
    app: promtail
data:
  promtail.yaml: |
    client:      # 配置Promtail如何连接到Loki的实例
      backoff_config:      # 配置当请求失败时如何重试请求给Loki
        max_period: 5m
        max_retries: 10
        min_period: 500ms
      batchsize: 4194304      # 发送给Loki的最大批次大小(以字节为单位)
      batchwait: 1s      # 发送批处理前等待的最大时间（即使批次大小未达到最大值）
      external_labels: {}      # 所有发送给Loki的日志添加静态标签
      timeout: 10s      # 等待服务器响应请求的最大时间
    positions:
      filename: /run/promtail/positions.yaml
    server:
      http_listen_port: 3101
    target_config:
      sync_period: 10s
    scrape_configs:
    - job_name: kubernetes-pods-name
      pipeline_stages:
        - docker: {}
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - source_labels:
        - __meta_kubernetes_pod_label_name
        target_label: __service__
      - source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: __host__
      - action: drop
        regex: ''
        source_labels:
        - __service__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        replacement: $1
        separator: /
        source_labels:
        - __meta_kubernetes_namespace
        - __service__
        target_label: job
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container
      - replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_uid
        - __meta_kubernetes_pod_container_name
        target_label: __path__
    - job_name: kubernetes-pods-app
      pipeline_stages:
        - docker: {}
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - action: drop
        regex: .+
        source_labels:
        - __meta_kubernetes_pod_label_name
      - source_labels:
        - __meta_kubernetes_pod_label_app
        target_label: __service__
      - source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: __host__
      - action: drop
        regex: ''
        source_labels:
        - __service__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        replacement: $1
        separator: /
        source_labels:
        - __meta_kubernetes_namespace
        - __service__
        target_label: job
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container
      - replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_uid
        - __meta_kubernetes_pod_container_name
        target_label: __path__
    - job_name: kubernetes-pods-direct-controllers
      pipeline_stages:
        - docker: {}
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - action: drop
        regex: .+
        separator: ''
        source_labels:
        - __meta_kubernetes_pod_label_name
        - __meta_kubernetes_pod_label_app
      - action: drop
        regex: '[0-9a-z-.]+-[0-9a-f]{8,10}'
        source_labels:
        - __meta_kubernetes_pod_controller_name
      - source_labels:
        - __meta_kubernetes_pod_controller_name
        target_label: __service__
      - source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: __host__
      - action: drop
        regex: ''
        source_labels:
        - __service__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        replacement: $1
        separator: /
        source_labels:
        - __meta_kubernetes_namespace
        - __service__
        target_label: job
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container
      - replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_uid
        - __meta_kubernetes_pod_container_name
        target_label: __path__
    - job_name: kubernetes-pods-indirect-controller
      pipeline_stages:
        - docker: {}
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - action: drop
        regex: .+
        separator: ''
        source_labels:
        - __meta_kubernetes_pod_label_name
        - __meta_kubernetes_pod_label_app
      - action: keep
        regex: '[0-9a-z-.]+-[0-9a-f]{8,10}'
        source_labels:
        - __meta_kubernetes_pod_controller_name
      - action: replace
        regex: '([0-9a-z-.]+)-[0-9a-f]{8,10}'
        source_labels:
        - __meta_kubernetes_pod_controller_name
        target_label: __service__
      - source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: __host__
      - action: drop
        regex: ''
        source_labels:
        - __service__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        replacement: $1
        separator: /
        source_labels:
        - __meta_kubernetes_namespace
        - __service__
        target_label: job
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container
      - replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_uid
        - __meta_kubernetes_pod_container_name
        target_label: __path__
    - job_name: kubernetes-pods-static
      pipeline_stages:
        - docker: {}
      kubernetes_sd_configs:
      - role: pod
      relabel_configs:
      - action: drop
        regex: ''
        source_labels:
        - __meta_kubernetes_pod_annotation_kubernetes_io_config_mirror
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_label_component
        target_label: __service__
      - source_labels:
        - __meta_kubernetes_pod_node_name
        target_label: __host__
      - action: drop
        regex: ''
        source_labels:
        - __service__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - action: replace
        replacement: $1
        separator: /
        source_labels:
        - __meta_kubernetes_namespace
        - __service__
        target_label: job
      - action: replace
        source_labels:
        - __meta_kubernetes_namespace
        target_label: namespace
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_name
        target_label: pod
      - action: replace
        source_labels:
        - __meta_kubernetes_pod_container_name
        target_label: container
      - replacement: /var/log/pods/*$1/*.log
        separator: /
        source_labels:
        - __meta_kubernetes_pod_annotation_kubernetes_io_config_mirror
        - __meta_kubernetes_pod_container_name
        target_label: __path__
EOF
```

### 2. 准备DaemonSet.yaml

```yaml
[root@k8s-kubersphere promtail]# cat > DaemonSet.yaml <<EOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: loki-promtail
  namespace: loki
  labels:
    app: promtail
spec:
  selector:
    matchLabels:
      app: promtail
  updateStrategy:
    rollingUpdate:
      maxUnavailable: 1
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: promtail
    spec:
      serviceAccountName: loki-promtail
      containers:
        - name: promtail
          image: grafana/promtail:2.9.3
          imagePullPolicy: IfNotPresent
          args:
          - -config.file=/etc/promtail/promtail.yaml
          - -client.url=http://10.111.200.188:3100/loki/api/v1/push
          # 注意这里我填写的是 Loki 的service地址
          env:
          - name: HOSTNAME
            valueFrom:
              fieldRef:
                apiVersion: v1
                fieldPath: spec.nodeName
          volumeMounts:
          - name: config
            mountPath: /etc/promtail
          - name: run
            mountPath: /run/promtail
          - name: var-lib-docker
            readOnly: true
            mountPath: /var/lib/docker/containers
          - name: pods
            readOnly: true
            mountPath: /var/log/pods
          ports:
          - containerPort: 3101
            name: http-metrics
            protocol: TCP
          securityContext:
            readOnlyRootFilesystem: true
            runAsGroup: 0
            runAsUser: 0
          readinessProbe:
            failureThreshold: 5
            httpGet:
              path: /ready
              port: http-metrics
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 10
            successThreshold: 1
            timeoutSeconds: 1
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
        operator: Exists
      volumes:
        - name: config
          configMap:
            defaultMode: 493
            name: loki-promtail
        - name: run
          hostPath:
            path: /run/promtail
            type: ""
        - name: var-lib-docker
          hostPath:
            path: /var/lib/docker/containers  # 注意你的docker存储目录是否是这个
        - name: pods
          hostPath:
            path: /var/log/pods
EOF
```

### 3. 准备Rbac.yaml

```yaml
[root@k8s-kubersphere promtail]# cat > Rbac.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: loki-promtail
  labels:
    app: promtail
  namespace: loki

---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  labels:
    app: promtail
  name: promtail-clusterrole
  namespace: kube-system
rules:
- apiGroups: [""] # "" indicates the core API group
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "watch", "list"]

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: promtail-clusterrolebinding
  labels:
    app: promtail
  namespace: loki
subjects:
  - kind: ServiceAccount
    name: loki-promtail
    namespace: loki
roleRef:
  kind: ClusterRole
  name: promtail-clusterrole
  apiGroup: rbac.authorization.k8s.io
EOF
```

## 五、启动服务

最后把所有的yaml文件apply一下，等待服务全部启动

```sh
[root@k8s-master01 promtail]# kubectl get pods -n loki 
NAME                  READY   STATUS    RESTARTS   AGE
loki-0                1/1     Running   0          115m
loki-promtail-45dc6   1/1     Running   0          108m
loki-promtail-hpbtp   1/1     Running   0          109m

```

## 六、Grafana配置Loki

![](/images/posts/Linux-Kubernetes/k8s_loki/2.png)

![](/images/posts/Linux-Kubernetes/k8s_loki/3.png)

![](/images/posts/Linux-Kubernetes/k8s_loki/4.png)

![](/images/posts/Linux-Kubernetes/k8s_loki/5.png)

![](/images/posts/Linux-Kubernetes/k8s_loki/6.png)

![](/images/posts/Linux-Kubernetes/k8s_loki/7.png)

![](/images/posts/Linux-Kubernetes/k8s_loki/8.png)

## 七、报错

loki-promtail服务日志报错

```sh
level=warn ts=2021-12-15T08:38:26.249917689Z caller=client.go:344 component=client host=loki.loki.svc.cluster.local:3100 msg="error sending batch, will retry" status=429 error="server returned HTTP status 429 Too Many Requests (429): Ingestion rate limit exceeded (limit: 4194304 bytes/sec) while attempting to ingest '16995' lines totaling '4194150' bytes, reduce log volume or contact your Loki administrator to see if the limit can be increased"
```

**问题**

因为你要收集的日志太多了，超过了 loki 的限制，所以会报 429 错误，如果你要增加限制可以修改 loki 的配置文件

**解决方法**

在 limits_config: 字段下添加两行内容

```yaml
[root@k8s-kubersphere loki]# vim ConfigMap.yaml
    limits_config:
      ingestion_rate_mb: 10    # 每个用户每秒的采样率限制
      ingestion_burst_size_mb: 20    # 每个用户允许的采样突发大小
```
重启loki服务
```sh
[root@k8s-kubersphere loki]# kubectl apply -f ConfigMap.yaml
[root@k8s-kubersphere loki]# kubectl delete pod -n loki loki-5cfc9dcb47-gc2w8
```

再次查看loki-promtail服务日志正常

```sh
level=info ts=2021-12-15T09:21:18.111711838Z caller=tailer.go:174 component=tailer msg="skipping update of position for a file which does not currently exist" path=/var/log/pods/hyperdl_dev-center-859dbc44c8-2ftbv_95c70437-a449-4652-8547-f3cac1a41361/writing-sys-center/13.log
level=info ts=2021-12-15T09:21:18.202355982Z caller=tailer.go:174 component=tailer msg="skipping update of position for a file which does not currently exist" path=/var/log/pods/hyper-rt_hyperrt-dev-center-846f6cff8d-pncpb_aa7cdf4f-27cc-4c3f-a1a5-76b6f2a53e7e/writing-user-auth/14.log
```
