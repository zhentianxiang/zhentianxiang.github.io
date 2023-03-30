---
layout: post
title: Linux-Kubernetes-02-二进制安装
date: 2021-04-27
tags: 实战-Kubernetes
---

## 1. 实验环境

![img](/images/posts/Linux-Kubernetes/二进制部署/1.png)

> - Nginx4层代理
>
> 利用nginx反向代理master的Api-server 6443 端口，然后转发到keepalived的vip上面的7443端口，之后集群node的组件找master上面的api-server的时候就可以走10.0.0.10VIP了，至此就实现了集群内部的负载，当然我这个master和node都部署在同一台机器上面，做这一步骤可有可无。
>
> - Nginx7层代理
>
> 外界访问pod资源流量代理是通过ingress服务暴露实现的，使用的插件名为traefik，traefik成功启动之后本地会监听81端口，也就是traefik映射到本地的端口，用于转发客户端发起访问业务容器的流量，首先客户端访问容器业务流量经过10.0.0.10vip，然后经过nginx的upstream机制转发到21和22master节点的81端口，也就是traefik，之后traefik把流量转发给clusterIP，也就是pod集群IP，最后找到业务容器

|  主机名   |   IP地址   |  主机角色   | 配置 | 存储 |
| :-------: | :--------: | :---------: | :--: | :--: |
| host0-11  | 10.0.0.11  |  负载主机   | 1C2G | 50G  |
| host0-12  | 10.0.0.12  |  负载主机   | 1C2G | 50G  |
| host0-21  | 10.0.0.21  | master+node | 2C4G | 50G  |
| host0-22  | 10.0.0.22  | master+node | 2C4G | 50G  |
| host0-200 | 10.0.0.200 |  运维主机   | 1C2G | 50G  |

部署集群无需太多的资源，但是后期交付微服务要尽可能的增加服务器配置。

> 注意：因为我master和node再同一台机器上，所以没有分开。并且均为centos7.6系统，内核为3.8以上。
>
> 扩容node节点需要：
>
> - 该节点的IP地址需要被记录在以下kubectl、api-server、kube-proxy的证书文件中
> - 该节点需要安装docker、kubectl以及kube-proxy

## 2. 安装前准备

### 2.1. 环境准备

**所有机器**都需要执行

```sh
[root@host0-200~]# systemctl stop firewalld
[root@host0-200~]# systemctl disable firewalld
[root@host0-200~]# sed -i 's/DNS1=10.0.0.254/DNS1=10.0.0.200/g' /etc/sysconfig/network-scripts/ifcfg-ens33
[root@host0-200~]# curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
[root@host0-200~]# yum install -y epel-release chrony bash-completion wget net-tools telnet tree nmap sysstat lrzsz dos2unix bind-utils vim less
[root@host0-200~]# vim /etc/hosts
127.0.0.1 localhost localhost.localdomain localhost4 localhost4.localdomain4
::1 localhost localhost.localdomain localhost6 localhost6.localdomain6
10.0.0.11 host0-11
10.0.0.12 host0-12
10.0.0.21 host0-21
10.0.0.22 host0-22
10.0.0.200 host0-200
[root@host0-200~]# vim /etc/chrony.conf
7 server host0-200 iburst      #添加一行内容，以host0-200为时间同步基准
[root@host0-200~]# systemctl restart chronyd && systemctl enable chronyd && chronyc sources
```

#### 2.2. BIND安装

##### 2.2.1. DNS 安装BIND

```sh
[root@host0-200~]# yum install -y bind
```

##### 2.2.2. DNS 配置BIND

- 主配置文件

```sh
[root@host0-200~]# vim /etc/named.conf  # 确保以下配置正确
//
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//
// See the BIND Administrator's Reference Manual (ARM) for details about the
// configuration located in /usr/share/doc/bind-{version}/Bv9ARM.html

options {
        listen-on port 53 { 10.0.0.200; };  #本机IP
        listen-on-v6 port 53 { ::1; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        recursing-file  "/var/named/data/named.recursing";
        secroots-file   "/var/named/data/named.secroots";
        allow-query     { any; };   #修改为any
        forwarders      { 10.0.0.1; }; #本机网关

        /*
         - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
         - If you are building a RECURSIVE (caching) DNS server, you need to enable
           recursion.
         - If your recursive DNS server has a public IP address, you MUST enable access
           control to limit queries to your legitimate users. Failing to do so will
           cause your server to become part of large scale DNS amplification
           attacks. Implementing BCP38 within your network would greatly
           reduce such attack surface
        */
        recursion yes;

        dnssec-enable no;  #修改为no
        dnssec-validation no; #修改为no
```

- 在 dns.host.com 配置区域文件

```sh
# 增加两个zone配置，od.com为业务域，host.com.zone为主机域
[root@host0-200~]# vim /etc/named.rfc1912.zones
zone "host.com" IN {
        type  master;
        file  "host.com.zone";
        allow-update { 10.0.0.200; };
};

zone "od.com" IN {
        type  master;
        file  "od.com.zone";
        allow-update { 10.0.0.200; };
};
```

- 在 dns.host.com 配置主机域文件

```sh
# line6中时间需要修改
[root@host0-200~]# vim /var/named/host.com.zone
$ORIGIN host.com.
$TTL 600    ; 10 minutes
@       IN SOA  dns.host.com. dnsadmin.host.com. (
                2020010501 ; serial
                10800      ; refresh (3 hours)
                900        ; retry (15 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
                )
            NS   dns.host.com.
$TTL 60 ; 1 minute
dns                A    10.0.0.200
host0-200          A    10.0.0.200
host0-11           A    10.0.0.11
host0-12           A    10.0.0.12
host0-21           A    10.0.0.21
host0-22           A    10.0.0.22
```

- 在 dns.host.com 配置业务域文件

```sh
[root@host0-200~]# vim /var/named/od.com.zone
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020010501 ; serial
                10800      ; refresh (3 hours)
                900        ; retry (15 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
                )
                NS   dns.od.com.
$TTL 60 ; 1 minute
dns                A    10.0.0.200
```

##### 2.2.3. 修改主机DNS

- 修改**所有主机**的dns服务器地址

```sh
[root@host0-200~]# sed -i 's/DNS1=10.0.0.254/DNS1=10.0.0.200/g' /etc/sysconfig/network-scripts/ifcfg-ens33
[root@host0-200~]# systemctl restart network
[root@host0-200~]# vim /etc/resolv.conf
# Generated by NetworkManager
search host.com    //添加此行
nameserver 10.0.0.200

在 dns.host.com 启动bind服务，并测试

[root@host0-200~]# named-checkconf # 检查配置文件
[root@host0-200~]# systemctl start named && systemctl enable named
[root@host0-200~]# host host0-22 10.0.0.200
Using domain server:
Name: 10.0.0.200
Address: 10.0.0.200#53
Aliases:

host0-22.host.com has address 10.0.0.22
```

- 本次实验环境使用的是虚拟机，因此也要对windows宿主机NAT网卡DNS进行修改

![img](/images/posts/Linux-Kubernetes/二进制部署/3.png)

### 2.3. 根证书准备

- 在 host0-200 下载工具

```sh
[root@host0-200 ~]# wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -O /usr/local/bin/cfssl
[root@host0-200 ~]# wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -O /usr/local/bin/cfssl-json
[root@host0-200 ~]# wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 -O /usr/local/bin/cfssl-certinfo
[root@host0-200 ~]# chmod u+x /usr/local/bin/cfssl*
```

- 在 host0-200 签发根证书

```sh
[root@host0-200 ~]# mkdir -pv /opt/certs/ && cd /opt/certs/
# 根证书配置：
# CN 一般写域名，浏览器会校验
# names 为地区和公司信息
# expiry 为过期时间
[root@host0-200 certs]# vim /opt/certs/ca-csr.json
{
    "CN": "OldboyEdu",
    "hosts": [
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "beijing",
            "L": "beijing",
            "O": "od",
            "OU": "ops"
        }
    ],
    "ca": {
        "expiry": "175200h"
    }
}
[root@host0-200 certs]# cfssl gencert -initca ca-csr.json | cfssl-json -bare ca
2020/01/05 10:42:07 [INFO] generating a new CA key and certificate from CSR
2020/01/05 10:42:07 [INFO] generate received request
2020/01/05 10:42:07 [INFO] received CSR
2020/01/05 10:42:07 [INFO] generating key: rsa-2048
2020/01/05 10:42:08 [INFO] encoded CSR
2020/01/05 10:42:08 [INFO] signed certificate with serial number 451005524427475354617025362003367427117323539780
[root@host0-200 certs]# ls -l ca*
-rw-r--r-- 1 root root  993 Jan  5 10:42 ca.csr
-rw-r--r-- 1 root root  328 Jan  5 10:39 ca-csr.json
-rw------- 1 root root 1675 Jan  5 10:42 ca-key.pem
-rw-r--r-- 1 root root 1346 Jan  5 10:42 ca.pem
```

### 2.4. DOCKER环境准备

需要安装docker的机器：host0-21 host0-22 host0-200，以host0-200为例



```sh
[root@host0-200 ~]# wget -O /etc/yum.repos.d/docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
[root@host0-200 ~]# yum install -y docker-ce
[root@host0-200 ~]# mkdir -pv /etc/docker/
# 不安全的registry中增加了harbor地址
# 各个机器上bip网段不一致，bip中间两段与宿主机最后两段相同，目的是方便定位问题
# 如果说域名不可访问，那么请把harbor.od.com换成所对应的IP地址+端口
[root@host0-200 ~]# vim /etc/docker/daemon.json
{
  "graph": "/data/docker",
  "storage-driver": "overlay2",
  "insecure-registries": ["registry.access.redhat.com","quay.io","harbor.od.com"],
  "registry-mirrors": ["https://registry.docker-cn.com"],
  "bip": "172.7.200.1/24",
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true
}
[root@host0-200 ~]# mkdir -pv /data/docker && systemctl start docker && systemctl enable docker
```

### 2.5. harbor安装

参考地址：https://www.yuque.com/duduniao/trp3ic/ohrxds#9Zpxx

官方地址：https://goharbor.io/

下载地址：https://github.com/goharbor/harbor/releases

#### 2.5.1. 安装harbor仓库

```sh
# 目录说明：
# /opt/src : 源码、文件下载目录
# /opt/release : 各个版本软件存放位置
# /opt/apps : 各个软件当前版本的软链接
[root@host0-200 ~]# mkdir -pv /opt/src /opt/release /opt/apps && cd /opt/src
[root@host0-200 src]# wget https://github.com/goharbor/harbor/releases/download/v1.9.4/harbor-offline-installer-v1.9.4.tgz
[root@host0-200 src]# tar xvf harbor-offline-installer-v1.9.4.tgz
[root@host0-200 src]# mv harbor /opt/release/harbor-v1.9.4
[root@host0-200 src]# ln -s /opt/release/harbor-v1.9.4 /opt/apps/harbor && ll /opt/apps/
total 0
lrwxrwxrwx 1 root root 26 Jan  5 11:13 harbor -> /opt/release/harbor-v1.9.4
# 实验环境仅修改以下配置项，生产环境还得修改密码
[root@host0-200 src]# vim /opt/apps/harbor/harbor.yml
hostname: harbor.od.com
http:
  port: 180
data_volume: /data/harbor     //40行
location: /data/harbor/logs   //87行
[root@host0-200 src]# mkdir -pv /data/harbor/logs
[root@host0-200 src]# yum install -y docker-compose
[root@host0-200 src]# cd /opt/apps/harbor/ && ./install.sh && docker-compose ps

[Step 0]: checking installation environment …
Note: docker version: 19.03.13
Note: docker-compose version: 1.18.0
[Step 1]: loading harborimages …

      Name                     Command               State             Ports          
--------------------------------------------------------------------------------------
harbor-core         /harbor/harbor_core              Up                                            
harbor-db           /docker-entrypoint.sh            Up      5432/tcp                              
harbor-jobservice   /harbor/harbor_jobservice  ...   Up                                            
harbor-log          /bin/sh -c /usr/local/bin/ ...   Up      127.0.0.1:1514->10514/tcp             
harbor-portal       nginx -g daemon off;             Up      8080/tcp                              
nginx               nginx -g daemon off;             Up      0.0.0.0:180->8080/tcp,:::180->8080/tcp
redis               redis-server /etc/redis.conf     Up      6379/tcp                              
registry            /entrypoint.sh /etc/regist ...   Up      5000/tcp                              
registryctl         /harbor/start.sh                 Up
```

- 设置harbor开机启动

```sh
[root@host0-200 harbor]# vim /etc/rc.d/rc.local  # 增加以下内容
# start harbor
cd /opt/apps/harbor
/usr/bin/docker-compose stop
/usr/bin/docker-compose start
```

#### 2.5.2. harbor 安装NGINX

- 安装Nginx反向代理harbor

```sh
# 当前机器中Nginx功能较少，使用yum安装即可。如有多个harbor考虑源码编译且配置健康检查
# nginx配置此处忽略，仅仅使用最简单的配置。

[root@host0-200 harbor]# yum -y install nginx
[root@host0-200 harbor]# vim /etc/nginx/conf.d/harbor.conf
[root@host0-200 harbor]# cat /etc/nginx/conf.d/harbor.conf
server {
    listen       80;
    server_name  harbor.od.com;
    # 避免出现上传失败的情况
    client_max_body_size 1000m;

    location / {
        proxy_pass http://127.0.0.1:180;
    }
}
[root@host0-200 harbor# systemctl start nginx && systemctl enable nginx
```

- dns 配置DNS解析

```sh
[root@host0-200~]# vim /var/named/od.com.zone  # 序列号需要滚动一个
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020010502 ; serial
                10800      ; refresh (3 hours)
                900        ; retry (15 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
                )
                NS   dns.od.com.
$TTL 60 ; 1 minute
dns                A    10.0.0.200
harbor             A    10.0.0.200
[root@host0-200~]# systemctl restart named.service  # reload 无法使得配置生效
[root@host0-200~]# host harbor.od.com
harbor.od.com has address 10.0.0.200
```

![img](/images/posts/Linux-Kubernetes/二进制部署/4.png)

- 新建项目: public

![img](/images/posts/Linux-Kubernetes/二进制部署/5.png)

- 测试harbor

```sh
# 如果第一次报错了，就在执行一次命令
[root@host0-200 ~]# docker pull nginx
[root@host0-200 ~]# docker tag nginx:latest harbor.od.com/public/nginx:latest
# 登录方式也是同上，用IP地址＋端口
[root@host0-200 ~]# docker login -u admin harbor.od.com
[root@host0-200 ~]# docker push harbor.od.com/public/nginx:latest
```

![img](/images/posts/Linux-Kubernetes/二进制部署/6.png)

![img](/images/posts/Linux-Kubernetes/二进制部署/7.png)

## 3. 主控节点安装

### 3.1. host0-200安装

etcd 的leader选举机制，要求至少为3台或以上的奇数台。本次安装涉及：host0-200，host0-21，host0-22

#### 3.1.1. 签发etcd证书

证书签发服务器 host0-200:

