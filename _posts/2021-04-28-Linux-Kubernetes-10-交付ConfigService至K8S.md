---
layout: post
title: Linux-Kubernetes-10-交付ConfigService至K8S
date: 2021-04-28
tags: 实战-Kubernetes
---



## 交付ConfiService至K8S

[官方 release 包](https://github.com/ctripcorp/apollo/tags)

### 安装Apollo config service压缩包

```sh
[root@host0-200 src]# cd /opt/src
[root@host0-200 src]# wget https://github.com/ctripcorp/apollo/releases/download/v1.5.1/apollo-configservice-1.5.1-github.zip
[root@host0-200 src]# mkdir -pv /data/dockerfile/apollo-configservice
[root@host0-200 src]# unzip -o apollo-configservice-1.5.1-github.zip -d /data/dockerfile/apollo-configservice/
Archive:  apollo-configservice-1.5.1-github.zip
   creating: /data/dockerfile/apollo-configservice/scripts/
  inflating: /data/dockerfile/apollo-configservice/config/application-github.properties  
  inflating: /data/dockerfile/apollo-configservice/apollo-configservice.conf  
  inflating: /data/dockerfile/apollo-configservice/scripts/shutdown.sh  
  inflating: /data/dockerfile/apollo-configservice/apollo-configservice-1.5.1-sources.jar  
  inflating: /data/dockerfile/apollo-configservice/scripts/startup.sh  
  inflating: /data/dockerfile/apollo-configservice/config/app.properties  
  inflating: /data/dockerfile/apollo-configservice/apollo-configservice-1.5.1.jar  
[root@host0-200 src]# cd /data/dockerfile/apollo-configservice/
[root@host0-200 apollo-configservice]# ll
总用量 60584
-rwxr-xr-x 1 root root 61991736 11月  9 2019 apollo-configservice-1.5.1.jar
-rwxr-xr-x 1 root root    40249 11月  9 2019 apollo-configservice-1.5.1-sources.jar
-rw-r--r-- 1 root root       57 4月  20 2017 apollo-configservice.conf
drwxr-xr-x 2 root root       65 4月  28 06:41 config
drwxr-xr-x 2 root root       43 10月  1 2019 scripts
```

### 修改配置文件

```sh
[root@host0-200 apollo-configservice]# vim config/application-github.properties
# DataSource
spring.datasource.url = jdbc:mysql://mysql.od.com:3306/ApolloConfigDB?characterEncoding=utf8
spring.datasource.username = apolloconfig
spring.datasource.password = 123123


#apollo.eureka.server.enabled=true
#apollo.eureka.client.enabled=true
```

### 配置域名解析

```sh
[root@host0-200 ~]# cat /var/named/od.com.zone 
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020010513 ; serial
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
mysql              A    10.0.0.11
[root@host0-200 ~]# systemctl restart named
```

### 配置启动脚本

[官方脚本](https://github.com/ctripcorp/apollo/blob/1.5.1/scripts/apollo-on-kubernetes/apollo-config-server/scripts/startup-kubernetes.sh)

```sh
[root@host0-200 scripts]# vim scripts/startup.sh
#!/bin/bash
SERVICE_NAME=apollo-configservice
## Adjust log dir if necessary
LOG_DIR=/opt/logs/apollo-config-server
## Adjust server port if necessary
SERVER_PORT=8080
APOLLO_PORTAL_SERVICE_NAME=$(hostname -i)

SERVER_URL="http://${APOLLO_CONFIG_SERVICE_NAME}:${SERVER_PORT}"

## Adjust memory settings if necessary
#export JAVA_OPTS="-Xms6144m -Xmx6144m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=4096m -XX:MaxNewSize=4096m -XX:SurvivorRatio=8"

## Only uncomment the following when you are using server jvm
#export JAVA_OPTS="$JAVA_OPTS -server -XX:-ReduceInitialCardMarks"

########### The following is the same for configservice, adminservice, portal ###########
export JAVA_OPTS="$JAVA_OPTS -XX:ParallelGCThreads=4 -XX:MaxTenuringThreshold=9 -XX:+DisableExplicitGC -XX:+ScavengeBeforeFullGC -XX:SoftRefLRUPolicyMSPerMB=0 -XX:+ExplicitGCInvokesConcurrent -XX:+HeapDumpOnOutOfMemoryError -XX:-OmitStackTraceInFastThrow -Duser.timezone=Asia/Shanghai -Dclient.encoding.override=UTF-8 -Dfile.encoding=UTF-8 -Djava.security.egd=file:/dev/./urandom"
export JAVA_OPTS="$JAVA_OPTS -Dserver.port=$SERVER_PORT -Dlogging.file=$LOG_DIR/$SERVICE_NAME.log -XX:HeapDumpPath=$LOG_DIR/HeapDumpOnOutOfMemoryError/"

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

### 编写dockerfile

[官方dockerfile](https://github.com/ctripcorp/apollo/blob/master/scripts/apollo-on-kubernetes/apollo-config-server/Dockerfile)

```sh
[root@host0-200 apollo-configservice]# vim Dockerfile
FROM harbor.od.com/base/jre8:8u112

ENV VERSION 1.5.1

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&\
    echo "Asia/Shanghai" > /etc/timezone

ADD apollo-configservice-${VERSION}.jar /apollo-configservice/apollo-configservice.jar
ADD config/ /apollo-configservice/config
ADD scripts/ /apollo-configservice/scripts

CMD ["/apollo-configservice/scripts/startup.sh"]
[root@host0-200 apollo-configservice]# docker build . -t harbor.od.com/infra/apollo-configservice:v1.5.1
Sending build context to Docker daemon  62.01MB
Step 1/7 : FROM harbor.od.com/base/jre8:8u112
 ---> bdd1f4ae7ac4
Step 2/7 : ENV VERSION 1.5.1
 ---> Using cache
 ---> 707125ebd330
Step 3/7 : RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&    echo "Asia/Shanghai" > /etc/timezone
 ---> Using cache
 ---> 22fe0b8d9b0f
Step 4/7 : ADD apollo-configservice-${VERSION}.jar /apollo-configservice/apollo-configservice.jar
 ---> e3f7d6eee401
Step 5/7 : ADD config/ /apollo-configservice/config
 ---> 974d8230819b
Step 6/7 : ADD scripts/ /apollo-configservice/scripts
 ---> 8135421fea69
Step 7/7 : CMD ["/apollo-configservice/scripts/startup.sh"]
 ---> Running in dbb4d7749765
Removing intermediate container dbb4d7749765
 ---> 3f83052aab71
Successfully built 3f83052aab71
Successfully tagged harbor.od.com/infra/apollo-configservice:v1.5.1
[root@host0-200 apollo-configservice]# docker push harbor.od.com/infra/apollo-configservice:v1.5.1 
The push refers to repository [harbor.od.com/infra/apollo-configservice]
048b622c1571: Pushed 
f9520b2da4cd: Pushed 
ac712565baf0: Pushed 
3ace07cf9de0: Pushed 
6b07dadefc3a: Mounted from base/jre8 
5fd6a74fc6cc: Mounted from base/jre8 
d934838ff7b9: Mounted from base/jre8 
e3b979fb1f54: Mounted from base/jre8 
3fdd66b5b83c: Mounted from base/jre8 
0690f10a63a5: Mounted from base/jre8 
c843b2cf4e12: Mounted from base/jre8 
fddd8887b725: Mounted from base/jre8 
42052a19230c: Mounted from base/jre8 
8d4d1ab5ff74: Mounted from base/jre8 
v1.5.1: digest: sha256:8f9c6a4f42259fab59e334e823ec5dd0a283eb19141a50cdba555be8a0362813 size: 3240
```

### 资源配置清单

```sh
[root@host0-200 apollo-configservice]# mkdir -pv /data/k8s-yaml/apollo-configservice/ && cd /data/k8s-yaml/apollo-configservice/
[root@host0-200 apollo-configservice]# vim cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: apollo-configservice-cm
  namespace: infra
data:
  application-github.properties: |
    # DataSource
    spring.datasource.url = jdbc:mysql://mysql.od.com:3306/ApolloConfigDB?characterEncoding=utf8
    spring.datasource.username = apolloconfig
    spring.datasource.password = 123123
    eureka.service.url = http://config.od.com/eureka
  app.properties: |
    appId=100003171

[root@host0-200 apollo-configservice]# vim dp.yaml
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: apollo-configservice
  namespace: infra
  labels: 
    name: apollo-configservice
spec:
  replicas: 1
  selector:
    matchLabels: 
      name: apollo-configservice
  template:
    metadata:
      labels: 
        app: apollo-configservice 
        name: apollo-configservice
    spec:
      volumes:
      - name: configmap-volume
        configMap:
          name: apollo-configservice-cm
      containers:
      - name: apollo-configservice
        image: harbor.od.com/infra/apollo-configservice:v1.5.1
        ports:
        - containerPort: 8080
          protocol: TCP
        volumeMounts:
        - name: configmap-volume
          mountPath: /apollo-configservice/config
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

[root@host0-200 apollo-configservice]# vim svc.yaml
kind: Service
apiVersion: v1
metadata: 
  name: apollo-configservice
  namespace: infra
spec:
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
  selector: 
    app: apollo-configservice

[root@host0-200 apollo-configservice]# vim ingress.yaml
kind: Ingress
apiVersion: extensions/v1beta1
metadata: 
  name: apollo-configservice
  namespace: infra
spec:
  rules:
  - host: config.od.com
    http:
      paths:
      - path: /
        backend: 
          serviceName: apollo-configservice
          servicePort: 8080
```

### 提交资源(Eureka)

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-configservice/cm.yaml
configmap/apollo-configservice-cm created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-configservice/dp.yaml
deployment.extensions/apollo-configservice created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-configservice/svc.yaml
service/apollo-configservice created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-configservice/ingress.yaml
ingress.extensions/apollo-configservice created
```

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/13.png)

### 查看数据库访问流量

```sh
[root@host0-11 ~]# mysql -uroot -p
Enter password: 
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 202
Server version: 10.1.48-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> show processlist;
+-----+--------------+----------------+----------------+---------+------+-------+------------------+----------+
| Id  | User         | Host           | db             | Command | Time | State | Info             | Progress |
+-----+--------------+----------------+----------------+---------+------+-------+------------------+----------+
| 191 | apolloconfig | host0-22:44556 | ApolloConfigDB | Sleep   |    0 |       | NULL             |    0.000 |
| 192 | apolloconfig | host0-22:44638 | ApolloConfigDB | Sleep   |    0 |       | NULL             |    0.000 |
| 193 | apolloconfig | host0-22:44656 | ApolloConfigDB | Sleep   |    0 |       | NULL             |    0.000 |
| 194 | apolloconfig | host0-22:44720 | ApolloConfigDB | Sleep   | 1526 |       | NULL             |    0.000 |
| 195 | apolloconfig | host0-22:44768 | ApolloConfigDB | Sleep   | 1512 |       | NULL             |    0.000 |
| 196 | apolloconfig | host0-22:44806 | ApolloConfigDB | Sleep   | 1502 |       | NULL             |    0.000 |
| 197 | apolloconfig | host0-22:44812 | ApolloConfigDB | Sleep   | 1500 |       | NULL             |    0.000 |
| 198 | apolloconfig | host0-22:44838 | ApolloConfigDB | Sleep   | 1494 |       | NULL             |    0.000 |
| 199 | apolloconfig | host0-22:45196 | ApolloConfigDB | Sleep   | 1389 |       | NULL             |    0.000 |
| 200 | apolloconfig | host0-22:45228 | ApolloConfigDB | Sleep   | 1380 |       | NULL             |    0.000 |
| 202 | root         | localhost      | NULL           | Query   |    0 | init  | show processlist |    0.000 |
+-----+--------------+----------------+----------------+---------+------+-------+------------------+----------+
```
