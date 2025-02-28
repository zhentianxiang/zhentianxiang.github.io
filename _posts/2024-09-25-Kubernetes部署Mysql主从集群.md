---
layout: post
title: 2024-09-25-Kubernetes部署Mysql主从集群
date: 2024-09-25
tags: 实战-Kubernetes
music-id: 135362

---

## 一、简介

一般情况下Kubernetes可以通过ReplicaSet以一个Pod模板创建多个Pod副本，但是它们都是无状态的，任何时候它们都可以被一个全新的Pod替换。然而有状态的Pod需要另外的方案确保当一个有状态的Pod挂掉后，这个Pod实例需要在别的节点上重建，但是新的实例必须与被替换的实例拥有相同的名称、网络标识和状态。这就是StatefulSet管理Pod的手段。

对于容器集群，有状态服务的挑战在于，通常集群中的任何节点都并非100%可靠的，服务所需的资源也会动态地更新改变。当节点由于故障或服务由于需要更多的资源而无法继续运行在原有节点上时，集群管理系统会为该服务重新分配一个新的运行位置，从而确保从整体上看，集群对外的服务不会中断。

### 1. 实验目的

- 搭建一个主从复制（Master-Slave）的MySQL集群
- 从节点可以水平扩展
- 所有的写操作只能在MySQL主节点上执行
- 读操作可以在MySQL主从节点上执行
- 从节点能同步主节点的数据

![](/images/posts/Linux-Kubernetes/部署Mysql-cluster/1.png)

### 2. 关于副本

**高可用性：**
将主库和从库部署在不同的节点上可以提高可用性。如果某个节点发生故障，集群的其他节点仍然可以继续提供服务。特别是对于生产环境，高可用性是非常关键的。

**资源隔离：**
通过将副本分布在不同的节点上，避免了同一节点上的资源竞争问题，例如 CPU、内存、磁盘 IO 等。每个节点上更少的资源竞争有助于数据库性能稳定。

**减少单点故障：**
如果所有副本都在同一个节点上，该节点故障会导致整个 MySQL 集群不可用。如果将它们分布在不同节点，单节点故障的影响会减小，主库和从库可以继续提供读写或读操作。

**软亲和性（Soft Affinity）：**
在大多数情况下，使用软亲和性规则会更灵活。软亲和性允许 Kubernetes 在资源紧张时仍然可以将多个副本调度到同一节点，但优先考虑将它们调度到不同的节点。这样你可以在性能和资源效率之间取得平衡。

**硬亲和性（Hard Affinity）：**
硬亲和性可以强制确保副本部署到不同的节点上，确保更高的资源隔离和容错性。但如果集群中资源紧张或节点数量有限，硬亲和性可能导致调度失败，副本无法启动。所以硬亲和性适合资源充足并且对高可用性要求非常高的环境。

## 二、开始部署

### 1. 创建 NameSpace

mysql-namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mysql
  labels:
    app: mysql-cluster
```

### 2. 创建 ConfigMap

mysql-config.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-cluster
  namespace: mysql
  labels:
    app: mysql-cluster
data:
  master.cnf: |
    # Master配置
    [mysqld]
    log-bin=mysql-bin                # 启用二进制日志
    server-id=1                      # 为主库指定一个唯一的服务器ID
    bind-address=0.0.0.0             # 允许任何 IP 访问，确保网络可连接
    lower_case_table_names=1         # 如果需要，确保表名不区分大小写
  slave.cnf: |
    # Slave配置
    [mysqld]
    server-id=2                      # 为从库指定一个唯一的服务器ID
    read-only=1                       # 启用只读模式
    relay-log=mysqld-relay-bin        # 启用中继日志
    log-bin=mysql-bin                # 启用二进制日志
```

### 3. 创建 Service

mysql-services.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-cluster
  namespace: mysql
  labels:
    app: mysql-cluster
spec:
  ports:
  - name: mysql-cluster
    port: 3306
  clusterIP: None
  selector:
    app: mysql-cluster
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-read
  namespace: mysql
  labels:
    app: mysql-cluster
spec:
  ports:
  - name: mysql-cluster
    port: 3306
  selector:
    app: mysql-cluster
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-cluster-write
  namespace: mysql
  labels:
    statefulset.kubernetes.io/pod-name: mysql-cluster-0
spec:
  type: NodePort
  ports:
    - name: cluster-write
      port: 3306
      nodePort: 31060
  selector:
    statefulset.kubernetes.io/pod-name: mysql-cluster-0
