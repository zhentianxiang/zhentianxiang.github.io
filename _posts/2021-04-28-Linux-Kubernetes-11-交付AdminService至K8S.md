---
layout: post
title: Linux-Kubernetes-11-交付AdminService至K8S
date: 2021-04-28
tags: 实战-Kubernetes
---

[官方二进制包](https://github.com/ctripcorp/apollo/releases/download/v1.5.1/apollo-adminservice-1.5.1-github.zip)

### 修改配置文件

```
[root@host0-200 src]# ls
apache-maven-3.6.1-bin.tar.gz  apollo-adminservice-1.5.1-github.zip  apollo-configservice-1.5.1-github.zip  dubbo-monitor-master  harbor-offline-installer-v1.8.6.tgz  master.zip
[root@host0-200 src]# mkdir -pv /data/dockerfile/apollo-adminservice
mkdir: 已创建目录 "/data/dockerfile/apollo-adminservice"
[root@host0-200 src]# unzip apollo-adminservice-1.5.1-github.zip -d /data/dockerfile/apollo-adminservice/
Archive:  apollo-adminservice-1.5.1-github.zip
   creating: /data/dockerfile/apollo-adminservice/scripts/
  inflating: /data/dockerfile/apollo-adminservice/config/app.properties  
  inflating: /data/dockerfile/apollo-adminservice/apollo-adminservice-1.5.1-sources.jar  
  inflating: /data/dockerfile/apollo-adminservice/scripts/shutdown.sh  
  inflating: /data/dockerfile/apollo-adminservice/apollo-adminservice.conf  
  inflating: /data/dockerfile/apollo-adminservice/scripts/startup.sh  
  inflating: /data/dockerfile/apollo-adminservice/config/application-github.properties  
  inflating: /data/dockerfile/apollo-adminservice/apollo-adminservice-1.5.1.jar  
[root@host0-200 src]# cd /data/dockerfile/apollo-adminservice/
[root@host0-200 apollo-adminservice]# ll
总用量 57024
-rwxr-xr-x 1 root root 58358738 11月  9 2019 apollo-adminservice-1.5.1.jar
-rwxr-xr-x 1 root root    25991 11月  9 2019 apollo-adminservice-1.5.1-sources.jar
-rw-r--r-- 1 root root       57 4月  20 2017 apollo-adminservice.conf
drwxr-xr-x 2 root root       65 4月  28 18:11 config
drwxr-xr-x 2 root root       43 10月  1 2019 scripts
```

由于使用了configmap资源将配置文件挂载出来了，所以不在修改配置文件，如需修改配置文件，请参考部署apollo-configservice时候的修改方法：

### 配置启动脚本文件

[官方脚本](https://raw.githubusercontent.com/ctripcorp/apollo/master/scripts/apollo-on-kubernetes/apollo-admin-server/scripts/startup-kubernetes.sh)

```sh
[root@host0-200 apollo-adminservice]# vim scripts/startup.sh
#!/bin/bash
SERVICE_NAME=apollo-adminservice
## Adjust log dir if necessary
LOG_DIR=/opt/logs/apollo-admin-server
## Adjust server port if necessary
SERVER_PORT=8080
APOLLO_ADMIN_SERVICE_NAME=$(hostname -i)
# SERVER_URL="http://localhost:${SERVER_PORT}"
SERVER_URL="http://${APOLLO_ADMIN_SERVICE_NAME}:${SERVER_PORT}"

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

### 配置Dockefile文件

```
[root@host0-200 apollo-adminservice]# vim Dockerfile
FROM harbor.od.com/base/jre8:8u112

ENV VERSION 1.5.1

RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&\
    echo "Asia/Shanghai" > /etc/timezone

ADD apollo-adminservice-${VERSION}.jar /apollo-adminservice/apollo-adminservice.jar
ADD config/ /apollo-adminservice/config
ADD scripts/ /apollo-adminservice/scripts

CMD ["/apollo-adminservice/scripts/startup.sh"]
```

### 生成镜像并上传至仓库

```
[root@host0-200 apollo-adminservice]# docker build . -t harbor.od.com/infra/apollo-adminservice:v1.5.1
Sending build context to Docker daemon  58.37MB
Step 1/7 : FROM stanleyws/jre8:8u112
 ---> fa3a085d6ef1
Step 2/7 : ENV VERSION 1.5.1
 ---> Running in f1f2f801d156
Removing intermediate container f1f2f801d156
 ---> be875ea69691
Step 3/7 : RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&    echo "Asia/Shanghai" > /etc/timezone
 ---> Running in 9a81cc9d03d7
Removing intermediate container 9a81cc9d03d7
 ---> b2eb86f95f03
Step 4/7 : ADD apollo-adminservice-${VERSION}.jar /apollo-adminservice/apollo-adminservice.jar
 ---> d8822949fa53
Step 5/7 : ADD config/ /apollo-adminservice/config
 ---> 45efff0e34ba
Step 6/7 : ADD scripts/ /apollo-adminservice/scripts
 ---> 0ac0ac7ab580
Step 7/7 : CMD ["/apollo-adminservice/scripts/startup.sh"]
 ---> Running in fc0e635f05fc
Removing intermediate container fc0e635f05fc
 ---> 80330d4497a3
Successfully built 80330d4497a3
Successfully tagged harbor.od.com/infra/apollo-adminservice:v1.5.1

[root@host0-200 apollo-adminservice]# docker push harbor.od.com/infra/apollo-adminservice:v1.5.1
The push refers to repository [harbor.od.com/infra/apollo-adminservice]
b46bc347cd7b: Pushed 
3575a7738cdd: Pushed 
5e6869ccfebd: Pushed 
3f6f5f9f7608: Pushed 
0690f10a63a5: Mounted from infra/apollo-configservice 
c843b2cf4e12: Mounted from infra/apollo-configservice 
fddd8887b725: Mounted from infra/apollo-configservice 
42052a19230c: Mounted from infra/apollo-configservice 
8d4d1ab5ff74: Mounted from infra/apollo-configservice 
v1.5.1: digest: sha256:85665da869e5bd9aebb4c754ca0984eb383a85b485e7b7c9bfa9aad26ad3cc8b size: 2201
```

### 准备资源配置清单

```sh
[root@host0-200 apollo-adminservice]# mkdir /data/k8s-yaml/apollo-adminservice && cd /data/k8s-yaml/apollo-adminservice
[root@host0-200 apollo-adminservice]# vim cm.yaml

apiVersion: v1
kind: ConfigMap
metadata:
  name: apollo-adminservice-cm
  namespace: infra
data:
  application-github.properties: |
    # DataSource
    spring.datasource.url = jdbc:mysql://mysql.od.com:3306/ApolloConfigDB?characterEncoding=utf8
    spring.datasource.username = apolloconfig
    spring.datasource.password = 123123
    eureka.service.url = http://config.od.com/eureka
  app.properties: |
    appId=100003172

[root@host0-200 apollo-adminservice]# vim dp.yaml
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: apollo-adminservice
  namespace: infra
  labels: 
    name: apollo-adminservice
spec:
  replicas: 1
  selector:
    matchLabels: 
      name: apollo-adminservice
  template:
    metadata:
      labels: 
        app: apollo-adminservice 
        name: apollo-adminservice
    spec:
      volumes:
      - name: configmap-volume
        configMap:
          name: apollo-adminservice-cm
      containers:
      - name: apollo-adminservice
        image: harbor.od.com/infra/apollo-adminservice:v1.5.1
        ports:
        - containerPort: 8080
          protocol: TCP
        volumeMounts:
        - name: configmap-volume
          mountPath: /apollo-adminservice/config
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
```

### 应用资源配置清单

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-adminservice/cm.yaml
configmap/apollo-adminservice-cm created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-adminservice/dp.yaml
deployment.extensions/apollo-adminservice created
```

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/14.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/15.png)

### 测试扩容集群

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/16.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/17.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/18.png)

此时adminservice已经注册到了注册中心
