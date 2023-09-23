---
layout: post
title: Linux-Kubernetes-45-Kubernetes部署harbor服务
date: 2022-09-14
tags: 实战-Kubernetes
music-id: 77131
---

# 部署Harbor仓库服务

## 一、准备部署 nfs 共享存储

```sh
[root@kubesphere nfs-provisioner-harbor]# cat > class.yaml <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: harbor-storage-nfs
  annotations:
    #storageclass.beta.kubernetes.io/is-default-class: "true"  #这个是让这个storage充当默认，这里不需要就注释掉
provisioner: example.com/nfs
EOF
```

注意修改 nfs 地址以及 nfs 挂载目录

```sh
[root@kubesphere nfs-provisioner-harbor]# cat > deployment.yaml <<EOF
kind: Deployment
apiVersion: apps/v1
metadata:
  name: nfs-provisioner-harbor
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: nfs-provisioner-harbor
  replicas: 3
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: nfs-provisioner-harbor
    spec:
      serviceAccount: nfs-provisioner-harbor
      containers:
        - name: nfs-provisioner-harbor
          image: 10.135.140.195/library/nfs-subdir-external-provisioner:v4.0.2
          imagePullPolicy: IfNotPresent
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
            # 注意这个值要和class里面的一致
              value: example.com/nfs
            - name: NFS_SERVER
            # 注意修改地址
              value: 10.135.137.17
            - name: NFS_PATH
              value: /NJcaasharbor
      volumes:
        - name: nfs-client-root
          nfs:
          # 注意修改地址
            server: 10.135.137.17
            path: /NJcaasharbor
EOF
```

```sh
[root@kubesphere nfs-provisioner-harbor]# cat > rbac.yaml <<EOF
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-provisioner-runner
  namespace: kube-system
rules:
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
  - apiGroups: [""]
    resources: ["services", "endpoints"]
    verbs: ["get"]
  - apiGroups: ["extensions"]
    resources: ["podsecuritypolicies"]
    resourceNames: ["nfs-provisioner"]
    verbs: ["use"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-provisioner
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: nfs-provisioner-harbor
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: nfs-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-provisioner
  namespace: kube-system
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-provisioner
  namespace: kube-system
subjects:
  - kind: ServiceAccount
    name: nfs-provisioner-harbor
    namespace: kube-system
roleRef:
  kind: Role
  name: leader-locking-nfs-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF
```

```sh
[root@kubesphere nfs-provisioner-harbor]# cat > serviceaccount.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-provisioner-harbor
  namespace: kube-system
EOF
```

测试 pvc 是否能够正常使用

```sh
[root@kubesphere nfs-provisioner-harbor]# cat > nginx-dp.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-dp
  labels:
    k8s-app: nginx-dp
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: nginx-dp
  template:
    metadata:
      labels:
        k8s-app: nginx-dp
    spec:
      containers:
      - name: nginx-dp
        image: 10.135.140.61/library/nginx:1.21.4
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
        volumeMounts:
        - name: html
          mountPath: /usr/share/nginx/html
      volumes:
      - name: html
        persistentVolumeClaim:
          claimName: nginx-dp-pvc
      restartPolicy: Always
EOF
```

```sh
[root@kubesphere nfs-provisioner-harbor]# cat > nginx-pvc.yaml <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-test-pvc
  annotations:
    volume.beta.kubernetes.io/storage-class: "harbor-storage-nfs"
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

## 二、准备部署 harbor

### 1. 原生态部署 harbor

#### 1.1 安装 helm

```sh
# 在线安装
$ curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
$ chmod 700 get_helm.sh
$ ./get_helm.sh
Downloading https://get.helm.sh/helm-v3.2.4-linux-amd64.tar.gz
Preparing to install helm into /usr/local/bin
helm installed into /usr/local/bin/helm

# 下载安装
# 下载Helm客户端
$ wget https://get.helm.sh/helm-v3.2.4-linux-amd64.tar.gz

# 接下来解压下载的包，然后将客户端放置到 /usr/local/bin/ 目录下：
# 解压 Helm
$ tar -zxvf helm-v3.2.4-linux-amd64.tar.gz