```

- 用户所有写请求，必须以DNS记录的方式直接访问到Master节点，也就是mysql-cluster-0.mysql这条DNS记录。
- 用户所有读请求，必须访问自动分配的DNS记录可以被转发到任意一个Master或Slave节点上，也就是mysql-read这条DNS记录。

### 4. 创建 MySQL 集群实例

mysql-statefulset.yaml

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-cluster
  namespace: mysql
  labels:
    app: mysql-cluster
spec:
  selector:
    matchLabels:
      app: mysql-cluster
  serviceName: mysql-cluster  # 修改为 mysql-cluster
  replicas: 3
  template:
    metadata:
      labels:
        app: mysql-cluster
    spec:
      affinity:
        nodeAffinity:  # 定义在调度 Pod 时的偏好条件
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: k8s-app
                    operator: In
                    values:
                      - mysql
        podAntiAffinity:  # 确保同一应用的 Pod 不会调度到同一个节点上，以实现负载均衡
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: mysql-cluster
                topologyKey: "kubernetes.io/hostname"
      initContainers:
      - name: init-mysql
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/mysql:5.7
        command:
        - bash
        - "-c"
        - |
          set -ex
          [[ $HOSTNAME =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          echo [mysqld] > /mnt/conf.d/server-id.cnf
          echo server-id=$((100 + $ordinal)) >> /mnt/conf.d/server-id.cnf
          if [[ ${ordinal} -eq 0 ]]; then
            cp /mnt/config-map/master.cnf /mnt/conf.d
          else
            cp /mnt/config-map/slave.cnf /mnt/conf.d
          fi
        volumeMounts:
        - name: conf
          mountPath: /mnt/conf.d
        - name: config-map
          mountPath: /mnt/config-map
      - name: clone-mysql
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/xtrabackup:1.0
        command:
        - bash
        - "-c"
        - |
          set -ex
          [[ -d /var/lib/mysql/mysql ]] && exit 0
          [[ $HOSTNAME =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          [[ $ordinal == 0 ]] && exit 0
          ncat --recv-only mysql-cluster-$(($ordinal-1)).mysql-cluster 3307 | xbstream -x -C /var/lib/mysql
          xtrabackup --prepare --target-dir=/var/lib/mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
      containers:
      - name: mysql
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/mysql:5.7
        env:
        - name: MYSQL_ALLOW_EMPTY_PASSWORD
          value: "1"
        ports:
        - name: mysql
          containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: 0.5
            memory: 1Gi
          limits:
            cpu: 2
            memory: 8Gi
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            command: ["mysql", "-h", "127.0.0.1", "-e", "SELECT 1"]
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 1
      - name: xtrabackup
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/xtrabackup:1.0
        ports:
        - name: xtrabackup
          containerPort: 3307
        command:
        - bash
        - "-c"
        - |
          set -ex
          cd /var/lib/mysql
          if [[ -f xtrabackup_slave_info ]]; then
            mv xtrabackup_slave_info change_master_to.sql.in
            rm -f xtrabackup_binlog_info
          elif [[ -f xtrabackup_binlog_info ]]; then
            [[ `cat xtrabackup_binlog_info` =~ ^(.*?)[[:space:]]+(.*?)$ ]] || exit 1
            rm xtrabackup_binlog_info
            echo "CHANGE MASTER TO MASTER_LOG_FILE='${BASH_REMATCH[1]}',\
                  MASTER_LOG_POS=${BASH_REMATCH[2]}" > change_master_to.sql.in
          fi
          if [[ -f change_master_to.sql.in ]]; then
            echo "Waiting for mysqld to be ready (accepting connections)"
            until mysql -h 127.0.0.1 -e "SELECT 1"; do sleep 1; done
            echo "Initializing replication from clone position"
            mv change_master_to.sql.in change_master_to.sql.orig
            mysql -h 127.0.0.1 <<EOF
          $(<change_master_to.sql.orig),
            MASTER_HOST='mysql-cluster-0.mysql-cluster',
            MASTER_USER='root',
            MASTER_PASSWORD='',
            MASTER_CONNECT_RETRY=10;
          START SLAVE;
          EOF
          fi
          exec ncat --listen --keep-open --send-only --max-conns=1 3307 -c \
            "xtrabackup --backup --slave-info --stream=xbstream --host=127.0.0.1 --user=root"
        resources:
          requests:
            cpu: 100m
            memory: 500Mi
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
      volumes:
      - name: conf
        emptyDir: {}
      - name: config-map
        configMap:
          name: mysql-cluster
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
      - "ReadWriteOnce"
      storageClassName: openebs-hostpath
      resources:
        requests:
          storage: 100Gi
```

### 5. 提交资源

```sh
$ kubectl apply -f .
```

## 三、验证集群

### 1. 查看 slave 节点连接状态

```sh
$ kubectl -n mysql exec mysql-cluster-1 -c mysql -- bash -c "mysql -uroot -e 'show slave status \G'"
$ kubectl -n mysql exec mysql-cluster-2 -c mysql -- bash -c "mysql -uroot -e 'show slave status \G'"
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: mysql-cluster-0.mysql-cluster
                  Master_User: root
                  Master_Port: 3306
                Connect_Retry: 10
              Master_Log_File: mysql-bin.000003
          Read_Master_Log_Pos: 154
               Relay_Log_File: mysqld-relay-bin.000002
                Relay_Log_Pos: 320
        Relay_Master_Log_File: mysql-bin.000003
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB: 
          Replicate_Ignore_DB: 
           Replicate_Do_Table: 
       Replicate_Ignore_Table: 
      Replicate_Wild_Do_Table: 
  Replicate_Wild_Ignore_Table: 
                   Last_Errno: 0
                   Last_Error: 
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 154
              Relay_Log_Space: 528
              Until_Condition: None
               Until_Log_File: 
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File: 
           Master_SSL_CA_Path: 
              Master_SSL_Cert: 
            Master_SSL_Cipher: 
               Master_SSL_Key: 
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error: 
               Last_SQL_Errno: 0
               Last_SQL_Error: 
  Replicate_Ignore_Server_Ids: 
             Master_Server_Id: 100
                  Master_UUID: 5e8814a1-c429-11ef-9c92-22a40940e72a
             Master_Info_File: /var/lib/mysql/master.info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind: 
      Last_IO_Error_Timestamp: 
     Last_SQL_Error_Timestamp: 
               Master_SSL_Crl: 
           Master_SSL_Crlpath: 
           Retrieved_Gtid_Set: 
            Executed_Gtid_Set: 
                Auto_Position: 0
         Replicate_Rewrite_DB: 
                 Channel_Name: 
           Master_TLS_Version:
```

### 2. 在 master 节点生成数据

```sh
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -e 'create database test'"
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -e 'use test;create table counter(c int);'"
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -e 'use test;insert into counter values(123)'"
```

### 3. 检查数据是否同步

```sh
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -e 'use test;select * from counter'"
mysql: [Warning] Using a password on the command line interface can be insecure.
c
123
$ kubectl -n mysql exec mysql-cluster-1 -c mysql -- bash -c "mysql -uroot -e 'use test;select * from counter'"
mysql: [Warning] Using a password on the command line interface can be insecure.
c
123
$ kubectl -n mysql exec mysql-cluster-2 -c mysql -- bash -c "mysql -uroot -e 'use test;select * from counter'"
mysql: [Warning] Using a password on the command line interface can be insecure.
c
123
```

### 4. 动态扩容 slave 节点

