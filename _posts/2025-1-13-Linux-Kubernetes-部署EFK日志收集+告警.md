---
layout: post
title: Linux-Kubernetes-部署EFK日志收集+告警
date: 2025-1-13
tags: 实战-Kubernetes
---

## 一、简介

### 1. 关于云原生中日志

随着现在各种软件系统的复杂度越来越高，特别是部署到云上之后，再想登录各个节点上查看各个模块的log，基本是不可行了。因为不仅效率低下，而且有时由于安全性，不可能让工程师直接访问各个物理节点。而且现在大规模的软件系统基本都采用集群的部署方式，意味着对每个service，会启动多个完全一样的POD对外提供服务，每个container都会产生自己的log，仅从产生的log来看，你根本不知道是哪个POD产生的，这样对查看分布式的日志更加困难。

所以在云时代，需要一个收集并分析log的解决方案。首先需要将分布在各个角落的log收集到一个集中的地方，方便查看。收集了之后，还可以进行各种统计分析，甚至用流行的大数据或maching learning的方法进行分析。当然，对于传统的软件部署方式，也需要这样的log的解决方案，不过本文主要从云的角度来介绍。

### 2. 架构介绍

关于什么是EFK，首先 E 代表的是：Elasticsearch，他是一个搜索引擎，负责存储日志并提供查询接口，同样可以理解为存储日志的数据库，F 代表的是：Fluentd，负责从 Kubernetes 搜集日志，每个 node 节点上面的 fluentd 监控并收集该节点上面的系统日志，并将处理过后的日志信息发送给 Elasticsearch，同样收集日志的工具还有 Filebeat 和 logstash 每个都有不同的用处，Filebeat 还可以充当 sidecar 边车模式运行在 pod 中他们挂在同一个日志目录通过这种方式收集日志来推送到 Elasticsearch 中，而 logstash 支持的功能比较多对于日志的处理比较更加细致所以相对来说更加吃系统资源，K 代表的就是 Kibana 他提供了一个 Web GUI，用户可以浏览和搜索存储在 Elasticsearch 中的日志。

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/EFK-stack-on-Kubernetes.png)

### 3. Elastalert 告警功能

Elastalert是Yelp公司基于python开发的ELK日志告警插件，Elastalert通过查询Elasticsearch中的记录与定于的告警规则进行对比，判断是否满足告警条件。发生匹配时，将为该告警触发一个或多个告警动作。告警规则由Elastalert的rules定义，每个规则定义一个查询。

**工作原理**

周期性的查询Elastsearch并且将数据传递给规则类型，规则类型定义了需要查询哪些数据。

当一个规则匹配触发，就会给到一个或者多个的告警，这些告警具体会根据规则的配置来选择告警途径，就是告警行为，比如邮件、企业微信、飞书、钉钉等

## 二、部署

### 1. 创建本地类型的 PVC

```sh
[root@k8s-master EFK]# cat local-storage.yaml 
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  # 设置为默认 StorageClass
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Retain

[root@k8s-master EFK]# cat elasticsearch-data-pv.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: elasticsearch-data-0
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /data/elasticsearch-data/0  # 本地存储路径，确保路径存在且已挂载
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - k8s-master  # 使用特定节点的名称
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: elasticsearch-data-1
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /data/elasticsearch-data/1  # 本地存储路径，确保路径存在且已挂载
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - k8s-master  # 使用特定节点的名称
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: elasticsearch-data-2
spec:
  capacity:
    storage: 100Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /data/elasticsearch-data/2  # 本地存储路径，确保路径存在且已挂载
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - k8s-master  # 使用特定节点的名称
[root@k8s-master EFK]# 
```

### 1. 部署 Elasticsearch

```sh
[root@k8s-master EFK]# cat elasticsearch-svc.yaml 
kind: Service
apiVersion: v1
metadata:
  name: elasticsearch
  namespace: kube-logging
  labels:
    app: elasticsearch
spec:
  selector:
    app: elasticsearch
  clusterIP: None
  ports:
    - port: 9200
      name: rest
    - port: 9300
      name: inter-node
---
kind: Service
apiVersion: v1
metadata:
  name: elasticsearch-cs
  namespace: kube-logging
  labels:
    app: elasticsearch
spec:
  selector:
    app: elasticsearch
  type: NodePort
  ports:
    - port: 9200
      name: rest
      nodePort: 30900
```