# 复制客户端执行文件到 bin 目录下，方便在系统下能执行 helm 命令
$ cp linux-amd64/helm /usr/local/bin/
```

#### 1.2 创建 namespace

```sh
$ kubectl create namespace harbor
```

#### 1.3 创建 TLS 证书

```sh
$ mkdir harbor-tls && cd harbor-tls
$ vim script.sh
#!/bin/bash
openssl req  -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 -out ca.crt -subj "/C=CN/L=Beijing/O=lisea/CN=harbor.demo.com"
openssl req -newkey rsa:4096 -nodes -sha256 -keyout tls.key -out tls.csr -subj "/C=CN/L=Beijing/O=lisea/CN=harbor.demo.com"
# IP地址可以多预留一些，主要是域名能解析到的地址，其他的地址写进去也没用
echo subjectAltName = IP:192.168.1.20, IP:192.168.1.21, IP:192.168.1.110, IP:127.0.0.1, DNS:example.com, DNS:harbor.demo.com > extfile.cnf
openssl x509 -req -days 3650 -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out tls.crt

$ bash script.sh

$ kubectl create secret tls harbor-tls -n harbor  --cert=tls.crt --key=tls.key
```

```sh
$ mkdir harbor-notary && cd harbor-notary

$ vim script.sh
#!/bin/bash
openssl req  -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 -out ca.crt -subj "/C=CN/L=Beijing/O=lisea/CN=harbor-notary.demo.com"
openssl req -newkey rsa:4096 -nodes -sha256 -keyout tls.key -out tls.csr -subj "/C=CN/L=Beijing/O=lisea/CN=harbor-notary.demo.com"
# IP地址可以多预留一些，主要是域名能解析到的地址，其他的地址写进去也没用
echo subjectAltName = IP:192.168.1.20, IP:192.168.1.21, IP:192.168.1.110, IP:127.0.0.1, DNS:example.com, DNS:harbor-notary.demo.com > extfile.cnf
openssl x509 -req -days 3650 -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out tls.crt

$ bash script.sh

$ kubectl create secret tls harbor-notary -n harbor  --cert=tls.crt --key=tls.key
```

#### 1.4 准备 harbor chart 文件

直接白嫖：https://blog.linuxtian.top/data/3-harbor%E7%9B%B8%E5%85%B3/values.yaml

```sh
$ vim values.yaml
expose:
  type: ingress
  tls:
    enabled: true
    certSource: secret
    auto:
    secret:
      secretName: "harbor-tls"
      notarySecretName: "harbor-notary-tls"
  ingress:
    hosts:
      core: harbor.demo.com
      notary: harbor-notary.demo.com
    controller: default
    kubeVersionOverride: ""
    annotations:
      kubernetes.io/ingress.class: "nginx"
      ingress.kubernetes.io/ssl-redirect: "true"
      ingress.kubernetes.io/proxy-body-size: "0"
      nginx.ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-body-size: "0"
  clusterIP:
    name: harbor
    ports:
      httpPort: 80
      httpsPort: 443
      notaryPort: 4443
  nodePort:
    name: harbor
    ports:
      http:
        port: 80
      https:
        port: 443
      notary:
        port: 4443
  loadBalancer:
    name: harbor
    IP: ""
    ports:
      httpPort: 80
      httpsPort: 443
      notaryPort: 4443
externalURL: https://harbor.demo.com

internalTLS:
  enabled: false
  certSource: "auto"
  trustCa: ""
  core:
    secretName: ""
    crt: ""
    key: ""
  jobservice:
    secretName: ""
    crt: ""
    key: ""
  registry:
    secretName: ""
    crt: ""
    key: ""
  portal:
    secretName: ""
    crt: ""
    key: ""
  chartmuseum:
    secretName: ""
    crt: ""
    key: ""
  trivy:
    secretName: ""
    crt: ""
    key: ""

ipFamily:
  ipv6:
    enabled: true
  ipv4:
    enabled: true