```sh
$ kubectl -n mysql scale statefulset mysql-cluster --replicas=5
$ kubectl get pods -n mysql -o wide
NAME              READY   STATUS    RESTARTS   AGE     IP               NODE                NOMINATED NODE   READINESS GATES
mysql-cluster-0   2/2     Running   0          15m     192.18.75.47     k8s-node5-storage   <none>           <none>
mysql-cluster-1   2/2     Running   0          14m     192.18.235.50    k8s-node7-storage   <none>           <none>
mysql-cluster-2   2/2     Running   0          14m     192.18.107.220   k8s-node3           <none>           <none>
mysql-cluster-3   2/2     Running   0          3m      192.18.169.163   k8s-node2           <none>           <none>
mysql-cluster-4   2/2     Running   0          2m11s   192.18.36.86     k8s-node1           <none>           <none>
$ kubectl -n mysql exec mysql-cluster-3 -c mysql -- bash -c "mysql -uroot -e 'use test;select * from counter'"
mysql: [Warning] Using a password on the command line interface can be insecure.
c
123
$ kubectl -n mysql exec mysql-cluster-4 -c mysql -- bash -c "mysql -uroot -e 'use test;select * from counter'"
mysql: [Warning] Using a password on the command line interface can be insecure.
c
123
```

## 四、模拟故障

### 1. 停止节点调度
```sh
$ kubectl cordon k8s-node1 
node/k8s-node1 cordoned
$ kubectl delete pods -n mysql mysql-cluster-0 
pod "mysql-cluster-0" deleted
```

### 2. 删除 pod 使其无法调度

```sh
$ kubectl delete pods -n mysql mysql-cluster-0 
pod "mysql-cluster-0" deleted

$ kubectl get pods -n mysql  -o wide
NAME              READY   STATUS        RESTARTS   AGE   IP               NODE        NOMINATED NODE   READINESS GATES
mysql-cluster-0   2/2     Terminating   0          21m   192.18.36.122    k8s-node1   <none>           <none>
mysql-cluster-1   2/2     Running       0          20m   192.18.169.172   k8s-node2   <none>           <none>
mysql-cluster-2   2/2     Running       0          20m   192.18.107.221   k8s-node3   <none>           <none>
```

### 3. 查看 slave 节点日志

```sh
$ kubectl -n mysql logs --tail=100 -f mysql-cluster-1 mysql
2024-12-27T08:26:55.317874Z 4 [ERROR] Slave I/O for channel '': error reconnecting to master 'root@mysql-cluster-0.mysql-cluster:3306' - retry-time: 10  retries: 3, Error_code: 2005
2024-12-27T08:27:05.332476Z 4 [ERROR] Slave I/O for channel '': error reconnecting to master 'root@mysql-cluster-0.mysql-cluster:3306' - retry-time: 10  retries: 4, Error_code: 2005
```

### 4. 进行 pvc 存储目录备份

```sh
$ kubectl get pvc -n mysql 
NAME                   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS       AGE
data-mysql-cluster-0   Bound    pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2   100Gi      RWO            openebs-hostpath   17m
data-mysql-cluster-1   Bound    pvc-151d9d1c-cec1-45ce-8341-7a9921b5c0dc   100Gi      RWO            openebs-hostpath   17m
data-mysql-cluster-2   Bound    pvc-a3faa26e-39c6-4e9d-85cf-41591f26905a   100Gi      RWO            openebs-hostpath   16m

# 登录到 k8s-node1
$ ssh k8s-node1 
Last login: Fri Dec 27 17:05:14 2024 from 172.16.246.151
$ cd /var/openebs/local/
$ ls
pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2
$ du -sh pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2/
213M    pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2/

$ zip -r pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2-mysql-cluster-0.zip pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2/

# 删除 pvc 否则一会儿重新调度还会调度在这儿（当然我模拟环境是吧 k8s-node1 停止调度了，不删除也不会调度）
$ rm -rf pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2
```
### 5. 选择新节点启动 mysql-cluster-0

```sh
$ logout
Connection to k8s-node1 closed.

# 选择新节点
$  kubectl label node k8s-node4 k8s-app=mysql
node/k8s-node4 labeled

# 恢复调度(我的目的是为了删除这个pod，否则一直Terminating)
$ kubectl uncordon k8s-node1 
node/k8s-node1 already uncordoned

# 停止 statefule 服务
$ kubectl scale statefulset -n mysql mysql-cluster --replicas=0
statefulset.apps/mysql-cluster scaled

# 并且删除他的 pvc 资源
$ kubectl delete pvc -n mysql data-mysql-cluster-0
persistentvolumeclaim "data-mysql-cluster-0" deleted

$ kubectl get pods -n mysql
No resources found in mysql namespace.

# 再次停止调度(防止调度到k8s-node1)有问题机器上去
$ kubectl cordon k8s-node1 
node/k8s-node1 cordoned

# 开启服务
$ kubectl scale statefulset -n mysql mysql-cluster --replicas=3

# 发现已经调度到 k8s-node4 节点了,同时也创建了新的 pvc 存储
$ kubectl get pods,pvc -n mysql  -o wide
NAME                  READY   STATUS     RESTARTS   AGE   IP       NODE        NOMINATED NODE   READINESS GATES
pod/mysql-cluster-0   0/2     Init:0/2   0          14s   <none>   k8s-node4   <none>           <none>

NAME                                         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS       AGE   VOLUMEMODE
persistentvolumeclaim/data-mysql-cluster-0   Bound    pvc-2e0d1733-da8d-4136-ba4f-0bad95cd3ef2   100Gi      RWO            openebs-hostpath   17s   Filesystem
persistentvolumeclaim/data-mysql-cluster-1   Bound    pvc-151d9d1c-cec1-45ce-8341-7a9921b5c0dc   100Gi      RWO            openebs-hostpath   35m   Filesystem
persistentvolumeclaim/data-mysql-cluster-2   Bound    pvc-a3faa26e-39c6-4e9d-85cf-41591f26905a   100Gi      RWO            openebs-hostpath   35m   Filesystem

# 再次停止调度
$ kubectl scale statefulset -n mysql mysql-cluster --replicas=0
statefulset.apps/mysql-cluster scaled
```

### 6. 恢复数据