- 创建ca的json配置: /opt/certs/ca-config.json
- server 表示服务端连接客户端时携带的证书，用于客户端验证服务端身份
- client 表示客户端连接服务端时携带的证书，用于服务端验证客户端身份
- peer 表示相互之间连接时使用的证书，如etcd节点之间验证

```sh
[root@host0-200 ~]# vim /opt/certs/ca-config.json
 
{
    "signing": {
        "default": {
            "expiry": "175200h"
        },
        "profiles": {
            "server": {
                "expiry": "175200h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth"
                ]
            },
            "client": {
                "expiry": "175200h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "client auth"
                ]
            },
            "peer": {
                "expiry": "175200h",
                "usages": [
                    "signing",
                    "key encipherment",
                    "server auth",
                    "client auth"
                ]
            }
        }
    }
}
```

- 创建etcd证书配置：/opt/certs/etcd-peer-csr.json

重点在hosts上，将所有可能的etcd服务器添加到host列表，不能使用网段，新增etcd服务器需要重新签发证书

```sh
[root@host0-200 ~]# vim /opt/certs/etcd-peer-csr.json

{
    "CN": "k8s-etcd",
    "hosts": [
        "10.0.0.21",
        "10.0.0.22",
        "10.0.0.200",
        "10.0.0.11",
        "10.0.0.12"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "beijing",
            "L": "beijing",
            "O": "od",
            "OU": "ops"
        }
    ]
}
```

- 签发证书

```sh
[root@host0-200 ~]# cd /opt/certs/
[root@host0-200 certs]# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=peer etcd-peer-csr.json |cfssl-json -bare etcd-peer && ll etcd-peer*
-rw-r--r-- 1 root root 1062 Jan  5 17:01 etcd-peer.csr
-rw-r--r-- 1 root root  363 Jan  5 16:59 etcd-csr.json
-rw------- 1 root root 1675 Jan  5 17:01 etcd-key.pem
-rw-r--r-- 1 root root 1428 Jan  5 17:01 etcd.pem
```

#### 3.1.2. 安装etcd

etcd地址：https://github.com/etcd-io/etcd/