persistence:
 enabled: true
 resourcePolicy: "keep"
 persistentVolumeClaim:
   registry:
     storageClass: "harbor-storage-nfs"
     accessMode: ReadWriteMany
     size: 300Gi
   chartmuseum:
     storageClass: "harbor-storage-nfs"
     accessMode: ReadWriteOnce
     size: 10Gi
   jobservice:
     storageClass: "harbor-storage-nfs"
     accessMode: ReadWriteMany
     size: 100Gi
   database:
     storageClass: "harbor-storage-nfs"
     accessMode: ReadWriteOnce
     size: 100Gi
   redis:
     storageClass: "harbor-storage-nfs"
     accessMode: ReadWriteOnce
     size: 10Gi
   trivy:
     storageClass: "harbor-storage-nfs"
     accessMode: ReadWriteOnce
     size: 10Gi
   
imageChartStorage:
  disableredirect: false

  type: filesystem
  filesystem:
    rootdirectory: /storage
  azure:
    accountname: accountname
    accountkey: base64encodedaccountkey
    container: containername
  gcs:
    bucket: bucketname
    encodedkey: base64-encoded-json-key-file
  s3:
    region: us-west-1
    bucket: bucketname
  swift:
    authurl: https://storage.myprovider.com/v3/auth
    username: username
    password: password
    container: containername
  oss:
    accesskeyid: accesskeyid
    accesskeysecret: accesskeysecret
    region: regionname
    bucket: bucketname

imagePullPolicy: IfNotPresent

imagePullSecrets:

updateStrategy:
  type: RollingUpdate

logLevel: info

harborAdminPassword: "Harbor12345"

caSecretName: ""

secretKey: "not-a-secure-key"

proxy:
  httpProxy:
  httpsProxy:
  noProxy: 127.0.0.1,localhost,.local,.internal
  components:
    - core
    - jobservice
    - trivy

nginx:
  image:
    repository: goharbor/nginx-photon
    tag: v2.4.3
  replicas: 3
  serviceAccountName: ""
  automountServiceAccountToken: false
  nodeSelector: {}
  tolerations: []
  affinity: {}
  podAnnotations: {}
  priorityClassName:

portal:
  image:
    repository: goharbor/harbor-portal
    tag: v2.4.3
  replicas: 3
  serviceAccountName: ""
  automountServiceAccountToken: false
  nodeSelector: {}
  tolerations: []
  affinity: {}
  podAnnotations: {}
  priorityClassName:

core:
  image:
    repository: goharbor/harbor-core
    tag: v2.4.3
  replicas: 3
  serviceAccountName: ""
  automountServiceAccountToken: false
  startupProbe:
    enabled: true
    initialDelaySeconds: 10
  nodeSelector: {}
  tolerations: []
  affinity: {}
  podAnnotations: {}
  secret: ""
  secretName: ""
  xsrfKey: ""
  priorityClassName:

jobservice:
  image:
    repository: goharbor/harbor-jobservice
    tag: v2.4.3
  replicas: 3
  serviceAccountName: ""
  automountServiceAccountToken: false
  maxJobWorkers: 10
  jobLoggers:
    - file

  nodeSelector: {}
  tolerations: []
  affinity: {}
  podAnnotations: {}
  secret: ""
  priorityClassName:

registry:
  serviceAccountName: ""
  automountServiceAccountToken: false
  registry:
    image:
      repository: goharbor/registry-photon
      tag: v2.4.3
  controller:
    image:
      repository: goharbor/harbor-registryctl
      tag: v2.4.3

  replicas: 3
  nodeSelector: {}
  tolerations: []
  affinity: {}
  podAnnotations: {}
  priorityClassName:
  secret: ""
  relativeurls: false
  credentials:
    username: "harbor_registry_user"
    password: "harbor_registry_password"

  middleware:
    enabled: false
    type: cloudFront
    cloudFront:
      baseurl: example.cloudfront.net
      keypairid: KEYPAIRID
      duration: 3000s
      ipfilteredby: none
      privateKeySecret: "my-secret"