```sh
# 登录到 k8s-node4
$ ssh k8s-node4

# 进入 pvc 存储目录
$ cd /var/openebs/local/

# 拷贝 k8s-node1 数据过来
$ scp k8s-node1:/var/openebs/local/*.zip ./

$ ls -lh
total 7.7M
drwxrwxrwx 2 root root    6 Dec 27 17:23 pvc-2e0d1733-da8d-4136-ba4f-0bad95cd3ef2
-rw-r--r-- 1 root root 7.7M Dec 27 17:26 pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2-mysql-cluster-0.zip

# 解压原数据文件
$ unzip pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2-mysql-cluster-0.zip

# 删除新创建的，重命名旧的为新的
$ rm -rf pvc-2e0d1733-da8d-4136-ba4f-0bad95cd3ef2/

$ mv pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2 pvc-2e0d1733-da8d-4136-ba4f-0bad95cd3ef2

$ ls -lh
total 7.7M
drwxrwxrwx 3 root root   19 Dec 27 16:47 pvc-2e0d1733-da8d-4136-ba4f-0bad95cd3ef2
-rw-r--r-- 1 root root 7.7M Dec 27 17:26 pvc-d64838da-13cd-4dba-a1d1-cc80203ce9d2-mysql-cluster-0.zip

$ ls pvc-2e0d1733-da8d-4136-ba4f-0bad95cd3ef2/mysql/
auto.cnf    client-cert.pem  ibdata1      ibtmp1            mysql-bin.000002  mysql-bin.index     public_key.pem   sys
ca-key.pem  client-key.pem   ib_logfile0  mysql             mysql-bin.000003  performance_schema  server-cert.pem  xtrabackup_backupfiles
ca.pem      ib_buffer_pool   ib_logfile1  mysql-bin.000001  mysql-bin.000004  private_key.pem     server-key.pem
```

### 7. 启动服务

```sh
$ kubectl scale statefulset -n mysql mysql-cluster --replicas=3

$ kubectl get pods -n mysql -o wide
NAME              READY   STATUS    RESTARTS   AGE   IP              NODE        NOMINATED NODE   READINESS GATES
mysql-cluster-0   1/2     Running   0          42s   192.18.122.94   k8s-node4   <none>           <none>

$ kubectl get pods -n mysql -o wide
NAME              READY   STATUS    RESTARTS   AGE    IP               NODE        NOMINATED NODE   READINESS GATES
mysql-cluster-0   2/2     Running   0          105s   192.18.122.94    k8s-node4   <none>           <none>
mysql-cluster-1   2/2     Running   0          63s    192.18.169.175   k8s-node2   <none>           <none>
mysql-cluster-2   2/2     Running   0          55s    192.18.107.204   k8s-node3   <none>           <none>
```

### 8. 检查服务

```sh
# 检查主从同步状态
$ kubectl -n mysql exec mysql-cluster-1 -c mysql -- bash -c "mysql -uroot -e 'show slave status \G'"|grep -E "Master_Host|Slave_IO_Running|Slave_SQL_Running"
                  Master_Host: mysql-cluster-0.mysql-cluster
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
      Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates

$ kubectl -n mysql exec mysql-cluster-2 -c mysql -- bash -c "mysql -uroot -e 'show slave status \G'"|grep -E "Master_Host|Slave_IO_Running|Slave_SQL_Running"
                  Master_Host: mysql-cluster-0.mysql-cluster
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
      Slave_SQL_Running_State: Slave has read all relay log; waiting for more updates

# 测试数据是否同步
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -e 'use test;select * from counter'"
c
123
$ kubectl -n mysql exec mysql-cluster-1 -c mysql -- bash -c "mysql -uroot -e 'use test;select * from counter'"
c
123
$ kubectl -n mysql exec mysql-cluster-2 -c mysql -- bash -c "mysql -uroot -e 'use test;select * from counter'"
c
123
```

## 四、mysql 8.0+ 集群

### 1. 创建 NameSpace

mysql-namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: mysql
  labels:
    app: mysql-cluster
```

### 2. 创建 ConfigMap

mysql-config.yaml

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-cluster
  namespace: mysql
  labels:
    app: mysql-cluster
data:
  master.cnf: |
    [mysqld]
    log-bin
    default_authentication_plugin= mysql_native_password
    datadir=/var/lib/mysql
    max_connections=3000
    innodb_lock_wait_timeout=500
    character-set-server=utf8mb4
    collation-server=utf8mb4_general_ci
    default-storage-engine=INNODB
    sort_buffer_size=4096M
    innodb_buffer_pool_size = 4096M
    innodb_log_file_size = 512M
    innodb_log_buffer_size = 4096M
    bulk_insert_buffer_size = 4096M
    tmp_table_size = 512M
    default-time-zone='+8:00'
    max_allowed_packet = 512M

  slave.cnf: |
    [mysqld]
    super-read-only
    default_authentication_plugin= mysql_native_password
    datadir=/var/lib/mysql
    max_connections=3000
    innodb_lock_wait_timeout=500
    character-set-server=utf8mb4
    collation-server=utf8mb4_general_ci
    default-storage-engine=INNODB
    sort_buffer_size=4096M
    innodb_buffer_pool_size = 4096M
    innodb_log_file_size = 512M 
    innodb_log_buffer_size = 4096M
    bulk_insert_buffer_size = 4096M
    tmp_table_size = 512M 
    default-time-zone='+8:00'
    max_allowed_packet = 512M
```

### 3. 创建 Service

mysql-services.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-cluster
  namespace: mysql
  labels:
    app: mysql-cluster
spec:
  ports:
  - name: mysql-cluster
    port: 3306
  clusterIP: None
  selector:
    app: mysql-cluster
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-read
  namespace: mysql
  labels:
    app: mysql-cluster
spec:
  ports:
  - name: mysql-cluster
    port: 3306
  selector:
    app: mysql-cluster
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-cluster-write
  namespace: mysql
  labels:
    statefulset.kubernetes.io/pod-name: mysql-cluster-0
spec:
  type: NodePort
  ports:
    - name: cluster-write
      port: 3306
      nodePort: 31060
  selector:
    statefulset.kubernetes.io/pod-name: mysql-cluster-0