实验使用版本: [etcd-v3.1.20-linux-amd64.tar.gz](https://github.com/etcd-io/etcd/releases/download/v3.1.20/etcd-v3.1.20-linux-amd64.tar.gz)

本次安装涉及：host0-200，host0-21，host0-22

- 下载etcd

```sh
[root@host0-200 ~]# mkdir -pv /opt/src /opt/release /opt/apps/etcd/certs
[root@host0-200 ~]# useradd -s /sbin/nologin -M etcd
[root@host0-200 ~]# cd /opt/src/
[root@host0-200 src]# wget https://github.com/etcd-io/etcd/releases/download/v3.1.20/etcd-v3.1.20-linux-amd64.tar.gz
[root@host0-200 src]# tar -xf etcd-v3.1.20-linux-amd64.tar.gz
[root@host0-200 src]# mv etcd-v3.1.20-linux-amd64 /opt/release/etcd-v3.1.20
[root@host0-200 src]# ln -s /opt/release/etcd-v3.1.20 /opt/apps/etcd && ll /opt/apps/etcd
lrwxrwxrwx 1 root root 25 Jan  5 17:56 /opt/apps/etcd -> /opt/release/etcd-v3.1.20
[root@host0-200 src]# mkdir -pv /opt/apps/etcd/certs /data/etcd/etcd-server /data/logs/etcd-server
```

- 下发证书到各个etcd上

```sh
[root@host0-200 ~]# cd /opt/certs/
[root@host0-200 ~]# scp ca.pem etcd-peer.pem etcd-peer-key.pem host0-21:/opt/apps/etcd/certs
[root@host0-200 ~]# scp ca.pem etcd-peer.pem etcd-peer-key.pem host0-22:/opt/apps/etcd/certs
[root@host0-200 ~]# scp ca.pem etcd-peer.pem etcd-peer-key.pem /opt/apps/etcd/certs

#注意三台服务器均操作
[root@host0-200 src]# md5sum /opt/apps/etcd/certs/*
8778d0c3411891af61a287e49a70c89a  /opt/apps/etcd/certs/ca.pem
7918783c2f6bf69e96edf03e67d04983  /opt/apps/etcd/certs/etcd-peer-key.pem
d4d849751a834c7727d42324fdedf92d  /opt/apps/etcd/certs/etcd-peer.pem
```

- 创建启动脚本(部分参数每台机器不同)

```sh
[root@host0-200 ~]# vim /opt/apps/etcd/etcd-server-startup.sh
#!/bin/sh
# listen-peer-urls etcd节点之间通信端口
# listen-client-urls 客户端与etcd通信端口
# quota-backend-bytes 配额大小
# 需要修改的参数：name,listen-peer-urls,listen-client-urls,initial-advertise-peer-urls
# 下面的注释需要手动删除掉，不然无法启动脚本

WORK_DIR=$(dirname $(readlink -f $0))
[ $? -eq 0 ] && cd $WORK_DIR || exit
#根据不通的主机修改不同的名字
/opt/apps/etcd/etcd --name etcd-server-host0-200 \
    --data-dir /data/etcd/etcd-server \
#根据不通的主机IP进行修改
    --listen-peer-urls https://10.0.0.200:2380 \
#根据不通的主机IP进行修改
    --listen-client-urls https://10.0.0.200:2379,http://127.0.0.1:2379 \
    --quota-backend-bytes 8000000000 \
#根据不通的主机IP进行修改
    --initial-advertise-peer-urls https://10.0.0.200:2380 \
#根据不通的主机IP进行修改
    --advertise-client-urls https://10.0.0.200:2379,http://127.0.0.1:2379 \
    --initial-cluster  etcd-server-host0-200=https://10.0.0.200:2380,etcd-server-host0-21=https://10.0.0.21:2380,etcd-server-host0-22=https://10.0.0.22:2380 \
    --ca-file ./certs/ca.pem \
    --cert-file ./certs/etcd-peer.pem \
    --key-file ./certs/etcd-peer-key.pem \
    --client-cert-auth  \
    --trusted-ca-file ./certs/ca.pem \
    --peer-ca-file ./certs/ca.pem \
    --peer-cert-file ./certs/etcd-peer.pem \
    --peer-key-file ./certs/etcd-peer-key.pem \
    --peer-client-cert-auth \
    --peer-trusted-ca-file ./certs/ca.pem \
    --log-output stdout
[root@host0-200 ~]# chmod u+x /opt/apps/etcd/etcd-server-startup.sh
[root@host0-200 ~]# chown -R etcd.etcd /opt/apps/etcd/ /data/etcd /data/logs/etcd-server
```

#### 3.1.3. 启动etcd

因为这些进程都是要启动为后台进程，要么手动启动，要么采用后台进程管理工具，实验中使用后台管理工具

```sh
[root@host0-200 ~]# yum install -y supervisor
[root@host0-200 ~]# systemctl start supervisord && systemctl enable supervisord
[root@host0-200 ~]# vim /etc/supervisord.d/etcd-server.ini
[program:etcd-server-host0-200] #根据主机名称修改
command=/opt/apps/etcd/etcd-server-startup.sh         ; the program (relative uses PATH, can take args)
numprocs=1                                            ; number of processes copies to start (def 1)
directory=/opt/apps/etcd                              ; directory to cwd to before exec (def no cwd)
autostart=true                                        ; start at supervisord start (default: true)
autorestart=true                                      ; retstart at unexpected quit (default: true)
startsecs=30                                          ; number of secs prog must stay running (def. 1)
startretries=3                                        ; max # of serial start failures (default 3)
exitcodes=0,2                                         ; 'expected' exit codes for process (default 0,2)
stopsignal=QUIT                                       ; signal used to kill process (default TERM)
stopwaitsecs=10                                       ; max num secs to wait b4 SIGKILL (default 10)
user=etcd                                             ; setuid to this UNIX account to run the program
redirect_stderr=true                                  ; redirect proc stderr to stdout (default false)
stdout_logfile=/data/logs/etcd-server/etcd.stdout.log ; stdout log path, NONE for none; default AUTO
stdout_logfile_maxbytes=64MB                          ; max # logfile bytes b4 rotation (default 50MB)
stdout_logfile_backups=5                              ; # of stdout logfile backups (default 10)
stdout_capture_maxbytes=1MB                           ; number of bytes in 'capturemode' (default 0)
stdout_events_enabled=false                           ; emit events on stdout writes (default false)
```

- etcd 启动服务查看进程

```sh
[root@host0-200 ~]# supervisorctl update
[root@host0-200 ~]# supervisorctl status  # supervisorctl 状态
etcd-server-host0-200                 RUNNING   pid 22375, uptime 0:00:39

[root@200 ~]# netstat -lntp|grep etcd
tcp        0      0 10.0.0.13:2379          0.0.0.0:*               LISTEN      22379/etcd          
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN      22379/etcd          
tcp        0      0 10.0.0.13:2380          0.0.0.0:*               LISTEN      22379/etcd

[root@host0-200 ~]# /opt/apps/etcd/etcdctl member list # 随着etcd重启，leader会变化
55fcbe0adaa45350: name=etcd-server-host0-200 peerURLs=https://10.0.0.200:2380 clientURLs=http://127.0.0.1:2379,https://10.0.0.200:2379 isLeader=true
cebdf10928a06f3c: name=etcd-server-host0-21 peerURLs=https://10.0.0.21:2380 clientURLs=http://127.0.0.1:2379,https://10.0.0.21:2379 isLeader=false
f7a9c20602b8532e: name=etcd-server-host0-22 peerURLs=https://10.0.0.22:2380 clientURLs=http://127.0.0.1:2379,https://10.0.0.22:2379 isLeader=false

[root@host0-200 ~]# /opt/apps/etcd/etcdctl cluster-health
member 55fcbe0adaa45350 is healthy: got healthy result from http://127.0.0.1:2379
member cebdf10928a06f3c is healthy: got healthy result from http://127.0.0.1:2379
member f7a9c20602b8532e is healthy: got healthy result from http://127.0.0.1:2379
cluster is healthy
```

- etcd 启停方式

```sh
[root@host0-200 ~]# supervisorctl start etcd-server-etcd
[root@host0-200 ~]# supervisorctl stop etcd-server-etcd
[root@host0-200 ~]# supervisorctl restart etcd-server-host0-200
[root@host0-200 ~]# supervisorctl status etcd-server-host0-200
```

### 3.2. APISERVER 安装

#### 3.2.1. 下载KUBERNETES服务端

aipserver 涉及的服务器：host0-11，host0-12

下载 kubernetes 二进制版本包需要科学上网工具

- 进入kubernetes的github页面: https://github.com/kubernetes/kubernetes
- 进入tags页签: https://github.com/kubernetes/kubernetes/tags
- 选择要下载的版本: https://github.com/kubernetes/kubernetes/releases/tag/v1.15.2
- 点击 CHANGELOG-${version}.md 进入说明页面: https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.15.md#downloads-for-v1152
- 下载Server Binaries: https://dl.k8s.io/v1.15.2/kubernetes-server-linux-amd64.tar.gz

```sh
[root@host0-21 ~]# cd /opt/src
[root@host0-21 src]# wget https://dl.k8s.io/v1.15.2/kubernetes-server-linux-amd64.tar.gz

[root@host0-21 src]# tar -xf kubernetes-server-linux-amd64.tar.gz
[root@host0-21 src]# mv kubernetes /opt/release/kubernetes-v1.15.2
[root@host0-21 src]# ln -s /opt/release/kubernetes-v1.15.2 /opt/apps/kubernetes && ll /opt/apps/kubernetes
lrwxrwxrwx 1 root root 31 Jan  6 12:59 /opt/apps/kubernetes -> /opt/release/kubernetes-v1.15.2
[root@host0-21 src]# cd /opt/apps/kubernetes && rm -f kubernetes-src.tar.gz && cd server/bin/ && mkdir certs && rm -f *.tar *_tag && ll
total 884636
-rwxr-xr-x 1 root root  43534816 Aug  5 18:01 apiextensions-apiserver
-rwxr-xr-x 1 root root 100548640 Aug  5 18:01 cloud-controller-manager
-rwxr-xr-x 1 root root 200648416 Aug  5 18:01 hyperkube
-rwxr-xr-x 1 root root  40182208 Aug  5 18:01 kubeadm
-rwxr-xr-x 1 root root 164501920 Aug  5 18:01 kube-apiserver
-rwxr-xr-x 1 root root 116397088 Aug  5 18:01 kube-controller-manager
-rwxr-xr-x 1 root root  42985504 Aug  5 18:01 kubectl
-rwxr-xr-x 1 root root 119616640 Aug  5 18:01 kubelet
-rwxr-xr-x 1 root root  36987488 Aug  5 18:01 kube-proxy
-rwxr-xr-x 1 root root  38786144 Aug  5 18:01 kube-scheduler
-rwxr-xr-x 1 root root   1648224 Aug  5 18:01 mounter
```

#### 3.2.2. 签发证书

签发证书 涉及的服务器：host0-200

- 签发client证书（apiserver和etcd通信证书）

```sh
[root@host0-200 ~]# cd /opt/certs/
[root@host0-200 certs]# vim /opt/certs/client-csr.json
{
    "CN": "k8s-node",
    "hosts": [
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "beijing",
            "L": "beijing",
            "O": "od",
            "OU": "ops"
        }
    ]
}
[root@host0-200 certs]# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client client-csr.json |cfssl-json -bare client
2020/01/06 13:42:47 [INFO] generate received request
2020/01/06 13:42:47 [INFO] received CSR
2020/01/06 13:42:47 [INFO] generating key: rsa-2048
2020/01/06 13:42:47 [INFO] encoded CSR
2020/01/06 13:42:47 [INFO] signed certificate with serial number 268276380983442021656020268926931973684313260543
2020/01/06 13:42:47 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[root@host0-200 certs]# ls client* -l
-rw-r--r-- 1 root root  993 Jan  6 13:42 client.csr
-rw-r--r-- 1 root root  280 Jan  6 13:42 client-csr.json
-rw------- 1 root root 1679 Jan  6 13:42 client-key.pem
-rw-r--r-- 1 root root 1363 Jan  6 13:42 client.pem
```

- 签发server证书（apiserver和其它k8s组件通信使用）

```sh
# hosts中将所有可能作为apiserver的ip添加进去，VIP 10.0.0.10 也要加入
[root@host0-200 certs]# vim /opt/certs/apiserver-csr.json
{
    "CN": "k8s-apiserver",
    "hosts": [
        "127.0.0.1",
        "192.168.0.1",
        "kubernetes.default",
        "kubernetes.default.svc",
        "kubernetes.default.svc.cluster",
        "kubernetes.default.svc.cluster.local",
        "10.0.0.21",
        "10.0.0.22",
        "10.0.0.11",
        "10.0.0.12",
        "10.0.0.10"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "beijing",
            "L": "beijing",
            "O": "od",
            "OU": "ops"
        }
    ]
}
[root@host0-200 certs]# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server apiserver-csr.json |cfssl-json -bare apiserver
2020/01/06 13:46:56 [INFO] generate received request
2020/01/06 13:46:56 [INFO] received CSR
2020/01/06 13:46:56 [INFO] generating key: rsa-2048
2020/01/06 13:46:56 [INFO] encoded CSR
2020/01/06 13:46:56 [INFO] signed certificate with serial number 573076691386375893093727554861295529219004473872
2020/01/06 13:46:56 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[root@host0-200 certs]# ls apiserver* -l
-rw-r--r-- 1 root root 1249 Jan  6 13:46 apiserver.csr
-rw-r--r-- 1 root root  566 Jan  6 13:45 apiserver-csr.json
-rw------- 1 root root 1675 Jan  6 13:46 apiserver-key.pem
-rw-r--r-- 1 root root 1598 Jan  6 13:46 apiserver.pem
```

- 证书下发

```sh
拷贝到host0-21和host0-22
[root@host0-200 certs]# scp ca.pem ca-key.pem client.pem client-key.pem apiserver.pem apiserver-key.pem host0-21:/opt/apps/kubernetes/server/bin/certs
[root@host0-200 certs]# scp ca.pem ca-key.pem client.pem client-key.pem apiserver.pem apiserver-key.pem host0-22:/opt/apps/kubernetes/server/bin/certs
```

#### 3.2.3. 配置APISERVER日志审计

aipserver 涉及的服务器：host0-21，host0-22

```sh
[root@host0-21 bin]# mkdir -pv /opt/apps/kubernetes/conf
[root@host0-21 bin]# vim /opt/apps/kubernetes/conf/audit

apiVersion: audit.k8s.io/v1beta1 # This is required.
kind: Policy
# Don't generate audit events for all requests in RequestReceived stage.
omitStages:
  - "RequestReceived"
rules:
  # Log pod changes at RequestResponse level
  - level: RequestResponse
    resources:
    - group: ""
      # Resource "pods" doesn't match requests to any subresource of pods,
      # which is consistent with the RBAC policy.
      resources: ["pods"]
  # Log "pods/log", "pods/status" at Metadata level
  - level: Metadata
    resources:
    - group: ""
      resources: ["pods/log", "pods/status"]

  # Don't log requests to a configmap called "controller-leader"
  - level: None
    resources:
    - group: ""
      resources: ["configmaps"]
      resourceNames: ["controller-leader"]

  # Don't log watch requests by the "system:kube-proxy" on endpoints or services
  - level: None
    users: ["system:kube-proxy"]
    verbs: ["watch"]
    resources:
    - group: "" # core API group
      resources: ["endpoints", "services"]

  # Don't log authenticated requests to certain non-resource URL paths.
  - level: None
    userGroups: ["system:authenticated"]
    nonResourceURLs:
    - "/api*" # Wildcard matching.
    - "/version"

  # Log the request body of configmap changes in kube-system.
  - level: Request
    resources:
    - group: "" # core API group
      resources: ["configmaps"]
    # This rule only applies to resources in the "kube-system" namespace.
    # The empty string "" can be used to select non-namespaced resources.
    namespaces: ["kube-system"]

  # Log configmap and secret changes in all other namespaces at the Metadata level.
  - level: Metadata
    resources:
    - group: "" # core API group
      resources: ["secrets", "configmaps"]

  # Log all other resources in core and extensions at the Request level.
  - level: Request
    resources:
    - group: "" # core API group
    - group: "extensions" # Version of group should NOT be included.

  # A catch-all rule to log all other requests at the Metadata level.
  - level: Metadata
    # Long-running requests like watches that fall under this rule will not
    # generate an audit event in RequestReceived.
    omitStages:
      - "RequestReceived"

[root@host0-21 bin]# mv /opt/apps/kubernetes/conf/audit /opt/apps/kubernetes/conf/audit.yaml
```

#### 3.2.4. 配置启动脚本

aipserver 涉及的服务器：host0-21，host0-22

- 创建启动脚本

```sh
[root@host0-21 bin]# vim /opt/apps/kubernetes/server/bin/kube-apiserver-startup.sh
#!/bin/bash

WORK_DIR=$(dirname $(readlink -f $0))
[ $? -eq 0 ] && cd $WORK_DIR || exit

/opt/apps/kubernetes/server/bin/kube-apiserver \
    --apiserver-count 2 \
    --audit-log-path /data/logs/kubernetes/kube-apiserver/audit-log \
    --audit-policy-file ../../conf/audit.yaml \
    --authorization-mode RBAC \
    --client-ca-file ./certs/ca.pem \
    --requestheader-client-ca-file ./certs/ca.pem \
    --enable-admission-plugins NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota \
    --etcd-cafile ./certs/ca.pem \
    --etcd-certfile ./certs/client.pem \
    --etcd-keyfile ./certs/client-key.pem \
    --etcd-servers https://10.0.0.200:2379,https://10.0.0.21:2379,https://10.0.0.22:2379 \
    --service-account-key-file ./certs/ca-key.pem \
    --service-cluster-ip-range 192.168.0.0/16 \
    --service-node-port-range 3000-29999 \
    --target-ram-mb=1024 \
    --kubelet-client-certificate ./certs/client.pem \
    --kubelet-client-key ./certs/client-key.pem \
    --log-dir  /data/logs/kubernetes/kube-apiserver \
    --tls-cert-file ./certs/apiserver.pem \
    --tls-private-key-file ./certs/apiserver-key.pem \
    --v 2

[root@host0-21 bin]# chmod u+x /opt/apps/kubernetes/server/bin/kube-apiserver-startup.sh
```

- 配置supervisor启动配置

```sh
[root@host0-21 bin]# vim /etc/supervisord.d/kube-apiserver.ini
[program:kube-apiserver-host0-21]
command=/opt/apps/kubernetes/server/bin/kube-apiserver-startup.sh ; the program (relative uses PATH, can take args)
numprocs=1                                            ; number of processes copies to start (def 1)
directory=/opt/apps/kubernetes/server/bin                  ; directory to cwd to before exec (def no cwd)
autostart=true                                        ; start at supervisord start (default: true)
autorestart=true                                      ; retstart at unexpected quit (default: true)
startsecs=30                                          ; number of secs prog must stay running (def. 1)
startretries=3                                        ; max # of serial start failures (default 3)
exitcodes=0,2                                         ; 'expected' exit codes for process (default 0,2)
stopsignal=QUIT                                       ; signal used to kill process (default TERM)
stopwaitsecs=10                                       ; max num secs to wait b4 SIGKILL (default 10)
user=root                                             ; setuid to this UNIX account to run the program
redirect_stderr=true                                  ; redirect proc stderr to stdout (default false)
stdout_logfile=/data/logs/kubernetes/kube-apiserver/apiserver.stdout.log ; stdout log path, NONE for none; default AUTO
stdout_logfile_maxbytes=64MB                          ; max # logfile bytes b4 rotation (default 50MB)
stdout_logfile_backups=5                              ; # of stdout logfile backups (default 10)
stdout_capture_maxbytes=1MB                           ; number of bytes in 'capturemode' (default 0)
stdout_events_enabled=false                           ; emit events on stdout writes (default false)

[root@host0-21 bin]# mkdir -pv /data/logs/kubernetes/kube-apiserver     //api-server日志
```

- 启停apiserver

```sh
[root@host0-21 bin]# supervisorctl update
[root@host0-21 bin]# supervisorctl status
[root@host0-21 ~]# supervisorctl start kube-apiserver-host0-21
[root@host0-21 ~]# supervisorctl stop kube-apiserver-host0-21
[root@host0-21 ~]# supervisorctl restart kube-apiserver-host0-21
[root@host0-21 ~]# supervisorctl status kube-apiserver-host0-21
```

- 查看进程

```sh
[root@host0-21 bin]# netstat -lntp|grep api
tcp        0      0 127.0.0.1:8080          0.0.0.0:*               LISTEN      32595/kube-apiserve 
tcp6       0      0 :::6443                 :::*                    LISTEN      32595/kube-apiserve 
[root@host0-21 bin]# ps uax|grep kube-apiserver|grep -v grep
root      32591  0.0  0.0 115296  1476 ?        S    20:17   0:00 /bin/bash /opt/apps/kubernetes/server/bin/kube-apiserver-startup.sh
root      32595  3.0  2.3 402720 184892 ?       Sl   20:17   0:16 /opt/apps/kubernetes/server/bin/kube-apiserver --apiserver-count 2 --audit-log-path /data/logs/kubernetes/kube-apiserver/audit-log --audit-policy-file ../../conf/audit.yaml --authorization-mode RBAC --client-ca-file ./certs/ca.pem --requestheader-client-ca-file ./certs/ca.pem --enable-admission-plugins NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota --etcd-cafile ./certs/ca.pem --etcd-certfile ./certs/client.pem --etcd-keyfile ./certs/client-key.pem --etcd-servers https://10.0.0.200:2379,https://10.0.0.21:2379,https://10.0.0.22:2379 --service-account-key-file ./certs/ca-key.pem --service-cluster-ip-range 192.168.0.0/16 --service-node-port-range 3000-29999 --target-ram-mb=1024 --kubelet-client-certificate ./certs/client.pem --kubelet-client-key ./certs/client-key.pem --log-dir /data/logs/kubernetes/kube-apiserver --tls-cert-file ./certs/apiserver.pem --tls-private-key-file ./certs/apiserver-key.pem --v 2
```

### 3.3. 配置APISERVER L4代理

#### 3.3.1. NGINX配置

L4 代理涉及的服务器：host0-11，host0-12

```sh
[root@host0-11~]# yum install -y nginx
[root@host0-11~]# vim /etc/nginx/nginx.conf
# 末尾加上以下内容，stream 只能加在 main 中
# 此处只是简单配置下nginx，实际生产中，建议进行更合理的配置
stream {
    log_format proxy '$time_local|$remote_addr|$upstream_addr|$protocol|$status|'
                     '$session_time|$upstream_connect_time|$bytes_sent|$bytes_received|'
                     '$upstream_bytes_sent|$upstream_bytes_received' ;

    upstream kube-apiserver {
        server 10.0.0.21:6443     max_fails=3 fail_timeout=30s;
        server 10.0.0.22:6443     max_fails=3 fail_timeout=30s;
    }
    server {
        listen 7443;
        proxy_connect_timeout 2s;
        proxy_timeout 900s;
        proxy_pass kube-apiserver;
        access_log /var/log/nginx/proxy.log proxy;
    }
}
[root@host0-11~]# systemctl start nginx &&  systemctl enable nginx
[root@host0-11~]# curl 127.0.0.1:7443  # 测试几次
Client sent an HTTP request to an HTTPS server.
[root@host0-11~]# cat /var/log/nginx/proxy.log
06/Jan/2020:21:00:27 +0800|127.0.0.1|10.0.0.21:6443|TCP|200|0.001|0.000|76|78|78|76
06/Jan/2020:21:05:03 +0800|127.0.0.1|10.0.0.22:6443|TCP|200|0.020|0.019|76|78|78|76
06/Jan/2020:21:05:04 +0800|127.0.0.1|10.0.0.21:6443|TCP|200|0.001|0.001|76|78|78|76
```

#### 3.3.2. KEEPALIVED配置

aipserver L4 代理涉及的服务器：host0-11，host0-12

- 安装keepalive

```sh
[root@host0-11~]# yum install -y keepalived
[root@host0-11~]# vim /etc/keepalived/check_port.sh # 配置检查脚本
#!/bin/bash
if [ $# -eq 1 ] && [[ $1 =~ ^[0-9]+ ]];then
    [ $(netstat -lntp|grep ":$1 " |wc -l) -eq 0 ] && echo "[ERROR] nginx may be not running!" && exit 1 || exit 0
else
    echo "[ERROR] need one port!"
    exit 1
fi
[root@host0-11~]# chmod u+x /etc/keepalived/check_port.sh
```

- 配置主节点：/etc/keepalived/keepalived.conf

**主节点中，必须加上** **nopreempt**

因为一旦因为网络抖动导致VIP漂移，不能让它自动飘回来，必须要分析原因后手动迁移VIP到主节点！如主节点确认正常后，重启备节点的keepalive，让VIP飘到主节点.

keepalived 的日志输出配置此处省略，生产中需要进行处理。

```sh
[root@host0-11 ~]# vim /etc/keepalived/keepalived.conf

! Configuration File for keepalived
global_defs {
   router_id 10.0.0.11         ###注意本机地址
}
vrrp_script chk_nginx {
    script "/etc/keepalived/check_port.sh 7443"
    interval 2
    weight -20
}
vrrp_instance VI_1 {
    state MASTER
    interface ens33   ###注意网卡名称
    virtual_router_id 251
    priority 100
    advert_int 1
    mcast_src_ip 10.0.0.11
    nopreempt

    authentication {
        auth_type PASS
        auth_pass 11111111
    }
    track_script {
         chk_nginx
    }
    virtual_ipaddress {
        10.0.0.10
    }
}
```

- 配置备节点：/etc/keepalived/keepalived.conf

```sh
[root@host0-11~]# vim /etc/keepalived/keepalived.conf

! Configuration File for keepalived
global_defs {
    router_id 10.0.0.12
}
vrrp_script chk_nginx {
    script "/etc/keepalived/check_port.sh 7443"
    interval 2
    weight -20
}
vrrp_instance VI_1 {
    state BACKUP
    interface ens33                 /////注意网卡名称
    virtual_router_id 251
    mcast_src_ip 10.0.0.12
    priority 90
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 11111111
    }
    track_script {
        chk_nginx
    }
    virtual_ipaddress {
        10.0.0.10
    }
}
```

- 启动keepalived

```sh
[root@host0-11~]# systemctl start keepalived && systemctl enable keepalived
[root@host0-11~]# ip addr show ens33
2: ens32: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:6d:b8:82 brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.200/24 brd 10.0.0.255 scope global noprefixroute ens32
       valid_lft forever preferred_lft forever
    inet 10.0.0.10/32 scope global ens32
       valid_lft forever preferred_lft forever
......
```

### 3.4. CONTROLLER-MANAGER 安装

controller-manager 涉及的服务器：host0-11，host0-12

controller-manager 设置为只调用当前机器的 apiserver，走127.0.0.1网卡，因此不配制SSL证书

```sh
[root@host0-21 ~]# vim /opt/apps/kubernetes/server/bin/kube-controller-manager-startup.sh
#!/bin/sh
WORK_DIR=$(dirname $(readlink -f $0))
[ $? -eq 0 ] && cd $WORK_DIR || exit

/opt/apps/kubernetes/server/bin/kube-controller-manager \
    --cluster-cidr 172.7.0.0/16 \
    --leader-elect true \
    --log-dir /data/logs/kubernetes/kube-controller-manager \
    --master http://127.0.0.1:8080 \
    --service-account-private-key-file ./certs/ca-key.pem \
    --service-cluster-ip-range 192.168.0.0/16 \
    --root-ca-file ./certs/ca.pem \
    --v 2
[root@host0-21 ~]# chmod u+x /opt/apps/kubernetes/server/bin/kube-controller-manager-startup.sh
[root@host0-21 ~]# vim /etc/supervisord.d/kube-controller-manager.ini
[program:kube-controller-manager-host0-21]
command=/opt/apps/kubernetes/server/bin/kube-controller-manager-startup.sh                     ; the program (relative uses PATH, can take args)
numprocs=1                                                                        ; number of processes copies to start (def 1)
directory=/opt/apps/kubernetes/server/bin                                              ; directory to cwd to before exec (def no cwd)
autostart=true                                                                    ; start at supervisord start (default: true)
autorestart=true                                                                  ; retstart at unexpected quit (default: true)
startsecs=30                                                                      ; number of secs prog must stay running (def. 1)
startretries=3                                                                    ; max # of serial start failures (default 3)
exitcodes=0,2                                                                     ; 'expected' exit codes for process (default 0,2)
stopsignal=QUIT                                                                   ; signal used to kill process (default TERM)
stopwaitsecs=10                                                                   ; max num secs to wait b4 SIGKILL (default 10)
user=root                                                                         ; setuid to this UNIX account to run the program
redirect_stderr=true                                                              ; redirect proc stderr to stdout (default false)
stdout_logfile=/data/logs/kubernetes/kube-controller-manager/controller.stdout.log  ; stderr log path, NONE for none; default AUTO
stdout_logfile_maxbytes=64MB                                                      ; max # logfile bytes b4 rotation (default 50MB)
stdout_logfile_backups=4                                                          ; # of stdout logfile backups (default 10)
stdout_capture_maxbytes=1MB                                                       ; number of bytes in 'capturemode' (default 0)
stdout_events_enabled=false

[root@host0-21 bin]# mkdir -pv /data/logs/kubernetes/kube-controller-manager

[root@host0-21 ~]# supervisorctl update
kube-controller-manager-host0-21: updated process group

[root@host0-21 ~]# supervisorctl status
etcd-server-host0-21               RUNNING   pid 16997, uptime 0:29:51
kube-apiserver-host0-21            RUNNING   pid 34466, uptime 0:14:37
kube-controller-manager-host0-21   RUNNING   pid 48602, uptime 0:02:21
```

### 3.5. KUBE-SCHEDULER安装

kube-scheduler 涉及的服务器：host0-21，host0-22

kube-scheduler 设置为只调用当前机器的 apiserver，走127.0.0.1网卡，因此不配制SSL证书

```sh
[root@host0-21 bin]# vim /opt/apps/kubernetes/server/bin/kube-scheduler-startup.sh
#!/bin/sh
WORK_DIR=$(dirname $(readlink -f $0))
[ $? -eq 0 ] && cd $WORK_DIR || exit

/opt/apps/kubernetes/server/bin/kube-scheduler \
    --leader-elect  \
    --log-dir /data/logs/kubernetes/kube-scheduler \
    --master http://127.0.0.1:8080 \
    --v 2

[root@host0-21 ~]# chmod u+x /opt/apps/kubernetes/server/bin/kube-scheduler-startup.sh

[root@host0-21 ~]# vim /etc/supervisord.d/kube-scheduler.ini
[program:kube-scheduler-host0-21]
command=/opt/apps/kubernetes/server/bin/kube-scheduler-startup.sh                     
numprocs=1                                                               
directory=/opt/apps/kubernetes/server/bin                                     
autostart=true                                                           
autorestart=true                                                         
startsecs=30                                                             
startretries=3                                                           
exitcodes=0,2                                                            
stopsignal=QUIT                                                          
stopwaitsecs=10                                                          
user=root                                                                
redirect_stderr=true                                                     
stdout_logfile=/data/logs/kubernetes/kube-scheduler/scheduler.stdout.log 
stdout_logfile_maxbytes=64MB                                             
stdout_logfile_backups=4                                                 
stdout_capture_maxbytes=1MB                                              
stdout_events_enabled=false

[root@host0-21 ~]# mkdir -pv /data/logs/kubernetes/kube-scheduler

[root@host0-21 ~]# supervisorctl update
kube-scheduler-host0-21: updated process group

[root@host0-21 ~]# supervisorctl status
host0-21-server-host0-21             RUNNING   pid 23637, uptime 1 day, 0:26:53
kube-apiserver-host0-21              RUNNING   pid 32591, uptime 2:06:22
kube-controller-manager-host0-21     RUNNING   pid 33357, uptime 0:10:37
kube-scheduler-host0-21              RUNNING   pid 33450, uptime 0:01:18
```

### 3.6. 检查主控节点状态

```sh
[root@host0-21 ~]# yum install -y bash-completion
[root@host0-21 ~]# ln -s /opt/apps/kubernetes/server/bin/kubectl /usr/local/bin/
[root@host0-21 ~]# source /usr/share/bash-completion/bash_completion
[root@host0-21 ~]# source <(kubectl completion bash)
[root@host0-21 ~]# echo "source <(kubectl completion bash)" >> ~/.bashrc
[root@host0-21 ~]# kubectl get cs
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok                   
controller-manager   Healthy   ok                   
etcd-1               Healthy   {"health": "true"}   
etcd-0               Healthy   {"health": "true"}   
etcd-2               Healthy   {"health": "true"}   
```

如果遇到数据库状态不是 “Healthy {“health”: “true”}”，则停止数据库，删除一下文件：rm -rf /data/etcd/etcd-server/member/，然后在启动服务，三台均是。

```sh
[root@host0-21 ~]# ln -s /opt/apps/kubernetes/server/bin/kubectl /usr/local/bin/
[root@host0-21 ~]# kubectl get cs
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok                   
scheduler            Healthy   ok                   
etcd-2               Healthy   {"health": "true"}   
etcd-1               Healthy   {"health": "true"}   
etcd-0               Healthy   {"health": "true"} 
```

## 4. 运算节点部署

### 4.1. KUBELET 部署

#### 4.1.1. 签发证书

证书签发在 host0-200 操作

```sh
[root@host0-200 ~]# cd /opt/certs/
[root@host0-200 certs]# vim kubelet-csr.json # 将所有可能的kubelet机器IP添加到hosts中
{
    "CN": "k8s-kubelet",
    "hosts": [
    "127.0.0.1",
    "10.0.0.10",
    "10.0.0.21",
    "10.0.0.22",
    "10.0.0.23",
    "10.0.0.24",
    "10.0.0.25",
    "10.0.0.26",
    "10.0.0.27",
    "10.0.0.28"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "beijing",
            "L": "beijing",
            "O": "od",
            "OU": "ops"
        }
    ]
}
[root@host0-200 certs]# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server kubelet-csr.json | cfssl-json -bare kubelet
2020/01/06 23:10:56 [INFO] generate received request
2020/01/06 23:10:56 [INFO] received CSR
2020/01/06 23:10:56 [INFO] generating key: rsa-2048
2020/01/06 23:10:56 [INFO] encoded CSR
2020/01/06 23:10:56 [INFO] signed certificate with serial number 61221942784856969738771370531559555767101820379
2020/01/06 23:10:56 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[root@host0-200 certs]# ls kubelet* -l
-rw-r--r-- 1 root root 1115 Jan  6 23:10 kubelet.csr
-rw-r--r-- 1 root root  452 Jan  6 23:10 kubelet-csr.json
-rw------- 1 root root 1675 Jan  6 23:10 kubelet-key.pem
-rw-r--r-- 1 root root 1468 Jan  6 23:10 kubelet.pem

[root@host0-200 certs]# scp kubelet.pem kubelet-key.pem host0-21:/opt/apps/kubernetes/server/bin/certs/
[root@host0-200 certs]# scp kubelet.pem kubelet-key.pem host0-22:/opt/apps/kubernetes/server/bin/certs/
```

#### 4.1.2. 创建KUBELET配置

kubelet配置在 host0-21 host0-22 操作

以下操作就是创建个普通用户，然后给这个用户授予k8s-node节点的权限，使其能够使用kubectl命令来管理k8s集群的资源。
这个普通用户叫k8s-node

- set-cluster

> 这个命令要实现的是，定义一下哪些节点为node节点，然后才能准确的分发给各个节点的k8s-node员权限
> 然后统一用所谓的myk8s集群来代表这些node节点，具体有哪些节点被圈起来定义进来，就看kubelet-csr.json如何签发的ca.pem证书
> 如果ca.pem根证书发生改变，那么就重新kubelet-csr.json签发ca.pem，然后再set-cluster创建kubelet.kubeconfig配置文件，最后重启kubectl

```sh
[root@host0-21 ~]# kubectl config set-cluster myk8s \  #首先用set-cluster myk8s，创建一个所谓的集群
--certificate-authority=/opt/apps/kubernetes/server/bin/certs/ca.pem \  #指定ca.pem证书
--embed-certs=true \  #承载式证书
--server=https://10.0.0.10:7443 \  #kubectl普通用户找api-server通信走https://10.0.0.10:7443
--kubeconfig=/opt/apps/kubernetes/conf/kubelet.kubeconfig  #在conf目录下生成一个base64编码的kubelet.kubeconfig文件，就是把ca.pem嵌套在这个kubelet.kubeconfig文件里面了
```

- set-credentials

> 做一个k8s-node普通用户，签发key密钥到kubectl.kubeconfig
> 然后为了承接上面的证书而签发的key密钥，kubectl作为客户端为了和api-server通信而做的key

```sh
[root@host0-21 ~]# kubectl config set-credentials k8s-node \
--client-certificate=/opt/apps/kubernetes/server/bin/certs/client.pem \
--client-key=/opt/apps/kubernetes/server/bin/certs/client-key.pem \
--embed-certs=true \
--kubeconfig=/opt/apps/kubernetes/conf/kubelet.kubeconfig
```

- set-context

> 确定用户和myk8s对应关系

```sh
[root@host0-21 ~]# kubectl config set-context myk8s-context \
--cluster=myk8s \
--user=k8s-node \
--kubeconfig=/opt/apps/kubernetes/conf/kubelet.kubeconfig
```

- use-context

> 设置当前使用哪个context

```sh
[root@host0-21 ~]# kubectl config use-context myk8s-context --kubeconfig=/opt/apps/kubernetes/conf/kubelet.kubeconfig
```

#### 4.1.3. 授权K8S-NODE用户

**此步骤只需要在一台master节点执行**

授权 k8s-node 用户绑定集群角色 system:node ，让 k8s-node 成为具备运算节点的权限。创建出来的用户会存放在etcd。

```sh
[root@host0-21 bin]# mkdir /yaml && vim /yaml/k8s-node.yaml
#定义资源类型的版本
apiVersion: rbac.authorization.k8s.io/v1
#定义资源为绑定角色
kind: ClusterRoleBinding
metadata:
#定义这个绑定角色的名称
  name: k8s-node
roleRef:
  apiGroup: rbac.authorization.k8s.io
#定义绑定的角色为集群角色
  kind: ClusterRole
#这个角色的名称
  name: system:node
#开始绑定普通用户和集群角色
subjects:
- apiGroup: rbac.authorization.k8s.io
#定义普通用户
  kind: User
#普通用户名称
  name: k8s-node
  
以上操作就是让创建k8s-node用户然后这个用户属于这个名为system:node的集群角色
[root@host0-21 ~]# kubectl create -f /yaml/k8s-node.yaml
clusterrolebinding.rbac.authorization.k8s.io/k8s-node created
[root@host0-21 ~]# kubectl get clusterrolebinding k8s-node
NAME       AGE
k8s-node   36s
[root@host0-21 ~]# kubectl get clusterrolebinding k8s-node -o yaml  #查看配置文件
```

#### 4.1.4. 装备PAUSE镜像

将pause镜像放入到harbor私有仓库中，仅在 harbor 操作：

> kubectl在启动的时候需要一个基础镜像来帮助我们启动pod
> kubectl是接收schdeuler调度以后命令kubectl在哪个node拉起容器
> 拉起pod容器必须要有一个基础镜像，说白了就是我要用pause去抢占位置抢占ip或者抢占namespace，来为pod预占。

```sh
如果pull太慢或者卡死，可以使用docker pull daocloud.io/daocloud/google_containers_pause-amd64:3.1

[root@host0-200 ~]# docker pull kubernetes/pause
[root@host0-200 ~]# docker tag kubernetes/pause:latest harbor.od.com/public/pause:latest
[root@host0-200 ~]# docker push harbor.od.com/public/pause:latest
```

#### 4.1.5. 创建启动脚本

在node节点创建脚本并启动kubelet，涉及服务器： host0-21 host0-22

```sh
[root@host0-21 ~]# vim /opt/apps/kubernetes/server/bin/kubelet-startup.sh
#!/bin/sh

WORK_DIR=$(dirname $(readlink -f $0))
[ $? -eq 0 ] && cd $WORK_DIR || exit

/opt/apps/kubernetes/server/bin/kubelet \
#不允许匿名登陆
    --anonymous-auth=false \
#与docker的daemon.json文件中一致
    --cgroup-driver systemd \
#集群IP
    --cluster-dns 192.168.0.2 \
    --cluster-domain cluster.local \
    --runtime-cgroups=/systemd/system.slice \
    --kubelet-cgroups=/systemd/system.slice \
#kubectl启动默认应该关闭swap，在这儿的意思就是我即便没有关闭swap分区也不会报错
    --fail-swap-on="false" \
#指定根证书
    --client-ca-file ./certs/ca.pem \
#指定生成的证书
    --tls-cert-file ./certs/kubelet.pem \
#kubectl作为服务端需要的证书和私钥
    --tls-private-key-file ./certs/kubelet-key.pem \
#主机名
    --hostname-override host0-21.host.com \
    --image-gc-high-threshold 20 \
    --image-gc-low-threshold 10 \
#指定上面自己做出来的配置文件
    --kubeconfig ../../conf/kubelet.kubeconfig \
    --log-dir /data/logs/kubernetes/kube-kubelet \
#指定kubectl用pause镜像
    --pod-infra-container-image harbor.od.com/public/pause:latest \
    --root-dir /data/kubelet

[root@host0-21 ~]# chmod u+x /opt/apps/kubernetes/server/bin/kubelet-startup.sh

[root@host0-21 ~]# vim /etc/supervisord.d/kube-kubelet.ini

[program:kube-kubelet-host0-21]
command=/opt/apps/kubernetes/server/bin/kubelet-startup.sh
numprocs=1
directory=/opt/apps/kubernetes/server/bin
autostart=true
autorestart=true
startsecs=30
startretries=3
exitcodes=0,2
stopsignal=QUIT
stopwaitsecs=10
user=root
redirect_stderr=true
stdout_logfile=/data/logs/kubernetes/kube-kubelet/kubelet.stdout.log
stdout_logfile_maxbytes=64MB
stdout_logfile_backups=5
stdout_capture_maxbytes=1MB
stdout_events_enabled=false

[root@host0-21 ~]# mkdir -pv /data/logs/kubernetes/kube-kubelet /data/kubelet

[root@host0-21 ~]# supervisorctl update

[root@host0-21 ~]# supervisorctl status
etcd-server-host0-21                 RUNNING   pid 23637, uptime 1 day, 14:56:25
kube-apiserver-host0-21              RUNNING   pid 32591, uptime 16:35:54
kube-controller-manager-host0-21     RUNNING   pid 33357, uptime 14:40:09
kube-kubelet-host0-21                RUNNING   pid 37232, uptime 0:01:08
kube-scheduler-host0-21              RUNNING   pid 33450, uptime 14:30:50

[root@host0-21 ~]# kubectl get node
NAME                STATUS   ROLES    AGE     VERSION
host0-21.host.com   Ready    <none>   3m13s   v1.15.2
host0-22.host.com   Ready    <none>   3m13s   v1.15.2
```

如果没说数据出现，请查看日志

```sh
[root@host0-21 ~]# tail -fn 500 /data/logs/kubernetes/kube-kubelet/kubelet.stdout.log
```

![img](/images/posts/Linux-Kubernetes/二进制部署/8.png)

说的是找不到7443端口，从而找不到主机，7443端口对应的10.0.0.10虚拟ip，而vip在keepalived主机上面，去主机重启keepalived服务就可以了。

```sh
查看日志还可能提示说没有权限
E0330 17:07:02.878643    7630 kubelet.go:2248] node "host0-12.host.com" not found
E0330 17:07:02.979450    7630 kubelet.go:2248] node "host0-12.host.com" not found
E0330 17:07:03.041043    7630 reflector.go:125] k8s.io/client-go/informers/factory.go:133: Failed to list *v1beta1.RuntimeClass: runtimeclasses.node.k8s.io is forbidden: User "system:anonymous" cannot list resource "runtimeclasses" in API group "node.k8s.io" at the cluster scope
E0330 17:07:03.080219    7630 kubelet.go:2248] node "host0-12.host.com" not found
E0330 17:07:03.180805    7630 kubelet.go:2248] node "host0-12.host.com" not found
E0330 17:07:03.248275    7630 reflector.go:125] k8s.io/kubernetes/pkg/kubelet/kubelet.go:444: Failed to list *v1.Service: services is forbidden: User "system:anonymous" cannot list resource "services" in API group "" at the cluster scope

需要以下：绑定一个cluster-admin的权限
[root@host0-21 ~]# kubectl create clusterrolebinding system:anonymous   --clusterrole=cluster-admin   --user=system:anonymous
再次查看节点状态发现没问题了
[root@host0-21 ~]# kubectl get nodes
NAME                STATUS   ROLES    AGE     VERSION
host0-12.host.com   Ready    <none>   3m13s   v1.15.2
host0-22.host.com   Ready    <none>   3m13s   v1.15.2
并且查看日志出现以下即为正常
E0330 17:08:56.488963    7630 kubelet.go:2248] node "host0-12.host.com" not found
E0330 17:08:56.589211    7630 kubelet.go:2248] node "host0-12.host.com" not found
E0330 17:08:56.689574    7630 kubelet.go:2248] node "host0-12.host.com" not found
I0330 17:08:56.689642    7630 reconciler.go:150] Reconciler: start to sync state   开始同步状态
E0330 17:08:56.790426    7630 kubelet.go:2248] node "host0-12.host.com" not found
I0330 17:08:56.833472    7630 kubelet_node_status.go:286] Setting node annotation to enable volume controller attach/detach

```



#### 4.1.6. 修改节点角色

使用 kubectl get nodes 获取的Node节点角色为空，可以按照以下方式修改（只是修改label标签）

只需修改host0-11即可，host0-12会自动同步

```sh
[root@host0-21 ~]# kubectl get node
NAME                STATUS   ROLES    AGE     VERSION
host0-12.host.com   Ready    <none>   3m13s   v1.15.2
host0-22.host.com   Ready    <none>   3m13s   v1.15.2

[root@host0-21 ~]# kubectl label node host0-21.host.com node-role.kubernetes.io/node=  #到=符号为止，下面的是输出信息
node/host0-12.host.com labeled

[root@host0-21 ~]# kubectl label node host0-21.host.com node-role.kubernetes.io/master=
node/host0-12.host.com labeled

[root@host0-22 ~]# kubectl label node host0-22.host.com node-role.kubernetes.io/master=
node/host0-22.host.com labeled

[root@host0-22 ~]# kubectl label node host0-22.host.com node-role.kubernetes.io/node=
node/host0-22.host.com labeled

[root@host0-21 ~]# kubectl get node
NAME                STATUS   ROLES         AGE     VERSION
host0-12.host.com   Ready    master,node   7m44s   v1.15.2
host0-22.host.com   Ready    master,node   7m44s   v1.15.2
```

### 4.2. KUBE-PROXY部署

**kube-proxy是用来连接pod网络和集群网络的，并不是像open stack中的neutron一样来给虚拟机提供网络的。**

#### 4.2.1. 签发证书

证书签发在 host0-200 操作

```sh
[root@host0-200 ~]# cd /opt/certs/

[root@host0-200 certs]# vim kube-proxy-csr.json  # CN 其实是k8s中的角色
{
    "CN": "system:kube-proxy",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "beijing",
            "L": "beijing",
            "O": "od",
            "OU": "ops"
        }
    ]
}
[root@host0-200 certs]# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=client kube-proxy-csr.json |cfssl-json -bare kube-proxy-client
2020/01/07 21:45:53 [INFO] generate received request
2020/01/07 21:45:53 [INFO] received CSR
2020/01/07 21:45:53 [INFO] generating key: rsa-2048
2020/01/07 21:45:53 [INFO] encoded CSR
2020/01/07 21:45:53 [INFO] signed certificate with serial number 620191685968917036075463174423999296907693104226
2020/01/07 21:45:53 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);

# 因为kube-proxy使用的用户是kube-proxy，不能使用client证书，必须要重新签发自己的证书
[root@host0-200 certs]# ls kube-proxy-c* -l 
-rw-r--r-- 1 root root 1005 Jan  7 21:45 kube-proxy-client.csr
-rw------- 1 root root 1675 Jan  7 21:45 kube-proxy-client-key.pem
-rw-r--r-- 1 root root 1375 Jan  7 21:45 kube-proxy-client.pem
-rw-r--r-- 1 root root  267 Jan  7 21:45 kube-proxy-csr.json

[root@host0-200 certs]# scp kube-proxy-client-key.pem kube-proxy-client.pem host0-21:/opt/apps/kubernetes/server/bin/certs/
[root@host0-200 certs]# scp kube-proxy-client-key.pem kube-proxy-client.pem host0-22:/opt/apps/kubernetes/server/bin/certs/
```

#### 4.2.2. 创建KUBE-PROXY配置

在所有node节点创建，涉及服务器：host0-21 ，host0-22

以下步骤和上面的4.1.2创建kubelet配置意思一样

```sh
[root@host0-21 ~]# kubectl config set-cluster myk8s \
--certificate-authority=/opt/apps/kubernetes/server/bin/certs/ca.pem \
--embed-certs=true \
--server=https://10.0.0.10:7443 \
--kubeconfig=/opt/apps/kubernetes/conf/kube-proxy.kubeconfig
  
[root@host0-21 ~]# kubectl config set-credentials kube-proxy \
--client-certificate=/opt/apps/kubernetes/server/bin/certs/kube-proxy-client.pem \
--client-key=/opt/apps/kubernetes/server/bin/certs/kube-proxy-client-key.pem \
--embed-certs=true \
--kubeconfig=/opt/apps/kubernetes/conf/kube-proxy.kubeconfig
  
[root@host0-21 ~]# kubectl config set-context myk8s-context \
--cluster=myk8s \
--user=kube-proxy \
--kubeconfig=/opt/apps/kubernetes/conf/kube-proxy.kubeconfig
  
[root@host0-21 ~]# kubectl config use-context myk8s-context --kubeconfig=/opt/apps/kubernetes/conf/kube-proxy.kubeconfig
```

#### 4.2.3. 加载IPVS模块

设计主机host0-21、host0-22

kube-proxy 共有3种流量调度模式，分别是 namespace，iptables，ipvs，其中ipvs性能最好。

关于ipvs的调度算法：https://www.jianshu.com/p/619c23fb1a14

> - 轮询调度（Round-Robin Scheduling）
>
> - 加轮询度（Weighted Round-Robin Scheduling）
>
> - 最小连接调度（Least-Connection Scheduling）
>
> - 加权最小连接调度（Weighted Least-Connection Scheduling）
>
> - 基于局部性的最少链接（Locality-Based Least Connections Scheduling）
>
> - 带复制的基于局部性最少链接（Locality-Based Least Connections with Replication Scheduling）
>
> - 目标地址散列调度（Destination Hashing Scheduling）
>
> - 源地址散列调度（Source Hashing Scheduling）
>
> - 最短预期延时调度（Shortest Expected Delay Scheduling）
>
> - 不排队调度（Never Queue Scheduling）

```sh
[root@host0-21 ~]# for i in $(ls /usr/lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*");do echo $i; /sbin/modinfo -F filename $i >/dev/null 2>&1 && /sbin/modprobe $i;done

# 查看模块
[root@host0-21 ~]# lsmod | grep ip_vs 
```

#### 4.2.4. 创建启动脚本

涉及主机：host0-21、host0-22

```sh
[root@host0-21 ~]# vim /opt/apps/kubernetes/server/bin/kube-proxy-startup.sh
#!/bin/sh

WORK_DIR=$(dirname $(readlink -f $0))
[ $? -eq 0 ] && cd $WORK_DIR || exit

/opt/apps/kubernetes/server/bin/kube-proxy \
  --cluster-cidr 172.7.0.0/16 \
  --hostname-override host0-21.host.com \ #在host0-22记得也要更换
  --proxy-mode=ipvs \   #指定为ipvs模块，如果不用可以缓存iptables，下面的nq切换为rr
  --ipvs-scheduler=nq \  #指定调度算法为nq
  --kubeconfig ../../conf/kube-proxy.kubeconfig

如果host0-22节点忘记修改“--hostname-override host0-12.host.com ”，则在host0-12修改脚本启动服务，然后查看脚本得日志文件，日志中提示有个端口被占用了,netstatus -lntp |grep 端口号，kill -9 结束进程，然后在重启脚本服务

[root@host0-21 ~]# chmod u+x /opt/apps/kubernetes/server/bin/kube-proxy-startup.sh

[root@host0-21 ~]# vim /etc/supervisord.d/kube-proxy.ini
[program:kube-proxy-host0-21]
command=/opt/apps/kubernetes/server/bin/kube-proxy-startup.sh
numprocs=1
directory=/opt/apps/kubernetes/server/bin
autostart=true
autorestart=true
startsecs=30
startretries=3
exitcodes=0,2
stopsignal=QUIT
stopwaitsecs=10
user=root
redirect_stderr=true
stdout_logfile=/data/logs/kubernetes/kube-proxy/proxy.stdout.log
stdout_logfile_maxbytes=64MB
stdout_logfile_backups=5
stdout_capture_maxbytes=1MB
stdout_events_enabled=false

[root@host0-21 ~]# mkdir -pv /data/logs/kubernetes/kube-proxy

[root@host0-21 ~]# supervisorctl update
```

#### 4.2.5. 验证集群

涉及主机：host0-21、host0-22

```sh
[root@host0-21 ~]# supervisorctl status
etcd-server-host0-21               RUNNING   pid 16997, uptime 2:02:34
kube-apiserver-host0-21            RUNNING   pid 87085, uptime 0:48:19
kube-controller-manager-host0-21   RUNNING   pid 86827, uptime 1:10:14
kube-kubelet-host0-21              RUNNING   pid 87285, uptime 0:18:43
kube-proxy-host0-21                RUNNING   pid 90900, uptime 0:01:51
kube-scheduler-host0-21            RUNNING   pid 87062, uptime 0:49:00

[root@host0-21 ~]# yum install -y ipvsadm
[root@host0-21 ~]# ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.0.1:443 nq   #发现集群网络为nq调度的算法
  -> 10.0.0.21:6443               Masq    1      0          0         
  -> 10.0.0.22:6443               Masq    1      0          0  

测试创建pod资源配置清单：只在host0-21配置就行，host0-22会同步，如果域名不可达，请输入仓库IP+端口
其实这pod并不是跑在master上，而是跑在node上面，只是master和node为同一主机

[root@host0-21 ~]# vim /yaml/nginx-ds.yaml
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: nginx-ds
spec:
  template:
    metadata:
      labels:
        app: nginx-ds
    spec:
      containers:
      - name: my-nginx
        image: harbor.od.com/public/nginx:latest
        ports:
        - containerPort: 80

[root@host0-21 ~]# kubectl create -f /yaml/nginx-ds.yaml
[root@host0-21 ~]# kubectl get pods
NAME             READY   STATUS    RESTARTS   AGE
nginx-ds-dwkvw   1/1     Running   0          82s
nginx-ds-rn5x4   1/1     Running   0          82s

[root@host0-21 ~]# kubectl get pods -o wide
NAME             READY   STATUS    RESTARTS   AGE     IP           NODE               NOMINATED NODE   READINESS GATES
nginx-ds-drhp8   1/1     Running   0          2m47s   172.7.22.2   host0-22.host.com   <none>           <none>
nginx-ds-xl9gh   1/1     Running   0          2m47s   172.7.22.2   host0-12.host.com   <none>           <none>

[root@host0-21 ~]# curl -I 172.7.22.2
HTTP/1.1 200 OK
Server: nginx/1.17.6
Date: Tue, 07 Jan 2020 14:28:46 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 19 Nov 2019 12:50:08 GMT
Connection: keep-alive
ETag: "5dd3e500-264"
Accept-Ranges: bytes

[root@host0-21 ~]# curl -I 172.7.22.2  # 缺少网络插件，无法跨节点通信

pod起不来有多种原因，有可能时harbor.od.com，这个仓库没起来，或者这个仓库中的镜像有问题从而导致pod起不来，查看pod的日志可以协助与排除问题

[root@host0-21 ~]# kubectl describe pod nginx-ds-6xdxz
Name:           nginx-ds-6xdxz
Namespace:      default
Priority:       0
Node:           host0-12.host.com/10.0.0.21
Start Time:     Wed, 30 Sep 2020 15:31:47 +0800
Labels:         app=nginx-ds
                controller-revision-hash=69bb4744d9
                pod-template-generation=1
Annotations:    <none>
Status:         Running
IP:             172.7.22.2
Controlled By:  DaemonSet/nginx-ds
Containers:
  my-nginx:
    Container ID:   docker://bbba82e2da9d6a31d1ac94ef431a49f4421a147b2c673cf55bfb3e21b213b143
    Image:          harbor.od.com/public/nginx:latest
    Image ID:       docker-pullable://harbor.od.com/public/nginx@sha256:794275d96b4ab96eeb954728a7bf11156570e8372ecd5ed0cbc7280313a27d19
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Sun, 04 Oct 2020 14:09:11 +0800
    Last State:     Terminated
      Reason:       Error
      Exit Code:    255
      Started:      Wed, 30 Sep 2020 15:36:23 +0800
      Finished:     Sun, 04 Oct 2020 13:51:36 +0800
    Ready:          True
    Restart Count:  1
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-cj45k (ro)
Conditions:
  Type              Status
  Initialized       True 
  Ready             True 
  ContainersReady   True 
  PodScheduled      True 
Volumes:
  default-token-cj45k:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-cj45k
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     node.kubernetes.io/disk-pressure:NoSchedule
                 node.kubernetes.io/memory-pressure:NoSchedule
                 node.kubernetes.io/not-ready:NoExecute
                 node.kubernetes.io/pid-pressure:NoSchedule
                 node.kubernetes.io/unreachable:NoExecute
                 node.kubernetes.io/unschedulable:NoSchedule
Events:
  Type     Reason                  Age                    From                       Message
  ----     ------                  ----                   ----                       -------
  Normal   Scheduled               3d22h                  default-scheduler          Successfully assigned default/nginx-ds-6xdxz to host0-12.host.com
  Warning  FailedCreatePodSandBox  3d22h (x6 over 3d22h)  kubelet, host0-12.host.com  Failed create pod sandbox: rpc error: code = Unknown desc = failed pulling image "10.0.0.200:180/public/pause:latest": Error response from daemon: Get https://10.0.0.200:180/v2/: http: server gave HTTP response to HTTPS client
  Warning  FailedMount             3d22h (x5 over 3d22h)  kubelet, host0-12.host.com  MountVolume.SetUp failed for volume "default-token-cj45k" : couldn't propagate object cache: timed out waiting for the condition
  Warning  FailedCreatePodSandBox  3d22h (x2 over 3d22h)  kubelet, host0-12.host.com  Failed create pod sandbox: rpc error: code = Unknown desc = failed pulling image "harbor.od.com/public/pause:latest": Error response from daemon: manifest for harbor.od.com/public/pause:latest not found: manifest unknown: manifest unknown
  Normal   Pulling                 3d22h                  kubelet, host0-12.host.com  Pulling image "harbor.od.com/public/nginx:latest"
  Normal   Pulled                  3d22h                  kubelet, host0-12.host.com  Successfully pulled image "harbor.od.com/public/nginx:latest"
  Normal   Created                 3d22h                  kubelet, host0-12.host.com  Created container my-nginx
  Normal   Started                 3d22h                  kubelet, host0-12.host.com  Started container my-nginx
  Normal   SandboxChanged          18m                    kubelet, host0-12.host.com  Pod sandbox changed, it will be killed and re-created.
  Warning  Failed                  16m (x4 over 18m)      kubelet, host0-12.host.com  Error: ErrImagePull
  Warning  Failed                  16m (x4 over 18m)      kubelet, host0-12.host.com  Failed to pull image "harbor.od.com/public/nginx:latest": rpc error: code = Unknown desc = Error response from daemon: received unexpected HTTP status: 502 Bad Gateway
  Warning  BackOff                 15m (x8 over 18m)      kubelet, host0-12.host.com  Back-off restarting failed container
  Normal   Pulling                 13m (x5 over 18m)      kubelet, host0-12.host.com  Pulling image "harbor.od.com/public/nginx:latest"
  Normal   BackOff                 8m28s (x25 over 18m)   kubelet, host0-12.host.com  Back-off pulling image "harbor.od.com/public/nginx:latest"
  Warning  Failed                  3m34s (x47 over 18m)   kubelet, host0-12.host.com  Error: ImagePullBackOff
  Normal   SandboxChanged          69s                    kubelet, host0-12.host.com  Pod sandbox changed, it will be killed and re-created.
  Normal   Pulling                 68s                    kubelet, host0-12.host.com  Pulling image "harbor.od.com/public/nginx:latest"
  Normal   Pulled                  68s                    kubelet, host0-12.host.com  Successfully pulled image "harbor.od.com/public/nginx:latest"
  Normal   Created                 68s                    kubelet, host0-12.host.com  Created container my-nginx
  Normal   Started                 68s                    kubelet, host0-12.host.com  Started container my-nginx
```

## 5. 核心插件部署

### 5.1. CNI网络插件

kubernetes设计了网络模型，但是pod之间通信的具体实现交给了CNI往插件。常用的CNI网络插件有：Flannel 、Calico、Canal、Contiv等，其中Flannel和Calico占比接近80%，Flannel占比略多于Calico。本次部署使用Flannel作为网络插件。涉及的机器 host0-11,host0-12

#### 5.1.1. 安装FLANNEL

github地址：https://github.com/coreos/flannel/releases

涉及的机器 host0-21,host0-22

```sh
[root@host0-21 ~]# cd /opt/src/
[root@host0-21 src]# wget https://github.com/coreos/flannel/releases/download/v0.11.0/flannel-v0.11.0-linux-amd64.tar.gz

# 因为flannel压缩包内部没有套目录,所以创建
[root@host0-21 src]# mkdir -pv /opt/release/flannel-v0.11.0
[root@host0-21 src]# tar -xf flannel-v0.11.0-linux-amd64.tar.gz -C /opt/release/flannel-v0.11.0
[root@host0-21 src]# ln -s /opt/release/flannel-v0.11.0 /opt/apps/flannel && ll /opt/apps/flannel
lrwxrwxrwx 1 root root 28 Jan  9 22:33 /opt/apps/flannel -> /opt/release/flannel-v0.11.0
[root@host0-21 src]# mkdir -pv /opt/apps/flannel/certs
```

#### 5.1.2. 拷贝证书

```sh
# flannel 需要以客户端的身份访问etcd，需要相关证书，flannel作为etcd的客户端
[root@host0-200 ~]# cd /opt/certs/
[root@host0-200 certs]# scp ca.pem client-key.pem client.pem host0-21:/opt/apps/flannel/certs/
[root@host0-200 certs]# scp ca.pem client-key.pem client.pem host0-22:/opt/apps/flannel/certs/
```

#### 5.1.3. 创建启动脚本

涉及的机器 host0-21,host0-22

```sh
[root@host0-21 src]# vim /opt/apps/flannel/subnet.env
FLANNEL_NETWORK=172.7.0.0/16
FLANNEL_SUBNET=172.7.21.1/24   #注意host0-22节点修改为172.17.22.1
FLANNEL_MTU=1500
FLANNEL_IPMASQ=false
[root@host0-21 src]# chmod u+x /opt/apps/flannel/subnet.env

# 需要在etcd机器上执行（随机一台即可），此操作为修改flannel的网络模型为host-gw
[root@host0-21 src]# /opt/apps/etcd/etcdctl set /coreos.com/network/config '{"Network": "172.7.0.0/16", "Backend": {"Type": "host-gw"}}'
{"Network": "172.7.0.0/16", "Backend": {"Type": "host-gw"}}
# 查看
[root@host0-21 src]# /opt/apps/etcd/etcdctl get /coreos.com/network/config
{"Network": "172.7.0.0/16", "Backend": {"Type": "host-gw"}}
 
[root@host0-21 src]# vim /opt/apps/flannel/flannel-startup.sh
#!/bin/sh

WORK_DIR=$(dirname $(readlink -f $0))
[ $? -eq 0 ] && cd $WORK_DIR || exit

/opt/apps/flannel/flanneld \
    --public-ip=10.0.0.21 \  #注意地址
    --etcd-endpoints=https://10.0.0.200:2379,https://10.0.0.21:2379,https://10.0.0.22:2379 \
    --etcd-keyfile=./certs/client-key.pem \
    --etcd-certfile=./certs/client.pem \
    --etcd-cafile=./certs/ca.pem \
    --iface=ens33 \
    --subnet-file=./subnet.env \
    --healthz-port=2401

[root@host0-21 src]# chmod u+x /opt/apps/flannel/flannel-startup.sh

[root@host0-21 src]# vim /etc/supervisord.d/flannel.ini
[program:flanneld-host0-21]
command=/opt/apps/flannel/flannel-startup.sh                 ; the program (relative uses PATH, can take args)
numprocs=1                                                   ; number of processes copies to start (def 1)
directory=/opt/apps/flannel                                  ; directory to cwd to before exec (def no cwd)
autostart=true                                               ; start at supervisord start (default: true)
autorestart=true                                             ; retstart at unexpected quit (default: true)
startsecs=30                                                 ; number of secs prog must stay running (def. 1)
startretries=3                                               ; max # of serial start failures (default 3)
exitcodes=0,2                                                ; 'expected' exit codes for process (default 0,2)
stopsignal=QUIT                                              ; signal used to kill process (default TERM)
stopwaitsecs=10                                              ; max num secs to wait b4 SIGKILL (default 10)
user=root                                                    ; setuid to this UNIX account to run the program
redirect_stderr=true                                         ; redirect proc stderr to stdout (default false)
stdout_logfile=/data/logs/flanneld/flanneld.stdout.log       ; stderr log path, NONE for none; default AUTO
stdout_logfile_maxbytes=64MB                                 ; max # logfile bytes b4 rotation (default 50MB)
stdout_logfile_backups=5                                     ; # of stdout logfile backups (default 10)
stdout_capture_maxbytes=1MB                                  ; number of bytes in 'capturemode' (default 0)
stdout_events_enabled=false                                  ; emit events on stdout writes (default false)

[root@host0-21 src]# mkdir -pv /data/logs/flanneld
[root@host0-21 src]# supervisorctl update
```

#### 5.1.4. 验证跨网络访问

涉及主机：host0-21、host0-22

```sh
[root@host0-21 src]# kubectl get pods -o wide
NAME             READY   STATUS    RESTARTS   AGE   IP           NODE                NOMINATED NODE   READINESS GATES
nginx-ds-7db29   1/1     Running   0          2d    172.7.22.2   host0-22.host.com   <none>           <none>
nginx-ds-vvsz7   1/1     Running   0          2d    172.7.21.2   host0-12.host.com   <none>           <none>

# 其实flannel就是提供了路由服务
[root@host0-21 flannel-v0.11.0]# route -n
Kernel IP routing table
Destination Gateway Genmask Flags Metric Ref Use Iface
0.0.0.0 10.0.0.254 0.0.0.0 UG 100 0 0 eth0
10.0.0.0 0.0.0.0 255.255.255.0 U 100 0 0 eth0
172.7.21.0 0.0.0.0 255.255.255.0 U 0 0 0 docker0
172.7.22.0 10.0.0.22 255.255.255.0 UG 0 0 0 eth0

[root@host0-21 src]# curl -I 172.7.22.2
HTTP/1.1 200 OK
Server: nginx/1.17.6
Date: Thu, 09 Jan 2020 14:55:21 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 19 Nov 2019 12:50:08 GMT
Connection: keep-alive
ETag: "5dd3e500-264"
Accept-Ranges: bytes
```

#### 5.1.5. 解决POD间IP透传问题

涉及主机：host0-21、host0-22

所有Node上操作，即优化NAT网络

```sh
# 现问题是，不通网段宿主机之间的pod，互相访问，日志中显示的IP地址是物理机

[root@host0-21 flannel-v0.11.0]# kubectl get pods -o wide
NAME           READY   STATUS     RESTARTS   AGE   IP          NODE     NOMINATED  NODE  READINESS GATES
nginx-ds-drhp8 1/1     Running    0          26m   172.7.22.2  host0-22.host.com
nginx-ds-xl9gh 1/1     Running    0          26m   172.7.22.2  host0-12.host.com

# 进入172.7.22.2地址中pod
[root@host0-21 ~]# kubectl exec -it nginx-ds-drhp8 /bin/bash
root@nginx-ds-rn5x4:/# curl 172.7.22.2   #访问172.7.22.2的pod

# 查看172.7.22.2pod的日志
[root@host0-12 certs]# kubectl logs -f nginx-ds-xl9gh
10.0.0.21 - - [30/Sep/2020:04:28:11 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.64.0" "-"
10.0.0.21 - - [30/Sep/2020:04:28:12 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.64.0" "-"
10.0.0.21 - - [30/Sep/2020:04:28:14 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.64.0" "-"

这是由于iptables的snat转发导致的，因为我pod访问其他node节点主机上的pod的时候要经过宿主的的iptables的postrouting这个表，然后对这个数据做snat转发，把它转发到其他node节点上的主机上进行互相访问pod。也就是如下规则：
iptables-save |grep POSTROUTING|grep docker0 
-A POSTROUTING -s 172.7.22.0/24 ! -o docker0 -j MASQUERADE
解释该规则：来源地址是172.7.22.0/24，他不是从docker0这个网络设备出网的，我们给他做MASQUERADE（源地址nat转换），伪装为宿主机IP出网。
我们现在需要的是出网的地址172.7.22.0/24不要做源地址nat转换。
 
# 引发问题的规则
[root@host0-21 ~]# iptables-save |grep POSTROUTING|grep docker0
-A POSTROUTING -s 172.7.21.0/24 ! -o docker0 -j MASQUERADE

[root@host0-22 ~]# iptables-save |grep POSTROUTING|grep docker0
-A POSTROUTING -s 172.7.22.0/24 ! -o docker0 -j MASQUERADE

# 处理方式：

[root@host0-21 ~]# yum install -y iptables-services

[root@host0-22 ~]# yum install -y iptables-services

[root@host0-21 ~]# systemctl start iptables.service && systemctl enable iptables.service

[root@host0-22 ~]# systemctl start iptables.service && systemctl enable iptables.service

# 先删除旧的策略

[root@host0-21 ~]# iptables -t nat -D POSTROUTING -s 172.7.21.0/24 ! -o docker0 -j MASQUERADE

[root@host0-22 ~]# iptables -t nat -D POSTROUTING -s 172.7.22.0/24 ! -o docker0 -j MASQUERADE

# 以下规则解释：
我源地址（172.7.22.0/24），不是从172.7.0.0/16地址出去的，也不是从docker0这个网络设备出去的才做MASQUERADE（源地址转换）
意思就是我出网就必须要经过该地址和docker0网卡，所以不要做源地址转换

[root@host0-21 ~]# iptables -t nat -I POSTROUTING -s 172.7.21.0/24 ! -d 172.7.0.0/16 ! -o docker0 -j MASQUERADE

[root@host0-22 ~]# iptables -t nat -I POSTROUTING -s 172.7.22.0/24 ! -d 172.7.0.0/16 ! -o docker0 -j MASQUERADE

[root@host0-21 ~]# iptables -t filter -D INPUT -j REJECT --reject-with icmp-host-prohibited

[root@host0-21 ~]# iptables -t filter -D FORWARD -j REJECT --reject-with icmp-host-prohibited

[root@host0-22 ~]# iptables -t filter -D INPUT -j REJECT --reject-with icmp-host-prohibited

[root@host0-22 ~]# iptables -t filter -D FORWARD -j REJECT --reject-with icmp-host-prohibited

[root@host0-22 ~]# iptables-save > /etc/sysconfig/iptables && service iptables save

[root@host0-22 ~]# iptables-save > /etc/sysconfig/iptables && service iptables save

# 此时从host0-11跨宿主机访问pod时，显示pod的IP
# 进入172.7.22.2地址中pod
[root@host0-21 ~]# kubectl exec -it nginx-ds-drhp8 /bin/bash
root@nginx-ds-rn5x4:/# curl 172.7.22.2 #访问172.7.22.2的pod
# 如果进不去就把host0-11和host0-12的 iptable给关掉，可能服务有问题，总之查看日志，pods服务处于同一个网段下就ok
# 查看172.7.22.2pod的日志
[root@host0-12 certs]# kubectl logs -f nginx-ds-drhp8
172.7.22.2 - - [30/Sep/2020:04:50:27 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.64.0" "-"
172.7.22.2 - - [30/Sep/2020:04:50:28 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.64.0" "-"
172.7.22.2 - - [30/Sep/2020:04:50:28 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.64.0" "-"
172.7.22.2 - - [30/Sep/2020:04:51:46 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.64.0" "-"
172.7.22.2 - - [30/Sep/2020:04:51:48 +0000] "GET / HTTP/1.1" 200 612 "-" "curl/7.64.0" "-"

此时显示的同一个网段的地址

**强调：如果k8s集群环境比较小完全可以自己手动添加node节点之间的静态路由来解决pod之间的网络连接**

**命令：**

​```sh
[root@host0-21 ~]# route add -net 172.7.22.0/24 gw 10.0.0.22 dev ens33
[root@host0-21 ~]# iptables -t filter -I FORWARD -d 172.7.22.0/24 -j ACCEPT
[root@host0-22 ~]# route add -net 172.7.21.0/24 gw 10.0.0.21 dev ens33
[root@host0-22 ~]# iptables -t filter -I FORWARD -d 172.7.21.0/24 -j ACCEPT
```

**然后再同上优化一下POSTROUTING规则**

### 5.2. COREDNS

- 简单来说，服务发现就是服务（应用）之间相互定位的过程
- 服务发现并非云计算时代独有的，传统的单体架构时代也会用到，以下场景中更需要服务发现
  - 服务的动态性强
  - 服务更新发布频繁
  - 服务支持自动伸缩
- 在k8s集群里，pod的ip是不停的变化的，如何以不变应万变呢？
  - 抽象出了server资源，通过标签选择器关联一组pod
  - 抽象出了集群网络，通过相对固定的集群IP，使服务接入点固定
- 那么如何自动关联server资源的名称和集群网络ip，从而达到服务被集群自动发现的目的呢？
  - 考虑到传统的DNS的模型：dns.host.com 👉10.0.0.200，就是主机名解析DNS服务器（bind软件）
  - 能否考虑到k8s里建立这样的模型：nginx-ds 👉192.168.0.5，就是集群IP与服务的名字互相关联解析起来

CoreDNS用于实现 service –> cluster IP 的DNS解析。以容器的方式交付到k8s集群，由k8s自行管理，降低人为操作的复杂度。

https://github.com/coredns/coredns/releases

#### 5.2.1. 配置YAML文件库

在host0-200中配置yaml文件库，后期通过Http方式去使用yaml清单文件。

- 配置nginx虚拟主机

```sh
[root@host0-200 ~]# vim /etc/nginx/conf.d/k8s-yaml.od.com.conf
server {
    listen       80;
    server_name  k8s-yaml.od.com;

    location / {
        autoindex on;
        default_type text/plain;
        root /data/k8s-yaml;
    }
}

[root@host0-200 ~]# mkdir -pv /data/k8s-yaml
[root@host0-200 ~]# systemctl restart nginx
```

- 配置dns解析(dns)

```sh
[root@host0-200~]# vim /var/named/od.com.zone
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020092803 ; serial
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
[root@host0-200~]# systemctl restart named
[root@host0-200~]# dig -t A k8s-yaml.od.com @10.0.0.200 +short
10.0.0.200
[root@host0-200 certs]# cd /data/k8s-yaml/
[root@host0-200 k8s-yaml]# ls
[root@host0-200 k8s-yaml]# mkdir -pv /data/k8s-yaml/coredns
```

![img](/images/posts/Linux-Kubernetes/二进制部署/9.png)

#### 5.2.2. COREDNS的资源清单文件

```sh
[root@host0-200 k8s-yaml]# mkdir -pv /data/k8s-yaml/coredns/coredns_1.6.1 && cd /data/k8s-yaml/coredns/coredns_1.6.1
```

- vim rbac.yaml

```sh
apiVersion: v1
kind: ServiceAccount
metadata:
  name: coredns
  namespace: kube-system
  labels:
      kubernetes.io/cluster-service: "true"
      addonmanager.kubernetes.io/mode: Reconcile
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
    addonmanager.kubernetes.io/mode: Reconcile
  name: system:coredns
rules:
- apiGroups:
  - ""
  resources:
  - endpoints
  - services
  - pods
  - namespaces
  verbs:
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
    addonmanager.kubernetes.io/mode: EnsureExists
  name: system:coredns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:coredns
subjects:
- kind: ServiceAccount
  name: coredns
  namespace: kube-system
```

- vim configmap.yaml

```sh
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        log
        health
        ready
        kubernetes cluster.local 192.168.0.0/16
        forward . 10.0.0.200
        cache 30
        loop
        reload
        loadbalance
    }