chartmuseum:
  enabled: true
  serviceAccountName: ""
  automountServiceAccountToken: false
  absoluteUrl: false
  image:
    repository: goharbor/chartmuseum-photon
    tag: v2.4.3
  replicas: 3
  nodeSelector: {}
  tolerations: []
  affinity: {}
  podAnnotations: {}
  priorityClassName:
  indexLimit: 0

trivy:
  enabled: true
  image:
    repository: goharbor/trivy-adapter-photon
    tag: v2.4.3
  serviceAccountName: ""
  automountServiceAccountToken: false
  replicas: 3
  debugMode: false
  vulnType: "os,library"
  severity: "UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL"
  ignoreUnfixed: false
  insecure: false
  gitHubToken: ""
  skipUpdate: false
  offlineScan: false
  timeout: 5m0s
  resources:
    requests:
      cpu: 200m
      memory: 512Mi
    limits:
      cpu: 1
      memory: 1Gi
  nodeSelector: {}
  tolerations: []
  affinity: {}
  podAnnotations: {}
  priorityClassName:

notary:
  enabled: true
  server:
    serviceAccountName: ""
    automountServiceAccountToken: false
    image:
      repository: goharbor/notary-server-photon
      tag: v2.4.3
    replicas: 3
    nodeSelector: {}
    tolerations: []
    affinity: {}
    podAnnotations: {}
    priorityClassName:
  signer:
    serviceAccountName: ""
    automountServiceAccountToken: false
    image:
      repository: goharbor/notary-signer-photon
      tag: v2.4.3
    replicas: 3
    nodeSelector: {}
    tolerations: []
    affinity: {}
    podAnnotations: {}
    priorityClassName:
  secretName: ""

database:
  type: internal # 如果使用外部数据库，请将"type"设置为"external"
  internal:
    serviceAccountName: ""
    automountServiceAccountToken: false
    image:
      repository: goharbor/harbor-db
      tag: v2.4.3
    replicas: 3
    password: "changeit"
    shmSizeLimit: 512Mi
    nodeSelector: {}
    tolerations: []
    affinity: {}
    priorityClassName:
    initContainer:
      migrator: {}
      permissions: {}
  external:
    host: "192.168.0.1"
    port: "5432"
    username: "user"
    password: "password"
    coreDatabase: "registry"
    notaryServerDatabase: "notary_server"
    notarySignerDatabase: "notary_signer"
    sslmode: "require"
  maxIdleConns: 100
  maxOpenConns: 900
  podAnnotations: {}

redis:
  type: internal # 如果使用外部数据库，请将"type"设置为"external"
  internal:
    serviceAccountName: ""
    automountServiceAccountToken: false
    image:
      repository: goharbor/redis-photon
      tag: v2.4.3
    replicas: 3
    nodeSelector: {}
    tolerations: []
    affinity: {}
    priorityClassName:
  external:
    # support redis, redis+sentinel
    # addr for redis: <host_redis>:<port_redis>
    # addr for redis+sentinel: <host_sentinel1>:<port_sentinel1>,<host_sentinel2>:<port_sentinel2>,<host_sentinel3>:<port_sentinel3>
    addr: "redis-redis-ha.redis.svc:26379"
    sentinelMasterSet: "mymaster"
    coreDatabaseIndex: "0"
    jobserviceDatabaseIndex: "1"
    registryDatabaseIndex: "2"
    chartmuseumDatabaseIndex: "3"
    trivyAdapterIndex: "5"
    password: ""
  podAnnotations: {}

exporter:
    replicas: 3
    podAnnotations: {}
    serviceAccountName: ""
    automountServiceAccountToken: false
    image:
      repository: goharbor/harbor-exporter
      tag: v2.4.3
    nodeSelector: {}
    tolerations: []
    affinity: {}
    cacheDuration: 23
    cacheCleanInterval: 14400
    priorityClassName:

metrics:
  enabled: false
  core:
    path: /metrics
    port: 8001
  registry:
    path: /metrics
    port: 8001
  jobservice:
    path: /metrics
    port: 8001
  exporter:
    path: /metrics
    port: 8001
  serviceMonitor:
    enabled: false
    additionalLabels: {}
    interval: ""
    metricRelabelings: []
    relabelings: []

