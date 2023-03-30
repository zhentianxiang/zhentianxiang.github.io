---
layout: post
title: Linux-Kubernetes-35-Kubernetes部署高可用MongoDB集群
date: 2021-09-03
tags: 实战-Kubernetes
---

在Kubernetes中，部署MongoDB主要用到的是`mongo-db-sidecar`

### 1. 架构

Mongodb的集群搭建方式主要有三种，主从模式，Replica set模式，sharding模式, 三种模式各有优劣，适用于不同的场合，属Replica set应用最为广泛，主从模式现在用的较少，sharding模式最为完备，但配置维护较为复杂。
`mongo-db-sidecar`使用的是Replica set模式，Mongodb的Replica Set即副本集方式主要有两个目的，一个是数据冗余做故障恢复使用，当发生硬件故障或者其它原因造成的宕机时，可以使用副本进行恢复。另一个是做读写分离，读的请求分流到副本上，减轻主（Primary）的读压力。
二进制部署MongoDB集群无需其他服务，直接在主节点执行类似以下的命令即可创建集群:

```
cfg={ _id:"testdb", members:[ {_id:0,host:'192.168.255.141:27017',priority:2}, {_id:1,host:'192.168.255.142:27017',priority:1}, {_id:2,host:'192.168.255.142:27019',arbiterOnly:true}] };
rs.initiate(cfg)
```

### 2. 部署

**本文是部署Mongodb的实践，因为此服务需要用到`namespace`下的`pods`的`list`权限进行集群操作，所以如果在实际部署时，请记得先进行2.5的RBAC操作，然后再进行2.4的Statefulset部署。**

#### 2.1 Namespace

```sh
$ kubectl create ns mongo
```

#### 2.2 StorageClass

这里需要提前部署好NFS或者其他可提供SC的存储集群。

在这一篇中有些pvc的部署过程，可以参考一下

