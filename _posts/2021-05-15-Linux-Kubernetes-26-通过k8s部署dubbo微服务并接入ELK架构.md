---
layout: post
title: Linux-Kubernetes-26-通过k8s部署dubbo微服务并接入ELK架构
date: 2021-05-15
tags: 实战-Kubernetes
---

需要这样一套日志收集、分析的系统：

- 收集 -- 能够采集多种来源的日志数据 (流式日志收集器)
- 传输 -- 能够稳定的把日志数据传输到中央系统 (消息队列)
- 存储 -- 可以将日志以结构化数据的形式存储起来 (搜索引擎)
- 分析 -- 支持方便的分析、检索方法，最好有GUI管理系统 (前端)
- 警告 -- 能够提供错误报告，监控机制 (监控工具)

优秀的社区开源解决方案 ---- ELK Stack

- E ----- ElasticSearch
- L ----- LogStash
- K ----- Kibana

## 1. 传统ELK模型

![](/images/posts/Linux-Kubernetes/交付ELK到K8S/1.png)

缺点：

- Logstash使用Jruby语言开发，吃资源，大量部署消耗极高
- 业务程序与Logstash耦合过松，不利于业务迁移
- 日志收集与ES解耦又过紧，易打爆、丢数据
- 在容器云环境下，传统ELK模型难以完成工作

## 2. ELK架构图

![](/images/posts/Linux-Kubernetes/交付ELK到K8S/2.png)

## 3. 制作tomcat容器的底包镜像