```

- vim deployment.yaml

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: coredns
    kubernetes.io/name: "CoreDNS"
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: coredns
  template:
    metadata:
      labels:
        k8s-app: coredns
    spec:
      priorityClassName: system-cluster-critical
      serviceAccountName: coredns
      containers:
      - name: coredns
        image: harbor.od.com/public/coredns:v1.6.1
        args:
        - -conf
        - /etc/coredns/Corefile
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
      dnsPolicy: Default
      volumes:
        - name: config-volume
          configMap:
            name: coredns
            items:
            - key: Corefile
              path: Corefile
```

- vim service.yaml

```sh
apiVersion: v1
kind: Service
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: coredns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "CoreDNS"
spec:
  selector:
    k8s-app: coredns
  clusterIP: 192.168.0.2
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
  - name: metrics
    port: 9153
    protocol: TCP
```

#### 5.2.3. 交付COREDNS到K8S

```sh
# 准备镜像,如果仓库用的IP，就把域名换成IP
# 如果pull失败，则在试一次，再不行就换成别的镜像网站
[root@host0-200 ~]# docker pull docker.io/coredns/coredns:1.6.1
[root@host0-200 ~]# docker tag coredns/coredns:1.6.1 harbor.od.com/public/coredns:v1.6.1
[root@host0-200 ~]# docker push harbor.od.com/public/coredns:v1.6.1
# 交付coredns,在host0-21执行即可，因为就是以声明式的方式启动了个pod
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/coredns/coredns_1.6.1/rbac.yaml
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/coredns/coredns_1.6.1/configmap.yaml
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/coredns/coredns_1.6.1/deployment.yaml
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/coredns/coredns_1.6.1/service.yaml
[root@host0-21 ~]# kubectl get all -n kube-system -o wide
NAME                           READY   STATUS    RESTARTS   AGE   IP           NODE                NOMINATED NODE   READINESS GATES
pod/coredns-6b6c4f9648-4vtcl   1/1     Running   0          38s   172.7.21.3   host0-12.host.com   <none>           <none>

NAME              TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)                  AGE   SELECTOR
service/coredns   ClusterIP   192.168.0.2   <none>        53/UDP,53/TCP,9153/TCP   29s   k8s-app=coredns

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                                SELECTOR
deployment.apps/coredns   1/1     1            1           39s   coredns      harbor.od.com/public/coredns:v1.6.1   k8s-app=coredns

NAME                                 DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES                                SELECTOR
replicaset.apps/coredns-6b6c4f9648   1         1         1       39s   coredns      harbor.od.com/public/coredns:v1.6.1   k8s-app=coredns,pod-template-hash=6b6c4f9648
```