```

- 用户所有写请求，必须以DNS记录的方式直接访问到Master节点，也就是mysql-cluster-0.mysql这条DNS记录。
- 用户所有读请求，必须访问自动分配的DNS记录可以被转发到任意一个Master或Slave节点上，也就是mysql-read这条DNS记录。

### 4. 创建 MySQL 密码 Secret

mysql-secret.yaml

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: mysql-cluster-secret
  namespace: mysql
  labels:
    app: mysql-cluster
type: Opaque
data:
  password: MTIzNDU2 # echo -n "123456" | base64
```

### 5. 创建 MySQL 集群实例

mysql-statefulset.yaml

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-cluster
  namespace: mysql
spec: 
  selector: 
    matchLabels: 
      app: mysql-cluster
  serviceName: mysql-cluster
  replicas: 3
  template: 
    metadata:
      labels:
        app: mysql-cluster
    spec:
      affinity:
        nodeAffinity:  # 定义在调度 Pod 时的偏好条件
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: k8s-app
                    operator: In
                    values:
                      - mysql
        podAntiAffinity:  # 确保同一应用的 Pod 不会调度到同一个节点上，以实现负载均衡
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app: mysql-cluster
                topologyKey: "kubernetes.io/hostname"
      initContainers:
      - name: init-mysql
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/mysql:8.0.18
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-cluster-secret
              key: password
        command:
        - bash
        - "-c"
        - |
          set ex
          # 从hostname中获取索引，比如(mysql-1)会获取(1)
          [[ $HOSTNAME =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          echo [mysqld] > /mnt/conf.d/server-id.cnf
          # 为了不让server-id=0而增加偏移量
          echo server-id=$((100 + $ordinal)) >> /mnt/conf.d/server-id.cnf
          # 拷贝对应的文件到/mnt/conf.d/文件夹中
          if [[ $ordinal -eq 0 ]]; then
            cp /mnt/config-map/master.cnf /mnt/conf.d/
          else
            cp /mnt/config-map/slave.cnf /mnt/conf.d/
          fi
        volumeMounts:
        - name: conf
          mountPath: /mnt/conf.d
        - name: config-map
          mountPath: /mnt/config-map
      - name: clone-mysql
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/xtrabackup:2.3
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-cluster-secret
              key: password
        command:
        - bash
        - "-c"
        - |
          set -ex
          # 整体意思:
          # 1.如果是主mysql中的xtrabackup,就不需要克隆自己了,直接退出
          # 2.如果是从mysql中的xtrabackup,先判断是否是第一次创建，因为第二次重启本地就有数据库，无需克隆。若是第一次创建(通过/var/lib/mysql/mysql文件是否存在判断),就需要克隆数据库到本地。
          # 如果有数据不必克隆数据，直接退出()
          [[ -d /var/lib/mysql/mysql ]] && exit 0
          # 如果是master数据也不必克隆
          [[ $HOSTNAME =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          [[ $ordinal -eq 0 ]] && exit 0
          # 从序列号比自己小一的数据库克隆数据，比如mysql-2会从mysql-1处克隆数据
          ncat --recv-only mysql-cluster-$(($ordinal-1)).mysql-cluster 3307 | xbstream -x -C /var/lib/mysql
          # 比较数据
          xtrabackup --prepare --target-dir=/var/lib/mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
      containers:
      - name: mysql
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/mysql:8.0.18
        args: ["--default-authentication-plugin=mysql_native_password"]
        env:
        - name: MYSQL_DATABASE
          value: "nacos"
        - name: MYSQL_PASSWORD
          value: "nacos"
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-cluster-secret
              key: password
        - name: MYSQL_ALLOW_EMPTY_PASSWORD
          value: "1"
        ports:
        - name: mysql
          containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 8Gi
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping", "-uroot", "-p${MYSQL_ROOT_PASSWORD}"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            command: ["mysqladmin", "ping", "-uroot", "-p${MYSQL_ROOT_PASSWORD}"]
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 1
      - name: xtrabackup
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/xtrabackup:2.3
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysql-cluster-secret
              key: password
        ports:
        - name: xtrabackup
          containerPort: 3307
        command:
        - bash
        - "-c"
        - |
          set -ex
          # 确定binlog 克隆数据位置(如果binlog存在的话).
          cd /var/lib/mysql
          # 如果存在该文件，则该xrabackup是从现有的从节点克隆出来的。
          if [[ -s xtrabackup_slave_info ]]; then
            mv xtrabackup_slave_info change_master_to.sql.in
            rm -f xtrabackup_binlog_info
          elif [[ -f xtrabackup_binlog_info ]]; then         
            [[ `cat xtrabackup_binlog_info` =~ ^(.*?)[[:space:]]+(.*?)$ ]] || exit 1
            rm xtrabackup_binlog_info
            echo "CHANGE MASTER TO MASTER_LOG_FILE='${BASH_REMATCH[1]}',\
                  MASTER_LOG_POS=${BASH_REMATCH[2]}" > change_master_to.sql.in
          fi     
          if [[ -f change_master_to.sql.in ]]; then
            echo "Waiting for mysqld to be ready (accepting connections)"
            until mysql -h 127.0.0.1 -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1"; do sleep 1; done
            echo "Initializing replication from clone position"
            mv change_master_to.sql.in change_master_to.sql.orig
            mysql -h 127.0.0.1 -p${MYSQL_ROOT_PASSWORD} <<EOF
          $(<change_master_to.sql.orig),
            MASTER_HOST='mysql-cluster-0.mysql-cluster',
            MASTER_USER='root',
            MASTER_PASSWORD='${MYSQL_ROOT_PASSWORD}',
            MASTER_CONNECT_RETRY=10;
          START SLAVE;
          EOF
          fi
          exec ncat --listen --keep-open --send-only --max-conns=1 3307 -c \
            "xtrabackup --backup --slave-info --stream=xbstream --host=127.0.0.1 --user=root --password=${MYSQL_ROOT_PASSWORD}"
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          limits:
            cpu: 500m
            memory: 2Gi
          requests:
            cpu: 500m
            memory: 1Gi
      volumes:
      - name: conf
        emptyDir: {}
      - name: config-map
        configMap:
          name: mysql-cluster
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:    
      accessModes:
        - ReadWriteOnce
      storageClassName: longhorn
      resources:
        requests:
          storage: 20Gi
```

### 6. 提交资源

```sh
$ kubectl apply -f .
```

## 五、验证集群

### 1. 查看节点信息

```sh
$ kubectl -n mysql exec -it mysql-cluster-0 -- bash -c "mysql -uroot -p123456 -e 'show master status \G;'"
Defaulted container "mysql" out of: mysql, xtrabackup, init-mysql (init), clone-mysql (init)
mysql: [Warning] Using a password on the command line interface can be insecure.
*************************** 1. row ***************************
             File: mysql-cluster-0-bin.000004
         Position: 810
     Binlog_Do_DB: 
 Binlog_Ignore_DB: 
Executed_Gtid_Set:

$ kubectl -n mysql exec -it mysql-cluster-1 -- bash -c "mysql -uroot -p123456 -e 'show slave status \G;'"|head -n 15
Defaulted container "mysql" out of: mysql, xtrabackup, init-mysql (init), clone-mysql (init)
mysql: [Warning] Using a password on the command line interface can be insecure.
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: mysql-cluster-0.mysql-cluster.mysql.svc.cluster.local
                  Master_User: root
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-cluster-0-bin.000004
          Read_Master_Log_Pos: 810
               Relay_Log_File: mysql-cluster-1-relay-bin.000002
                Relay_Log_Pos: 987
        Relay_Master_Log_File: mysql-cluster-0-bin.000004
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB: 

$ kubectl -n mysql exec -it mysql-cluster-2 -- bash -c "mysql -uroot -p123456 -e 'show slave status \G;'"|head -n 15
Defaulted container "mysql" out of: mysql, xtrabackup, init-mysql (init), clone-mysql (init)
mysql: [Warning] Using a password on the command line interface can be insecure.
*************************** 1. row ***************************
               Slave_IO_State: Waiting for master to send event
                  Master_Host: mysql-cluster-0.mysql-cluster.mysql.svc.cluster.local
                  Master_User: root
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-cluster-0-bin.000004
          Read_Master_Log_Pos: 810
               Relay_Log_File: mysql-cluster-2-relay-bin.000002
                Relay_Log_Pos: 987
        Relay_Master_Log_File: mysql-cluster-0-bin.000004
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB:
```

如果第二个从节点提示 No 不是 Yes，可以尝试如下

```sh
$ kubectl -n mysql exec -it mysql-cluster-2 -- bash -c "mysql -uroot -p123456 -e 'STOP SLAVE;'"
$ kubectl -n mysql exec -it mysql-cluster-2 -- bash -c "mysql -uroot -p123456 -e 'RESET SLAVE;'"
$ kubectl -n mysql exec -it mysql-cluster-2 -- bash -c "mysql -uroot -p123456 -e 'START SLAVE;'"
$ kubectl -n mysql exec -it mysql-cluster-2 -- bash -c "mysql -uroot -p123456 -e 'show slave status \G;'"|head -n 15
```

### 2. 在 master 节点生成数据

```sh
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -p123456 -e 'create database test'"
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -p123456 -e 'use test;create table counter(c int);'"
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -p123456 -e 'use test;insert into counter values(123)'"
```

### 3. 检查数据是否同步

```sh
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -p123456 -e 'use test;select * from counter'"
mysql: [Warning] Using a password on the command line interface can be insecure.
c
123
$ kubectl -n mysql exec mysql-cluster-1 -c mysql -- bash -c "mysql -uroot -p123456 -e 'use test;select * from counter'"
mysql: [Warning] Using a password on the command line interface can be insecure.
c
123
$ kubectl -n mysql exec mysql-cluster-2 -c mysql -- bash -c "mysql -uroot -p123456 -e 'use test;select * from counter'"
mysql: [Warning] Using a password on the command line interface can be insecure.
c
123
```

### 4. 动态扩容 slave 节点

```sh
$ kubectl -n mysql scale statefulset mysql-cluster --replicas=5
$ kubectl get pods -n mysql -o wide
NAME              READY   STATUS    RESTARTS   AGE     IP               NODE                NOMINATED NODE   READINESS GATES
mysql-cluster-0   2/2     Running   0          15m     192.18.75.47     k8s-node5-storage   <none>           <none>
mysql-cluster-1   2/2     Running   0          14m     192.18.235.50    k8s-node7-storage   <none>           <none>
mysql-cluster-2   2/2     Running   0          14m     192.18.107.220   k8s-node3           <none>           <none>
mysql-cluster-3   2/2     Running   0          3m      192.18.169.163   k8s-node2           <none>           <none>
mysql-cluster-4   2/2     Running   0          2m11s   192.18.36.86     k8s-node1           <none>           <none>
$ kubectl -n mysql exec mysql-cluster-3 -c mysql -- bash -c "mysql -uroot -p123456 -e 'use test;select * from counter'"
mysql: [Warning] Using a password on the command line interface can be insecure.
c
123
$ kubectl -n mysql exec mysql-cluster-4 -c mysql -- bash -c "mysql -uroot -p123456 -e 'use test;select * from counter'"
mysql: [Warning] Using a password on the command line interface can be insecure.
c
123
```

## 六、存储高可用性和 Mysql 数据完整性验证

### 1. 集群节点信息

为了验证集群的高可用性，我将关闭某一台存储来验证 mysql 集群是否正常写入和读取数据

首先来你看一下我的节点信息,最后三台机器为存储机器，也是部署在k8s中的,使用的 longohorn 分布式存储,定义的最后三台机器为存储节点。

```sh
$ kubectl get node 
NAME                STATUS   ROLES                  AGE     VERSION
k8s-master1         Ready    control-plane,master   2d20h   v1.23.0
k8s-master2         Ready    control-plane,master   2d20h   v1.23.0
k8s-master3         Ready    control-plane,master   2d20h   v1.23.0
k8s-node1           Ready    <none>                 2d20h   v1.23.0
k8s-node2           Ready    <none>                 2d20h   v1.23.0
k8s-node3           Ready    <none>                 2d20h   v1.23.0
k8s-node4           Ready    <none>                 2d20h   v1.23.0
k8s-node5-storage   Ready    <none>                 2d20h   v1.23.0
k8s-node6-storage   Ready    <none>                 2d20h   v1.23.0
k8s-node7-storage   Ready    <none>                 2d20h   v1.23.0
```

由于节点亲和性和 pod 亲和性，三个 pod 分别部署在 3 台节点上,保证集群的高可用性，和负载均衡性

```sh
$ kubectl get pods -n mysql  -o wide
NAME              READY   STATUS    RESTARTS       AGE     IP               NODE        NOMINATED NODE   READINESS GATES
mysql-cluster-0   2/2     Running   0              4m31s   192.18.169.135   k8s-node2   <none>           <none>
mysql-cluster-1   2/2     Running   1 (3m4s ago)   3m46s   192.18.107.227   k8s-node3   <none>           <none>
mysql-cluster-2   2/2     Running   1 (7s ago)     3m      192.18.122.125   k8s-node4   <none>           <none>
```

### 2. 脚本测试数据完整性

首先 mysql 集群肯定不用验证高可用性，断开一台 slave 还能正常运行，当然 master 断开的话就完蛋了因为集群做的是一主多从

- 使用脚本来持续写入数据 write_data.sh

```sh
#!/bin/bash

# MySQL 连接信息
MYSQL_HOST="192.18.169.135"  # 主节点地址
MYSQL_USER="root"
MYSQL_PASS="123456"  # 替换为实际密码
DATABASE="test_db"
TABLE="test_table"

# 测试 MySQL 连接是否成功
echo "Testing MySQL connection..."
mysql -h ${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASS} -e "SELECT VERSION();" || {
    echo "Failed to connect to MySQL at ${MYSQL_HOST}."
    exit 1
}

# 创建数据库
echo "Creating database: ${DATABASE}..."
mysql -h ${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASS} -e "CREATE DATABASE IF NOT EXISTS ${DATABASE};" || {
    echo "Failed to create database ${DATABASE}."
    exit 1
}

# 创建表
echo "Creating table: ${TABLE}..."
mysql -h ${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASS} -e "
    USE ${DATABASE};
    CREATE TABLE IF NOT EXISTS ${TABLE} (
        id INT AUTO_INCREMENT PRIMARY KEY,
        data VARCHAR(255)
    );
" || {
    echo "Failed to create table ${TABLE} in database ${DATABASE}."
    exit 1
}

# 循环写入数据
echo "Inserting data..."
for i in $(seq 1 100); do
    mysql -h ${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASS} -e "
        USE ${DATABASE};
        INSERT INTO ${TABLE} (data) VALUES ('Test data $i');
    " || {
        echo "Failed to insert Test data $i."
        exit 1
    }
    echo "Inserted Test data $i"
    sleep 1  # 控制插入频率，模拟实际写入过程
done

echo "Data insertion completed."
```

- 使用脚本来读取数据 read_data.sh

```sh
#!/bin/bash

# MySQL 连接信息
MYSQL_HOST="10.96.214.80"  # 主节点地址
MYSQL_USER="root"
MYSQL_PASS="123456"  # 替换为实际密码
DATABASE="test_db"
TABLE="test_table"

# 测试 MySQL 连接是否成功
echo "Testing MySQL connection..."
mysql -h ${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASS} -e "SELECT VERSION();" || {
    echo "Failed to connect to MySQL at ${MYSQL_HOST}."
    exit 1
}

# 循环读取数据
echo "Reading data from ${TABLE} in ${DATABASE}..."
while true; do
    mysql -h ${MYSQL_HOST} -u${MYSQL_USER} -p${MYSQL_PASS} -e "
        USE ${DATABASE};
        SELECT * FROM ${TABLE};
    " || {
        echo "Failed to read data from ${TABLE} in database ${DATABASE}."
        exit 1
    }
    
    echo "Data read successfully."
    sleep 1  # 每秒读取一次
done
```

### 3. 开始测试

准备三个 shell 窗口分别执行脚本和 reboot 重启某一台存储节点

- 窗口 1

```sh
$ ./write_data.sh
Testing MySQL connection...
+-----------+
| VERSION() |
+-----------+
| 8.0.18    |
+-----------+
Creating database: test_db...
Creating table: test_table...
Inserting data...
Inserted Test data 1
Inserted Test data 2
Inserted Test data 3
Inserted Test data 4
Inserted Test data 5
Inserted Test data 6
Inserted Test data 7
Inserted Test data 8
Inserted Test data 9
Inserted Test data 10
```

- 窗口 2

```sh
./read_data.sh
Data read successfully.
+-----+---------------+
| id  | data          |
+-----+---------------+
|   1 | Test data 1   |
|   2 | Test data 2   |
|   3 | Test data 3   |
|   4 | Test data 4   |
|   5 | Test data 5   |
|   6 | Test data 6   |
|   7 | Test data 7   |
|   8 | Test data 8   |
|   9 | Test data 9   |
|  10 | Test data 10  |
```

- 窗口 3

```sh
Last login: Thu Sep 26 09:48:22 2024 from 10.4.212.151
[root@k8s-node5-storage ~]# reboot

[root@k8s-master1 ~]# kubectl get node -o wide
NAME                STATUS     ROLES                  AGE     VERSION   INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION                CONTAINER-RUNTIME
k8s-master1         Ready      control-plane,master   2d20h   v1.23.0   10.4.212.151   <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   docker://20.10.9
k8s-master2         Ready      control-plane,master   2d20h   v1.23.0   10.4.212.152   <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   docker://20.10.9
k8s-master3         Ready      control-plane,master   2d20h   v1.23.0   10.4.212.153   <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   docker://20.10.9
k8s-node1           Ready      <none>                 2d20h   v1.23.0   10.4.212.154   <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   docker://20.10.9
k8s-node2           Ready      <none>                 2d20h   v1.23.0   10.4.212.155   <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   docker://20.10.9
k8s-node3           Ready      <none>                 2d20h   v1.23.0   10.4.212.156   <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   docker://20.10.9
k8s-node4           Ready      <none>                 2d20h   v1.23.0   10.4.212.157   <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   docker://20.10.9
k8s-node5-storage   NotReady   <none>                 2d20h   v1.23.0   10.4.212.158   <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   docker://20.10.9
k8s-node6-storage   Ready      <none>                 2d20h   v1.23.0   10.4.212.159   <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   docker://20.10.9
k8s-node7-storage   Ready      <none>                 2d20h   v1.23.0   10.4.212.160   <none>        CentOS Linux 7 (Core)   5.4.160-1.el7.elrepo.x86_64   docker://20.10.9
```
持续观察窗口1和2是否断开，数据是否一致

## 七、数据库压力测试

### 1. 安装 Sysbench

```sh
$ yum -y install sysbench
```

### 2. 创建数据库

```sh
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -p123456 -e 'CREATE DATABASE IF NOT EXISTS sbtest;'"
```

### 3. 创建要测试的表

192.18.169.135 是 mysql-cluster-0 master 节点的 pod 地址

```sh
$ sysbench /usr/share/sysbench/oltp_read_write.lua \
    --db-driver=mysql \
    --mysql-host=192.18.169.135 \
    --mysql-user=root \
    --mysql-password=123456 \
    --mysql-db=sbtest \
    --tables=1 \
    --table-size=100000 \
    prepare
```

### 4. 写入压力测试

> 这里的参数解释：
> --table-size=100000 设置每个表中的行数，这里是 10 万 行
> --threads=10: 指定 10 个并发线程进行测试。
> --time=60: 进行 60 秒的压力测试。
> --report-interval=1: 每秒报告一次结果

```sh
sysbench /usr/share/sysbench/oltp_read_write.lua \
    --db-driver=mysql \
    --mysql-host=192.18.169.135 \
    --mysql-user=root \
    --mysql-password=123456 \
    --mysql-db=sbtest \
    --tables=1 \
    --table-size=100000 \
    --threads=10 \
    --time=60 \
    --report-interval=1 \
    run
```

### 5. 写入压力测试结果

#### SQL统计：

- **查询执行**：
  - 读操作：284536次
  - 写操作：81296次
  - 其他操作：40648次
  - 总计：406480次
- **事务**：20324次（每秒338.56次）
- **查询总数**：406480次（每秒6771.24次）
- **忽略错误**：0次（每秒0次）
- **重新连接**：0次（每秒0次）

#### 常规统计：

- **总时间**：60.0260秒
- **总事件数**：20324

#### 延迟（毫秒）：

- **最小值**：12.95毫秒
- **平均值**：29.52毫秒
- **最大值**：226.85毫秒
- **95百分位**：48.34毫秒
- **总和**：600054.33毫秒

#### 线程公平性：

- **事件（平均值/标准差）**：2032.4000/35.41
- **执行时间（平均值/标准差）**：60.0054/0.01

#### 分析：

- **事务和查询性能**：你的数据库每秒可以处理338.56次事务和6771.24次查询，表明数据库在测试期间表现良好。
- **延迟**：平均延迟为29.52毫秒，这通常被认为是良好的性能。然而，最大延迟达到了226.85毫秒，这可能表明在某些情况下数据库响应较慢。95百分位延迟是48.34毫秒，这意味着95%的请求在48.34毫秒内得到响应。
- **线程公平性**：事件和执行时间的平均值与标准差都相对较低，这表明测试期间的负载在各个线程之间分配相对均匀。

### 6. 读取压力测试

10.96.214.80 是 mysql 的 service 地址, 因为读取有多个 slave 节点, 可以使用 service 进行负载均衡

```sh
sysbench /usr/share/sysbench/oltp_read_only.lua \
    --db-driver=mysql \
    --mysql-host=10.96.214.80 \
    --mysql-user=root \
    --mysql-password=123456 \
    --mysql-db=sbtest \
    --tables=1 \
    --table-size=100000 \
    --threads=10 \
    --time=60 \
    --report-interval=1 \
    run
```

### 7. 读取压力测试结果

#### SQL统计：

- **查询执行**：
  - 读操作：1,237,194次
  - 写操作：0次
  - 其他操作（如开始事务、提交事务）：176,742次
  - 总计：1,413,936次
- **事务**：88,371次（每秒1472.60次）
- **查询总数**：1,413,936次（每秒23,561.58次）
- **忽略错误**：0次（每秒0.00次），表明测试过程中没有发生错误。
- **重新连接**：0次（每秒0.00次）

#### 常规统计：

- **总时间**：60.0072秒
- **总事件数**：88,371

#### 延迟（毫秒）：

- **最小值**：4.21毫秒
- **平均值**：6.79毫秒
- **最大值**：214.04毫秒
- **95百分位**：7.70毫秒，这意味着95%的请求在7.70毫秒内得到响应。
- **总和**：599,805.19毫秒

#### 线程公平性：

- **事件（平均值/标准差）**：8,837.10/183.24，表明线程之间事件分配相对均匀。
- **执行时间（平均值/标准差）**：59.9805/0.00，表明线程之间执行时间分配也非常接近。

#### 分析：

- **事务和查询性能**：数据库每秒可以处理1472.60次事务和23,561.58次查询，这表明数据库在读取测试期间表现出色。
- **延迟**：平均延迟为6.79毫秒，这是一个非常快的响应时间，表明数据库能够迅速处理查询。95百分位延迟是7.70毫秒，这意味着95%的请求都在7.70毫秒内得到处理，这对于大多数应用来说都是可接受的。
- **错误**：没有忽略错误，这是一个很好的结果，表明测试在没有遇到任何问题的情况下完成。
- **线程公平性**：线程之间的事件和执行时间分配非常均匀，这表明负载分配合理，没有出现某些线程比其他线程工作更多或更少的情况。

### 8. 清理测试数据

```sh
$ kubectl -n mysql exec mysql-cluster-0 -c mysql -- bash -c "mysql -uroot -p123456 -e 'DROP DATABASE sbtest;'"
```