trace:
  enabled: false
  provider: jaeger
  sample_rate: 1
  jaeger:
    endpoint: http://hostname:14268/api/traces
  otel:
    endpoint: hostname:4318
    url_path: /v1/traces
    compression: false
    insecure: true
    timeout: 10s
```

#### 1.5 启动服务

```sh
$ helm repo add harbor https://helm.goharbor.io

# 在线启动
$ helm upgrade --install harbor harbor/harbor -f values.yaml -n harbor

# 本地启动
$ helm pull harbor/harbor --version 1.8.3

$ tar xf harbor-1.8.3.tgz

$ cp values.yaml harbor/values.yaml

$ helm install harbor harbor/harbor -f harbor/values.yaml -n harbor

# harbor-jobservice 的 pvc 好像有问题，需要手动删除然后重新创建一个

$ kubectl delete pvc -n harbor harbor-jobservice

$ vim harbor-jobservice-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: harbor-jobservice
  namespace: harbor
  annotations:
    volume.beta.kubernetes.io/storage-class: "nfs-provisioner-storage"
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 20Gi

$ kubectl apply -f harbor-jobservice-pvc.yaml
```

### 2. 外置 redis 和 postgres

只需要将 databases 和 redis 的 type 模式设置为 external 即可，然后修改相关地址端口和密码数据库信息

外置 redis 好像只能用 sentinel 模式

#### 2.1 部署 redis-cluster

```sh
$ helm repo add bitnami https://charts.bitnami.com/bitnami

$ helm search repo bitnami/redis --versions

$ helm pull bitnami/redis-cluster --version 7.6.1

$ tar xf redis-cluster-7.6.1.tgz

$ cp redis-cluster/values.yaml redis-cluster/values.yaml.bak

$ vim redis-cluster/values.yaml

## 全局配置中未定义 storageClass: ""，会使用集群默认的 storageClass，
## 此处 k8s 集群的默认 storageClass 为 nfs，底层为 华为云 SFS Turbo
## 使用此文档部署，需要自行解决 storageClass 问题 (ceph, nfs, 公有云提供的 nfs)
global:
  redis:
    password: "admin123456"                # 定义 redis 密码

persistence:
  storageClass: "nfs-provisioner-storage"
  accessModes:
    - ReadWriteOnce
  size: 10Gi

image:
  registry: docker.io
  repository: bitnami/redis-cluster
  tag: 7.2.0-debian-11-r0
  pullPolicy: IfNotPresent
  pullSecrets: []

podSecurityContext:
  enabled: true
  fsGroup: 1001
  runAsUser: 1001

containerSecurityContext:
  enabled: true
  runAsUser: 1001
  runAsNonRoot: true

service:
  ports:
    redis: 6379
  nodePorts:
    redis: ""
  type: ClusterIP
  clusterIP: ""
  loadBalancerIP: ""

  livenessProbe:                # 修改了 livenessProbe 的探测时间
    enabled: true
    initialDelaySeconds: 60
    periodSeconds: 30
    timeoutSeconds: 10
    successThreshold: 1
    failureThreshold: 5
  readinessProbe:               # 修改了 readinessProbe 的探测时间
    enabled: true
    initialDelaySeconds: 60
    periodSeconds: 30
    timeoutSeconds: 10
    successThreshold: 1
    failureThreshold: 5
  startupProbe:         # 修改了 startupProbe 的探测时间
    enabled: false
    path: /
    initialDelaySeconds: 300
    periodSeconds: 30
    timeoutSeconds: 10
    failureThreshold: 6
    successThreshold: 1

  nodeSelector: {}           # 设置了服务的 node 亲和性，确保服务运行在指定的节点 （部分 k8s-node 节点运行中间件，部分 k8s-node 节点运行业务）
updateJob:
  nodeSelector: {}           # 设置了服务的 node 亲和性，确保服务运行在指定的节点 （部分 k8s-node 节点运行中间件，部分 k8s-node 节点运行业务）


$ kubectl create ns redis-cluster

$ helm install redis-cluster bitnami/redis-cluster -f redis-cluster/values.yaml -n redis-cluster