[Tomcat官网](https://tomcat.apache.org/)

### 3.1 下载Tomcat二进制包

在运维主机host0-200

[Tomcat-8.5.66](https://mirror.bit.edu.cn/apache/tomcat/tomcat-8/v8.5.66/bin/apache-tomcat-8.5.66.tar.gz)

```sh
[root@host0-200 ~]# cd /opt/src
[root@host0-200 src]# 
[root@host0-200 src]# wget https://mirror.bit.edu.cn/apache/tomcat/tomcat-8/v8.5.66/bin/apache-tomcat-8.5.66.tar.gz
--2020-08-17 22:52:23--  https://mirror.bit.edu.cn/apache/tomcat/tomcat-8/v8.5.66/bin/apache-tomcat-8.5.66.tar.gz
Resolving mirror.bit.edu.cn (mirror.bit.edu.cn)... 219.143.204.117, 202.204.80.77, 2001:da8:204:1205::22
Connecting to mirror.bit.edu.cn (mirror.bit.edu.cn)|219.143.204.117|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 10379806 (9.9M) [application/octet-stream]
Saving to: ‘apache-tomcat-8.5.66.tar.gz’

100%[==================================================================================================>] 10,379,806   153KB/s   in 70s    

2020-08-17 22:53:33 (144 KB/s) - ‘apache-tomcat-8.5.66.tar.gz’ saved [10379806/10379806]
```

创建存放Tomcat的目录并解压至此目录

```sh
[root@host0-200 ~]# mkdir -pv /data/dockerfile/tomcat8
[root@host0-200 ~]# tar -xf /opt/src/apache-tomcat-8.5.66.tar.gz -C /data/dockerfile/tomcat8
```

### 3.2 简单配置tomcat

关闭ajp端口

在/data/dockerfile/tomcat8/apache-tomcat-8.5.66/conf/server.xml找到AJP的，添加上注释即可关闭AJP端口

```sh
[root@host0-200 src]# vim /data/dockerfile/tomcat8/apache-tomcat-8.5.66/conf/server.xml
<!-- <Connector protocol="AJP/1.3"
               address="::1"
               port="8009"
               redirectPort="8443" />
-- >
```

### 3.3 配置日志

- 删除3manager，4host-manager的handlers并注释相关的内容

文件路径如下：/data/dockerfile/tomcat8/apache-tomcat-8.5.66/conf/logging.properties

修改好后如下所示

```sh
[root@host0-200 src]# vim /data/dockerfile/tomcat8/apache-tomcat-8.5.66/conf/logging.properties
handlers = 1catalina.org.apache.juli.AsyncFileHandler, 2localhost.org.apache.juli.AsyncFileHandler,  java.util.logging.ConsoleHandler
```
- 注释3manager和4host-manager的日志配置内容

```sh
#3manager.org.apache.juli.AsyncFileHandler.level = FINE
#3manager.org.apache.juli.AsyncFileHandler.directory = ${catalina.base}/logs
#3manager.org.apache.juli.AsyncFileHandler.prefix = manager.
#3manager.org.apache.juli.AsyncFileHandler.encoding = UTF-8

#4host-manager.org.apache.juli.AsyncFileHandler.level = FINE
#4host-manager.org.apache.juli.AsyncFileHandler.directory = ${catalina.base}/logs
#4host-manager.org.apache.juli.AsyncFileHandler.prefix = host-manager.
#4host-manager.org.apache.juli.AsyncFileHandler.encoding = UTF-8
```

- 将其它的日志的等级修改为INFO

```sh
1catalina.org.apache.juli.AsyncFileHandler.level = INFO
2localhost.org.apache.juli.AsyncFileHandler.level = INFO
java.util.logging.ConsoleHandler.level = INFO
```

### 3.4 准备Dockerfile文件

```sh
[root@host0-200 ~]# wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.3.1/jmx_prometheus_javaagent-0.3.1.jar -O /data/dockerfile/tomcat8/jmx_javaagent-0.3.1.jar

[root@host0-200 ~]# cat > /data/dockerfile/tomcat8/Dockerfile << EOF
From harbor.od.com/base/jre8:8u112
RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&\ 
    echo 'Asia/Shanghai' >/etc/timezone
ENV CATALINA_HOME /opt/tomcat
ENV LANG zh_CN.UTF-8
ADD apache-tomcat-8.5.66/ /opt/tomcat
ADD config.yml /opt/prom/config.yml
ADD jmx_javaagent-0.3.1.jar /opt/prom/jmx_javaagent-0.3.1.jar
WORKDIR /opt/tomcat
ADD entrypoint.sh /entrypoint.sh
CMD ["/entrypoint.sh"]
EOF
```

- config.yml文件内容如下：

```sh
[root@host0-200 ~]# cat > /data/dockerfile/tomcat8/config.yml << EOF
---
rules:
  - pattern: '.*'
EOF
```

- entrypoint.sh文件内容如下：

```sh
[root@host0-200 ~]# cat > /data/dockerfile/tomcat8/entrypoint.sh << EOF
#!/bin/bash
M_OPTS="-Duser.timezone=Asia/Shanghai -javaagent:/opt/prom/jmx_javaagent-0.3.1.jar=\$(hostname -i):\${M_PORT:-"12346"}:/opt/prom/config.yml"
C_OPTS=\${C_OPTS}
MIN_HEAP=\${MIN_HEAP:-"128m"}
MAX_HEAP=\${MAX_HEAP:-"128m"}
JAVA_OPTS=\${JAVA_OPTS:-"-Xmn384m -Xss256k -Duser.timezone=GMT+08  -XX:+DisableExplicitGC -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+CMSParallelRemarkEnabled -XX:+UseCMSCompactAtFullCollection -XX:CMSFullGCsBeforeCompaction=0 -XX:+CMSClassUnloadingEnabled -XX:LargePageSizeInBytes=128m -XX:+UseFastAccessorMethods -XX:+UseCMSInitiatingOccupancyOnly -XX:CMSInitiatingOccupancyFraction=80 -XX:SoftRefLRUPolicyMSPerMB=0 -XX:+PrintClassHistogram  -Dfile.encoding=UTF8 -Dsun.jnu.encoding=UTF8"}
CATALINA_OPTS="\${CATALINA_OPTS}"
JAVA_OPTS="\${M_OPTS} \${C_OPTS} -Xms\${MIN_HEAP} -Xmx\${MAX_HEAP} \${JAVA_OPTS}"
sed -i -e "1a\JAVA_OPTS=\"\$JAVA_OPTS\"" -e "1a\CATALINA_OPTS=\"\$CATALINA_OPTS\"" /opt/tomcat/bin/catalina.sh

cd /opt/tomcat && /opt/tomcat/bin/catalina.sh run 2>&1 >> /opt/tomcat/logs/stdout.log
EOF

[root@host0-200 ~]# ls -l /data/dockerfile/tomcat8/entrypoint.sh 
-rw-r--r-- 1 root root 827 Aug 17 23:47 /data/dockerfile/tomcat8/entrypoint.sh
[root@host0-200 ~]# 
[root@host0-200 ~]# chmod u+x /data/dockerfile/tomcat8/entrypoint.sh 
[root@host0-200 ~]# 
[root@host0-200 ~]# ls -l /data/dockerfile/tomcat8/entrypoint.sh 
-rwxr--r-- 1 root root 827 Aug 17 23:47 /data/dockerfile/tomcat8/entrypoint.sh
```

### 3.5 构建tomcat底包

```sh
[root@host0-200 ~]# cd /data/dockerfile/tomcat8/
[root@host0-200 tomcat8]# 
[root@host0-200 tomcat8]# docker build . -t harbor.od.com/base/tomcat:v8.5.66
Sending build context to Docker daemon  10.35MB
Step 1/10 : From harbor.od.com/base/jre8:8u112
 ---> 1237758f0be9
Step 2/10 : RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&    echo 'Asia/Shanghai' >/etc/timezone
 ---> Running in dd43a1973ae6
Removing intermediate container dd43a1973ae6
 ---> 7d376f75a369
Step 3/10 : ENV CATALINA_HOME /opt/tomcat
 ---> Running in 5d1a8302488f
Removing intermediate container 5d1a8302488f
 ---> e6d8a5069f4b
Step 4/10 : ENV LANG zh_CN.UTF-8
 ---> Running in 9ab19ad646de
Removing intermediate container 9ab19ad646de
 ---> c61931622aae
Step 5/10 : ADD apache-tomcat-8.5.57/ /opt/tomcat
 ---> 6953dffb9b11
Step 6/10 : ADD config.yml /opt/prom/config.yml
 ---> 4d67798f76f5
Step 7/10 : ADD jmx_javaagent-0.3.1.jar /opt/prom/jmx_javaagent-0.3.1.jar
 ---> 2ff30950c856
Step 8/10 : WORKDIR /opt/tomcat
 ---> Running in f0692b96c235
Removing intermediate container f0692b96c235
 ---> 00847c31b601
Step 9/10 : ADD entrypoint.sh /entrypoint.sh
 ---> 6a44a6205708
Step 10/10 : CMD ["/entrypoint.sh"]
 ---> Running in d2e6b80af0af
Removing intermediate container d2e6b80af0af
 ---> c3c4fcdbe8fd
Successfully built c3c4fcdbe8fd
Successfully tagged harbor.od.com/base/tomcat:v8.5.66
```

### 3.6 上传至仓库

```sh
[root@host0-200 ~]# docker push harbor.od.com/base/tomcat:v8.5.66
The push refers to repository [harbor.od.com/base/tomcat]
1adedb0df456: Pushed 
c456d7815bdc: Pushed 
adbd684689e5: Pushed 
fc2e7ea50383: Pushed 
1d6b6320a33e: Pushed 
c012afdfa38e: Mounted from base/jre8 
30934063c5fd: Mounted from base/jre8 
0378026a5ac0: Mounted from base/jre8 
12ac448620a2: Mounted from base/jre8 
78c3079c29e7: Mounted from base/jre8 
0690f10a63a5: Mounted from base/jre8 
c843b2cf4e12: Mounted from base/jre8 
fddd8887b725: Mounted from base/jre8 
42052a19230c: Mounted from base/jre8 
8d4d1ab5ff74: Mounted from base/jre8 
v8.5.57: digest: sha256:83098849296b452d1f4886f9c84db8978c3d8d16b12224f8b76f20ba79abd8d6 size: 3448
```

## 4. 实战交付tomcat形式的dubbo服务消费者到K8S集群

### 4.1 创建Tomcat的jenkins流水线

![](/images/posts/Linux-Kubernetes/交付ELK到K8S/3.png)

```sh
pipeline {
  agent any 
    stages {
    stage('pull') { //get project code from repo 
      steps {
        sh "git clone ${params.git_repo} ${params.app_name}/${env.BUILD_NUMBER} && cd ${params.app_name}/${env.BUILD_NUMBER} && git checkout ${params.git_ver}"
        }
    }
    stage('build') { //exec mvn cmd
      steps {
        sh "cd ${params.app_name}/${env.BUILD_NUMBER}  && /var/jenkins_home/maven-${params.maven}/bin/${params.mvn_cmd}"
      }
    }
    stage('unzip') { //unzip  target/*.war -c target/project_dir
      steps {
        sh "cd ${params.app_name}/${env.BUILD_NUMBER} && cd ${params.target_dir} && mkdir project_dir && unzip *.war -d ./project_dir"
      }
    }
    stage('image') { //build image and push to registry
      steps {
        writeFile file: "${params.app_name}/${env.BUILD_NUMBER}/Dockerfile", text: """FROM harbor.od.com/${params.base_image}
ADD ${params.target_dir}/project_dir /opt/tomcat/webapps/${params.root_url}"""
        sh "cd  ${params.app_name}/${env.BUILD_NUMBER} && docker build -t harbor.od.com/${params.image_name}:${params.git_ver}_${params.add_tag} . && docker push harbor.od.com/${params.image_name}:${params.git_ver}_${params.add_tag}"
      }
    }
  }
}
```

### 4.2 构建镜像

![](/images/posts/Linux-Kubernetes/交付ELK到K8S/4.png)

![](/images/posts/Linux-Kubernetes/交付ELK到K8S/5.png)

### 4.3 以apollo的test的环境为例

将以apollo实验环境中的test的环境的dubbo-demo-consumer的dp.yaml来起，只需要修改dp.yaml即可

dp.yaml文件内容如下：

在运维主机(host0-200)上执行

```sh
[root@host0-200 ~]# cat > /data/k8s-yaml/test/dubbo-demo-consumer/dp.yaml << EOF
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: dubbo-demo-consumer
  namespace: test
  labels:
    name: dubbo-demo-consumer
spec:
  replicas: 1
  selector:
    matchLabels:
      name: dubbo-demo-consumer
  template:
    metadata:
      labels:
        app: dubbo-demo-consumer
        name: dubbo-demo-consumer
    spec:
      containers:
      - name: dubbo-demo-consumer
        image: harbor.od.com/app/dubbo-demo-web:tomcat_20210521_2100
        ports:
        - containerPort: 8080
          protocol: TCP
        env:
        - name: JAR_BALL
          value: dubbo-client.jar
        - name: C_OPTS
          value: -Denv=fat -Dapollo.meta=http://config-test.od.com
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
EOF
```

先将运行着的apollo的test环境下的dubbo-demo-consumer的deployment设置为0

在master节点(host0-21或host0-22)任意一台执行即可

```sh
[root@host0-21 ~]# kubectl get deployment -n test
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
apollo-adminservice    1/1     1            1           166m
apollo-configservice   1/1     1            1           168m
dubbo-demo-consumer    1/1     1            1           87m
dubbo-demo-service     1/1     1            1           123m
[root@host0-21 ~]# 
[root@host0-21 ~]# kubectl scale --replicas=0 deployment/dubbo-demo-consumer -n test 
deployment.extensions/dubbo-demo-consumer scaled
[root@host0-21 ~]# 
[root@host0-21 ~]# kubectl get deployment -n test
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
apollo-adminservice    1/1     1            1           166m
apollo-configservice   1/1     1            1           168m
dubbo-demo-consumer    0/0     0            0           87m
dubbo-demo-service     1/1     1            1           123m
```

### 4.4 应用test环境下的dubbo-demo-consumer的deployment资源配置清单

在master节点(host0-21或host0-22)任意一台执行即可

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/test/dubbo-demo-consumer/dp.yaml
deployment.extensions/dubbo-demo-consumer configured
```

再次将test环境下的dubbo-demo-consumer的deployment设置为1个副本

```sh
[root@host0-21 ~]# kubectl get deployment -n test
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
apollo-adminservice    1/1     1            1           166m
apollo-configservice   1/1     1            1           168m
dubbo-demo-consumer    0/0     0            0           87m
dubbo-demo-service     1/1     1            1           123m
[root@host0-21 ~]# 
[root@host0-21 ~]# kubectl scale --replicas=1 deployment/dubbo-demo-consumer -n test 
deployment.extensions/dubbo-demo-consumer scaled
[root@host0-21 ~]# 
[root@host0-21 ~]# kubectl get deployment -n test
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
apollo-adminservice    1/1     1            1           166m
apollo-configservice   1/1     1            1           168m
dubbo-demo-consumer    1/1     1            1           87m
dubbo-demo-service     1/1     1            1           123m
```

### 4.5 访问http://demo-test.od.com/hello?name=maple

![](/images/posts/Linux-Kubernetes/交付ELK到K8S/6.png)

## 5. 二进制安装部署elasticsearch

elasticsearch官网：https://www.elastic.co/cn/

elasticsearch的github地址：https://github.com/elastic/elasticsearch

将elasticsearch安装至host0-12.od.com主机，elasticsearch 6.8.6需要java jdk的1.8.0版本及以上

### 5.1 下载elasticsearch-6.8.6并解压制作超链接

```sh
[root@host0-12 ~]# mkdir -pv /opt/src
[root@host0-12 ~]# wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-6.8.6.tar.gz -O /opt/src/elasticsearch-6.8.6.tar.gz
[root@host0-12 ~]# tar xf /opt/src/elasticsearch-6.8.6.tar.gz -C /opt/
[root@host0-12 ~]# ln -s /opt/elasticsearch-6.8.6/ /opt/elasticsearch
```

### 5.2 创建存储数据和日志的目录

```sh
[root@host0-12 ~]#  mkdir -pv /data/elasticsearch/{data,logs}
```

### 5.3 配置elasticsearch

编辑/opt/elasticsearch/config/elasticsearch.yml文件,修改相对应的内容为如下的值

```sh
[root@host0-12 ~]# vim /opt/elasticsearch/config/elasticsearch.yml
cluster.name: es.od.com
node.name: host0-12.host.com
path.data: /data/elasticsearch/data
path.logs: /data/elasticsearch/logs
bootstrap.memory_lock: true
network.host: 10.0.0.12
http.port: 9200
```

编辑/opt/elasticsearch/config/jvm.options文件，修改相对应的内容如下：如下的值可以根据实现的环境来设置，建议不超过32G

```sh
[root@host0-12 ~]# vim /opt/elasticsearch/config/jvm.options
-Xms512m
-Xmx512m
```

### 5.4 为elasticsearch创建一个普通用户，方便以后使用此用户启动

```sh
[root@host0-12 ~]# useradd -s /bin/bash -M es
[root@host0-12 ~]# chown -R es.es /opt/elasticsearch-6.8.6
[root@host0-12 ~]# chown -R es.es /data/elasticsearch
```

### 5.5 添加es的文件描述符

```sh
[root@host0-12 ~]# cat > /etc/security/limits.d/es.conf << EOF
es hard nofile 65536
es soft fsize unlimited
es hard memlock unlimited
es soft memlock unlimited
EOF
```

### 5.6 调整内核参数

```sh
[root@host0-12 ~]# sysctl -w vm.max_map_count=262144
vm.max_map_count = 262144
#或者
[root@host0-12 ~]# echo "vm.max_map_count=262144" > /etc/sysctl.conf
[root@host0-12 ~]# sysctl -p
vm.max_map_count = 262144
```

### 5.7 启动es

```sh
[root@host0-12 ~]# su -c "/opt/elasticsearch/bin/elasticsearch -d" es
[root@host0-12 ~]# 
[root@host0-12 ~]# ps aux | grep elasticsearch
es         9492 78.7 40.6 3135340 757876 ?      Sl   22:08   0:19 /usr/java/jdk/bin/java -Xms512m -Xmx512m -XX:+UseConcMarkSweepGC -XX:CMSInitiatingOccupancyFraction=75 -XX:+UseCMSInitiatingOccupancyOnly -Des.networkaddress.cache.ttl=60 -Des.networkaddress.cache.negative.ttl=10 -XX:+AlwaysPreTouch -Xss1m -Djava.awt.headless=true -Dfile.encoding=UTF-8 -Djna.nosys=true -XX:-OmitStackTraceInFastThrow -Dio.netty.noUnsafe=true -Dio.netty.noKeySetOptimization=true -Dio.netty.recycler.maxCapacityPerThread=0 -Dlog4j.shutdownHookEnabled=false -Dlog4j2.disable.jmx=true -Djava.io.tmpdir=/tmp/elasticsearch-605583263416383431 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=data -XX:ErrorFile=logs/hs_err_pid%p.log -XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintTenuringDistribution -XX:+PrintGCApplicationStoppedTime -Xloggc:logs/gc.log -XX:+UseGCLogFileRotation -XX:NumberOfGCLogFiles=32 -XX:GCLogFileSize=64m -Des.path.home=/opt/elasticsearch -Des.path.conf=/opt/elasticsearch/config -Des.distribution.flavor=default -Des.distribution.type=tar -cp /opt/elasticsearch/lib/* org.elasticsearch.bootstrap.Elasticsearch -d
es         9515  0.0  0.2  72140  5096 ?        Sl   22:08   0:00 /opt/elasticsearch/modules/x-pack-ml/platform/linux-x86_64/bin/controller
root       9622  0.0  0.0 112712   968 pts/0    S+   22:08   0:00 grep --color=auto elasticsearch
```

### 5.7 制作elsaticsearch自启动脚本

```sh
[root@host0-12 ~]# cat > /etc/systemd/system/es.service << EOF
[Unit]
Description=ElasticSearch
Requires=network.service
After=network.service
[Service]
User=es
Group=es
LimitNOFILE=65536
LimitMEMLOCK=infinity
Environment=JAVA_HOME=/usr/java/jdk
ExecStart=/opt/elasticsearch/bin/elasticsearch
SuccessExitStatus=143
[Install]
WantedBy=multi-user.target
EOF
```

### 5.8 设置es.service拥有可执行权限

```sh
[root@host0-12 ~]# chmod +x /etc/systemd/system/es.service
```

### 5.9 加入开机自动服务

```sh
[root@host0-12 ~]# systemctl daemon-reload
[root@host0-12 ~]# systemctl start es
```

### 5.9.1 调整ES日志模板

```sh
[root@host0-12 ~]# curl -H "Content-Type:application/json" -XPUT http://10.0.0.12:9200/_template/k8s -d '{
  "template" : "k8s*",
  "index_patterns": ["k8s*"],  
  "settings": {
    "number_of_shards": 5,
    "number_of_replicas": 0
  }
}'
```

## 6. 安装部署kafka

kafka官网：http://kafka.apache.org/

kafka的github地址：https://github.com/apache/kafka

在host0-11主机上安装kafka

### 6.1 下载kafka-2.2.2并解压及超链接

```sh
[root@host0-11 ~]# mkdir -pv /opt/src
[root@host0-11 ~]# 
[root@host0-11 ~]# wget https://archive.apache.org/dist/kafka/2.2.0/kafka_2.12-2.2.0.tgz -O /opt/src/kafka_2.12-2.2.2.tgz
[root@host0-11 ~]# 
[root@host0-11 ~]# tar xf /opt/src/kafka_2.12-2.2.0.tgz -C /opt
[root@host0-11 ~]# 
[root@host0-11 ~]# ln -s /opt/kafka_2.12-2.2.0/ /opt/kafka
```

### 6.2 创建存储kafka的日志目录

```sh
[root@host0-11 ~]# mkdir -pv /data/kafka/logs
```

### 6.3 修改kafka配置文件

```sh
[root@host0-11 ~]# vim /opt/kafka/config/server.properties
log.dirs=/data/kafka/logs
zookeeper.connect=localhost:2181
log.flush.interval.messages=10000
log.flush.interval.ms=1000
delete.topic.enable=true
host.name=host0-11.host.com
```

### 6.4 设置开机自启

```sh
[root@host0-11 ~]# cat > /etc/systemd/system/kafka.service << EOF
[Unit]
Description=Kafka
After=network.target  zookeeper.service

[Service]
Type=simple
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/java/jdk/bin"
User=root
Group=root
ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
ExecStop=/opt/kafka/bin/kafka-server-stop.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
```

启动

```sh
[root@host0-11 ~]# chmod +x /etc/systemd/system/kafka.service
[root@host0-11 ~]# 
[root@host0-11 ~]# systemctl daemon-reload
[root@host0-11 ~]# 
[root@host0-11 ~]# systemctl enable kafka
[root@host0-11 ~]# 
[root@host0-11 ~]# systemctl start kafka
[root@host0-11 ~]# 
[root@host0-11 ~]# netstat -luntp|grep 9092
tcp6       0      0 10.0.0.11:9092      :::*                    LISTEN      37926/java  
```

## 7.部署kafka-manager

[kafka-manager的github地址](https://github.com/yahoo/CMAK)

在运维主机(host0-200.od.com)操作

### 7.1 创建kafka-manager存放Dockerfile目录

```sh
[root@host0-200 ~]# mkdir -pv /data/dockerfile/kafka-manager
```

### 7.2 准备Dckerfile文件

```sh
[root@host0-200 ~]# cd /data/dockerfile/kafka-manager
[root@host0-200 kafka-manager]# vim Dockerfile
FROM hseeberger/scala-sbt:11.0.2-oraclelinux7_1.3.13_2.13.3

ENV ZK_HOSTS=10.0.0.11:2181

RUN ls / && ls /tmp

COPY kafka-manager-2.0.0.2/ /tmp

RUN ls /tmp/bin

WORKDIR /tmp

EXPOSE 9000

ENTRYPOINT ["./bin/kafka-manager","-Dconfig.file=conf/application.conf"]

[root@host0-200 kafka-manager]# ls
Dockerfile  kafka-manager-2.0.0.2  kafka-manager-2.0.0.2.zip
```

> 可以直接下载已经编译好的2.0.0.2的包
>
> 链接：https://pan.baidu.com/s/1p_y1HtsQkNExWuxOiiLsUQ 
> 提取码：ximw 
> 复制这段内容后打开百度网盘手机App，操作更方便哦

### 7.3 制作kafka-manager的docker镜像

```sh
[root@host0-200 ~]# cd /data/dockerfile/kafka-manager/
[root@host0-200 ~]# docker build . -t harbor.od.com/infra/kafka-manager:v2.0.0.2
[root@host0-200 ~]# docker login harbor.od.com
[root@host0-200 ~]# docker push harbor.od.com/infra/kafka-manager:v2.0.0.2
```

### 7.4 准备kafka-manager资源配置清单

```sh
[root@host0-200 ~]# mkdir -pv /data/k8s-yaml/kafka-manager

#dp资源
[root@host0-200 ~]# cat > /data/k8s-yaml/kafka-manager/dp.yaml << EOF
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: kafka-manager
  namespace: infra
  labels: 
    name: kafka-manager
spec:
  replicas: 1
  selector:
    matchLabels: 
      name: kafka-manager
  template:
    metadata:
      labels: 
        app: kafka-manager
        name: kafka-manager
    spec:
      containers:
      - name: kafka-manager
        image: harbor.od.com/infra/kafka-manager:v2.0.0.2
        ports:
        - containerPort: 9000
          protocol: TCP
        env:
        - name: ZK_HOSTS
          value: zk1.od.com:2181
        - name: APPLICATION_SECRET
          value: letmein
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
EOF

#svc资源
[root@host0-200 ~]# cat > /data/k8s-yaml/kafka-manager/svc.yaml << EOF
kind: Service
apiVersion: v1
metadata: 
  name: kafka-manager
  namespace: infra
spec:
  ports:
  - protocol: TCP
    port: 9000
    targetPort: 9000
  selector: 
    app: kafka-manager
  clusterIP: None
  type: ClusterIP
  sessionAffinity: None
EOF

#ingress资源
[root@host0-200 ~]# cat > /data/k8s-yaml/kafka-manager/ingress.yaml << EOF
kind: Ingress
apiVersion: extensions/v1beta1
metadata: 
  name: kafka-manager
  namespace: infra
spec:
  rules:
  - host: km.od.com
    http:
      paths:
      - path: /
        backend: 
          serviceName: kafka-manager
          servicePort: 9000
EOF
```

### 7.5 应用kafka-manager资源配置清单

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/kafka-manager/dp.yaml
deployment.extensions/kafka-manager created
[root@host0-21 ~]# 
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/kafka-manager/service.yaml
service/kafka-manager created
[root@host0-21 ~]# 
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/kafka-manager/Ingress.yaml
ingress.extensions/kafka-manager created
[root@host0-21 ~]# 
[root@host0-21 ~]# kubectl get pod -n infra | grep kafka
kafka-manager-69b7585d95-w7ch5   1/1     Running   0          80s
```

### 7.6 解析域名

```sh
[root@host0-200 ~]# vim /var/named/od.com.zone
km	        A          10.0.0.10
[root@host0-200 ~]# systemctl restart named
```

### 7.7 在kafka-manager(CMAK)添加Cluster

浏览器访问：km.od.com



![](/images/posts/Linux-Kubernetes/交付ELK到K8S/7.png)

![](/images/posts/Linux-Kubernetes/交付ELK到K8S/8.png)

![](/images/posts/Linux-Kubernetes/交付ELK到K8S/9.png)

## 8.制作filebeat底包并接入dubbo服务消费者

[filebeat官方下载地址](https://www.elastic.co/cn/downloads/beats/filebeat)

### 8.1 制作docker镜像

准备filebeat存储dockerfile的目录

```sh
[root@host0-200 src]# mkdir -pv /data/dockerfile/filebeat
[root@host0-200 src]# cd /data/dockerfile/filebeat
```

准备Dockerfile文件

```sh
[root@host0-200 filebeat]# vim Dockerfile
FROM debian:jessie

RUN set -x && \
  apt-get update && \
  apt-get install -y wget && \
  wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.5.1-linux-x86_64.tar.gz -O /opt/filebeat.tar.gz && \
  cd /opt && \
  echo "daf1a5e905c415daf68a8192a069f913a1d48e2c79e270da118385ba12a93aaa91bda4953c3402a6f0abf1c177f7bcc916a70bcac41977f69a6566565a8fae9c  filebeat.tar.gz" | sha512sum -c - && \
  tar xzvf filebeat.tar.gz && \
  cd filebeat-* && \
  cp filebeat /bin && \
  cd /opt && \
  rm -rf filebeat* && \
  apt-get purge -y wget && \
  apt-get autoremove -y && \
  apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY docker-entrypoint.sh /

ENTRYPOINT ["/docker-entrypoint.sh"]
```

```sh
[root@host0-200 filebeat]# vim docker-entrypoint.sh
#!/bin/bash

ENV=${ENV:-"test"}
PROJ_NAME=${PROJ_NAME:-"no-define"}
MULTILINE=${MULTILINE:-"^\d{2}"}

cat > /etc/filebeat.yaml << EOF
filebeat.inputs:
- type: log
  fields_under_root: true
  fields:
    topic: logm-${PROJ_NAME}
  paths:
    - /logm/*.log
    - /logm/*/*.log
    - /logm/*/*/*.log
    - /logm/*/*/*/*.log
    - /logm/*/*/*/*/*.log
  scan_frequency: 120s
  max_bytes: 10485760
  multiline.pattern: '$MULTILINE'
  multiline.negate: true
  multiline.match: after
  multiline.max_lines: 100
- type: log
  fields_under_root: true
  fields:
    topic: logu-${PROJ_NAME}
  paths:
    - /logu/*.log
    - /logu/*/*.log
    - /logu/*/*/*.log
    - /logu/*/*/*/*.log
    - /logu/*/*/*/*/*.log
    - /logu/*/*/*/*/*/*.log
output.kafka:
  hosts: ["10.0.0.11:9092"]
  topic: k8s-fb-$ENV-%{[topic]}
  version: 2.0.0
  required_acks: 0
  max_message_bytes: 10485760
EOF

set -xe

# If user don't provide any command
# Run filebeat
if [[ "$1" == "" ]]; then
     exec filebeat  -c /etc/filebeat.yaml
else
    # Else allow the user to run arbitrarily commands like bash
    exec "$@"
fi
```

给docker-entrypoint.sh添加执行权限

```sh
[root@host0-200 ~]# chmod +x /data/dockerfile/filebeat/docker-entrypoint.sh 
```

### 8.2 构建filebeat镜像

```sh
[root@host0-200 filebeat]# docker build . -t harbor.od.com/infra/filebeat:v7.5.1
```

### 8.3 上传filebeat至私有仓库

```sh
[root@host0-200 ~]# docker login harbor.od.com
[root@host0-200 ~]# docker push harbor.od.com/infra/filebeat:v7.5.1
The push refers to repository [harbor.od.com/infra/filebeat]
8e2236b85988: Pushed 
c2d8da074e58: Pushed 
a126e19b0447: Pushed 
v7.5.1: digest: sha256:cee0803ee83a326663b50839ac63981985b672b4579625beca5f2bc1182df4c1 size: 948
```

修改好Tomcat的dp.yaml文件内容如下：

```sh
[root@host0-200 ~]# cat > /data/k8s-yaml/test/dubbo-demo-consumer/dp.yaml << EOF
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: dubbo-demo-consumer
  namespace: test
  labels: 
    name: dubbo-demo-consumer
spec:
  replicas: 1
  selector:
    matchLabels: 
      name: dubbo-demo-consumer
  template:
    metadata:
      labels: 
        app: dubbo-demo-consumer
        name: dubbo-demo-consumer
    spec:
      containers:
      - name: dubbo-demo-consumer
        image: harbor.od.com/app/dubbo-demo-web:tomcat_20210521_2100
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          protocol: TCP
        env:
        - name: C_OPTS
          value: -Denv=fat -Dapollo.meta=http://config-test.od.com
        volumeMounts:
        - mountPath: /opt/tomcat/logs
          name: logm
      - name: filebeat
        image: harbor.od.com/infra/filebeat:v7.5.1
        imagePullPolicy: IfNotPresent
        env:
        - name: ENV
          value: test
        - name: PROJ_NAME
          value: dubbo-demo-web
        volumeMounts:
        - mountPath: /logm
          name: logm
      volumes:
      - emptyDir: {}
        name: logm
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
EOF
```

应用修改后的资源配置清单，应用前，先将之前的dp.yaml使用kubectl delete -f 来删除pod

```sh
[root@host0-21 ~]# kubectl delete -f http://k8s-yaml.od.com/test/dubbo-demo-consumer/dp.yaml
deployment.extensions "dubbo-demo-consumer" deleted
[root@host0-21 ~]# 
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/test/dubbo-demo-consumer/dp.yaml
deployment.extensions/dubbo-demo-consumer created
[root@host0-21 ~]# 
[root@host0-21 ~]# kubectl get pod -n test
NAME                                   READY   STATUS    RESTARTS   AGE
apollo-adminservice-5cccf97c64-6448z   1/1     Running   6          5d3h
apollo-configservice-5f6555448-dnrts   1/1     Running   6          5d3h
dubbo-demo-consumer-7488576d88-ghlt5   2/2     Running   0          49s
dubbo-demo-service-cc6b9d8c7-wfkgh     1/1     Running   0          6s
```

### 8.4 浏览器访问http://demo-test.od.com/hello?name=maple-tomcat

![](/images/posts/Linux-Kubernetes/交付ELK到K8S/10.png)

![](/images/posts/Linux-Kubernetes/交付ELK到K8S/11.png)

## 9.部署logstash镜像

Logstash链接：https://www.elastic.co/cn/logstash

在运维主机host0-200上运行

### 9.1 下载Logstach-6.8.6镜像

```sh
[root@host0-200 ~]# docker pull logstash:6.8.6
6.8.6: Pulling from library/logstash
ab5ef0e58194: Pull complete 
c2bdff85c0ef: Pull complete 
ea4021eabbe3: Pull complete 
04880b09f62d: Pull complete 
495c57fa2867: Pull complete 
b1226a129846: Pull complete 
a368341d0685: Pull complete 
93bfc3cf8fb8: Pull complete 
89333ddd001c: Pull complete 
289ecf0bfa6d: Pull complete 
b388674055dd: Pull complete 
Digest: sha256:0ae81d624d8791c37c8919453fb3efe144ae665ad921222da97bc761d2a002fe
Status: Downloaded newer image for logstash:6.8.6
docker.io/library/logstash:6.8.6
```

### 9.2 将Logstash镜像的标签修改并上传到私有仓库

```sh
[root@host0-200 ~]# docker tag docker.io/library/logstash:6.8.6 harbor.od.com/infra/logstash:6.8.6
[root@host0-200 ~]# 
[root@host0-200 ~]# docker login harbor.od.com
Authenticating with existing credentials...
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
[root@host0-200 ~]# 
[root@host0-200 ~]# docker push harbor.od.com/infra/logstash:6.8.6
The push refers to repository [harbor.od.com/infra/logstash]
666f2e4c4af9: Pushed 
5c6cd1f13da3: Pushed 
d6dd7f93ab29: Pushed 
30dad013eb8c: Pushed 
ee5cfcf3cf84: Pushed 
8c3a9cdf8d67: Pushed 
34f741ce8747: Pushed 
4ba9ea58780c: Pushed 
f2528af7ad89: Pushed 
c1e731026d5a: Pushed 
77b174a6a187: Pushed 
6.8.6: digest: sha256:0ed0f4605e6848b9ae2df7edf6092abf475c4cdf0f591e00d5e15e4b1e5e1961 size: 2824
```

### 9.3 创建自定义镜像文件

```sh
[root@host0-200 ~]# mkdir -pv /data/dockerfile/logstash
```

自定义dockerfile文件

```sh
[root@host0-200 ~]# cat > /data/dockerfile/logstash/dockerfile << EOF
From harbor.od.com/infra/logstash:6.8.6
ADD logstash.yml /usr/share/logstash/config
EOF
```

自定义logstash.yml文件

```sh
[root@host0-200 ~]# cat > /data/dockerfile/logstash/logstash.yml << EOF
http.host: "0.0.0.0"
path.config: /etc/logstash
xpack.monitoring.enabled: false
EOF
```

### 9.4 构建自定义镜像

```sh
[root@host0-200 ~]# cd /data/dockerfile/logstash/
[root@host0-200 logstash]# 
[root@host0-200 logstash]# docker build . -t harbor.od.com/infra/logstash:v6.8.6
Sending build context to Docker daemon  3.072kB
Step 1/2 : From harbor.od.com/infra/logstash:6.8.6
 ---> d0a2dac51fcb
Step 2/2 : ADD logstash.yml /usr/share/logstash/config
 ---> 3deaf4ee882c
Successfully built 3deaf4ee882c
Successfully tagged harbor.od.com/infra/logstash:v6.8.6
```

### 9.5 上传构建自定义镜像至私有仓库

```sh
[root@host0-200 ~]# docker login harbor.od.com
Authenticating with existing credentials...
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
[root@host0-200 ~]# 
[root@host0-200 ~]# docker push harbor.od.com/infra/logstash:v6.8.6
The push refers to repository [harbor.od.com/infra/logstash]
b111e0ee0d68: Pushed 
666f2e4c4af9: Layer already exists 
5c6cd1f13da3: Layer already exists 
d6dd7f93ab29: Layer already exists 
30dad013eb8c: Layer already exists 
ee5cfcf3cf84: Layer already exists 
8c3a9cdf8d67: Layer already exists 
34f741ce8747: Layer already exists 
4ba9ea58780c: Layer already exists 
f2528af7ad89: Layer already exists 
c1e731026d5a: Layer already exists 
77b174a6a187: Layer already exists 
v6.8.6: digest: sha256:4cfa2ca033aa577dfd77c5ed79cfdf73950137cd8c2d01e52befe4cb6da208a5 size: 3031
```

### 9.6 启动自定义logstash的docker镜像

创建存放logstash配置文件目录

```sh
[root@host0-200 ~]# mkdir -pv /etc/logstash
```

创建logstash启动配置文件

```sh
[root@host0-200 ~]# cat > /etc/logstash/logstash-test.conf << EOF
input {
  kafka {
    bootstrap_servers => "10.0.0.11:9092"
    client_id => "10.0.0.200"
    consumer_threads => 4
    group_id => "k8s_test"
    topics_pattern => "k8s-fb-test-.*"
  }
}

filter {
  json {
    source => "message"
  }
}

output {
  elasticsearch {
    hosts => ["10.0.0.12:9200"]
    index => "k8s-test-%{+YYYY.MM}"
  }
}
EOF
```

启动logstash镜像

```sh
[root@host0-200 ~]# docker run -d --restart=always --name logstash-test -v /etc/logstash:/etc/logstash harbor.od.com/infra/logstash:v6.8.6 -f /etc/logstash/logstash-test.conf
[root@host0-200 ~]# 
[root@host0-200 ~]# docker ps -a|grep logstash
de684cbfe00c        harbor.od.com/infra/logstash:v6.8.6                       "/usr/local/bin/dock…"   28 seconds ago      Up 27 seconds          5044/tcp, 9600/tcp                             logstash-test
```

### 9.7 重新访问http://demo-test.od.com/hello?name=maple-tomcat，建议多刷新几次

### 9.8 验证ElasticSearch里的索引

```sh
[root@host0-200 src]# curl 10.0.0.12:9200/_cat/indices?v
```