[Linux-Kubernetes-34-交付EFK到K8S](https://blog.linuxtian.top/2021/08/Linux-Kubernetes-34-%E4%BA%A4%E4%BB%98EFK%E5%88%B0K8S/)

```sh
$ vim mongo-clutser-sc.yaml
```

因为我直接用的上一篇的NFS中的 【PROVISIONER_NAME】，所以这里还是这个

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: mongodb-data
provisioner: example.com/nfs
```

#### 2.3 Headless && NodePort

```sh
$ vim mongo-headless.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongo-hs
  namespace: mongo
  labels:
    app: mongo
spec:
  ports:
  - port: 27017
    targetPort: 27017
  clusterIP: None
  selector:
    app: mongo
```

```sh
$ vim mongo-svc.yaml
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongo-svc
  namespace: mongo
  labels:
    app: mongo
spec:
  ports:
  - port: 27017
    targetPort: 27017
    nodePort: 27017
  type: NodePort
  selector:
    app: mongo
```

#### 2.4 Statefulset

```sh
$ vim mongo-statefulset.yaml
```

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongo
  namespace: mongo
spec:
  serviceName: "mongo-hs"
  replicas: 3
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
        environment: test
        logging: "true"
    spec:
      serviceAccountName: mongo
      terminationGracePeriodSeconds: 10
      containers:
        - name: mongo
          image: mongo:3.4.22
          imagePullPolicy: IfNotPresent
          command:
            - mongod
            - "--replSet"
            - rs0
            - "--bind_ip"
            - 0.0.0.0
            - "--smallfiles"
            - "--noprealloc"
          ports:
            - containerPort: 27017
          volumeMounts:
            - name: mongo-persistent-storage
              mountPath: /data/db
        - name: mongo-sidecar
          image: cvallance/mongo-k8s-sidecar
          imagePullPolicy: IfNotPresent
          env:
            - name: MONGO_SIDECAR_POD_LABELS
              value: "role=mongo,environment=test"
  volumeClaimTemplates:
  - metadata:
      name: mongo-persistent-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: mongodb-data
      resources:
        requests:
          storage: 10Gi
```

#### 2.5 RBAC

```sh
$ vim mongo-rbac.yaml
```

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: mongo
  name: mongo
  labels:
    app: mongo
    addonmanager.kubernetes.io/mode: Reconcile
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: mongo
  namespace: mongo
  labels:
    app: mongo
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: mongo
    namespace: mongo
```

### 3. 启动服务

```sh
$ kubectl apply -f .
```

```sh
$ kubectl get all -n mongo
```

### 4. 查看集群状态

```sh
$ kubectl exec -it mongo-0 -n mongo -- mongo
```

可能会提示如下信息：

```sh
Defaulting container name to mongo.
Use 'kubectl describe pod/mongo-0 -n mongo' to see all of the containers in this pod.
MongoDB shell version v3.4.22
connecting to: mongodb://127.0.0.1:27017
MongoDB server version: 3.4.22
Server has startup warnings:
2019-08-24T09:23:57.039+0000 I CONTROL  [initandlisten]
2019-08-24T09:23:57.039+0000 I CONTROL  [initandlisten] ** WARNING: Access control is not enabled for the database.
2019-08-24T09:23:57.039+0000 I CONTROL  [initandlisten] **          Read and write access to data and configuration is unrestricted.
2019-08-24T09:23:57.039+0000 I CONTROL  [initandlisten] ** WARNING: You are running this process as the root user, which is not recommended.
2019-08-24T09:23:57.039+0000 I CONTROL  [initandlisten]
2019-08-24T09:23:57.040+0000 I CONTROL  [initandlisten]
2019-08-24T09:23:57.040+0000 I CONTROL  [initandlisten] ** WARNING: /sys/kernel/mm/transparent_hugepage/enabled is 'always'.
2019-08-24T09:23:57.040+0000 I CONTROL  [initandlisten] **        We suggest setting it to 'never'
2019-08-24T09:23:57.040+0000 I CONTROL  [initandlisten]
2019-08-24T09:23:57.040+0000 I CONTROL  [initandlisten] ** WARNING: /sys/kernel/mm/transparent_hugepage/defrag is 'always'.
2019-08-24T09:23:57.040+0000 I CONTROL  [initandlisten] **        We suggest setting it to 'never'
2019-08-24T09:23:57.040+0000 I CONTROL  [initandlisten]
> rs.status()
{
        "info" : "run rs.initiate(...) if not yet done for the set",
        "ok" : 0,
        "errmsg" : "no replset config has been received",
        "code" : 94,
        "codeName" : "NotYetInitialized"
}
>
```

此时集群是不可用的，需要手动加入节点

### 5. 加入集群

#### 5.1 查看pod网络信息

```sh
$ kubectl get pod -n mongo -o wide
NAME      READY   STATUS    RESTARTS   AGE    IP                NODE         NOMINATED NODE   READINESS GATES
mongo-0   2/2     Running   0          3h3m   192.100.235.217   k8s-master   <none>           <none>
mongo-1   2/2     Running   0          3h2m   192.100.235.199   k8s-master   <none>           <none>
mongo-2   2/2     Running   0          3h1m   192.100.235.230   k8s-master   <none>           <none>
```

#### 5.2 进入容器

```sh
$ kubectl exec -it -n mongo mongo-0 bash
```

#### 5.4 加入节点

```sh
root@mongo-0:/# mongo --port 27017 --host 192.100.235.217
> cfg={"_id":"rs0","members":[{"_id":0,"host":"192.100.235.217:27017"},{"_id":1,"host":"192.100.235.199:27017"},{"_id":2,"host":"192.100.235.230:27017"}]}
# 输出信息如下
{
    "_id" : "haha",
    "members" : [
        {
            "_id" : 0,
            "host" : "192.100.235.217:27017"
        },
        {
            "_id" : 1,
            "host" : "192.100.235.199:27017"
        },
        {
            "_id" : 2,
            "host" : "192.100.235.230:27017"
        }
    ]
}
# 初始化节点
> rs.initiate(cfg)

{
    "ok" : 1,
    "operationTime" : Timestamp(1524083843, 1),
    "$clusterTime" : {
        "clusterTime" : Timestamp(1524083843, 1),
        "signature" : {
            "hash" : BinData(0,"AAAAAAAAAAAAAAAAAAAAAAAAAAA="),
            "keyId" : NumberLong(0)
        }
    }
}

rs0:OTHER> # 回车
rs0:PRIMARY> # 回车
# 查看节点状态
rs0:PRIMARY> rs.status()
{
        "set" : "rs0",
        "date" : ISODate("2021-09-03T05:54:35.927Z"),
        "myState" : 1,
        "term" : NumberLong(1),
        "syncingTo" : "",
        "syncSourceHost" : "",
        "syncSourceId" : -1,
        "heartbeatIntervalMillis" : NumberLong(2000),
        "optimes" : {
                "lastCommittedOpTime" : {
                        "ts" : Timestamp(1630648474, 1),
                        "t" : NumberLong(1)
                },
                "appliedOpTime" : {
                        "ts" : Timestamp(1630648474, 1),
                        "t" : NumberLong(1)
                },
                "durableOpTime" : {
                        "ts" : Timestamp(1630648474, 1),
                        "t" : NumberLong(1)
                }
        },
        "members" : [
                {
                        "_id" : 0,
                        "name" : "192.100.235.217:27017",
                        "health" : 1,
                        "state" : 1,
                        "stateStr" : "PRIMARY",
                        "uptime" : 11645,
                        "optime" : {
                                "ts" : Timestamp(1630648474, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDate" : ISODate("2021-09-03T05:54:34Z"),
                        "syncingTo" : "",
                        "syncSourceHost" : "",
                        "syncSourceId" : -1,
                        "infoMessage" : "",
                        "electionTime" : Timestamp(1630642302, 1),
                        "electionDate" : ISODate("2021-09-03T04:11:42Z"),
                        "configVersion" : 1,
                        "self" : true,
                        "lastHeartbeatMessage" : ""
                },
                {
                        "_id" : 1,
                        "name" : "192.100.235.199:27017",
                        "health" : 1,
                        "state" : 2,
                        "stateStr" : "SECONDARY",
                        "uptime" : 6183,
                        "optime" : {
                                "ts" : Timestamp(1630648474, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDurable" : {
                                "ts" : Timestamp(1630648474, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDate" : ISODate("2021-09-03T05:54:34Z"),
                        "optimeDurableDate" : ISODate("2021-09-03T05:54:34Z"),
                        "lastHeartbeat" : ISODate("2021-09-03T05:54:35.102Z"),
                        "lastHeartbeatRecv" : ISODate("2021-09-03T05:54:34.206Z"),
                        "pingMs" : NumberLong(0),
                        "lastHeartbeatMessage" : "",
                        "syncingTo" : "192.100.235.217:27017",
                        "syncSourceHost" : "192.100.235.217:27017",
                        "syncSourceId" : 0,
                        "infoMessage" : "",
                        "configVersion" : 1
                },
                {
                        "_id" : 2,
                        "name" : "192.100.235.230:27017",
                        "health" : 1,
                        "state" : 2,
                        "stateStr" : "SECONDARY",
                        "uptime" : 6183,
                        "optime" : {
                                "ts" : Timestamp(1630648474, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDurable" : {
                                "ts" : Timestamp(1630648474, 1),
                                "t" : NumberLong(1)
                        },
                        "optimeDate" : ISODate("2021-09-03T05:54:34Z"),
                        "optimeDurableDate" : ISODate("2021-09-03T05:54:34Z"),
                        "lastHeartbeat" : ISODate("2021-09-03T05:54:35.108Z"),
                        "lastHeartbeatRecv" : ISODate("2021-09-03T05:54:34.216Z"),
                        "pingMs" : NumberLong(0),
                        "lastHeartbeatMessage" : "",
                        "syncingTo" : "192.100.235.199:27017",
                        "syncSourceHost" : "192.100.235.199:27017",
                        "syncSourceId" : 1,
                        "infoMessage" : "",
                        "configVersion" : 1
                }
        ],
        "ok" : 1
}
# 最后也可以登录到其他两个容器里面 rs.status() 查看节点状态
```