#### 5.2.4. 测试DNS

```sh
# 创建deployment类新的pod资源
[root@host0-21 ~]# kubectl create deployment nginx-dp --image=harbor.od.com/public/nginx:latest -n kube-public
deployment.apps/nginx-dp created
[root@host0-21 ~]# kubectl get pods -n kube-public
NAME                        READY   STATUS              RESTARTS   AGE
nginx-dp-79d757b7fb-frd6p   0/1     ContainerCreating   0          15s
[root@host0-21 ~]# kubectl get deployment -n kube-public
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
nginx-dp   1/1     1            1           37s

# 将deployment加入service
[root@host0-21 ~]# kubectl expose deployment nginx-dp --port=80 -n kube-public
service/nginx-dp exposed
[root@host0-21 ~]# kubectl get svc -n kube-public
NAME       TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
nginx-dp   ClusterIP   192.168.49.209   <none>        80/TCP    7s

# 测试COREDNS，集群外必须使用FQDN(Fully Qualified Domain Name)，全域名
[root@host0-21 ~]# dig -t A nginx-dp.kube-public.svc.cluster.local @192.168.0.2 +short
192.168.49.209
# 以上出现这就说明coredns（192.168.0.2）起到作用了，我可以直接通过服务（deployment）的名字（nginx-web）解析到公网地址，从而实现服务暴露
# 如果解析不到，请查看dns主机的/etc/resolv.conf文件中是否还有search host.com
```