```sh
[root@k8s-master EFK]# cat elasticsearch/elasticsearch-statefulset.yaml 
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-cluster
  namespace: kube-logging
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      initContainers:
      - name: fix-permissions
        image: busybox
        imagePullPolicy: IfNotPresent
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        securityContext:
          privileged: true
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
      - name: increase-vm-max-map
        image: busybox
        imagePullPolicy: IfNotPresent
        command: ["sysctl", "-w", "vm.max_map_count=262144"]
        securityContext:
          privileged: true
      - name: increase-fd-ulimit
        image: busybox
        imagePullPolicy: IfNotPresent
        command: ["sh", "-c", "ulimit -n 65536"]
        securityContext:
          privileged: true
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:7.2.0
        imagePullPolicy: IfNotPresent
        env:
          - name: cluster.name
            value: k8s-logs
          - name: node.name
            valueFrom:
              fieldRef:
                fieldPath: metadata.name
          - name: discovery.seed_hosts
            value: "es-cluster-0.elasticsearch,es-cluster-1.elasticsearch,es-cluster-2.elasticsearch"
          - name: cluster.initial_master_nodes
            value: "es-cluster-0,es-cluster-1,es-cluster-2"
          - name: ES_JAVA_OPTS
            value: "-Xms512m -Xmx512m"
        ports:
        - containerPort: 9200
          name: rest
          protocol: TCP
        - containerPort: 9300
          name: inter-node
          protocol: TCP
        resources:
            limits:
              cpu: 2
              memory: "4096Mi"
            requests:
              cpu: 0.1
              memory: "512Mi"
        volumeMounts:
        - name: data
          mountPath: /usr/share/elasticsearch/data
  volumeClaimTemplates:
  - metadata:
      name: data
      labels:
        app: elasticsearch
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: local-storage
      resources:
        requests:
          storage: 100Gi
```

```sh
[root@k8s-master EFK]# mkdir -pv /data/elasticsearch-data/{0,1,2}
[root@k8s-master EFK]# kubectl create ns kube-logging
[root@k8s-master EFK]# kubectl apply -f elasticsearch-statefulset.yaml
statefulset.apps/es-cluster created
[root@k8s-master EFK]# kubectl get pods -n kube-logging -o wide
NAME           READY   STATUS    RESTARTS   AGE     IP              NODE        NOMINATED NODE   READINESS GATES
es-cluster-0   1/1     Running   0          3m42s   10.233.123.11   k8s-app-0   <none>           <none>
es-cluster-1   1/1     Running   0          2m39s   10.233.123.12   k8s-app-0   <none>           <none>
es-cluster-2   1/1     Running   0          2m29s   10.233.123.13   k8s-app-0   <none>           <none>
```

普通 deployment 使用 local 存储如下

```sh
[root@k8s-master EFK]# cat data-pvc.yaml 
apiVersion: v1
kind: PersistentVolume
metadata:
  name: local-pv
spec:
  capacity:
    storage: 10Gi
  volumeMode: Filesystem
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-storage
  local:
    path: /data/test-pvc/01  # 本地存储路径，确保路径存在且已挂载
  nodeAffinity:
    required:
      nodeSelectorTerms:
        - matchExpressions:
            - key: kubernetes.io/hostname
              operator: In
              values:
                - k8s-master  # 使用特定节点的名称
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: local-pvc
spec:
  storageClassName: local-storage
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

### 2. 部署 Fluentd

```sh
[root@k8s-master EFK]# cat fluentd/fluentd-configmap.yaml 
kind: ConfigMap
apiVersion: v1
metadata:
  name: fluentd-config
  namespace: kube-logging