$ kubectl get pods -n redis-cluster

$ kubectl get secret -n redis-cluster redis-cluster -o jsonpath="{.data.redis-password}" | base64 --decode

$ export REDIS_PASSWORD=$(kubectl get secret --namespace "redis-cluster" redis-cluster -o jsonpath="{.data.redis-password}" | base64 -d)

$ kubectl run --namespace redis-cluster redis-cluster-client --rm --tty -i --restart='Never' \
 --env REDIS_PASSWORD=$REDIS_PASSWORD \
--image docker.io/bitnami/redis-cluster:7.2.0-debian-11-r0 -- bash

$ redis-cli -c -h redis-cluster -a $REDIS_PASSWORD

$ cluster info

$ cluster nodes
```

#### 2.2 部署 redis-sentinel

```sh
$ helm repo add dandydev https://dandydeveloper.github.io/charts

$ helm search repo dandydev/redis-ha --versions

$ tar xf redis-ha-4.17.4.tgz

$ cp redis-ha/values.yaml redis-ha/values.yaml.bak

# 修改 auth: false 为 auth: true 取消 password 的注释并设置自定义密码
# 修改 hardAntiAffinity: true 为 hardAntiAffinity: false 使其允许 pod 运行在同一台机器上
# 修改 storageClass 使用的 sc 名称
$ vim redis-ha/values.yaml

$ kubectl create ns redis-sentinel

$ helm install redis-sentinel dandydev/redis-ha -f redis-ha/values.yaml -n redis-sentinel

$ kubectl exec -it redis-sentinel-redis-ha-server-0 -n redis-sentinel -c redis -- sh

$ redis-cli -h redis-sentinel-redis-ha.redis-sentinel.svc.cluster.local
```

harbor 修改外部 redis 即可

```sh
  external:
    # support redis, redis+sentinel
    # addr for redis: <host_redis>:<port_redis>
    # addr for redis+sentinel: <host_sentinel1>:<port_sentinel1>,<host_sentinel2>:<port_sentinel2>,<host_sentinel3>:<port_sentinel3>
    addr: "redis-sentinel-redis-ha.redis-sentinel.svc:26379"
    sentinelMasterSet: "mymaster"
    coreDatabaseIndex: "0"
    jobserviceDatabaseIndex: "1"
    registryDatabaseIndex: "2"
    chartmuseumDatabaseIndex: "3"
    trivyAdapterIndex: "5"
    password: "sentinel123456"
```

#### 2.3 部署 postgresql-cluster

**方法一:**

官方文档: https://access.crunchydata.com/documentation/postgres-operator/5.0.0/tutorial/create-cluster/

包不太好找了我直接提供: 
- https://blog.linuxtian.top/data/3-harbor%E7%9B%B8%E5%85%B3/harbor/postgres-ha.zip

```sh
$ unzip postgres-ha.zip

$ cd postgres-ha.zip

$ helm install pgo . -n pgo --create-namespace

$ kubectl apply -f ha-postgres.yaml -n postgres

$ kubectl get secrets -n postgres harbor-pguser-harbor -o 'jsonpath={.data.password}' | base64 -d

$ kubectl get secrets -n postgres harbor-pguser-harbor -o 'jsonpath={.data.host}' | base64 -d
```

**方法二:**


```sh
$ helm search repo postgresql

$ helm pull bitnami/postgresql-ha

$ tar xf postgresql-ha-11.8.5.tgz

$ cd postgresql-ha

$ helm install postgres-ha bitnami/postgresql-ha \
--set postgresql.password=pg12345 \
--set postgresql.repmgrPassword=repmgr12345 \
--set persistence.storageClass=nfs-provisioner-storage \
--set persistence.size=8Gi \
-n postgres-ha \
--create-namespace
NAME: postgres-ha
LAST DEPLOYED: Sun Aug 20 01:25:38 2023
NAMESPACE: postgres-ha
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
CHART NAME: postgresql-ha
CHART VERSION: 11.8.5
APP VERSION: 15.4.0
** Please be patient while the chart is being deployed **
PostgreSQL can be accessed through Pgpool via port 5432 on the following DNS name from within your cluster:

    postgres-ha-postgresql-ha-pgpool.postgres-ha.svc.cluster.local