#### 第二种测试coredns

```sh
# 查看刚才创建deployment在哪台宿主机上（在host0-22）
[root@host0-21 ~]# kubectl get pods -n kube-public -o wide
NAME                        READY   STATUS    RESTARTS   AGE   IP           NODE                NOMINATED NODE   READINESS GATES
nginx-dp-79d757b7fb-frd6p   1/1     Running   0          13m   172.7.22.3   host0-22.host.com   <none>           <none>
[root@host0-21 ~]# kubectl get pods -o wide
NAME             READY   STATUS    RESTARTS   AGE    IP           NODE                NOMINATED NODE   READINESS GATES
nginx-ds-5plnl   1/1     Running   0          129m   172.7.22.2   host0-22.host.com   <none>           <none>
nginx-ds-6lr65   1/1     Running   0          129m   172.7.22.2   host0-12.host.com   <none>           <none>

# 进入宿主机（host0-21）pod中访问它的集群ip和集群服务的名称（nginx-dp）
[root@host0-21 ~]# kubectl exec -it nginx-ds-6lr65 /bin/bash
root@nginx-ds-6lr65:/# curl 192.168.49.209
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

# 测试访问service集群名称
root@nginx-ds-6lr65:/# curl nginx-dp.kube-public
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

为什么能够访问短域名（nginx-dp.kube-public）就能访问到呢,因为如下
root@nginx-ds-6lr65:/# cat /etc/resolv.conf 
nameserver 192.168.0.2
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
因为这个里面有个search的域环境，所以能用短域名进行访问，也就是说之前在10.0.0.200这台主机上配置的DNS中设置了
[root@host0-200 ~]# cat /etc/resolv.conf
# Generated by NetworkManager
search host.com
nameserver 10.0.0.200
而且这个中还有默认的default.svc.cluster.local svc.cluster.local这两个域
root@nginx-ds-6lr65:/# cat /etc/resolv.conf 
nameserver 192.168.0.2
search default.svc.cluster.local svc.cluster.local cluster.local
options ndots:5
```



