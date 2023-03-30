---
layout: post
title: Linux-Kubernetes-12-交付Portal至K8S
date: 2021-04-28
tags: 实战-Kubernetes
---

### 安装压缩包

[官方压缩包](https://github.com/ctripcorp/apollo/releases/download/v1.5.1/apollo-portal-1.5.1-github.zip)

```sh
[root@host0-200 apollo-adminservice]# mkdir -pv /data/dockerfile/apollo-portal
[root@host0-200 src]# unzip apollo-portal-1.5.1-github.zip -d /data/dockerfile/apollo-portal/
Archive:  apollo-portal-1.5.1-github.zip
   creating: /data/dockerfile/apollo-portal/scripts/
  inflating: /data/dockerfile/apollo-portal/apollo-portal.conf  
  inflating: /data/dockerfile/apollo-portal/apollo-portal-1.5.1.jar  
  inflating: /data/dockerfile/apollo-portal/scripts/startup.sh  
  inflating: /data/dockerfile/apollo-portal/config/apollo-env.properties  
  inflating: /data/dockerfile/apollo-portal/scripts/shutdown.sh  
  inflating: /data/dockerfile/apollo-portal/config/app.properties  
  inflating: /data/dockerfile/apollo-portal/apollo-portal-1.5.1-sources.jar  
  inflating: /data/dockerfile/apollo-portal/config/application-github.properties
```

### 配置压缩包

```sh
[root@host0-200 src]# cd /data/dockerfile/apollo-portal/
[root@host0-200 apollo-portal]# ll
总用量 42512
-rwxr-xr-x 1 root root 42342196 11月  9 2019 apollo-portal-1.5.1.jar
-rwxr-xr-x 1 root root  1183429 11月  9 2019 apollo-portal-1.5.1-sources.jar
-rw-r--r-- 1 root root       57 4月  20 2017 apollo-portal.conf
drwxr-xr-x 2 root root       94 4月  28 19:24 config
drwxr-xr-x 2 root root       43 10月  1 2019 scripts
```

因为这个连接的是ApolloPortalDB数据库，所以要去数据库进行相关的配置

### 配置数据库

[官方sql脚本](https://raw.githubusercontent.com/ctripcorp/apollo/master/scripts/apollo-on-kubernetes/db/portal-db/apolloportaldb.sql)

```sh
[root@host0-11 ~]# wget https://raw.githubusercontent.com/ctripcorp/apollo/master/scripts/apollo-on-kubernetes/db/portal-db/apolloportaldb.sql -O apolloportal.sql
--2021-04-28 19:41:25--  https://raw.githubusercontent.com/ctripcorp/apollo/master/scripts/apollo-on-kubernetes/db/portal-db/apolloportaldb.sql
正在解析主机 raw.githubusercontent.com (raw.githubusercontent.com)... 185.199.110.133, 185.199.111.133, 185.199.109.133, ...
正在连接 raw.githubusercontent.com (raw.githubusercontent.com)|185.199.110.133|:443... 已连接。
已发出 HTTP 请求，正在等待回应... 200 OK
长度：16355 (16K) [text/plain]
正在保存至: “apolloportal.sql”

100%[=======================================================================================================================================================================================================>] 16,355      --.-K/s 用时 0.009s  

2021-04-28 19:41:26 (1.78 MB/s) - 已保存 “apolloportal.sql” [16355/16355])

[root@host0-11 ~]# mysql -u root -p
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 304
Server version: 10.1.48-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> source ./apolloportal.sql
Query OK, 0 rows affected (0.00 sec)

Query OK, 0 rows affected (0.00 sec)
MariaDB [ApolloPortalDB]> show databases;
+--------------------+
| Database           |
+--------------------+
| ApolloConfigDB     |
| ApolloPortalDB     |
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
5 rows in set (0.00 sec)

MariaDB [ApolloPortalDB]> use ApolloPortalDB
Database changed

MariaDB [ApolloPortalDB]> show tables;
+--------------------------+
| Tables_in_ApolloPortalDB |
+--------------------------+
| App                      |
| AppNamespace             |
| Authorities              |
| Consumer                 |
| ConsumerAudit            |
| ConsumerRole             |
| ConsumerToken            |
| Favorite                 |
| Permission               |
| Role                     |
| RolePermission           |
| ServerConfig             |
| UserRole                 |
| Users                    |
+--------------------------+
14 rows in set (0.00 sec)
```

### 配置数据库授权

```sh
MariaDB [ApolloPortalDB]> grant INSERT,DELETE,UPDATE,SELECT on ApolloPortalDB.* to 'apolloportal'@'10.0.0.%'  identified by "123123";
Query OK, 0 rows affected (0.00 sec)
MariaDB [ApolloPortalDB]> select user,host from mysql.user;
+--------------+-----------+
| user         | host      |
+--------------+-----------+
| apolloconfig | 10.0.0.%  |
| apolloportal | 10.0.0.%  |
| root         | 127.0.0.1 |
| root         | ::1       |
|              | host0-13  |
| root         | host0-13  |
|              | localhost |
| root         | localhost |
+--------------+-----------+
8 rows in set (0.00 sec)
```

### 修改数据库信息

```sh
MariaDB [ApolloPortalDB]> select * from ServerConfig\G
*************************** 1. row ***************************
                       Id: 1
                      Key: apollo.portal.envs
                    Value: dev, fat, uat, pro
                  Comment: 可支持的环境列表
                IsDeleted:  
     DataChange_CreatedBy: default
   DataChange_CreatedTime: 2021-04-28 19:42:34
DataChange_LastModifiedBy: 
      DataChange_LastTime: 2021-04-28 19:42:34
*************************** 2. row ***************************
                       Id: 2
                      Key: organizations
                    Value: [{"orgId":"TEST1","orgName":"样例部门1"},{"orgId":"TEST2","orgName":"样例部门2"}]

# 添加value值
MariaDB [ApolloPortalDB]> update ServerConfig set Value='[{"orgId":"od01","orgName":"Linux学院"},{"orgId":"od02","orgName":"云计算学院"},{"orgId":"od03","orgName":"Python学院"}]' where Id=2;
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

MariaDB [ApolloPortalDB]> select * from ServerConfig\G
*************************** 1. row ***************************
                       Id: 1
                      Key: apollo.portal.envs
                    Value: dev, fat, uat, pro
                  Comment: 可支持的环境列表
                IsDeleted:  
     DataChange_CreatedBy: default
   DataChange_CreatedTime: 2021-04-28 19:42:34
DataChange_LastModifiedBy: 
      DataChange_LastTime: 2021-04-28 19:42:34
*************************** 2. row ***************************
                       Id: 2
                      Key: organizations
                    Value: [{"orgId":"od01","orgName":"Linux学院"},{"orgId":"od02","orgName":"云计算学院"},{"orgId":"od03","orgName":"Python学院"}]
                  Comment: 部门列表
```

> 由于使用concigmap资源，故之做介绍，不在这里修改：
>
> 配置portal meta serice：
>
> 这里列出的是支持的环境列表配置：

```sh
[root@host0-200 config]# cat apollo-env.properties 
local.meta=http://localhost:8080
dev.meta=http://fill-in-dev-meta-server:8080
fat.meta=http://fill-in-fat-meta-server:8080
uat.meta=http://fill-in-uat-meta-server:8080
lpt.meta=${lpt_meta}
pro.meta=http://fill-in-pro-meta-server:8080
```

### 配置启动脚本

[官方脚本](https://raw.githubusercontent.com/ctripcorp/apollo/1.5.1/scripts/apollo-on-kubernetes/apollo-portal-server/scripts/startup-kubernetes.sh)

```sh
[root@host0-200 apollo-portal]# vim scripts/startup.sh
#!/bin/bash
SERVICE_NAME=apollo-portal
## Adjust log dir if necessary
LOG_DIR=/opt/logs/apollo-portal-server
## Adjust server port if necessary
SERVER_PORT=8080
APOLLO_ADMIN_SERVICE_NAME=$(hostname -i)

# SERVER_URL="http://localhost:$SERVER_PORT"
SERVER_URL="http://${APOLLO_PORTAL_SERVICE_NAME}:${SERVER_PORT}"

## Adjust memory settings if necessary
#export JAVA_OPTS="-Xms2560m -Xmx2560m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=1536m -XX:MaxNewSize=1536m -XX:SurvivorRatio=8"

## Only uncomment the following when you are using server jvm
#export JAVA_OPTS="$JAVA_OPTS -server -XX:-ReduceInitialCardMarks"

########### The following is the same for configservice, adminservice, portal ###########
export JAVA_OPTS="$JAVA_OPTS -XX:ParallelGCThreads=4 -XX:MaxTenuringThreshold=9 -XX:+DisableExplicitGC -XX:+ScavengeBeforeFullGC -XX:SoftRefLRUPolicyMSPerMB=0 -XX:+ExplicitGCInvokesConcurrent -XX:+HeapDumpOnOutOfMemoryError -XX:-OmitStackTraceInFastThrow -Duser.timezone=Asia/Shanghai -Dclient.encoding.override=UTF-8 -Dfile.encoding=UTF-8 -Djava.security.egd=file:/dev/./urandom"
export JAVA_OPTS="$JAVA_OPTS -Dserver.port=$SERVER_PORT -Dlogging.file.name=$LOG_DIR/$SERVICE_NAME.log -XX:HeapDumpPath=$LOG_DIR/HeapDumpOnOutOfMemoryError/"

# Find Java
if [[ -n "$JAVA_HOME" ]] && [[ -x "$JAVA_HOME/bin/java" ]]; then
    javaexe="$JAVA_HOME/bin/java"
elif type -p java > /dev/null 2>&1; then
    javaexe=$(type -p java)
elif [[ -x "/usr/bin/java" ]];  then
    javaexe="/usr/bin/java"
else
    echo "Unable to find Java"
    exit 1
fi

if [[ "$javaexe" ]]; then
    version=$("$javaexe" -version 2>&1 | awk -F '"' '/version/ {print $2}')
    version=$(echo "$version" | awk -F. '{printf("%03d%03d",$1,$2);}')
    # now version is of format 009003 (9.3.x)
    if [ $version -ge 011000 ]; then
        JAVA_OPTS="$JAVA_OPTS -Xlog:gc*:$LOG_DIR/gc.log:time,level,tags -Xlog:safepoint -Xlog:gc+heap=trace"
    elif [ $version -ge 010000 ]; then
        JAVA_OPTS="$JAVA_OPTS -Xlog:gc*:$LOG_DIR/gc.log:time,level,tags -Xlog:safepoint -Xlog:gc+heap=trace"
    elif [ $version -ge 009000 ]; then
        JAVA_OPTS="$JAVA_OPTS -Xlog:gc*:$LOG_DIR/gc.log:time,level,tags -Xlog:safepoint -Xlog:gc+heap=trace"
    else
        JAVA_OPTS="$JAVA_OPTS -XX:+UseParNewGC"
        JAVA_OPTS="$JAVA_OPTS -Xloggc:$LOG_DIR/gc.log -XX:+PrintGCDetails"
        JAVA_OPTS="$JAVA_OPTS -XX:+UseConcMarkSweepGC -XX:+UseCMSCompactAtFullCollection -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=60 -XX:+CMSClassUnloadingEnabled -XX:+CMSParallelRemarkEnabled -XX:CMSFullGCsBeforeCompaction=9 -XX:+CMSClassUnloadingEnabled  -XX:+PrintGCDateStamps -XX:+PrintGCApplicationConcurrentTime -XX:+PrintHeapAtGC -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=5 -XX:GCLogFileSize=5M"
    fi
fi

printf "$(date) ==== Starting ==== \n"

cd `dirname $0`/..
chmod 755 $SERVICE_NAME".jar"
./$SERVICE_NAME".jar" start

rc=$?;

if [[ $rc != 0 ]];
then
    echo "$(date) Failed to start $SERVICE_NAME.jar, return code: $rc"
    exit $rc;
fi

tail -f /dev/null
```

### 编写dockerfile文件

```sh
[root@host0-200 apollo-portal]# vim Dockerfile

FROM harbor.od.com/base/jre8:8u112

ENV VERSION 1.5.1

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&\
    echo "Asia/Shanghai" > /etc/timezone

ADD apollo-portal-${VERSION}.jar /apollo-portal/apollo-portal.jar
ADD config/ /apollo-portal/config
ADD scripts/ /apollo-portal/scripts

CMD ["/apollo-portal/scripts/startup.sh"]
```

### 上传镜像

```sh
[root@host0-200 apollo-portal]# docker build . -t harbor.od.com/infra/apollo-portal:v1.5.1
Sending build context to Docker daemon  42.36MB
Step 1/7 : FROM stanleyws/jre8:8u112
 ---> fa3a085d6ef1
Step 2/7 : ENV VERSION 1.5.1
 ---> Using cache
 ---> 3c714c38ed42
Step 3/7 : RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&    echo "Asia/Shanghai" > /etc/timezone
 ---> Using cache
 ---> 554ac271efef
Step 4/7 : ADD apollo-portal-${VERSION}.jar /apollo-portal/apollo-portal.jar
 ---> 9862b219d727
Step 5/7 : ADD config/ /apollo-portal/config
 ---> c64f9d5cfcbd
Step 6/7 : ADD scripts/ /apollo-portal/scripts
 ---> 588743ec27aa
Step 7/7 : CMD ["/apollo-portal/scripts/startup.sh"]
 ---> Running in 8283fc6dd5d9
Removing intermediate container 8283fc6dd5d9
 ---> a5ad570ceb98
Successfully built a5ad570ceb98
Successfully tagged harbor.od.com/infra/apollo-portal:v1.5.1
[root@host0-200 apollo-portal]# docker push harbor.od.com/infra/apollo-portal:v1.5.1
The push refers to repository [harbor.od.com/infra/apollo-portal]
c15245a7e9ae: Pushed 
8fc3b67a77a3: Pushed 
506876287f67: Pushed 
ea00563634b4: Mounted from infra/apollo-adminservice 
0690f10a63a5: Mounted from infra/apollo-adminservice 
c843b2cf4e12: Mounted from infra/apollo-adminservice 
fddd8887b725: Mounted from infra/apollo-adminservice 
42052a19230c: Mounted from infra/apollo-adminservice 
8d4d1ab5ff74: Mounted from infra/apollo-adminservice 
v1.5.1: digest: sha256:361f58e022252ed4fd16406000adaec23a90c29123c3d3a24a80d4641c5e4165 size: 2201
```

### 编写资源配置清单

```sh
[root@host0-200 apollo-portal]# mkdir -pv /data/k8s-yaml/apollo-portal && cd /data/k8s-yaml/apollo-portal
mkdir: 已创建目录 "/data/k8s-yaml/apollo-portal"
[root@host0-200 apollo-portal]# vim cm.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: apollo-portal-cm
  namespace: infra
data:
  application-github.properties: |
    # DataSource
    spring.datasource.url = jdbc:mysql://mysql.od.com:3306/ApolloPortalDB?characterEncoding=utf8
    spring.datasource.username = apolloportal
    spring.datasource.password = 123123
  app.properties: |
    appId=100003173
  apollo-env.properties: |
    dev.meta=http://config.od.com

[root@host0-200 apollo-portal]# vim dp.yaml

kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: apollo-portal
  namespace: infra
  labels: 
    name: apollo-portal
spec:
  replicas: 1
  selector:
    matchLabels: 
      name: apollo-portal
  template:
    metadata:
      labels: 
        app: apollo-portal 
        name: apollo-portal
    spec:
      volumes:
      - name: configmap-volume
        configMap:
          name: apollo-portal-cm
      containers:
      - name: apollo-portal
        image: harbor.od.com/infra/apollo-portal:v1.5.1
        ports:
        - containerPort: 8080
          protocol: TCP
        volumeMounts:
        - name: configmap-volume
          mountPath: /apollo-portal/config
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        imagePullPolicy: IfNotPresent
      imagePullSecrets:
      - name: harbor
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      securityContext: 
        runAsUser: 0
      schedulerName: default-scheduler
  strategy:
    type: RollingUpdate
    rollingUpdate: 
      maxUnavailable: 1
      maxSurge: 1
  revisionHistoryLimit: 7
  progressDeadlineSeconds: 600

[root@host0-200 apollo-portal]# vim svc.yaml

kind: Service
apiVersion: v1
metadata: 
  name: apollo-portal
  namespace: infra
spec:
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
  selector: 
    app: apollo-portal

[root@host0-200 apollo-portal]# vim ingress.yaml

kind: Ingress
apiVersion: extensions/v1beta1
metadata: 
  name: apollo-portal
  namespace: infra
spec:
  rules:
  - host: portal.od.com
    http:
      paths:
      - path: /
        backend: 
          serviceName: apollo-portal
          servicePort: 8080
```

### 提交资源配置清单

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-portal/cm.yaml
configmap/apollo-portal-cm created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-portal/svc.yaml
deployment.extensions/apollo-portal created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-portal/dp.yaml
service/apollo-portal created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-portal/ingress.yaml
ingress.extensions/apollo-portal created
```

### 配置解析

```sh
[root@host0-200 ~]# vim /var/named/od.com.zone 

$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020010514 ; serial
                10800      ; refresh (3 hours)
                900        ; retry (15 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
                )
                NS   dns.od.com.
$TTL 60 ; 1 minute
dns                A    10.0.0.200
harbor             A    10.0.0.200
k8s-yaml           A    10.0.0.200
traefik            A    10.0.0.10
dashboard          A    10.0.0.10
zk1                A    10.0.0.11
zk2                A    10.0.0.12
zk3                A    10.0.0.21
mirrors            A    10.0.0.200
jenkins            A    10.0.0.10
dubbo-monitor      A    10.0.0.10
demo               A    10.0.0.10
config             A    10.0.0.10
mysql              A    10.0.0.21
portal             A    10.0.0.10
[root@host0-200 ~]# systemctl restart named
```