Pgpool acts as a load balancer for PostgreSQL and forward read/write connections to the primary node while read-only connections are forwarded to standby nodes.

To get the password for "postgres" run:

    export POSTGRES_PASSWORD=$(kubectl get secret --namespace postgres-ha postgres-ha-postgresql-ha-postgresql -o jsonpath="{.data.password}" | base64 -d)

To get the password for "repmgr" run:

    export REPMGR_PASSWORD=$(kubectl get secret --namespace postgres-ha postgres-ha-postgresql-ha-postgresql -o jsonpath="{.data.repmgr-password}" | base64 -d)

To connect to your database run the following command:

    kubectl run postgres-ha-postgresql-ha-client --rm --tty -i --restart='Never' --namespace postgres-ha --image docker.io/bitnami/postgresql-repmgr:15.4.0-debian-11-r5 --env="PGPASSWORD=$POSTGRES_PASSWORD"  \
        --command -- psql -h postgres-ha-postgresql-ha-pgpool -p 5432 -U postgres -d postgres

To connect to your database from outside the cluster execute the following commands:

    kubectl port-forward --namespace postgres-ha svc/postgres-ha-postgresql-ha-pgpool 5432:5432 &
    psql -h 127.0.0.1 -p 5432 -U postgres -d postgres
```

进入数据库创建相关数据库名称

```sh
postgres=# create database harbor;
postgres=# CREATE USER harbor WITH PASSWORD 'harbor12345';
postgres=# GRANT CONNECT ON DATABASE harbor TO harbor;
postgres=# SELECT usename FROM pg_user WHERE usename = 'harbor';
postgres=# create database registry;
postgres=# create database notary_signer;
postgres=# create database notary_server;
postgres=# \q
```

修改 harbor 数据库为外置数据库

```sh
  external:
    host: "postgres-ha-postgresql-ha-pgpool.postgres-ha"
    port: "5432"
    username: "harbor"
    password: "harbor12345"
    coreDatabase: "registry"
    notaryServerDatabase: "notary_server"
    notarySignerDatabase: "notary_signer"
    sslmode: "require"
  maxIdleConns: 100
  maxOpenConns: 900
  podAnnotations: {}
```

**方法二:**

部署postgreSQL operator

```sh
$ helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator

$ helm search repo postgres-operator-charts
NAME                                      	CHART VERSION	APP VERSION	DESCRIPTION                                       
postgres-operator-charts/postgres-operator	1.10.0       	1.10.0     	Postgres Operator creates and manages PostgreSQ...

$ helm pull postgres-operator-charts/postgres-operator

$ tar xvf postgres-operator-1.10.0.tgz 

$ cd postgres-operator/

$ helm install postgres-operator postgres-operator-charts/postgres-operator -n postgres-operator --create-namespace

$ kubectl --namespace=postgres-operator get pods -l "app.kubernetes.io/name=postgres-operator"

$ helm repo add postgres-operator-ui https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui

$ helm search repo postgres-operator-ui

$ helm pull postgres-operator-ui/postgres-operator-ui

$ tar xf postgres-operator-ui-1.10.0.tgz

$ cd postgres-operator-ui

$ helm install postgres-operator-ui postgres-operator-ui/postgres-operator-ui -n postgres-operator

$ kubectl --namespace=postgres-operator get pods -l "app.kubernetes.io/name=postgres-operator-ui"

$ wget https://raw.githubusercontent.com/zalando/postgres-operator/v1.8.2/manifests/minimal-postgres-manifest.yaml

# 修改文件内容, 创建 harbor用户，并为 harbor 创建需要的3个数据库：registry、notary_server、notary_signer
$ vim minimal-postgres-manifest.yaml
apiVersion: "acid.zalan.do/v1"
kind: postgresql
metadata:
  name: acid-minimal-cluster
  namespace: postgres-operator
