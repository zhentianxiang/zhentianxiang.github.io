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

### 1. 部署 pgo 服务

[helm-harbor.tar.gz](https://blog.linuxtian.top/data/3-harbor%E7%9B%B8%E5%85%B3/helm-harbor.tar.gz)

[helm-v3.9.3-linux-amd64.tar.gz](https://blog.linuxtian.top/data/3-harbor%E7%9B%B8%E5%85%B3/helm-v3.9.3-linux-amd64.tar.gz)

导入镜像

```sh
[root@kubesphere app]# mkdir helm-harbor
[root@kubesphere app]# tar xvf helm-harbor.tar.gz
[root@kubesphere app]# cd helm-harbor/images/harbor/
[root@kubesphere harbor]# ./import.sh docker
[root@kubesphere harbor]# cd ../pgo/
[root@kubesphere pgo]# ./import.sh docker
[root@kubesphere pgo]# cd ../redis/
[root@kubesphere redis]# ./import.sh docker
```

修改镜像 tag，将镜像推送到事先准备好的 registry 仓库中

```sh
[root@kubesphere app]# docker run -d -p 5000:5000  \
--name registry --restart=always \
-v /data/registry:/var/lib/registry \
registry:2
Unable to find image 'registry:2' locally
2: Pulling from library/registry
79e9f2f55bf5: Pull complete
0d96da54f60b: Pull complete
5b27040df4a2: Pull complete
e2ead8259a04: Pull complete
3790aef225b9: Pull complete
Digest: sha256:169211e20e2f2d5d115674681eb79d21a217b296b43374b8e39f97fcf866b375
Status: Downloaded newer image for registry:2
fd654277e40a237a2487a20de7c9e6ea11aa0f71b3484625928c1c84c70d29b7
[root@VM-16-9-centos harbor]# vim /etc/docker/daemon.json
{
    "insecure-registries": ["10.0.16.9:5000"]
}
[root@VM-16-9-centos harbor]# systemctl restart docker

# harbor
[root@VM-16-9-centos harbor]# docker images|grep goharbor|grep v2.4.3 |sed 's/goharbor/10.0.16.9\:5000\/goharbor/g'|awk '{print "docker tag" " " $3 " " $1":"$2}' |bash
[root@VM-16-9-centos harbor]# docker images |grep "10.0.16.9:5000/goharbor"
10.0.16.9:5000/goharbor/harbor-portal                                         v2.4.3.1            3067c5ee87da        2 days ago          151MB
10.0.16.9:5000/goharbor/nginx-photon                                          v2.4.3.1            545404fd1696        2 days ago          142MB
10.0.16.9:5000/goharbor/chartmuseum-photon                                    v2.4.3              f39a9694988d        5 months ago        172MB
10.0.16.9:5000/goharbor/trivy-adapter-photon                                  v2.4.3              a406a715461c        5 months ago        251MB
10.0.16.9:5000/goharbor/notary-server-photon                                  v2.4.3              da89404c7cf9        5 months ago        109MB
10.0.16.9:5000/goharbor/notary-signer-photon                                  v2.4.3              38468ac13836        5 months ago        107MB
10.0.16.9:5000/goharbor/harbor-registryctl                                    v2.4.3              61243a84642b        5 months ago        135MB
10.0.16.9:5000/goharbor/registry-photon                                       v2.4.3              9855479dd6fa        5 months ago        77.9MB
10.0.16.9:5000/goharbor/harbor-jobservice                                     v2.4.3              7fea87c4b884        5 months ago        219MB
10.0.16.9:5000/goharbor/harbor-core                                           v2.4.3              d864774a3b8f        5 months ago        197MB
10.0.16.9:5000/goharbor/harbor-db                                             v2.4.3              7693d44a2ad6        5 months ago        225MB
[root@VM-16-9-centos harbor]# docker images |grep "10.0.16.9:5000/goharbor"|awk '{print "docker push "$1":"$2}' |bash
The push refers to repository [10.0.16.9:5000/goharbor/harbor-portal]
c705b35852ec: Pushed
9f9c1e7ff5fd: Pushed
7b72d5d921cb: Pushed
aa3739f310f5: Pushed
6906edffc609: Pushed
f88642d922a1: Pushed
2842e5d66803: Pushed
b5ebffba54d3: Pushed
v2.4.3.1: digest: sha256:8c57bdd6b1d8485871494ffcfbfc21819ff0ab65fed214d8d64f870882f8c4f8 size: 1989

# pgo
[root@VM-16-9-centos pgo]# docker images |grep -E "crunchy-pgbouncer|postgres-operator|postgres-operator-upgrade|crunchy-pgbackrest|crunchy-postgres"|sed 's/registry.developers.crunchydata.com/10.0.16.9\:5000/g'|awk '{print "docker tag" " " $3 " " $1":"$2}' |bash
[root@VM-16-9-centos pgo]# docker images |grep 10.0.16.9:5000/crunchydata
10.0.16.9:5000/crunchydata/crunchy-pgbackrest                                 ubi8-2.38-2         29751805a893        5 months ago        664MB
10.0.16.9:5000/crunchydata/crunchy-postgres                                   ubi8-14.4-0         926adcbc25fb        5 months ago        887MB
10.0.16.9:5000/crunchydata/crunchy-pgbouncer                                  ubi8-1.16-4         9984c2e658a7        5 months ago        578MB
10.0.16.9:5000/crunchydata/postgres-operator                                  ubi8-5.1.2-0        14c26248d0bb        5 months ago        144MB
10.0.16.9:5000/crunchydata/postgres-operator-upgrade                          ubi8-5.1.2-0        01b0a71ea829        5 months ago        136MB
[root@VM-16-9-centos pgo]#  docker images |grep 10.0.16.9:5000/crunchydata |awk '{print "docker push "$1":"$2}' |bash
The push refers to repository [10.0.16.9:5000/crunchydata/crunchy-pgbackrest]
f1dd0c604f88: Pushed
7887c6d54161: Pushed
4f358a3ede87: Pushed

# redis
[root@VM-16-9-centos redis]# docker tag redis:6.2.5-alpine 10.0.16.9:5000/redis:6.2.5-alpine
[root@VM-16-9-centos redis]# docker push 10.0.16.9:5000/redis:6.2.5-alpine
The push refers to repository [10.0.16.9:5000/redis]
70dec5d92878: Pushed
e9176f2edf81: Pushed
87792b9ad065: Pushed
346615b02a36: Pushed
512970cfaf24: Pushed
e2eb06d8af82: Pushed
6.2.5-alpine: digest: sha256:649d5317016d601ac7d6a7b7ef56b6d96196fb7df433d10143189084d52ee6f7 size: 1571
```

替换原配置文件中的镜像地址为10.0.16.9:5000

```sh
# harbor
[root@VM-16-9-centos harbor-1.8.3]# sed -i 's/goharbor/10.0.16.9\:5000\/goharbor/g' values.yaml
[root@VM-16-9-centos harbor-1.8.3]# cat values.yaml |grep repository:|sed 's/ //g'
repository:10.0.16.9:5000/goharbor/nginx-photon
repository:10.0.16.9:5000/goharbor/harbor-portal
repository:10.0.16.9:5000/goharbor/harbor-core
repository:10.0.16.9:5000/goharbor/harbor-jobservice
repository:10.0.16.9:5000/goharbor/registry-photon
repository:10.0.16.9:5000/goharbor/harbor-registryctl
repository:10.0.16.9:5000/goharbor/chartmuseum-photon
repository:10.0.16.9:5000/goharbor/trivy-adapter-photon
repository:10.0.16.9:5000/goharbor/notary-server-photon
repository:10.0.16.9:5000/goharbor/notary-signer-photon
repository:10.0.16.9:5000/goharbor/harbor-db
repository:10.0.16.9:5000/goharbor/redis-photon
repository:10.0.16.9:5000/goharbor/harbor-exporter

# pgo
[root@VM-16-9-centos pgo_install]# sed -i 's/registry.developers.crunchydata.com/10.0.16.9:5000/g' values.yaml
[root@VM-16-9-centos pgo_install]# cat values.yaml |grep image: |sed 's/ //g'
image:10.0.16.9:5000/crunchydata/crunchy-postgres:ubi8-14.4-0
image:10.0.16.9:5000/crunchydata/crunchy-postgres-gis:ubi8-14.4-3.1-0
image:10.0.16.9:5000/crunchydata/crunchy-postgres-gis:ubi8-14.4-3.2-0
image:10.0.16.9:5000/crunchydata/crunchy-postgres:ubi8-13.7-1
image:10.0.16.9:5000/crunchydata/crunchy-postgres-gis:ubi8-13.7-3.0-1
image:10.0.16.9:5000/crunchydata/crunchy-postgres-gis:ubi8-13.7-3.1-1
image:10.0.16.9:5000/crunchydata/crunchy-pgadmin4:ubi8-4.30-2
image:10.0.16.9:5000/crunchydata/crunchy-pgbackrest:ubi8-2.38-2
image:10.0.16.9:5000/crunchydata/crunchy-pgbouncer:ubi8-1.16-4
image:10.0.16.9:5000/crunchydata/crunchy-postgres-exporter:ubi8-5.1.2-0
image:10.0.16.9:5000/crunchydata/crunchy-upgrade:ubi8-5.1.2-0
[root@VM-16-9-centos postgres_cluster]# sed -i 's/registry.developers.crunchydata.com/10.0.16.9:5000/g' ha-postgres.yaml
[root@VM-16-9-centos postgres_cluster]# cat ha-postgres.yaml |grep image: |sed 's/ //g'
image:10.0.16.9:5000/crunchydata/crunchy-postgres:ubi8-14.4-0
image:10.0.16.9:5000/crunchydata/crunchy-pgbackrest:ubi8-2.38-2
image:10.0.16.9:5000/crunchydata/crunchy-pgbouncer:ubi8-1.16-4

# redis
[root@VM-16-9-centos redis-ha]# sed -i 's/repository\: redis/repository\: 10.0.16.9\:5000\/redis/g' values.yaml
[root@VM-16-9-centos redis-ha]# cat values.yaml|grep "repository: 10.0.16.9"|sed 's/ //g'
repository:10.0.16.9:5000/redis
```

安装 helm 工具

```sh
[root@kubesphere redis]# cd /app/harbor-helm
[root@kubesphere harbor-helm]# tar zxvf helm-v3.9.3-linux-amd64.tar.gz
[root@kubesphere harbor-helm]# cp linux-amd64/helm /usr/bin/helm
```

安装 postgres

检查事项：

1. 检查默认存储名与实际k8s是否相符，默认nfs-sc，不填写使用默认的sc

2. 检查分配的pvc⼤⼩是否合适，默认15g

3. 检查数据库名和⽤⼾名，默认名是harbor

```sh
# 可以使用我提前准备好，那样就不需要修改太多了
# https://blog.linuxtian.top/data/helm-harbor/pgo/ha-postgres.yaml
# 修改 storageclass 为我们自己创建的，下面我就不多写了
[root@kubesphere harbor-helm]# vim pgo/postgres_cluster/ha-postgres.yaml

............................
- name: harbor-ha-instance
  replicas: 2
  dataVolumeClaimSpec:
    storageClassName: harbor-storage-nfs
    accessModes:
      - "ReadWriteOnce"
    resources:
      requests:
        storage: 15Gi
............................
repos:
  - name: repo1
    volume:
      volumeClaimSpec:
        storageClassName: harbor-storage-nfs
        accessModes:
          - "ReadWriteOnce"
        resources:
          requests:
            storage: 10Gi
```

启动服务

```sh
[root@kubesphere harbor-helm]# cd pgo/pgo_install/
[root@kubesphere pgo_install]# kubectl create ns pgo
[root@kubesphere pgo_install]# helm install -n pgo pgo .
[root@kubesphere pgo_install]# kubectl get pods -n pgo
NAME                           READY   STATUS    RESTARTS   AGE
pgo-694f6b79bc-hc98j           1/1     Running   0          18d
pgo-694f6b79bc-r947l           1/1     Running   0          18d
pgo-upgrade-76fdb74df8-sxpqk   1/1     Running   0          18d
pgo-upgrade-76fdb74df8-vtzqz   1/1     Running   0          18d
[root@kubesphere pgo_install]# kubectl create ns postgres
[root@kubesphere pgo_install]# kubectl -n postgres apply -f ../postgres_cluster/ha-postgres.yaml
[root@kubesphere pgo_install]# kubectl get pods -n postgres
NAME                               READY   STATUS      RESTARTS   AGE
harbor-backup-m7r5-5ck96           0/1     Completed   0          26s
harbor-harbor-ha-instance-2q5w-0   4/4     Running     0          43s
harbor-harbor-ha-instance-wk2r-0   4/4     Running     0          39s
harbor-pgbouncer-f4ccf6d84-8rssp   2/2     Running     0          42s
harbor-pgbouncer-f4ccf6d84-mdwdb   2/2     Running     0          42s
harbor-repo-host-0                 2/2     Running     0          42s
```

### 2. 部署 redis 服务

> Redis 采⽤哨兵模式启动，使⽤helm 安装，服务供harbor调⽤
>
> Redis 的主要配置是 values.yaml
>
> 检查事项：
>
> 检查副本数量，默认是3
>
> masterGroupName参数设置，默认值是mymaster
>
> storageclass名称，默认没添加需要添加：storageClass: "harbor-storage-nfs"

```sh
[root@kubesphere pgo_install]# cd ../../redis-ha/

# 我准备好的
# https://blog.linuxtian.top/data/helm-harbor/redis/values.yaml
[root@kubesphere redis-ha]# vim values.yaml
```

启动服务

```sh
[root@kubesphere redis-ha]# kubectl create ns redis
[root@kubesphere redis-ha]# helm install -n redis redis .
[root@kubesphere was]# kubectl get pods -n redis
NAME                      READY   STATUS    RESTARTS   AGE
redis-redis-ha-server-0   3/3     Running   0          18d
redis-redis-ha-server-1   3/3     Running   0          18d
redis-redis-ha-server-2   3/3     Running   0          18d
```

### 3. 部署 harbor

> 主要配置⽂件是 value.yaml ⽂件,部署harbor 需要获取postgres 和redis 的信息
>
> Postgres 数据库访问信息全部保存在 secret 中，获取⽅法如下:

**获取password**

```sh
[root@kubesphere redis-ha]# cd ../harbor/harbor-1.8.3/
[root@VM-16-9-centos helm-harbor]# kubectl get secrets -n postgres harbor-pguser-harbor -o json | jq -r '.data.password' | base64 --decode
MksG^-5s.^NDR+>ZT]Xj>]Uf[root@VM-16-9-centos helm-harbor]#
```

**获取 host 的 svc**

```sh
[root@VM-16-9-centos helm-harbor]# kubectl get secrets -n postgres harbor-pguser-harbor -o json | jq -r '.data.host'| base64 --decode
harbor-primary.postgres.svc[root@kubesphere harbor-1.8.3]#
```

**检查事项**

```sh

# harbor 访问部分

1. 25行，commonName: "192.168.20.120"   IP 地址和域名自己随意配置，后期 docker login  你喜欢用地址就写 IP，喜欢用域名就写域名

2. 81行，nodePort: 30080

3. 86行，nodePort: 30443

4. 122行，externalURL: https://192.168.20.120:30443      因为nodeport是30443，所以得加端口

5. 355行，harborAdminPassword: "Harbor12345"  自定义修改数据库密码

# database 数据库部分

1. 704行，type: external ，默认值是internal

2. 740行:，host: "harbor-primary.postgres.svc" 与上⾯获取到pg host 信息保持⼀致

3. 743行，password: "password"， 与上⾯获取到pg password信息保持⼀致

4. 754行，sslmode: "require"

# redis 部分

1. 768行，type: external，默认值是internal

2. 790行，addr: "redis-redis-ha.redis.svc:26379"， 与上⾯获取到 redis svc信息保持⼀致

3. 792行，sentinelMasterSet: "mymaster"， 与上⾯获取到 redis sentinelMasterSet信息保持⼀致

# pvc 部分
# registry
1. 215行，storageClass: "harbor-storage-nfs"
2. 218行，size: 300Gi  大小根据实际共享存储大小来定义
# jobservice
3. 227行，storageClass: "harbor-storage-nfs"
4. 230行，size: 100Gi  大小根据实际共享存储大小来定义
```

如果外部访问方式是 ingress的话，那么会与需要以下配置

```sh
expose:
  type: ingress
  enabled: true
  certSource: auto
    #commonName: "k8s.harbor.com"
  secret:
    secretName: "k8s.harbor.com"
    notarySecretName: "k8s.harbor.com"
ingress:
  hosts:
    core: k8s.harbor.com
    notary: k8s.harbor.com

externalURL: https://k8s.harbor.com
```

**修该pvc**

```sh

```

启动服务

```sh
# 这里就不一一修改了，直接用提供好的配置文件然后自己修改修改
# https://blog.linuxtian.top/data/helm-harbor/harbor/values.yaml
[root@kubesphere harbor-1.8.3]# vim values.yaml
[root@kubesphere harbor-1.8.3]# kubectl create ns harbor
[root@kubesphere harbor-1.8.3]# helm install -n harbor harbor .
[root@kubesphere harbor-1.8.3]# kubectl get pods -n harbor
NAME                                 READY   STATUS    RESTARTS       AGE
harbor-core-7d9465c84c-9fmf7         1/1     Running   1 (18d ago)    18d
harbor-core-7d9465c84c-tmj5x         1/1     Running   12 (18d ago)   18d
harbor-core-7d9465c84c-zgcsx         1/1     Running   1 (18d ago)    18d
harbor-jobservice-5bc6f6bb7d-4z2st   1/1     Running   0              18d
harbor-jobservice-5bc6f6bb7d-h57h7   1/1     Running   12 (18d ago)   18d
harbor-jobservice-5bc6f6bb7d-wpzvs   1/1     Running   0              18d
harbor-nginx-749c899565-gw8zj        1/1     Running   2 (18d ago)    18d
harbor-nginx-749c899565-mhngd        1/1     Running   0              18d
harbor-nginx-749c899565-x5zdw        1/1     Running   2 (18d ago)    18d
harbor-portal-57cf48cfc8-cdbz4       1/1     Running   0              18d
harbor-portal-57cf48cfc8-gt8m7       1/1     Running   0              18d
harbor-portal-57cf48cfc8-wnndw       1/1     Running   0              18d
harbor-registry-54d4d76bc5-4fxrv     2/2     Running   0              18d
harbor-registry-54d4d76bc5-jx7b2     2/2     Running   0              18d
harbor-registry-54d4d76bc5-v4mmm     2/2     Running   0              18d
```

![](/images/posts/Linux-Kubernetes/Kubernetes部署harbor服务/1.png)
![](/images/posts/Linux-Kubernetes/Kubernetes部署harbor服务/2.png)
![](/images/posts/Linux-Kubernetes/Kubernetes部署harbor服务/3.png)

### 4. docker login 证书配置

```sh
[root@kubesphere certs.d]# mkdir 10.135.139.130:30443
[root@kubesphere certs.d]# cd 10.135.139.130\:30443/
[root@kubesphere certs.d]# kubectl get secrets  -n harbor harbor-nginx
[root@kubesphere certs.d]# kubectl get secrets  -n harbor harbor-nginx -o jsonpath="{.data.ca\.crt}" | base64 --decode > server.crt
[root@kubesphere 10.135.139.130:30443]# ls
server.crt
[root@kubesphere 10.135.139.130:30443]# docker login 10.135.139.130:30443 -u admin -p 1qaz@WSX
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```

ingress 访问公钥

```sh
[root@kubesphere k8s.harbor.com:443]# kubectl get secrets -n harbor harbor-ingress -o jsonpath="{.data.ca\.crt}" | base64 --decode > server.crt
[root@kubesphere k8s.harbor.com:443]# docker login  k8s.harbor.com:443 -u admin -p Harbor12345
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
[root@kubesphere ~]# docker tag nginx:latest k8s.harbor.com:443/library/nginx:latest
[root@kubesphere ~]# docker push k8s.harbor.com:443/library/nginx:latest
The push refers to repository [k8s.harbor.com:443/library/nginx]
d874fd2bc83b: Pushed
32ce5f6a5106: Pushed
f1db227348d0: Pushed
b8d6e692a25e: Pushed
e379e8aedd4d: Pushing [==================================================>]     62MB
2edcec3590a4: Pushing [======================================>            ]  61.93MB/80.37MB
```

### 5. CoreDNS 添加 hosts 解析

```sh
[root@kubesphere ~]# kubectl edit configmap -n kube-system coredns
# Please edit the object below. Lines beginning with a '#' will be ignored,
# and an empty file will abort the edit. If an error occurs while saving this file will be
# reopened with the relevant failures.
#
apiVersion: v1
data:
  Corefile: |
    .:53 {
        errors
        health {
           lameduck 5s
        }

        hosts {
          192.168.20.120 k8s.harbor.com
          192.168.20.121 k8s.harbor.com
          fallthrough
.........................
```

重启 pod 进行验证

```sh
[root@kubesphere ~]# kubectl delete pods -n kube-system `kubectl get pods -n kube-system |grep coredns |awk {'print $1'}`
[root@kubesphere ~]# kubectl exec -it jekyll-6589bc94c7-fgttl -- bash
root@jekyll-6589bc94c7-fgttl:/# apt-get install -y inetutils-ping
root@jekyll-6589bc94c7-fgttl:/# ping k8s.harbor.com
PING k8s.harbor.com (192.168.20.120): 56 data bytes
64 bytes from 192.168.20.120: icmp_seq=0 ttl=64 time=0.166 ms
64 bytes from 192.168.20.120: icmp_seq=1 ttl=64 time=0.060 ms
64 bytes from 192.168.20.120: icmp_seq=2 ttl=64 time=0.135 ms
64 bytes from 192.168.20.120: icmp_seq=3 ttl=64 time=0.052 ms
^C--- k8s.harbor.com ping statistics ---
4 packets transmitted, 4 packets received, 0% packet loss
round-trip min/avg/max/stddev = 0.052/0.103/0.166/0.049 ms
```

## 三、更改域名信息和证书信息

### 1. 更换访问域名

```sh
[root@kubesphere ~]# kubectl edit cm -n harbor harbor-core -o yaml
# 修改
  EXT_ENDPOINT: https://harbor.test.com
[root@kubesphere ~]# kubectl rollout restart deployment -n harbor harbor-core
```

### 2. 更换证书

```sh
# 重新对域名或IP进行签证书，记得备份
[root@kubesphere ~]# kubectl get secrets -n harbor harbor-nginx -o yaml > harbor-nginx-secret.yaml
# 签证书
[root@kubesphere ~]# vim script.sh
#!/bin/bash
openssl req  -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 -out ca.crt -subj "/C=CN/L=Beijing/O=lisea/CN=harbor.test.com"
openssl req -newkey rsa:4096 -nodes -sha256 -keyout tls.key -out tls.csr -subj "/C=CN/L=Beijing/O=lisea/CN=harbor.test.com"
# IP地址可以多预留一些，主要是域名能解析到的地址，其他的地址写进去也没用
echo subjectAltName = IP:192.168.1.20, IP:192.168.1.21, IP:192.168.1.110, IP:127.0.0.1, DNS:example.com, DNS:harbor.test.com > extfile.cnf
openssl x509 -req -days 3650 -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out tls.crt
[root@kubesphere ~]# bash script.sh
[root@kubesphere ~]# kubectl delete secrets -n harbor harbor-nginx
[root@kubesphere ~]# kubectl create secret generic harbor-nginx -n harbor \
--from-file=tls.crt \
--from-file=tls.key \
--from-file=ca.crt
[root@kubesphere ~]# kubectl rollout restart deployment -n harbor harbor-nginx
[root@kubesphere ~]# cp ca.crt /etc/docker/certs.d/harbor.test.com/
# 或者
[root@kubesphere ~]# kubectl get secrets  -n harbor harbor-nginx -o jsonpath="{.data.ca\.crt}" | base64 --decode > /etc/docker/certs.d/harbor.test.com/ca.crt
```

### 3. 后期使用 ingress

```sh
[root@kubesphere ~]# vim harbor-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: harbor-ingress
  namespace: harbor
  annotations:
    #kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    ingress.kubernetes.io/ssl-redirect: "true"
    ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - harbor.test.com
    secretName: harbor-nginx
  rules:
  - host: harbor.test.com
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