### 5.3. INGRESS-CONTROLLER

- k8s的DNS实现了服务在集群内被自动发现，并且可以访问外网，那如何使得服务在k8s集群外被使用和访问呢？
  - 使用NodePort型的Service
    - 注意：无法使用kube-proxy的ipvs模型，只能使用iptables模型
  - 使用ingress资源
    - 注意：ingress只能调度并暴露7层应用，特指http和https协议服务
- ingress是k8s API的标准资源类型之一，也是一种核心资源，他其实就是一组基于域名和URL路径，把大量的请求转发甚至指定的Service资源的规则
- 可以将集群外部的请求流量转发至集群内，从而实现服务暴露
- ingress控制器是能够为ingress资源监听某套接字，然后根据ingress规则匹配机制调度流量的一个组件
- 说白了就是，ingress没啥神秘的，就是简化版nginx+一段go脚本而已，虽然我不懂
- ingress-controller 是一个代理服务器，将ingress的规则能真正实现的方式，常用的有
  - ingress-nginx
  - HAProxy
  - Traefik
  - .....

> service是将一组pod管理起来，提供了一个cluster ip和service name的统一访问入口，屏蔽了pod的ip变化。 ingress 是一种基于七层的流量转发策略，即将符合条件的域名或者location流量转发到特定的service上，而ingress仅仅是一种规则，k8s内部并没有自带代理程序完成这种规则转发。但是在k8s集群中，建议使用traefik，性能比haroxy强大，更新配置不需要重载服务，是首选的ingress-controller。github地址：https://github.com/traefik/traefik/releases

---

> 用户访问pod资源所经过的路径为：首先找到vip10.0.0.10:6443，然后经过lL7的负载转发给ingress:81端口，ingress:81端口在把流量转发给kube-proxy，kube-proxy在找到service IP，然后再找到pod
>
> 81端口为下面资源配置清单提到的ingress从pod映射到宿主机的端口，类似于nodeport

#### 5.3.1. 配置TRAEFIK资源清单

清单文件存放到 host0-200:/data/k8s-yaml/traefik/traefik_1.7.2

```sh
[root@host0-200 coredns_1.6.1]# mkdir -pv /data/k8s-yaml/traefik/traefik_1.7.2 && cd /data/k8s-yaml/traefik/traefik_1.7.2
```

- vim rbac.yaml

```sh
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  name: traefik-ingress-controller
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
- kind: ServiceAccount
  name: traefik-ingress-controller
  namespace: kube-system
```

- vim daemonset.yaml

```sh
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: traefik-ingress
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress
spec:
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress
        name: traefik-ingress
    spec:
      serviceAccountName: traefik-ingress-controller
      terminationGracePeriodSeconds: 60
      containers:
      - image: harbor.od.com/public/traefik:v1.7.2
        name: traefik-ingress
        ports:
        - name: controller
          containerPort: 80
          hostPort: 81
        - name: admin-web
          containerPort: 8080
        securityContext:
          capabilities:
            drop:
            - ALL
            add:
            - NET_BIND_SERVICE
        args:
        - --api
        - --kubernetes
        - --logLevel=INFO
        - --insecureskipverify=true
        - --kubernetes.endpoint=https://10.0.0.10:7443
        - --accesslog
        - --accesslog.filepath=/var/log/traefik_access.log
        - --traefiklog
        - --traefiklog.filepath=/var/log/traefik.log
        - --metrics.prometheus
```

- vim service.yaml

```sh
kind: Service
apiVersion: v1
metadata:
  name: traefik-ingress-service
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress
  ports:
    - protocol: TCP
      port: 80
      name: controller
    - protocol: TCP
      port: 8080
      name: admin-web
```

- vim ingress.yaml

```sh
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-web-ui
  namespace: kube-system
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: traefik.od.com
    http:
      paths:
      - path: /
        backend:
          serviceName: traefik-ingress-service
          servicePort: 8080
```

- 准备镜像

```sh
[root@host0-200 traefik_1.7.2]# docker pull docker.io/traefik:v1.7.2-alpine
[root@host0-200 traefik_1.7.2]# docker tag traefik:v1.7.2-alpine harbor.od.com/public/traefik:v1.7.2
[root@host0-200 traefik_1.7.2]# docker push harbor.od.com/public/traefik:v1.7.2
```

#### 5.3.2. 交付TRAEFIK到K8S

```sh
# 注意是域名还是IP
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/traefik/traefik_1.7.2/rbac.yaml
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/traefik/traefik_1.7.2/daemonset.yaml
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/traefik/traefik_1.7.2/service.yaml
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/traefik/traefik_1.7.2/ingress.yaml
[root@host0-21 ~]# kubectl get pods -n kube-system -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE                NOMINATED NODE   READINESS GATES
coredns-6b6c4f9648-4vtcl   1/1     Running   1          24h   172.7.22.3   host0-12.host.com   <none>           <none>
traefik-ingress-4gm4w      1/1     Running   0          77s   172.7.22.5   host0-12.host.com   <none>           <none>
traefik-ingress-hwr2j      1/1     Running   0          77s   172.7.22.3   host0-22.host.com   <none>           <none>
[root@host0-21 ~]# kubectl get ds -n kube-system 
NAME              DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
traefik-ingress   2         2         2       2            2           <none>          107s
如果发现没有成功启动，那就重启两台主机的docker，再重启一下pod资源
# 可以查看服务的信息
[root@host0-21 ~]# kubectl describe pods traefik-ingress-*****
```