spec:
  teamId: "acid"
  volume:
    size: 1Gi
    storageClass: nfs-provisioner-storage
  numberOfInstances: 2
  users:
    harbor:
    - superuser
    - createdb
  databases:
    registry: harbor
    notary_server: harbor
    notary_signer: harbor
  preparedDatabases:
    registry: {}
    notary_server: {}
    notary_signer: {}
  postgresql:
    version: "14"

$ kubectl apply -f minimal-postgres-manifest.yaml

# 获取数据库密码
$ kubectl -n postgres-operator get secret postgres.acid-minimal-cluster.credentials.postgresql.acid.zalan.do -o 'jsonpath={.data.password}' | base64 -d
```

harbor 配置数据库

```sh
database:
  type: external
  external:
    host: "acid-minimal-cluster.postgres-operator"
    port: "5432"
    username: "harbor"
    password: "H9AZVgIoXWUPgoYpQJq0Z3NoVNzxKPAZjZCApg3sUafl9lI0ixFtNGKlkeP2ieY8"
    coreDatabase: "registry"
    notaryServerDatabase: "notary_server"
    notarySignerDatabase: "notary_signer"
    sslmode: "require"
```


### 4. 配置docker证书

```sh
$ mkdir -p /etc/docker/certs.d/harbor.demo.com

$ kubectl get secrets -n harbor harbor-tls -o jsonpath="{.data.tls\.crt}" | base64 --decode > /etc/docker/certs.d/harbor.demo.com/tls.crt

$ docker login harbor.demo.com
```

### 5. 更换证书


#### 5.1 使用 nodeport 类型的

```sh
# 重新对域名或IP进行签证书，记得备份
[root@kubesphere ~]# kubectl get secrets -n harbor harbor-tls -o yaml > harbor-nginx-secret.yaml
# 签证书
[root@kubesphere ~]# vim script.sh
#!/bin/bash
openssl req  -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 -out ca.crt -subj "/C=CN/L=Beijing/O=lisea/CN=harbor.demo.com"
openssl req -newkey rsa:4096 -nodes -sha256 -keyout tls.key -out tls.csr -subj "/C=CN/L=Beijing/O=lisea/CN=harbor.demo.com"
# IP地址可以多预留一些，主要是域名能解析到的地址，其他的地址写进去也没用
echo subjectAltName = IP:192.168.1.20, IP:192.168.1.21, IP:192.168.1.110, IP:127.0.0.1, DNS:example.com, DNS:harbor.demo.com > extfile.cnf
openssl x509 -req -days 3650 -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out tls.crt
[root@kubesphere ~]# bash script.sh
[root@kubesphere ~]# kubectl delete secrets -n harbor harbor-tls

# 两种方式貌似都可以
[root@kubesphere ~]# kubectl create secret generic harbor-tls -n harbor \
--from-file=tls.crt \
--from-file=tls.key \
--from-file=ca.crt

# 第二种
[root@kubesphere ~]# kubectl create secret tls harbor-tls -n harbor \
--cert=tls.crt \
--key=tls.key
[root@kubesphere ~]# kubectl rollout restart deployment -n harbor harbor-nginx
[root@kubesphere ~]# cp ca.crt /etc/docker/certs.d/harbor.demo.com/
# 或者
[root@kubesphere ~]# kubectl get secrets  -n harbor harbor-tls -o jsonpath="{.data.ca\.crt}" | base64 --decode > /etc/docker/certs.d/harbor.demo.com/ca.crt
```

#### 5.2 后期使用想使用 ingress

```sh
[root@kubesphere ~]# vim harbor-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: harbor-ingress
  namespace: harbor
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    # 表示后端服务也是 https 格式,如果后端不是 https 请求则不需要配置,因为 harbor-nginx 本身就是 https 代理的
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    ingress.kubernetes.io/ssl-redirect: "true"
    ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  tls:
  - hosts:
    - harbor.demo.com
    secretName: harbor-tls      # 使用上面创建的 secret
  rules:
  - host: harbor.demo.com
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: harbor
            port:
              number: 443
```

#### 5.3 更换 ingress 的证书

删除旧的 ingress 和 secret 直接重新申请证书，然后创建 secret 即可