data:
  system.conf: |-
    <system>
      root_dir /tmp/fluentd-buffers/
    </system>
  containers.input.conf: |-
    <source>
      @id fluentd-containers.log
      @type tail
      path /var/log/containers/*.log
      pos_file /var/log/es-containers.log.pos
      tag raw.kubernetes.*
      read_from_head true
      <parse>
        @type multi_format
        <pattern>
          format json
          time_key time
          time_format %Y-%m-%dT%H:%M:%S.%NZ
        </pattern>
        <pattern>
          format /^(?<time>.+) (?<stream>stdout|stderr) [^ ]* (?<log>.*)$/
          time_format %Y-%m-%dT%H:%M:%S.%N%:z
        </pattern>
        <pattern>
          format /^(?<time>.+) (?<stream>stdout|stderr) (?<log>.*)/
          time_format %Y-%m-%dT%H:%M:%S.%N%:z
        </pattern>
      </parse>
    </source>
    # 在日志输出中检测异常，并将其作为一条日志转发
    # https://github.com/GoogleCloudPlatform/fluent-plugin-detect-exceptions
    <match raw.kubernetes.**>           # 匹配tag为raw.kubernetes.**日志信息
      @id raw.kubernetes
      @type detect_exceptions           # 使用detect-exceptions插件处理异常栈信息
      remove_tag_prefix raw             # 移除 raw 前缀
      message log                       
      stream stream                     
      multiline_flush_interval 5
      max_bytes 5000000
      max_lines 1000
    </match>

    <filter **>  # 拼接日志
      @id filter_concat
      @type concat                # Fluentd Filter 插件，用于连接多个事件中分隔的多行日志。
      key message
      multiline_end_regexp /\n$/  # 以换行符“\n”拼接
      separator ""
    </filter>

    # 添加 Kubernetes metadata 数据
    <filter kubernetes.**>
      @id filter_kubernetes_metadata
      @type kubernetes_metadata
    </filter>

    # 修复 ES 中的 JSON 字段
    # 插件地址：https://github.com/repeatedly/fluent-plugin-multi-format-parser
    <filter kubernetes.**>
      @id filter_parser
      @type parser                # multi-format-parser多格式解析器插件
      key_name log                # 在要解析的记录中指定字段名称。
      reserve_data true           # 在解析结果中保留原始键值对。
      remove_key_name_field true  # key_name 解析成功后删除字段。
      <parse>
        @type multi_format
        <pattern>
          format json
        </pattern>
        <pattern>
          format none
        </pattern>
      </parse>
    </filter>

    # 删除一些多余的属性
    <filter kubernetes.**>
      @type record_transformer
      remove_keys $.docker.container_id,$.kubernetes.container_image_id,$.kubernetes.pod_id,$.kubernetes.namespace_id,$.kubernetes.master_url,$.kubernetes.labels.pod-template-hash
    </filter>

    # 只保留具有logging=true标签的Pod日志
    <filter kubernetes.**>
      @id filter_log
      @type grep
      <regexp>
        key $.kubernetes.labels.logging
        pattern ^true$
      </regexp>
    </filter>

  ###### 监听配置，一般用于日志聚合用 ######
  forward.input.conf: |-
    # 监听通过TCP发送的消息
    <source>
      @id forward
      @type forward
    </source>

  output.conf: |-
    <match **>
      @id elasticsearch
      @type elasticsearch
      @log_level info
      include_tag_key true
      host elasticsearch
      port 9200
      logstash_format true
      logstash_prefix k8s-app  # 设置 index 前缀为 k8s
      request_timeout    30s
      <buffer>
        @type file
        path /var/log/fluentd-buffers/kubernetes.system.buffer
        flush_mode interval
        retry_type exponential_backoff
        flush_thread_count 2
        flush_interval 5s
        retry_forever
        retry_max_interval 30
        chunk_limit_size 2M
        queue_limit_length 8
        overflow_action block
      </buffer>
    </match>
```

```sh
[root@k8s-master EFK]# cat fluentd/fluentd-daemonset.yaml 
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd-es
  namespace: kube-logging
  labels:
    k8s-app: fluentd-es
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: fluentd-es
  labels:
    k8s-app: fluentd-es
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
rules:
- apiGroups:
  - ""
  resources:
  - "namespaces"
  - "pods"
  verbs:
  - "get"
  - "watch"
  - "list"
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: fluentd-es
  labels:
    k8s-app: fluentd-es
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
subjects:
- kind: ServiceAccount
  name: fluentd-es
  namespace: kube-logging
  apiGroup: ""
roleRef:
  kind: ClusterRole
  name: fluentd-es
  apiGroup: ""
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-es
  namespace: kube-logging
  labels:
    k8s-app: fluentd-es
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  selector:
    matchLabels:
      k8s-app: fluentd-es
  template:
    metadata:
      labels:
        k8s-app: fluentd-es
        kubernetes.io/cluster-service: "true"
    spec:
      priorityClassName: system-node-critical  # 确保如果节点被驱逐，fluentd不会被驱逐，支持关键的基于 pod 注释的优先级方案。
      serviceAccountName: fluentd-es
      dnsPolicy: ClusterFirst
      containers:
      - name: fluentd-es
        #image: quay.io/fluentd_elasticsearch/fluentd:v3.0.1 # 该镜像是官方默认的
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/fluentd:v3.0.1  # 该镜像是我安装了 Fluentd Filter 插件
        env:
        - name: FLUENTD_ARGS
          value: --no-supervisor -q
        - name: TZ
          value: Asia/Shanghai
        resources:
          limits:
            cpu: 200m
            memory: 500Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: containers
          mountPath: /data/lib/docker/containers/  # 这里根据你 docker 的存储目录来定义
          readOnly: true
        - name: config-volume
          mountPath: /etc/fluent/config.d
      nodeSelector:
        beta.kubernetes.io/fluentd-ds-ready: "true"
      tolerations:
      - operator: Exists
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: containers
        hostPath:
          path: /data/lib/docker/containers/  # 这里根据你 docker 的存储目录来定义
      - name: config-volume
        configMap:
          name: fluentd-config
```

```sh
[root@k8s-master EFK]# kubectl apply -f fluentd/
```

### 3. 部署 Kibana

```sh
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: kube-logging
  labels:
    app: kibana
spec:
  type: NodePort
  selector:
    app: kibana
  ports:
  - port: 5601
    protocol: TCP
    targetPort: 5601
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kibana
  namespace: kube-logging
  labels:
    app: kibana
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        image: docker.elastic.co/kibana/kibana:7.2.0
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            cpu: 1000m
          requests:
            cpu: 100m
        env:
          - name: ELASTICSEARCH_URL
            value: http://elasticsearch:9200
        ports:
        - containerPort: 5601
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kibana
  namespace: kube-logging
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
  labels:
    name: kibana-ingress
spec:
  ingressClassName: nginx
  rules:
  - host: k8s-kibana.localhost.com
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: kibana
            port:
              number: 5601
```

```sh
[root@k8s-master EFK]# kubectl apply -f kibana/
```

### 4. 部署 Elastalert

```sh
[root@k8s-master EFK]# cat elastalert/elastalert-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: elastalert-config
  namespace: kube-logging
data:
  k8s_app_error.yaml: |
    es_host: elasticsearch  # Elasticsearch 连接地址
    es_port: 9200           # Elasticsearch 端口
    name: k8s_error_log     # 规则名称，用于标识规则
    type: frequency         # 规则类型，frequency 表示基于日志的频率进行告警,有多种类型,不同的类型配置项有不同
    query_key:              # 不进行重复提醒的字段
      - "message"           # 使用 message 字段进行判断
    #aggregation:            # 聚合10 分钟内的结果，合并在一起发送
      #minutes: 5
    realert:                # 同一规则的两次警报之间的最短时间
      minutes: 1            # 最短时间间隔，控制同一规则的重复告警间隔
    exponential_realert:    # 指数型扩展 realert 时间，例如第一次是 5 分钟，第二次是 10 分钟，以此类推
      hours: 1    
    index: k8s-*            # 匹配索引，支持正则
    num_events: 1           # 与规则匹配的日志出现次数
    timeframe:              # 在这个时间段内，如果出现指定次数的日志，将触发告警
      minutes: 1
    aggregation_key: name     # 根据报警的名称，将相同的报警按照name来聚合
    filter:
    - query:
        query_string:
          #query: "level.keyword : ERROR AND msg : java*Exception"   # 错误级别是ERROR并且msg字段包含java开头Exception结尾的内容就匹配成功，elastalert就会推送报警
          query: "message: ERROR"  # 错误级别是ERROR的日志
    alert:
    - feishu  # 使用飞书插件

    feishu_robot_webhook_url: "https://open.feishu.cn/open-apis/bot/v2/hook/17eb3c9f-80c3-4abd-a137-415b514b96ff"   # 飞书机器人接口地址
    alert_subject: "k8s业务error异常"       # 告警标题
    alert_text_args:
    - "alert_subject"                    # 告警标题
    - "@timestamp"                       # 告警触发时间
    - "message"                          # 错误日志
    - "num_hits"                         # 错误数量
    - "num_matches"                      # 规则命中数
    - "kubernetes.host"                  # 主机名
    - "kubernetes.namespace_name"        # Kubernetes 命名空间
    - "kubernetes.pod_name"              # Kubernetes Pod 名称
    - "kubernetes.container_image"       # 容器镜像
    - "kubernetes.container_name"        # 容器名称
    - "stream"                           # 日志流
    - "_index"                           # 索引名称
    alert_text_type: alert_text_only
    alert_text:
      "
      【告警主题】: {}\n
      【触发时间】: {}\n
      【错误日志】: {}\n
      【错误数量】: {}\n
      【规则命中数】: {}\n
      【主机名】: {}\n
      【Kubernetes命名空间】: {}\n
      【Kubernetes Pod】: {}\n
      【容器镜像】: {}\n
      【容器名称】: {}\n
      【日志流】: {}\n
      【索引名称】: {}\n
      "

  config.json: |
    {
      "appName": "elastalert-server",
      "port": 3030,                
      "wsport": 3333,
      "elastalertPath": "/opt/elastalert",
      "verbose": false,
      "es_debug": false,
      "debug": false,
      "rulesPath": {
        "relative": true,
        "path": "/rules"
      },
      "templatesPath": {
        "relative": true,
        "path": "/rule_templates"
      },
      "es_host": "elasticsearch",
      "es_port": 9200,
      "writeback_index": "elastalert_status"
    }
  # ElastAlert主配置文件，定义了规则目录、执行频率等全局设置
  elastalert.yaml: |
    rules_folder: rules              # 规则目录
    run_every:
      seconds: 60                     # 每 60 秒检查一次规则
    buffer_time:
      minutes: 15                     # 缓冲时间为 15 分钟
    es_host: elasticsearch            # Elasticsearch 主机
    es_port: 9200                     # Elasticsearch 端口
    use_ssl: False                    # 是否使用 SSL 加密
    verify_certs: False               # 是否验证 SSL 证书
    writeback_index: elastalert_status  # 用于写回告警状态的索引
    writeback_alias: elastalert_alerts  # 用于写回告警的别名
    alert_time_limit:
      days: 2                         # 记录告警的最大时间范围，超过2天的告警会被清除
```

使用 email 告警通知，使用 email 告警通知记得创建 smtp_auth.yaml  文件存储邮箱登陆信息

```sh
[root@k8s-master EFK]# cat elastalert/elastalert-configmap.yaml-bak 
apiVersion: v1
kind: ConfigMap
metadata:
  name: elastalert-config
  namespace: kube-logging
data:
  elastalert.yaml: |
    rules_folder: rules
    run_every:
      seconds: 60
    buffer_time:
      minutes: 15
    es_host: elasticsearch
    es_port: 9200
    use_ssl: False
    verify_certs: False
    writeback_index: elastalert_status
    writeback_alias: elastalert_alerts
    alert_time_limit:
      days: 2
  k8s_app_error.yaml: |
    es_host: elasticsearch
    es_port: 9200
    name: prod-server-rules
    type: frequency
    query_key:              # 不进行重复提醒的字段
      - message
    aggregation:            # 聚合1分钟内的结果，合并在一起发送
      minutes: 1
    realert:                # 同一规则的两次警报之间的最短时间
      minutes: 2
    exponential_realert:    # 指数级扩大realert时间
      hours: 1    
    index: k8s-*         # 匹配索引，支持正则
    num_events: 1           # 与规则匹配的日志出现次数
    timeframe:              # 在timeframe时间内出现num_events次与规则匹配的日志，将会触发报警
      minutes: 1
    aggregation_key: name     # 根据报警的名称，将相同的报警按照name来聚合
    filter:
    - query:
        query_string:
          #query: "level.keyword : ERROR AND msg : java*Exception"   # 错误级别是ERROR并且msg字段包含java开头Exception结尾的内容就匹配成功，elastalert就会推送报警
          query: "message: ERROR"  # 错误级别是ERROR的日志
    alert:
    - "email"
    - "feishu"  # 使用飞书告警模块

    email_format: html
    alert_text_type: alert_text_only
    # 标题
    alert_subject: "生产环境日志告警通知"
    # 丰富的邮件模板，包含了更多详细的字段
    alert_text: "<br><a href='http://k8s-kibana.localhost.com/app/kibana' target='_blank' style='padding: 8px 16px;background-color: #46bc99;text-decoration:none;color:white;border-radius: 5px;'>立刻前往Kibana查看</a><br>
    <table>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>告警时间</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{@timestamp}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>服务名称</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{module}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>日志级别</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{level}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>错误日志</td>
    <td style='padding:10px 5px;border-radius: 5px;background-color: #F8F9FA;'>{msg}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>错误数量</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{num_hits}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>匹配日志数量</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{num_matches}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>主机名</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{host}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>Pod 名称</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{kubernetes.pod_name}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>容器名称</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{kubernetes.container_name}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>容器ID</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{kubernetes.container_id}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>日志流</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{stream}</td></tr>
    <tr><td style='padding:5px;text-align: right;font-weight: bold;border-radius: 5px;background-color: #eef;'>索引名称</td>
    <td style='padding:5px;border-radius: 5px;background-color: #eef;'>{_index}</td></tr>
    </table>"

    email:
    - "2099637909@qq.com"
    smtp_host: smtp.qq.com
    smtp_port: 25
    smtp_auth_file: /opt/elastalert/smtp_auth.yaml      
    from_addr: 2099637909@qq.com

    feishu_robot_webhook_url: "https://open.feishu.cn/open-apis/bot/v2/hook/17eb3c9f-80c3-4abd-a137-415b514b96ff"   # 飞书机器人接口地址
    alert_subject: "k8s业务error异常"       # 告警标题

    # 告警模板引用，指定哪些字段会被填充到模板中
    alert_text_args:
    - "alert_subject"                    # 告警标题
    - "@timestamp"                       # 告警触发时间
    - "level"                            # 日志级别
    - "message"                          # 错误日志
    - "num_hits"                         # 错误数量
    - "num_matches"                      # 规则命中数
    - "kubernetes.host"                  # 主机名
    - "kubernetes.namespace_name"        # Kubernetes 命名空间
    - "kubernetes.pod_name"              # Kubernetes Pod 名称
    - "kubernetes.container_image"       # 容器镜像
    - "kubernetes.container_name"        # 容器名称
    - "kubernetes.container_id"          # 容器 ID
    - "stream"                           # 日志流
    - "_index"                           # 索引名称

    alert_text_type: alert_text_only
    alert_text:
      "
      【告警主题】: {}\n
      【触发时间】: {}\n
      【日志级别】: {}\n
      【错误日志】: {}\n
      【错误数量】: {}\n
      【规则命中数】: {}\n
      【主机名】: {}\n
      【Kubernetes命名空间】: {}\n
      【Kubernetes Pod】: {}\n
      【容器镜像】: {}\n
      【容器名称】: {}\n
      【容器ID】: {}\n
      【日志流】: {}\n
      【索引名称】: {}\n
      "
  
  config.json: |
    {
      "appName": "elastalert-server",
      "port": 3030,
      "wsport": 3333,
      "elastalertPath": "/opt/elastalert",
      "verbose": false,
      "es_debug": false,
      "debug": false,
      "rulesPath": {
        "relative": true,
        "path": "/rules"
      },
      "templatesPath": {
        "relative": true,
        "path": "/rule_templates"
      },
      "es_host": "elasticsearch",
      "es_port": 9200,
      "writeback_index": "elastalert_status"
    }
```

```sh
[root@k8s-master EFK]# cat elastalert/smtp_auth.yaml
user: 2099637909@qq.com
password: odvodhilxmcqcfhf
[root@k8s-master EFK]# kubectl create secret generic smtp-auth --from-file=elastalert/email_auth.yaml -n kube-logging

第二种创建方法：
[root@k8s-master EFK]# echo $(cat elastalert/smtp_auth.yaml| base64) | tr  -d " "

[root@k8s-master EFK]# cat elastalert/smtp_auth.yaml 
apiVersion: v1
kind: Secret
metadata:
  name: smtp-auth
  namespace: kube-logging
data:
  # 把 echo 的值复制过来
  smtp_auth.yaml: dXNlcjogMjA5OTYzNzkwOUBxcS5jb20KcGFzc3dvcmQ6IG9kdm9kaGlseG1jcWNmaGYK
[root@k8s-master EFK]# kubectl apply -f elastalert/smtp_auth.yaml
```

```sh
[root@k8s-master EFK]# cat elastalert/deployment.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: elastalert
  name: elastalert
  namespace: kube-logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elastalert
  template:
    metadata:
      labels:
        app: elastalert
      name: elastalert
    spec:
      containers:
      - name: elastalert
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/elastalert2-feishu:2.21.0
        #image: bitsensor/elastalert:3.0.0-beta.1   
        imagePullPolicy: IfNotPresent
        env:
        - name: TZ
          value: Asia/Shanghai
        ports:
          - containerPort: 3030
            name: tcp-3030
            protocol: TCP
          - containerPort: 3333
            name: tcp-3333
            protocol: TCP
        resources:
          limits:
            cpu: '1'
            memory: "1024Mi"
          requests:
            cpu: '0.5'
            memory: "512Mi"
        volumeMounts:
          - name: elastalert-config
            mountPath: /opt/elastalert/config.yaml
            subPath: elastalert.yaml
          - name: smtp-auth-volume
            mountPath: /opt/elastalert/smtp_auth.yaml
            subPath: smtp_auth.yaml
          - name: elastalert-config
            mountPath: /opt/elastalert-server/config/config.json
            subPath: config.json
          - name: elastalert-config
            mountPath: /opt/elastalert/rules/k8s_app_error.yaml
            subPath: k8s_app_error.yaml
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      volumes:
      - name: elastalert-config
        configMap:
          defaultMode: 420
          name: elastalert-config
      - name: smtp-auth-volume
        secret:
          secretName: smtp-auth
---
apiVersion: v1
kind: Service
metadata:
  name: elastalert
  namespace: kube-logging
spec:
  ports:
  - name: serverport
    port: 3030
    protocol: TCP
    targetPort: 3030
  - name: transport
    port: 3333
    protocol: TCP
    targetPort: 3333
  selector:
    app: elastalert
```

## 三、使用 Kibana

### 1. 业务报错模拟

自定义一个程序来模拟

```sh
[root@k8s-master EFK]# cat Dockerfile 
# 使用官方 Python 基础镜像
FROM registry.cn-hangzhou.aliyuncs.com/tianxiang_app/python:3.9.21-alpine

# 设置工作目录
WORKDIR /app

# 将 Python 脚本复制到容器中
COPY log_simulator.py /app/

# 安装依赖（如果有的话）
#RUN pip install --no-cache-dir -r requirements.txt

# 启动脚本
CMD ["python", "log_simulator.py"]
```

```sh
[root@k8s-master EFK]# docker build . -t log-simulator:v1 
```

```sh
[root@k8s-master EFK]# cat deployment.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: log-simulator
  namespace: default  # 可以根据需要修改命名空间
spec:
  replicas: 1  # 启动一个副本，也可以根据需要增加副本数
  selector:
    matchLabels:
      app: log-simulator
  template:
    metadata:
      labels:
        app: log-simulator
        logging: "true"  # true 应该是字符串（"true"），而不是布尔值，YAML 会把 true 误认为是布尔值
    spec:
      containers:
      - name: log-simulator
        image: harbor.meta42.indc.vnet.com/library/log-simulator:v1
        ports:
        - containerPort: 8080  # 如果需要暴露端口可以添加，模拟的服务没有端口暴露
        resources:
          limits:
            memory: "128Mi"
            cpu: "500m"
          requests:
            memory: "64Mi"
            cpu: "250m"
      restartPolicy: Always

[root@k8s-master EFK]# kubectl apply -f deployment.yaml 
[root@k8s-master EFK]# kubectl logs log-simulator-546c458bb5-pfv5x 
2025-02-17 08:35:05,962 - INFO - User 4519 successfully completed transaction 219900
2025-02-17 08:35:06,963 - INFO - User 9570 successfully completed transaction 946353
2025-02-17 08:35:08,966 - WARNING - Warning: Transaction 424406 for user 1864 encountered minor issue
2025-02-17 08:35:09,966 - WARNING - Warning: Transaction 118367 for user 4462 encountered minor issue
2025-02-17 08:35:17,974 - CRITICAL - Critical issue with transaction 111038 for user 3711
2025-02-17 08:35:21,977 - INFO - User 3702 successfully completed transaction 729744
2025-02-17 08:35:22,978 - ERROR - Error processing transaction 839601 for user 9459
2025-02-17 08:35:27,985 - INFO - User 4263 successfully completed transaction 954406
```

不出意外的话你就能在 kibana 上看到正常日志和报错日志了。

我这里为了模拟的真实一点，直接使用相对完善的 Java 程序来模拟了，直接看截图看效果吧

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/8.png)

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/9.png)

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/10.png)

### 2. 配置添加索引

如果 ES 中没有搜集到日志这里添加索引是找不到 k8s-app 开头的日志，所以上面我们先模拟业务情景了

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/1.png)

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/2.png)

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/3.png)

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/4.png)

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/5.png)

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/6.png)

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/7.png)

## 四、飞书告警

### 1. 效果展示

![](/images/posts/Linux-Kubernetes/Linux-Kubernetes-部署EFK日志收集+告警/11.png)

## 五、调整 ES 索引保留时间

### 1. 查看 ILM 策略，可以看到默认索引数据保留时间为7天

```sh
[root@k8s-master EFK]# curl http://10.233.38.110:9200/_ilm/policy?pretty
{
  "watch-history-ilm-policy" : {
    "version" : 2,
    "modified_date" : "2025-02-17T09:14:55.797Z",
    "policy" : {
      "phases" : {
        "delete" : {
          "min_age" : "7d",
          "actions" : {
            "delete" : { }
          }
        }
      }
    }
  }
}
```

### 2. 修改索引保留时间为30天

```sh
[root@k8s-master EFK]# curl -X PUT "http://10.233.38.110:9200/_ilm/policy/watch-history-ilm-policy" -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
'
```

### 3. 查看索引（indices）设置和相关信息

```sh
[root@k8s-master EFK]# curl -X GET "http://10.233.38.110:9200/_settings?pretty"|grep k8s-app
```

### 4. 为现有索引应用该 ILM 策略

```sh
[root@k8s-master EFK]# curl -X PUT "http://10.233.38.110:9200/k8s-app-2025.02.17/_settings" -H 'Content-Type: application/json' -d'
{
  "settings": {
    "index.lifecycle.name": "watch-history-ilm-policy",
    "index.lifecycle.rollover_alias": "logs"
  }
}
'
```

### 5. 查看索引的生命周期管理状态，以确保策略已成功应用

```sh
[root@k8s-master EFK]# curl -X GET "http://10.233.38.110:9200/k8s-app-2025.02.17/_ilm/explain?pretty"
{
  "indices" : {
    "k8s-app-2025.02.17" : {
      "index" : "k8s-app-2025.02.17",
      "managed" : true,
      "policy" : "watch-history-ilm-policy",
      "lifecycle_date_millis" : 1739781319447,
      "phase" : "new",
      "phase_time_millis" : 1739784554675,
      "action" : "complete",
      "action_time_millis" : 1739784554675,
      "step" : "complete",
      "step_time_millis" : 1739784554675
    }
  }
}
```