#### 5.3.3. 配置外部NGINX负载均衡

- 在host0-11,host0-12配置nginx L7转发

以下配置文件中所说的意思就是，我把*.od.com的7层流量没有差别的抛给ingress-controller，也就是抛给ingress控制器，然后控制器会根据你的ingress资源来把流量转发给相应的service资源，之后service会把流量转发给pod，最后到容器业务
其实说白了就是把以后认为所有的业务容器的流量都转发到流量代理服务器上，也就是host0-11和host0-12

```sh
[root@host0-11~]# vim /etc/nginx/conf.d/od.com.conf
server {
    server_name *.od.com;
  
    location / {
        proxy_pass http://default_backend_traefik;
        proxy_set_header Host       $http_host;
        proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;
    }
}

upstream default_backend_traefik {
    # 所有的nodes都放到upstream中
    server 10.0.0.21:81    max_fails=3 fail_timeout=10s;
    server 10.0.0.22:81    max_fails=3 fail_timeout=10s;
}
[root@host0-11~]# systemctl restart nginx
```

- 配置dns解析

```sh
[root@host0-200~]# vim /var/named/od.com.zone 
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020092804 ; serial
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
[root@host0-200~]# systemctl restart named
```

- 查看traefik网页

![img](/images/posts/Linux-Kubernetes/二进制部署/10.png)

> - 首先本文章中讲的od.com是pod的业务域
>
> - 客户端访问traefik.od.com（也就是访问pod业务），traefik.od.com为什么能走到10.0.0.10这个vip呢，因为做了bind域名解析，通过DNS解析保证了客户端能够访问到traefik.od.com并且能够访问到vip，vip实际上是附着到了10.0.0.21和10.0.0.22，所以要找10.0.0.21上面这个l7的反向代理规则，并且nginx配置文件中把*.od.com业务域的流量没有差别的抛给了ingress，nginx自身并没有做任何事，只是把流量转发给了ingress，那么ingress是去应用了一个ingress.yaml资源配置清单，它有一个host的配置段，这个host的名字叫traefik.od.com，然后还有一个path规则，path所对应的有个/跟，然后又把流量没有差别的抛给traefik-ingress-service（ingress POD），然后通过ingress POD去暴露其他的pod服务如（80端口）
>
> - 这也就是为什么说ingress是简化版的nginx，他也实现了流量转发调度 
>
> - 这个资源配置清单实现的功能是就是把nginx代理过来的流量转发给ingress pod



### 5.4. DASHBOARD

#### 5.4.1. 配置资源清单,建议赶紧拍好快照，因为下面的操作可能有问题。

清单文件存放到 harbor:/data/k8s-yaml/dashboard/dashboard_1.8.3

```sh
[root@host0-200 traefik_1.7.2]# mkdir -pv /data/k8s-yaml/dashboard/dashboard_1.8.3 && cd /data/k8s-yaml/dashboard/dashboard_1.8.3/
```

- 准备镜像

```sh
# 镜像准备       
# 因不可描述原因，无法访问k8s.gcr.io，改成registry.aliyuncs.com/google_containers
[root@host0-200 dashboard_1.8.3]# docker pull registry.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.8.3
[root@host0-200 dashboard_1.8.3]# docker tag registry.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.8.3 harbor.od.com/public/kubernetes-dashboard-amd64:v1.8.3
[root@host0-200 dashboard_1.8.3]# docker push harbor.od.com/public/kubernetes-dashboard-amd64:v1.8.3
```

- vim rbac.yaml

```sh
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
    addonmanager.kubernetes.io/mode: Reconcile
  name: kubernetes-dashboard-admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard-admin
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard-admin
  namespace: kube-system
```

- vim deployment.yaml

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kubernetes-dashboard
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      priorityClassName: system-cluster-critical
      containers:
      - name: kubernetes-dashboard
        image: harbor.od.com/public/kubernetes-dashboard-amd64:v1.8.3
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 50m
            memory: 100Mi
        ports:
        - containerPort: 8443
          protocol: TCP
        args:
          # PLATFORM-SPECIFIC ARGS HERE
          - --auto-generate-certificates
        volumeMounts:
        - name: tmp-volume
          mountPath: /tmp
        livenessProbe:
          httpGet:
            scheme: HTTPS
            path: /
            port: 8443
          initialDelaySeconds: 30
          timeoutSeconds: 30
      volumes:
      - name: tmp-volume
        emptyDir: {}
      serviceAccountName: kubernetes-dashboard-admin
      tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Exists"
```

- vim service.yaml

```sh
apiVersion: v1
kind: Service
metadata:
  name: kubernetes-dashboard
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  selector:
    k8s-app: kubernetes-dashboard
  ports:
  - port: 443
    targetPort: 8443
```

- vim ingress.yaml

```sh
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: kubernetes-dashboard
  namespace: kube-system
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: dashboard.od.com
    http:
      paths:
      - backend:
          serviceName: kubernetes-dashboard
          servicePort: 443
```

#### 5.4.2. 交付DASHBOARD到K8S

```sh
# 到底是域名还是IP
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dashboard/dashboard_1.8.3/rbac.yaml
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dashboard/dashboard_1.8.3/deployment.yaml
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dashboard/dashboard_1.8.3/service.yaml
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dashboard/dashboard_1.8.3/ingress.yaml
# 查看是否成功启动
[root@host0-21 ~]# kubectl get pods -n kube-system -o wide
```

#### 5.4.3. 配置DNS解析

```sh
[root@host0-200~]# vim /var/named/od.com.zone 
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020011303 ; serial
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
[root@host0-200~]# systemctl restart named.service 
```

#### 5.4.4. 签发SSL证书

```sh
[root@host0-200 ~]# cd /opt/certs/
[root@host0-200 certs]# (umask 077; openssl genrsa -out dashboard.od.com.key 2048)  # 创建证书
[root@host0-200 certs]# openssl req -new -key dashboard.od.com.key -out dashboard.od.com.csr -subj "/CN=dashboard.od.com/C=CN/ST=BJ/L=Beijing/O=OldboyEdu/OU=ops"   # 签发证书请求文件
[root@host0-200 certs]# openssl x509 -req -in dashboard.od.com.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out dashboard.od.com.crt -days 3650  # 签发私钥
[root@host0-200 certs]# ll dashboard.od.com.*
-rw-r--r-- 1 root root 1196 Jan 29 20:52 dashboard.od.com.crt
-rw-r--r-- 1 root root 1005 Jan 29 20:51 dashboard.od.com.csr
-rw------- 1 root root 1675 Jan 29 20:51 dashboard.od.com.key
切换到host0-11和host0-12的/etc/nginx目录下创建个certs目录
[root@host0-11~]# cd /etc/nginx/ && mkdir certs && cd certs
[root@host0-200 certs]# scp dashboard.od.com.key dashboard.od.com.crt  host0-12:/etc/nginx/certs/
[root@host0-200 certs]# scp dashboard.od.com.key dashboard.od.com.crt  host0-11:/etc/nginx/certs/
```

#### 5.4.5. 配置NGINX

```sh
# host0-11和host0-12都需要操作
[root@host0-11~]# vim /etc/nginx/conf.d/dashborad.conf
server {
    listen       80;
    server_name  dashboard.od.com;
    rewrite ^(.*)$ https://${server_name}$1 permanent;
}

server {
    listen       443 ssl;
    server_name  dashboard.od.com;

    ssl_certificate "certs/dashboard.od.com.crt";
    ssl_certificate_key "certs/dashboard.od.com.key";
    ssl_session_cache shared:SSL:1m;
    ssl_session_timeout  10m;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://default_backend_traefik;
        proxy_set_header Host       $http_host;
        proxy_set_header x-forwarded-for $proxy_add_x_forwarded_for;
    }
}
[root@host0-11~]# nginx -t && nginx -s reload
浏览器访问：控制台
```
dashboard.od.com

![img](/images/posts/Linux-Kubernetes/二进制部署/11.png)

#### 5.4.6. 测试TOKEN登陆
1.10.1版本的dashboard会让你用token登陆，此次测试的为1.8.1，如果想试自己可以上传一个新的1.10.1镜像然后修改一下deployment的镜像即可。

此token就是最高管理员权限，当然，仅限于我的dashboard rbac。
```sh
[root@host0-21 ~]# kubectl get secret -n kube-system
NAME                                     TYPE                                  DATA   AGE
coredns-token-6qqpv                      kubernetes.io/service-account-token   3      19d
default-token-cr6gx                      kubernetes.io/service-account-token   3      19d
heapster-token-wzdp5                     kubernetes.io/service-account-token   3      13d
kubernetes-dashboard-admin-token-gg8ld   kubernetes.io/service-account-token   3      18d
kubernetes-dashboard-key-holder          Opaque                                2      18d
traefik-ingress-controller-token-bcslq   kubernetes.io/service-account-token   3      18d
[root@host0-21 ~]# kubectl describe secret kubernetes-dashboard-admin-token-gg8ld -n kube-system |grep ^token
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZC1hZG1pbi10b2tlbi1nZzhsZCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZC1hZG1pbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjA3NGNiZWJjLWM3OTEtNDNkYy04NjRlLWYzMzE3NmY1YzcxYyIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTprdWJlcm5ldGVzLWRhc2hib2FyZC1hZG1pbiJ9.kq2FwyPbScM9sCmpK0kaD6339qkk4jm3_R8NgTp8i6AxzljGtwelwJ12JlWcDfHLcK0BuXqSh3JE8VDXHkM9KJ2gAgFMzGc2qkcKp1l5ihD_28_X8ki9aKQaZKZUSqzwcx7mdarXmQ4B7QJUnmglGDRtcpoopJLdbk7ObZYbFrUqZC3xOlqz_ezqcNp64eVkkyQyKfgYybpf4HNLLCZoDmVIuJh4HVpK7ZqPGH0ES_xevPRn7rBNPu2NuKakY1dD5Avl9KoWr9xOtO9Qh181Vi-fdoXQWD1QMI74low1sFV4FvsE_ucvKbgjM9FRNn-bgSacjc0NWp1AhIBB7bcOYA
```
## 6.部署heapster

这是一个dashboard的附加插件，就是一个监控小软件。

### 6.1.pull镜像以及打标签上传镜像

```sh
[root@host0-200 ~]# docker pull quay.io/bitnami/heapster:1.5.4
1.5.4: Pulling from bitnami/heapster
4018396ca1ba: Pull complete
0e4723f815c4: Pull complete
d8569f30adeb: Pull complete
Digest: sha256:6d891479611ca06a5502bc36e280802cbf9e0426ce4c008dd2919c2294ce0324
Status: Downloaded newer image for quay.io/bitnami/heapster:1.5.4
quay.io/bitnami/heapster:1.5.4
[root@host0-200 ~]# docker tag quay.io/bitnami/heapster:1.5.4 harbor.od.com/public/heapster:v1.5.4
[root@host0-200 ~]# docker push harbor.od.com/public/heapster:v1.5.4
The push refers to repository [harbor.od.com/public/heapster]
20d37d828804: Pushed
b9b192015e25: Pushed
b76dba5a0109: Pushed
v1.5.4: digest: sha256:bfb71b113c26faeeea27799b7575f19253ba49ccf064bac7b6137ae8a36f48a5 size: 952
```
### 6.2.准备资源配置清单

首先创建相应的目录

```sh
[root@host0-200 ~]# mkdir -pv /data/k8s-yaml/dashboard/heapster && cd /data/k8s-yaml/dashboard/heapster
mkdir: 已创建目录 "/data/k8s-yaml/dashboard/heapster"
```

- vim rbac.yaml

```sh
apiVersion: v1
kind: ServiceAccount
metadata:
  name: heapster
  namespace: kube-system
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: heapster
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:heapster
subjects:
- kind: ServiceAccount
  name: heapster
  namespace: kube-system
```

- vim deployment.yaml

```sh
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: heapster
  namespace: kube-system
spec:
  replicas: 1
  template:
    metadata:
     labels:
       task: monitoring
       k8s-app: heapster
    spec:
      serviceAccountName: heapster
      containers:
      - name: heapster
        image: harbor.od.com/public/heapster:v1.5.4
        imagePullPolicy: IfNotPresent
        command:
        - /opt/bitnami/heapster/bin/heapster
        #- --source=kubernetes:https://kubernetes.default?kubeletHttps=true&kubeletPort=10250&insecure=true
```

- vim service.yaml

```sh
apiVersion: v1
kind: Service
metadata:
  labels:
    task: monitoring
    # For use as a Cluster add-no (https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
    # If you are NOT using this as an addon,you should comment out this line.
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: Heapster
  name: heapster
  namespace: kube-system
spec:
  ports:
  - port: 80
    targetPort: 8082
  selector:
    k8s-app: heapster
```
- vim heapster_modify.yaml
```sh
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  creationTimestamp: "2021-08-04T04:26:29Z"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:heapster
  resourceVersion: "52"
  selfLink: /apis/rbac.authorization.k8s.io/v1/clusterroles/system%3Aheapster
  uid: e55c58e4-2cdf-4f87-ab5d-bda4b70b15be
rules:
- apiGroups:
  - ""
  resources:
  - events
  - namespaces
  - nodes
  - pods
  - nodes/stats
  verbs:
  - create
  - get
  - list
  - watch
- apiGroups:
  - extensions
  resources:
  - deployments
  verbs:
  - get
  - list
  - watch
```

### 6.3.生成服务

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dashboard/heapster/rbac.yaml
serviceaccount/heapster unchanged
[root@host0-21 ~]# kubectl get serviceaccount -n kube-system
NAME                         SECRETS   AGE
coredns                      1         6d12h
default                      1         6d14h
heapster                     1         19h
kubernetes-dashboard-admin   1         5d16h
traefik-ingress-controller   1         6d9h

[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dashboard/heapster/deployment.yaml
deployment.extensions/heapster created
[root@host0-21 ~]# kubectl get pods -n kube-system
NAME                                    READY   STATUS    RESTARTS   AGE
coredns-6b6c4f9648-xpqs9                1/1     Running   1          5d11h
heapster-5bb4cb85dd-dtnqs               1/1     Running   0          13m
kubernetes-dashboard-5dbdd9bdd7-xjdfv   1/1     Running   1          5d16h
traefik-ingress-z4nzg                   1/1     Running   0          19h
traefik-ingress-zvsxh                   1/1     Running   1          6d9h
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/dashboard/heapster/service.yaml
service/heapster created
[root@host0-21 ~]# kubectl get svc -n kube-system
NAME                      TYPE        CLUSTER-IP        EXTERNAL-IP   PORT(S)                  AGE
coredns                   ClusterIP   192.168.0.2       <none>        53/UDP,53/TCP,9153/TCP   6d12h
heapster                  ClusterIP   192.168.187.48    <none>        80/TCP                   11m
kubernetes-dashboard      ClusterIP   192.168.104.11    <none>        443/TCP                  5d16h
traefik-ingress-service   ClusterIP   192.168.194.152   <none>        80/TCP,8080/TCP          6d9h
```
