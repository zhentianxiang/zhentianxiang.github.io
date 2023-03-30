---
layout: post
title: Linux-Kubernetes-04-部署zookeeper集群
date: 2021-04-27
tags: 实战-Kubernetes
---



# 实验设计图

# 实验过程

|  主机名   |   IP地址   |       角色       |
| :-------: | :--------: | :---------------:|
| host0-11  | 10.0.0.11  |   负载主机+zk1   |
| host0-12  | 10.0.0.12  |   负载主机+zk2   |
| host0-21  | 10.0.0.21  |   master+node+zk3|
| host0-22  | 10.0.0.22  |   master+node    |
| host0-200 | 10.0.0.200 |     运维主机     |

## 部署zookeeper

### 安装jdk1.8（3台zk角色主机）

[jdk1.8](https://www.oracle.com/java/technologies/javase/javase8u211-later-archive-downloads.html)

涉及主机：host0-11、host0-12、host0-21，以host0-11为例

下载解压压缩包以及软连接

```sh
[root@host0-11 ~]# mkdir -pv /opt/src && cd /opt/src/
[root@host0-11 src]# mkdir /usr/java && tar xf jdk-8u231-linux-x64.tar.gz -C /usr/java/
[root@host0-11 src]# ln -s /usr/java/jdk1.8.0_231/ /usr/java/jdk && ll /usr/java/
总用量 0
lrwxrwxrwx 1 root root  23 4月   7 12:04 jdk -> /usr/java/jdk1.8.0_231/
drwxr-xr-x 7   10  143 245 10月  5 2019 jdk1.8.0_231
```

配置环境变量

```sh
[root@host0-11 src]# vim /etc/profile
export JAVA_HOME=/usr/java/jdk
export PATH=$JAVA_HOME/bin:$JAVA_HOME/bin:$PATH
export CLASSPATH=$CLASSPATH:$JAVA_HOME/lib:$JAVA_HOME/lib/tools.jar
[root@host0-11 src]# source /etc/profile && java -version
java version "1.8.0_231"
Java(TM) SE Runtime Environment (build 1.8.0_231-b11)
Java HotSpot(TM) 64-Bit Server VM (build 25.231-b11, mixed mode)
```

### 下载安装zookeeper

[zookeeper-3.4.14](http://archive.apache.org/dist/zookeeper/zookeeper-3.4.14/zookeeper-3.4.14.tar.gz)

涉及主机：host0-11、host0-12、host0-21，以host0-11为例

```sh
[root@host0-11 src]# wget http://archive.apache.org/dist/zookeeper/zookeeper-3.4.14/zookeeper-3.4.14.tar.gz
--2021-04-07 12:36:52--  http://archive.apache.org/dist/zookeeper/zookeeper-3.4.14/zookeeper-3.4.14.tar.gz
正在解析主机 archive.apache.org (archive.apache.org)... 138.201.131.134, 2a01:4f8:172:2ec5::2
正在连接 archive.apache.org (archive.apache.org)|138.201.131.134|:80... 已连接。
已发出 HTTP 请求，正在等待回应... 200 OK
长度：37676320 (36M) [application/x-gzip]
正在保存至: “zookeeper-3.4.14.tar.gz”

100%[=================================>] 37,676,320  2.52MB/s 用时 62s

2021-04-07 12:37:57 (591 KB/s) - 已保存 “zookeeper-3.4.14.tar.gz” [37676320/37676320])

[root@host0-11 src]# tar xf zookeeper-3.4.14.tar.gz -C /opt/
[root@host0-11 src]# ln -s /opt/zookeeper-3.4.14/ /opt/zookeeper && ll /opt/
总用量 4
drwxr-xr-x  2 root root   51 3月  31 20:27 apps
drwx--x--x  4 root root   28 3月  31 16:56 containerd
drwxr-xr-x  5 root root   75 3月  31 20:26 release
drwxr-xr-x  2 root root  196 4月   7 13:07 src
lrwxrwxrwx  1 root root   22 4月   7 13:10 zookeeper -> /opt/zookeeper-3.4.14/
drwxr-xr-x 14 2002 2002 4096 3月   7 2019 zookeeper-3.4.14
```

### 配置数据和日志目录

```sh
[root@host0-11 src]# mkdir -pv /data/zookeeper/data /data/zookeeper/logs
mkdir: 已创建目录 "/data/zookeeper"
mkdir: 已创建目录 "/data/zookeeper/data"
mkdir: 已创建目录 "/data/zookeeper/logs"
[root@host0-11 src]# mv /opt/zookeeper/conf/zoo_sample.cfg /opt/zookeeper/conf/zoo.cfg
[root@host0-11 src]# vim /opt/zookeeper/conf/zoo.cfg
tickTime=2000
initLimit=10
syncLimit=5
dataDir=/data/zookeeper/data
dataLogDir=/data/zookeeper/logs
clientPort=2181
server.1=zk1.od.com:2888:3888
server.2=zk2.od.com:2888:3888
server.3=zk3.od.com:2888:3888
```

### 配置named解析

```sh
[root@host0-200 src]# vim /var/named/od.com.zone
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2021033108 ; serial
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
[root@host0-200 src]# systemctl restart named
[root@host0-200 src]# dig -t A zk1.od.com @10.0.0.200 +short
10.0.0.11
[root@host0-200 src]# dig -t A zk2.od.com @10.0.0.200 +short
10.0.0.12
[root@host0-200 src]# dig -t A zk3.od.com @10.0.0.200 +short
10.0.0.21
```

### 配置myid

在host0-11上

```sh
[root@host0-11 opt]# vim /data/zookeeper/data/myid
1
```

在host0-12上

```sh
[root@host0-12 opt]# vim /data/zookeeper/data/myid
2
```

在host0-21上

```sh
[root@host0-21 opt]# vim /data/zookeeper/data/myid
3
```

### 启动zookeeper

```sh
[root@host0-11 src]# /opt/zookeeper/bin/zkServer.sh start
ZooKeeper JMX enabled by default
Using config: /opt/zookeeper/bin/../conf/zoo.cfg
Starting zookeeper ... STARTED
[root@host0-11 conf]# netstat -lntp |grep 2181
tcp6       0      0 :::2181                 :::*                    LISTEN      25950/java
[root@host0-11 opt]# /opt/zookeeper/bin/zkServer.sh status
ZooKeeper JMX enabled by default
Using config: /opt/zookeeper/bin/../conf/zoo.cfg
Mode: follower

[root@host0-11 src]# /opt/zookeeper/bin/zkServer.sh start
ZooKeeper JMX enabled by default
Using config: /opt/zookeeper/bin/../conf/zoo.cfg
Starting zookeeper ... STARTED
[root@host0-11 conf]# netstat -lntp|grep 2181
tcp6       0      0 :::2181                 :::*                    LISTEN      74370/java
[root@host0-11 conf]# /opt/zookeeper/bin/zkServer.sh status
ZooKeeper JMX enabled by default
Using config: /opt/zookeeper/bin/../conf/zoo.cfg
Mode: follower
```

## 
