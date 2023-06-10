---
layout: post
title: Linux-Kubernetes-42-部署高可用Kubnernetes
date: 2021-12-17
tags: 实战-Kubernetes
music-id: 287063
---

## 一、简介三大步骤

第一步、部署Nginx+keepalived高可用负载


第二步、部署Etcd集群


第三步、初始化K8S集群

## 二、实验环境

| 角色                 | IP                   | 组件                                 |
| -------------------- | -------------------- | ------------------------------------ |
| k8s-cluster-master01 | 192.168.1.124        | k8s、docker、nginx、keepalived、etcd |
| k8s-cluster-master02 | 192.168.1.132        | k8s、docker、nginx、keepalived、etcd |
| k8s-cluster-node01   | 192.168.1.126        | k8s、docker、etcd                    |
| k8s-cluster-node02   | 192.168.1.139        | k8s、docker、harbor                  |
| keepalived VIP       | 192.168.1.200（VIP） |                                      |

```sh
# 四台均一样
[root@k8s-cluster-master01 ~]# uname -a
Linux k8s-cluster-master01 3.10.0-1160.el7.x86_64 #1 SMP Mon Oct 19 16:18:59 UTC 2020 x86_64 x86_64 x86_64 GNU/Linux
[root@k8s-cluster-master01 ~]# cat /proc/version
Linux version 3.10.0-1160.el7.x86_64 (mockbuild@kbuilder.bsys.centos.org) (gcc version 4.8.5 20150623 (Red Hat 4.8.5-44) (GCC) ) #1 SMP Mon Oct 19 16:18:59 UTC 2020
[root@k8s-cluster-master01 ~]# cat /etc/centos-release
CentOS Linux release 7.9.2009 (Core)
[root@k8s-cluster-master01 ~]# free -h
              total        used        free      shared  buff/cache   available
Mem:           3.7G        315M        2.2G        8.6M        1.2G        3.2G
Swap:            0B          0B          0B
[root@k8s-cluster-master01 ~]# lscpu
Architecture:          x86_64
CPU op-mode(s):        32-bit, 64-bit
Byte Order:            Little Endian
CPU(s):                4
On-line CPU(s) list:   0-3
Thread(s) per core:    1
Core(s) per socket:    1
座：                 4
...............
```

## 三、基础环境部署（四台机器同样操作）

### 1. 关闭防火墙

```sh
[root@k8s-cluster-master01 ~]# systemctl stop firewalld && systemctl disable firewalld
```

### 2. 关闭selinux

```sh
[root@k8s-cluster-master01 ~]# sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
[root@k8s-cluster-master01 ~]# setenforce 0
```

### 3. 关闭swap

```sh
[root@k8s-cluster-master01 ~]# swapoff -a
[root@k8s-cluster-master01 ~]# sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fsta
```

### 4. 配置hosts解析

```sh
[root@k8s-cluster-master01 ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.1.124 k8s-cluster-master01
192.168.1.132 k8s-cluster-master02
192.168.1.126 k8s-cluster-node01
192.168.1.139 k8s-cluster-node02
```

### 5. 免密登录配置

遇到提示回车即可
```sh
[root@k8s-master01 ~]# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:2iq1E1Wt9wfKp3eEc50TLw+9yHOscljS0PSdlCWLN3U root@k8s-master01
The key's randomart image is:
+---[RSA 2048]----+
|           .  . E|
|          . .o *.|
|         . .+ * o|
|        . ...o.=.|
|       .S  ooo +=|
|      oo   .ooBoB|
|     ..o.   =ooOo|
|    . o.   o.=.+o|
|     ...    oo+. |
+----[SHA256]-----+
[root@k8s-master01 ~]# ls ~/.ssh/
id_rsa  id_rsa.pub  known_hosts
```
拷贝公钥到master02机器上

```#!/bin/sh
[root@k8s-master01 ~]# scp ~/.ssh/id_rsa.pub 192.168.1.186:~/.ssh/
root@192.168.1.186's password:
scp: /root/.ssh/: Is a directory
# 提示找不到这个目录就去master02机器上执行以下 `ssh localhost`
[root@k8s-master01 ~]# scp ~/.ssh/id_rsa.pub 192.168.1.186:~/.ssh/
root@192.168.1.186's password:
id_rsa.pub
# 切换到master02
[root@k8s-master02 ~]# cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
```

验证ssh免密登录

```#!/bin/sh
[root@k8s-master01 ~]# ssh 192.168.1.186
Last login: Tue Dec 21 14:04:15 2021 from 192.168.11.199
```

### 6. 内核调整,将桥接的IPv4流量传递到iptables的链

```sh
[root@k8s-cluster-master01 ~]# lsmod | grep br_netfilter #确认是否有加载此模块
[root@k8s-cluster-master01 ~]# sudo modprobe br_netfilter  #没有的话可以先加载
[root@k8s-cluster-master01 ~]# cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
[root@k8s-cluster-master01 ~]# sudo sysctl --system
[root@k8s-cluster-master01 ~]# sysctl -w net.ipv4.ip_forward=1
net.ipv4.ip_forward = 1
```
### 7. 安装基础程序

```sh
[root@k8s-cluster-master01 ~]# yum install -y vim net-tools telnet chrony bash-completion wget tree nmap sysstat lrzsz dos2unix bind-utils less pciutils ntpdate ipset ipvsadm
```

### 8. 如何使用ipvs作为流量转发，那么如下

```#!/bin/sh
[root@k8s-cluster-master01 ~]# for i in $(ls /usr/lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*");do echo $i; /sbin/modinfo -F filename $i >/dev/null 2>&1 && /sbin/modprobe $i;done
```
```#!/bin/sh
[root@k8s-cluster-master01 cfg]# lsmod | grep ip_vs
ip_vs_wlc              12519  0
ip_vs_sed              12519  0
ip_vs_pe_sip           12740  0
nf_conntrack_sip       33780  1 ip_vs_pe_sip
ip_vs_nq               12516  0
ip_vs_lc               12516  0
ip_vs_lblcr            12922  0
ip_vs_lblc             12819  0
ip_vs_ftp              13079  0
ip_vs_dh               12688  0
ip_vs_sh               12688  0
ip_vs_wrr              12697  0
ip_vs_rr               12600  4
nf_nat                 26583  3 ip_vs_ftp,nf_nat_ipv4,nf_nat_masquerade_ipv4
ip_vs                 145458  28 ip_vs_dh,ip_vs_lc,ip_vs_nq,ip_vs_rr,ip_vs_sh,ip_vs_ftp,ip_vs_sed,ip_vs_wlc,ip_vs_wrr,ip_vs_pe_sip,ip_vs_lblcr,ip_vs_lblc
nf_conntrack          139264  8 ip_vs,nf_nat,nf_nat_ipv4,xt_conntrack,nf_nat_masquerade_ipv4,nf_conntrack_netlink,nf_conntrack_sip,nf_conntrack_ipv4
libcrc32c              12644  4 xfs,ip_vs,nf_nat,nf_conntrack
```
Ubuntu1804开启ipvs
```sh
root@ubuntu:~# for i in $(ls /lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*");do echo $i; /sbin/modinfo -F filename $i >/dev/null 2>&1 && /sbin/modprobe $i; done
root@ubuntu:~# lsmod | grep ip_vs
root@ubuntu:~# ls /lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*" >> /etc/modules
```
### 9.配置时间同步

```sh
[root@k8s-cluster-master01 ~]# ntpdate time.windows.com
或者
[root@k8s-cluster-master01 ~]# timedatectl set-timezone Asia/Shanghai
```

Ubuntu1804
```#!/bin/sh
root@ubuntu:~# timedatectl set-timezone Asia/Shanghai
```

## 四、部署Nginx+Keepalived高可用负载均衡器

master1和master2同样操作

### 1. nginx配置
```sh
[root@k8s-cluster-master01 ~]# touch /etc/yum.repos.d/nginx.repo
[root@k8s-cluster-master01 ~]# cat > /etc/yum.repos.d/nginx.repo <<EOF
# nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/7/x86_64/
gpgcheck=0
enabled=1
EOF
[root@k8s-cluster-master01 ~]# yum install -y nginx nginx-all-modules
[root@k8s-cluster-master01 ~]# cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
[root@k8s-cluster-master01 ~]# cat /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

# 四层负载均衡，为两台Master apiserver组件提供负载均衡
stream {

    log_format  main  '$remote_addr $upstream_addr - [$time_local] $status $upstream_bytes_sent';

    access_log  /var/log/nginx/k8s-access.log  main;

    upstream k8s-apiserver {
       server 192.168.1.124:6443;   # Master1 APISERVER IP:PORT
       server 192.168.1.132:6443;   # Master2 APISERVER IP:PORT
    }

    server {
       listen 16443;  # 由于nginx与master节点复用，这个监听端口不能是6443，否则会冲突
       proxy_pass k8s-apiserver;
    }
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    server {
        listen       80 default_server;
        server_name  _;

        location / {
        }
    }
}
```

# 3. 启动服务

```sh
[root@k8s-cluster-master01 nginx]# systemctl enable nginx.service --now
Created symlink from /etc/systemd/system/multi-user.target.wants/nginx.service to /usr/lib/systemd/system/nginx.service.
```

### 4. kpeepalived配置

如果你想做三台机器为master，那么下面的BACKUP节点的配置，再master03节点上也配置一下，注意优先级比master02要低就行

主备优先级配置不一样

- 主

```sh
[root@k8s-cluster-master01 ~]# yum -y install keepalived
[root@k8s-cluster-master01 ~]# cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak
[root@k8s-cluster-master01 ~]# cat /etc/keepalived/keepalived.conf
global_defs {
   notification_email {
     acassen@firewall.loc
     failover@firewall.loc
     sysadmin@firewall.loc
   }
   notification_email_from Alexandre.Cassen@firewall.loc  
   smtp_server 127.0.0.1
   smtp_connect_timeout 30
   router_id NGINX_MASTER
}

vrrp_script check_nginx {
    script "/etc/keepalived/check_nginx.sh"
}

vrrp_instance VI_1 {
    state MASTER
    interface eth0  # 修改为实际网卡名
    virtual_router_id 51 # VRRP 路由 ID实例，每个实例是唯一的
    priority 100    # 优先级，备服务器设置 90
    advert_int 1    # 指定VRRP 心跳包通告间隔时间，默认1秒
    authentication {
        auth_type PASS      
        auth_pass 1111
    }  
    # 虚拟IP
    virtual_ipaddress {
        192.168.1.200/24
    }
    track_script {
        check_nginx
    }
}
```

- 备

```sh
[root@k8s-cluster-master02 ~]# cat /etc/keepalived/keepalived.conf
global_defs {
   notification_email {
     acassen@firewall.loc
     failover@firewall.loc
     sysadmin@firewall.loc
   }
   notification_email_from Alexandre.Cassen@firewall.loc  
   smtp_server 127.0.0.1
   smtp_connect_timeout 30
   router_id NGINX_BACKUP
}

vrrp_script check_nginx {
    script "/etc/keepalived/check_nginx.sh"
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51 # VRRP 路由 ID实例，每个实例是唯一的
    priority 90
    advert_int 1
    authentication {
        auth_type PASS      
        auth_pass 1111
    }  
    virtual_ipaddress {
        192.168.1.200/24
    }
    track_script {
        check_nginx
    }
}
```

### 5. 检查nginx运行状态脚本

每个机器上都配置

```sh
[root@k8s-cluster-master01 ~]# cat  /etc/keepalived/check_nginx.sh
#!/bin/bash
count=$(netstat -lntp|grep 16443 |egrep -cv "grep|$$")

if [ "$count" -eq 0 ];then
    exit 1
else
    exit 0
fi

[root@k8s-cluster-master01 ~]# chmod +x /etc/keepalived/check_nginx.sh
```

### 6. 启动服务

```sh
[root@k8s-cluster-master01 nginx]# systemctl enable keepalived.service --now
Created symlink from /etc/systemd/system/multi-user.target.wants/keepalived.service to /usr/lib/systemd/system/keepalived.service.
```

## 五、部署Etcd集群

### 1. 准备cfssl证书生成

安装命令

```sh
[root@k8s-cluster-master01 nginx]#  wget https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 -O /usr/local/bin/cfssl
[root@k8s-cluster-master01 nginx]#  wget https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64 -O /usr/local/bin/cfssl-json
[root@k8s-cluster-master01 nginx]#  wget https://pkg.cfssl.org/R1.2/cfssl-certinfo_linux-amd64 -O /usr/local/bin/cfssl-certinfo
[root@k8s-cluster-master01 nginx]#  chmod u+x /usr/local/bin/cfssl*
```

签发根证书

```sh
[root@k8s-cluster-master01 ~]# mkdir -pv /opt/certs/ && cd /opt/certs/
mkdir: 已创建目录 "/opt/certs/"
[root@k8s-cluster-master01 certs]# cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "172500h"
    },
    "profiles": {
      "www": {
         "expiry": "172500h",
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
EOF
[root@k8s-cluster-master01 certs]# cat > ca-csr.json <<EOF
{
    "CN": "etcd CA",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing"
        }
    ]
}
EOF
[root@k8s-cluster-master01 certs]# cfssl gencert -initca ca-csr.json | cfssl-json -bare ca
2021/12/17 12:43:23 [INFO] generating a new CA key and certificate from CSR
2021/12/17 12:43:23 [INFO] generate received request
2021/12/17 12:43:23 [INFO] received CSR
2021/12/17 12:43:23 [INFO] generating key: rsa-2048
2021/12/17 12:43:24 [INFO] encoded CSR
2021/12/17 12:43:24 [INFO] signed certificate with serial number 715596046456905871390970396162538590705769330677
[root@k8s-cluster-master01 certs]# ls
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem
```

### 2. 签发Etcd证书

- 创建ca的json配置: /opt/certs/ca-config.json
- server 表示服务端连接客户端时携带的证书，用于客户端验证服务端身份
- client 表示客户端连接服务端时携带的证书，用于服务端验证客户端身份
- peer 表示相互之间连接时使用的证书，如etcd节点之间验证

为了后期扩容，可以多些几个IP地址

```sh
[root@k8s-cluster-master01 certs]# cat > server-csr.json <<EOF
{
    "CN": "etcd",
    "hosts": [
    "192.168.1.124",
    "192.168.1.132",
    "192.168.1.126"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "BeiJing",
            "ST": "BeiJing"
        }
    ]
}
EOF
```

生成etcd证书

```sh
[root@k8s-cluster-master01 certs]# cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=www server-csr.json | cfssl-json -bare server
2021/12/17 12:49:57 [INFO] generate received request
2021/12/17 12:49:57 [INFO] received CSR
2021/12/17 12:49:57 [INFO] generating key: rsa-2048
2021/12/17 12:49:57 [INFO] encoded CSR
2021/12/17 12:49:57 [INFO] signed certificate with serial number 178018382913269522537542851189940505479106379731
2021/12/17 12:49:57 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[root@k8s-cluster-master01 certs]# ls
ca-config.json  ca.csr  ca-csr.json  ca-key.pem  ca.pem  server.csr  server-csr.json  server-key.pem  server.pem
```

### 3. 安装Etcd（三台机器）

创建工作目录
```sh
[root@k8s-cluster-master01 certs]# mkdir /opt/etcd/{bin,cfg,ssl} -pv
mkdir: 已创建目录 "/opt/etcd"
mkdir: 已创建目录 "/opt/etcd/bin"
mkdir: 已创建目录 "/opt/etcd/cfg"
mkdir: 已创建目录 "/opt/etcd/ssl"
[root@k8s-cluster-master01 certs]# cd /usr/local/src
[root@k8s-cluster-master01 src]# wget https://github.com/etcd-io/etcd/releases/download/v3.4.9/etcd-v3.4.9-linux-amd64.tar.gz
[root@k8s-cluster-master01 src]# tar zvxf etcd-v3.4.9-linux-amd64.tar.gz
[root@k8s-cluster-master01 src]# mv etcd-v3.4.9-linux-amd64/{etcd,etcdctl} /opt/etcd/bin/
[root@k8s-cluster-master01 src]# cat > /opt/etcd/cfg/etcd.conf <<EOF
#[Member]
ETCD_NAME="etcd-1"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://192.168.1.124:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.1.124:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.1.124:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.1.124:2379"
ETCD_INITIAL_CLUSTER="etcd-1=https://192.168.1.124:2380,etcd-2=https://192.168.1.132:2380,etcd-3=https://192.168.1.126:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF
```
- ETCD_NAME：节点名称，集群中唯一
- ETCDDATADIR：数据目录
- ETCDLISTENPEER_URLS：集群通信监听地址
- ETCDLISTENCLIENT_URLS：客户端访问监听地址
- ETCDINITIALADVERTISEPEERURLS：集群通告地址
- ETCDADVERTISECLIENT_URLS：客户端通告地址
- ETCDINITIALCLUSTER：集群节点地址
- ETCDINITIALCLUSTER_TOKEN：集群Token
- ETCDINITIALCLUSTER_STATE：加入集群的当前状态，new是新集群，existing表示加入已有集群

### 4. systemcd管理Etcd

```sh
[root@k8s-cluster-master01 src]# cat > /usr/lib/systemd/system/etcd.service <<EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=/opt/etcd/cfg/etcd.conf
ExecStart=/opt/etcd/bin/etcd --cert-file=/opt/etcd/ssl/server.pem --key-file=/opt/etcd/ssl/server-key.pem --peer-cert-file=/opt/etcd/ssl/server.pem --peer-key-file=/opt/etcd/ssl/server-key.pem --trusted-ca-file=/opt/etcd/ssl/ca.pem --peer-trusted-ca-file=/opt/etcd/ssl/ca.pem --logger=zap
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
```

将刚才certs目录下的证书拷贝到配置文件中指定的位置

```sh
[root@k8s-cluster-master01 src]# cp /opt/certs/ca*pem /opt/etcd/ssl/
[root@k8s-cluster-master01 src]# cp /opt/certs/server*pem /opt/etcd/ssl/
[root@k8s-cluster-master01 src]# ls /opt/etcd/ssl/
ca-key.pem  ca.pem  server-key.pem  server.pem
```

### 5. 启动Etcd

首先把etcd目录拷贝到其余两台机器的相同目录下，然后启动

```sh
[root@k8s-cluster-master01 ~]# scp -r /opt/etcd/ 192.168.1.132:/opt
[root@k8s-cluster-master01 ~]# scp -r /opt/etcd/ 192.168.1.126:/opt
```

启动服务

```sh
[root@k8s-cluster-master01 ~]# systemctl start etcd
[root@k8s-cluster-master01 ~]# systemctl enable etcd
Created symlink from /etc/systemd/system/multi-user.target.wants/etcd.service to /usr/lib/systemd/system/etcd.service.
[root@k8s-cluster-master01 ~]# systemctl status etcd
● etcd.service - Etcd Server
   Loaded: loaded (/usr/lib/systemd/system/etcd.service; enabled; vendor preset: disabled)
   Active: active (running) since 五 2021-12-17 13:34:04 CST; 5s ago
 Main PID: 443 (etcd)
    Tasks: 13
   Memory: 25.5M
   CGroup: /system.slice/etcd.service
           └─443 /opt/etcd/bin/etcd --cert-file=/opt/etcd/ssl/server.pem --key-file=/opt/etcd/ssl/server-key.pem --peer-cert-file=/opt/etcd/ssl/server.pem --peer-key-file=/opt/etcd/ssl/server-key.pem --trusted-ca-file=/opt/etcd/ssl/ca.pem --peer-trusted-ca-file=/opt/...

12月 17 13:34:04 k8s-cluster-master01 etcd[443]: {"level":"info","ts":"2021-12-17T13:34:04.470+0800","caller":"rafthttp/stream.go:250","msg":"set message encoder","from":"9702c6794fa06d5e","to":"9702c6794fa06d5e","stream-type":"stream Message"}
12月 17 13:34:04 k8s-cluster-master01 etcd[443]: {"level":"warn","ts":"2021-12-17T13:34:04.470+0800","caller":"rafthttp/stream.go:277","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream Message","local-membe..."a9da512f9c5f83d7"}
12月 17 13:34:04 k8s-cluster-master01 etcd[443]: {"level":"info","ts":"2021-12-17T13:34:04.470+0800","caller":"rafthttp/stream.go:250","msg":"set message encoder","from":"9702c6794fa06d5e","to":"9702c6794fa06d5e","stream-type":"stream Message"}
12月 17 13:34:04 k8s-cluster-master01 etcd[443]: {"level":"warn","ts":"2021-12-17T13:34:04.470+0800","caller":"rafthttp/stream.go:277","msg":"established TCP streaming connection with remote peer","stream-writer-type":"stream Message","local-membe..."6ecdacfb52076732"}
12月 17 13:34:04 k8s-cluster-master01 etcd[443]: {"level":"info","ts":"2021-12-17T13:34:04.472+0800","caller":"rafthttp/stream.go:425","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream Message","local-membe..."a9da512f9c5f83d7"}
12月 17 13:34:04 k8s-cluster-master01 etcd[443]: {"level":"info","ts":"2021-12-17T13:34:04.473+0800","caller":"rafthttp/stream.go:425","msg":"established TCP streaming connection with remote peer","stream-reader-type":"stream MsgApp v2","local-mem..."a9da512f9c5f83d7"}
12月 17 13:34:04 k8s-cluster-master01 etcd[443]: {"level":"info","ts":"2021-12-17T13:34:04.486+0800","caller":"etcdserver/server.go:715","msg":"initialized peer connections; fast-forwarding election ticks","local-member-id":"9702c6794fa06d5e","forward-ticks":8,"forw...
12月 17 13:34:04 k8s-cluster-master01 etcd[443]: {"level":"info","ts":"2021-12-17T13:34:04.518+0800","caller":"etcdserver/server.go:2036","msg":"published local member to cluster through raft","local-member-id":"9702c6794fa06d5e","local-member-attributes":"{Name:etc...
12月 17 13:34:04 k8s-cluster-master01 systemd[1]: Started Etcd Server.
12月 17 13:34:04 k8s-cluster-master01 etcd[443]: {"level":"info","ts":"2021-12-17T13:34:04.520+0800","caller":"embed/serve.go:191","msg":"serving client traffic securely","address":"192.168.1.124:2379"}
```

### 6. 验证集群状态

```sh
[root@k8s-cluster-master01 ~]# netstat -lntp |grep etcd
tcp        0      0 192.168.1.124:2379      0.0.0.0:*               LISTEN      932/etcd            
tcp        0      0 192.168.1.124:2380      0.0.0.0:*               LISTEN      932/etcd
[root@k8s-cluster-master01 ~]# /opt/etcd/bin/etcdctl --cacert=/opt/etcd/ssl/ca.pem --cert=/opt/etcd/ssl/server.pem --key=/opt/etcd/ssl/server-key.pem --endpoints="https://192.168.1.124:2379,https://192.168.1.132:2379,https://192.168.1.126:2379" endpoint health --write-out=table
+----------------------------+--------+-------------+-------+
|          ENDPOINT          | HEALTH |    TOOK     | ERROR |
+----------------------------+--------+-------------+-------+
| https://192.168.1.124:2379 |   true | 20.285863ms |       |
| https://192.168.1.126:2379 |   true | 21.690739ms |       |
| https://192.168.1.132:2379 |   true | 22.971063ms |       |
+----------------------------+--------+-------------+-------+
[root@k8s-cluster-master01 ~]# /opt/etcd/bin/etcdctl --cacert=/opt/etcd/ssl/ca.pem --cert=/opt/etcd/ssl/server.pem --key=/opt/etcd/ssl/server-key.pem --endpoints="https://192.168.1.124:2379,https://192.168.1.132:2379,https://192.168.1.126:2379" member list -w table
```

kubeadm 安装的集群，etcdctl命令如下

```#!/bin/sh
# 查看 etcd 高可用集群健康状态
[root@k8s-cluster-master01 ~]# etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key member list -w table
+------------------+---------+----------------+------------------------+------------------------+------------+
|        ID        | STATUS  |      NAME      |       PEER ADDRS       |      CLIENT ADDRS      | IS LEARNER |
+------------------+---------+----------------+------------------------+------------------------+------------+
| e3e235add1631042 | started | vm-16-9-centos | https://10.0.16.9:2380 | https://10.0.16.9:2379 |      false |
+------------------+---------+----------------+------------------------+------------------------+------------+
# 查看 etcd 高可用集群列表
[root@VM-16-9-centos ~]# etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key endpoint health -w table
+------------------------+--------+------------+-------+
|        ENDPOINT        | HEALTH |    TOOK    | ERROR |
+------------------------+--------+------------+-------+
| https://127.0.0.1:2379 |   true | 7.980517ms |       |
+------------------------+--------+------------+-------+
# 查看 etcd 高可用集群 leader
[root@VM-16-9-centos ~]# etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key endpoint status -w table
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|        ENDPOINT        |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://127.0.0.1:2379 | e3e235add1631042 |  3.4.13 |   23 MB |      true |      false |         5 |   15933839 |           15933839 |        |
+------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
# 查看数据，只查看key，不查看value
[root@VM-16-9-centos ~]# etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key get / --prefix=true --keys-only
/registry/apiextensions.k8s.io/customresourcedefinitions/alertmanagerconfigs.monitoring.coreos.com

/registry/apiextensions.k8s.io/customresourcedefinitions/alertmanagers.monitoring.coreos.com

/registry/apiextensions.k8s.io/customresourcedefinitions/applications.app.k8s.io

..................

把 / 换成指定的 key 就查看指定的 key，如 /registry/pods/default

[root@VM-16-9-centos ~]# etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key get /registry/pods/default --prefix=true --keys-only
/registry/pods/default/jekyll-75b94dbd5f-88phk

/registry/pods/default/jekyll-75b94dbd5f-kcjd9

/registry/pods/default/jekyll-75b94dbd5f-xlrnj

/registry/pods/default/nfs-provisioner-774cf89994-4zs5w
```

## 六、安装docker和k8s（所有机器均配置）


### 1. docker 安装配置

```sh
[root@k8s-cluster-master01 ~]# wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
[root@k8s-cluster-master01 ~]# yum -y install docker-ce-19.03.15 docker-ce-cli-19.03.15 containerd.io
[root@k8s-cluster-master01 ~]# systemctl enable docker --now
[root@k8s-cluster-master01 ~]# vim /etc/docker/daemon.json
# docker存储目录根据实际情况修改
{
  "storage-driver": "overlay2",
  "insecure-registries": ["registry.access.redhat.com","quay.io"],
  "registry-mirrors": ["https://q2gr04ke.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true
}
[root@k8s-cluster-master01 ~]# systemctl daemon-reload
[root@k8s-cluster-master01 ~]# systemctl restart docker
```
如果需要配置nvidia作为默认运行时环境，需要参考下面的配置

```#!/bin/sh
[root@k8s-cluster-master01 ~]# yum -y install nvidia-docker2
```
```#!/bin/sh
{
  "runtimes": {
    "nvidia": {
      "path": "/usr/bin/nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "nvidia",
  "graph": "/home/docker",
  "storage-driver": "overlay2",
  "insecure-registries": ["registry.access.redhat.com","quay.io"],
  "registry-mirrors": ["https://registry.docker-cn.com","https://docker.mirrors.ustc.edu.cn"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true
}
```

### 2. harbor仓库安装（k8s-node02）

仓库官方地址：https://github.com/goharbor/harbor/releases/
```sh
[root@k8s-cluster-master01 ~]# mkdir /home/k8s-data && cd /home/k8s-data
[root@k8s-cluster-master01 ~]# tar xf  harbor-offline-installer-v2.1.5.tgz
[root@k8s-cluster-master01 ~]# cp /home/k8s-data/harbor/harbor.yml.tmpl /home/k8s-data/harbor/harbor.yml
[root@k8s-cluster-master01 ~]# sed -i 's/hostname: reg.mydomain.com/hostname: '192.168.1.139'/g' /home/k8s-data/harbor/harbor.yml
[root@k8s-cluster-master01 ~]# sed -i 's/port: 80/port: 180/g' /home/k8s-data/harbor/harbor.yml
[root@k8s-cluster-master01 ~]# sed -i 's/https:/#https:/g' /home/k8s-data/harbor/harbor.yml
[root@k8s-cluster-master01 ~]# sed -i 's/port: 443/#port: 443/g' /home/k8s-data/harbor/harbor.yml
[root@k8s-cluster-master01 ~]# sed -i 's/data_volume: \/data/data_volume: \/home\/k8s-data\/harbor\/data/g' /home/k8s-data/harbor/harbor.yml
[root@k8s-cluster-master01 ~]# wget https://github.com/docker/compose/releases/download/1.28.6/docker-compose-Linux-x86_64
[root@k8s-cluster-master01 ~]# chmod +x docker-compose-Linux-x86_64 && mv docker-compose-Linux-x86_64 /usr/bin/docker-compose
[root@k8s-cluster-master01 ~]# ./install.sh
[root@k8s-cluster-master01 ~]# docker-compose ps
```

配置开机自启

```sh
[root@k8s-cluster-master01 ~]# vim /etc/systemd/system/harbor.service
[Unit]
Description=Harbor
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=http://github.com/vmware/harbor

[Service]
Type=oneshot
ExecStartPre=/usr/bin/docker-compose -f /home/k8s-data/harbor/docker-compose.yml down
# #需要注意harbor的安装位置
ExecStart=/usr/bin/docker-compose -f /home/k8s-data/harbor/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f /home/k8s-data/harbor/docker-compose.yml down
# This service shall be considered active after start
RemainAfterExit=yes

[Install]
# Components of this application should be started at boot time
WantedBy=multi-user.target
```
```sh
[root@k8s-cluster-master01 ~]# systemctl enable harbor --now
[root@k8s-cluster-master01 ~]# systemctl restart harbor
[root@k8s-cluster-master01 ~]# docker-compose ps
      Name                     Command                       State                     Ports          
------------------------------------------------------------------------------------------------------
harbor-core         /harbor/entrypoint.sh            Up (health: starting)                            
harbor-db           /docker-entrypoint.sh            Up (health: starting)                            
harbor-jobservice   /harbor/entrypoint.sh            Up (health: starting)                            
harbor-log          /bin/sh -c /usr/local/bin/ ...   Up (health: starting)   127.0.0.1:1514->10514/tcp
harbor-portal       nginx -g daemon off;             Up (health: starting)                            
nginx               nginx -g daemon off;             Up (health: starting)   0.0.0.0:180->8080/tcp    
redis               redis-server /etc/redis.conf     Up (health: starting)                            
registry            /home/harbor/entrypoint.sh       Up (health: starting)                            
registryctl         /home/harbor/start.sh            Up (health: starting)
```

### 3. k8s安装配置

```sh
[root@k8s-cluster-master01 ~]# cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```

### 4. 安装各个k8s组件

```sh
[root@k8s-cluster-master01 ~]# yum install -y kubelet-1.18.19 kubeadm-1.18.19 kubectl-1.18.19
[root@k8s-cluster-master01 ~]# systemctl enable kubelet
```

### 8. 修改kubelet的cgroups也为systemd
在最后面添加这个参数--cgroup-driver=systemd
```sh
[root@k8s-cluster-master01 ~]# vim /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml --cgroup-driver=systemd"
[root@k8s-cluster-master01 ~]# systemctl daemon-reload
[root@k8s-cluster-master01 ~]# systemctl restart kubelet
```

## 七、初始化Master

### 1. 生成初始化配置文件

```sh
[root@k8s-cluster-master01 k8s-init]# cat kubeadm-config.yaml
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: 9037x2.tcaqnpaqkra9vsbw
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.1.124
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: k8s-cluster-master01
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  certSANs:  # 包含所有Master/LB/VIP IP，一个都不能少！为了方便后期扩容可以多写几个预留的IP。
  - k8s-cluster-master01        #初始化master名称
  - k8s-cluster-master02
  - 192.168.1.124
  - 192.168.1.132
  - 192.168.1.126
  - 192.168.1.139
  - 127.0.0.1
  extraArgs:
    authorization-mode: Node,RBAC
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: 192.168.1.200:16443 # 负载均衡虚拟IP（VIP）和端口
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  external:  # 使用外部etcd
    endpoints:
    - https://192.168.1.124:2379 # etcd集群3个节点
    - https://192.168.1.132:2379
    - https://192.168.1.126:2379
    caFile: /opt/etcd/ssl/ca.pem # 连接etcd所需证书
    certFile: /opt/etcd/ssl/server.pem
    keyFile: /opt/etcd/ssl/server-key.pem
imageRepository: registry.aliyuncs.com/google_containers # 由于默认拉取镜像地址k8s.gcr.io国内无法访问，这里指定阿里云镜像仓库地址
kind: ClusterConfiguration
kubernetesVersion: v1.18.19 # K8s版本，与上面安装的一致
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16  # Pod网络，与下面部署的CNI网络组件yaml中保持一致
  serviceSubnet: 10.96.0.0/12  # 集群内部虚拟网络，Pod统一访问入口
scheduler: {}
---
### 如果集群使用IPvs网络模式进行调度，需要增加以下信息字段，还需要yum -y install ipvsadm 安装这个以便管理
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs  # kube-proxy 模式
```
开始初始化集群
```sh
[root@k8s-cluster-master01 k8s-init]# kubeadm init --config kubeadm-config.yaml

..........................................................

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

  kubeadm join 192.168.1.200:16443 --token 9037x2.tcaqnpaqkra9vsbw \
    --discovery-token-ca-cert-hash sha256:23e4b3729d998e3a97d3dd72989080572a0e5ca9e9a2cd708b5a8cc7bfd09f36 \
    --control-plane

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 192.168.1.200:16443 --token 9037x2.tcaqnpaqkra9vsbw \
    --discovery-token-ca-cert-hash sha256:23e4b3729d998e3a97d3dd72989080572a0e5ca9e9a2cd708b5a8cc7bfd09f36
```
初始化完成后，会有两个join的命令，带有 --control-plane 是用于加入组建多master集群的，不带的是加入节点的
拷贝kubectl使用的连接k8s认证文件到默认路径

```sh
[root@k8s-cluster-master01 k8s-init]#   mkdir -p $HOME/.kube
[root@k8s-cluster-master01 k8s-init]#   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
[root@k8s-cluster-master01 k8s-init]#   sudo chown $(id -u):$(id -g) $HOME/.kube/config
[root@k8s-cluster-master01 k8s-init]# kubectl get node -o wide
NAME                   STATUS     ROLES    AGE     VERSION    INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION           CONTAINER-RUNTIME
k8s-cluster-master01   NotReady   master   2m34s   v1.18.19   192.168.1.124   <none>        CentOS Linux 7 (Core)   3.10.0-1160.el7.x86_64   docker://19.3.15
```

### 2. 初始化Mster2

将Master1节点生成的证书拷贝到Master2

```sh
[root@k8s-cluster-master01 k8s-init]# scp -r /etc/kubernetes/pki/ 192.168.1.132:/etc/kubernetes/pki/
```

切换机器

```sh
[root@k8s-cluster-master02 ~]# kubeadm join 192.168.1.200:16443 --token 9037x2.tcaqnpaqkra9vsbw \
>     --discovery-token-ca-cert-hash sha256:23e4b3729d998e3a97d3dd72989080572a0e5ca9e9a2cd708b5a8cc7bfd09f36 \
>     --control-plane
```

初始化完成拷贝认证文件

```sh
[root@k8s-cluster-master02 ~]# mkdir -p $HOME/.kube
[root@k8s-cluster-master02 ~]# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
[root@k8s-cluster-master02 ~]# sudo chown $(id -u):$(id -g) $HOME/.kube/config
[root@k8s-cluster-master02 ~]# kubectl get node -o wide
NAME                   STATUS     ROLES    AGE     VERSION    INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION           CONTAINER-RUNTIME
k8s-cluster-master01   NotReady   master   7m29s   v1.18.19   192.168.1.124   <none>        CentOS Linux 7 (Core)   3.10.0-1160.el7.x86_64   docker://19.3.15
k8s-cluster-master02   NotReady   master   70s     v1.18.19   192.168.1.132   <none>        CentOS Linux 7 (Core)   3.10.0-1160.el7.x86_64   docker://19.3.15
```

配置命令补齐功能

```sh
[root@k8s-cluster-master01 k8s-init]# source /usr/share/bash-completion/bash_completion
[root@k8s-cluster-master01 k8s-init]# source <(kubectl completion bash)
[root@k8s-cluster-master01 k8s-init]# echo "source <(kubectl completion bash)" >> ~/.bashrc
```

默认master节点是有污点的，pod不会被调度上去，所以需要配置容忍度或者删除污点

```sh
[root@k8s-cluster-master01 k8s-init]# kubectl taint node k8s-cluster-master01 node-role.kubernetes.io/master-
[root@k8s-cluster-master02 k8s-init]# kubectl taint node k8s-cluster-master02 node-role.kubernetes.io/master-
```

### 3. 初始化普通node节点

```sh
[root@k8s-cluster-node01 ssl]# kubeadm join 192.168.1.200:16443 --token 9037x2.tcaqnpaqkra9vsbw \
>     --discovery-token-ca-cert-hash sha256:23e4b3729d998e3a97d3dd72989080572a0e5ca9e9a2cd708b5a8cc7bfd09f36
[root@k8s-cluster-master01 k8s-init]# kubectl get node
NAME                   STATUS     ROLES    AGE     VERSION
k8s-cluster-master01   NotReady   master   8m57s   v1.18.19
k8s-cluster-master02   NotReady   master   2m38s   v1.18.19
k8s-cluster-node01     NotReady   <none>   18s     v1.18.19
k8s-cluster-node02     NotReady   <none>   19s     v1.18.19
```

由于还没有安装CNI网络插件，所以是NotReady

### 4. 安装网络插件

```sh
[root@k8s-cluster-master01 k8s-init]# wget https://blog.linuxtian.top/data/calico.yaml
[root@k8s-master ~]# vim calico.yaml
3847               value: "k8s,bgp"  #在此行下面添加三行新的内容
3848             # add IP automatic detection
3849             - name: IP_AUTODETECTION_METHOD
3850               value: "interface=eth0"   ###根据自己系统的网卡名称进行修改
[root@k8s-master ~]# kubectl apply -f calico.yaml
```

查看pod启动状态，还在拉取镜像中

```sh
[root@k8s-cluster-master01 k8s-init]# kubectl get pods -A
NAMESPACE     NAME                                           READY   STATUS     RESTARTS   AGE
kube-system   calico-kube-controllers-77ff9c69dd-r2dhr       0/1     Pending    0          2m9s
kube-system   calico-node-cm952                              0/1     Init:0/3   0          2m10s
kube-system   calico-node-lnkfq                              0/1     Init:0/3   0          2m10s
kube-system   calico-node-s4njk                              0/1     Init:0/3   0          2m10s
kube-system   calico-node-xvf9c                              0/1     Init:0/3   0          2m10s
kube-system   coredns-7ff77c879f-bhttv                       0/1     Pending    0          20m
kube-system   coredns-7ff77c879f-wqkfv                       0/1     Pending    0          20m
kube-system   kube-apiserver-k8s-cluster-master01            1/1     Running    0          20m
kube-system   kube-apiserver-k8s-cluster-master02            1/1     Running    0          14m
kube-system   kube-controller-manager-k8s-cluster-master01   1/1     Running    2          20m
kube-system   kube-controller-manager-k8s-cluster-master02   1/1     Running    1          14m
kube-system   kube-proxy-7djth                               1/1     Running    0          12m
kube-system   kube-proxy-8vp8z                               1/1     Running    0          14m
kube-system   kube-proxy-nrxwg                               1/1     Running    0          12m
kube-system   kube-proxy-r7hcw                               1/1     Running    0          20m
kube-system   kube-scheduler-k8s-cluster-master01            1/1     Running    3          20m
kube-system   kube-scheduler-k8s-cluster-master02            1/1     Running    1          14m
```

```sh
[root@k8s-cluster-master01 k8s-init]# kubectl get pods -A -o wide
NAMESPACE     NAME                                           READY   STATUS            RESTARTS   AGE   IP               NODE                   NOMINATED NODE   READINESS GATES
kube-system   calico-kube-controllers-77ff9c69dd-r2dhr       1/1     Running           0          12m   10.244.161.1     k8s-cluster-node02     <none>           <none>
kube-system   calico-node-cm952                              1/1     Running           0          12m   192.168.1.126    k8s-cluster-node01     <none>           <none>
kube-system   calico-node-lnkfq                              1/1     Running           0          12m   192.168.1.139    k8s-cluster-node02     <none>           <none>
kube-system   calico-node-s4njk                              1/1     Running           0          12m   192.168.1.124    k8s-cluster-master01   <none>           <none>
kube-system   calico-node-xvf9c                              1/1     Running           0          12m   192.168.1.132    k8s-cluster-master02   <none>           <none>
kube-system   coredns-7ff77c879f-bhttv                       1/1     Running           0          30m   10.244.161.2     k8s-cluster-node02     <none>           <none>
kube-system   coredns-7ff77c879f-wqkfv                       1/1     Running           0          30m   10.244.180.193   k8s-cluster-node01     <none>           <none>
kube-system   kube-apiserver-k8s-cluster-master01            1/1     Running           0          31m   192.168.1.124    k8s-cluster-master01   <none>           <none>
kube-system   kube-apiserver-k8s-cluster-master02            1/1     Running           0          24m   192.168.1.132    k8s-cluster-master02   <none>           <none>
kube-system   kube-controller-manager-k8s-cluster-master01   1/1     Running           3          31m   192.168.1.124    k8s-cluster-master01   <none>           <none>
kube-system   kube-controller-manager-k8s-cluster-master02   1/1     Running           3          24m   192.168.1.132    k8s-cluster-master02   <none>           <none>
kube-system   kube-proxy-7djth                               1/1     Running           0          22m   192.168.1.126    k8s-cluster-node01     <none>           <none>
kube-system   kube-proxy-8vp8z                               1/1     Running           0          24m   192.168.1.132    k8s-cluster-master02   <none>           <none>
kube-system   kube-proxy-nrxwg                               1/1     Running           0          22m   192.168.1.139    k8s-cluster-node02     <none>           <none>
kube-system   kube-proxy-r7hcw                               1/1     Running           0          30m   192.168.1.124    k8s-cluster-master01   <none>           <none>
kube-system   kube-scheduler-k8s-cluster-master01            1/1     Running           4          31m   192.168.1.124    k8s-cluster-master01   <none>           <none>
kube-system   kube-scheduler-k8s-cluster-master02            1/1     Running           2          24m   192.168.1.132    k8s-cluster-master02   <none>           <none>
```

```sh
[root@k8s-cluster-master01 k8s-init]# kubectl get node
NAME                   STATUS   ROLES    AGE   VERSION
k8s-cluster-master01   Ready    master   31m   v1.18.19
k8s-cluster-master02   Ready    master   25m   v1.18.19
k8s-cluster-node01     Ready    <none>   23m   v1.18.19
k8s-cluster-node02     Ready    <none>   23m   v1.18.19
```

### 5. 验证K8S集群状态

```sh
[root@k8s-cluster-master01 k8s-init]# cat nginx-dp.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    k8s-app: nginx
spec:
  type: NodePort
  selector:
    k8s-app: nginx
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
    nodePort: 30080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    k8s-app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      k8s-app: nginx
  template:
    metadata:
      labels:
        k8s-app: nginx
    spec:
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:  # 硬策略
          - labelSelector:
              matchExpressions:
              - key: k8s-app
                operator: In
                values:
                - nginx
            topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        image: nginx:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
      restartPolicy: Always
```

```sh
[root@k8s-cluster-master01 k8s-init]# kubectl apply -f nginx-dp.yaml
[root@k8s-cluster-master01 k8s-init]# kubectl get pods,svc -o wide
NAME                         READY   STATUS    RESTARTS   AGE     IP               NODE                 NOMINATED NODE   READINESS GATES
pod/nginx-86546d6646-b2l9z   1/1     Running   0          4m12s   10.244.161.3     k8s-cluster-node02   <none>           <none>
pod/nginx-86546d6646-bkbr2   1/1     Running   0          4m12s   10.244.180.194   k8s-cluster-node01   <none>           <none>
pod/nginx-86546d6646-d2222   1/1     Running   0          4m12s   10.244.180.195   k8s-cluster-node01   <none>           <none>

NAME                 TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE     SELECTOR
service/kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP        73m     <none>
service/nginx        NodePort    10.105.192.153   <none>        80:30080/TCP   4m13s   k8s-app=nginx
```

进入容器测试

```sh
root@nginx-86546d6646-d2222:/# curl www.baidu.com  # 测试公网
<!DOCTYPE html>
<!--STATUS OK--><html> <head><meta http-equiv=content-type content=text/html;charset=utf-8><meta http-equiv=X-UA-Compatible content=IE=Edge><meta content=always name=referrer><link rel=stylesheet type=text/css href=http://s1.bdstatic.com/r/www/cache/bdorz/baidu.min.css><title>百度一下，你就知道</title></head> <body link=#0000cc> <div id=wrapper> <div id=head> <div class=head_wrapper> <div class=s_form> <div class=s_form_wrapper> <div id=lg> <img hidefocus=true src=//www.baidu.com/img/bd_logo1.png width=270 height=129> </div> <form id=form name=f action=//www.baidu.com/s class=fm> <input type=hidden name=bdorz_come value=1> <input type=hidden name=ie value=utf-8> <input type=hidden name=f value=8> <input type=hidden name=rsv_bp value=1> <input type=hidden name=rsv_idx value=1> <input type=hidden name=tn value=baidu><span class="bg s_ipt_wr"><input id=kw name=wd class=s_ipt value maxlength=255 autocomplete=off autofocus></span><span class="bg s_btn_wr"><input type=submit id=su value=百度一下 class="bg s_btn"></span> </form> </div> </div> <div id=u1> <a href=http://news.baidu.com name=tj_trnews class=mnav>新闻</a> <a href=http://www.hao123.com name=tj_trhao123 class=mnav>hao123</a> <a href=http://map.baidu.com name=tj_trmap class=mnav>地图</a> <a href=http://v.baidu.com name=tj_trvideo class=mnav>视频</a> <a href=http://tieba.baidu.com name=tj_trtieba class=mnav>贴吧</a> <noscript> <a href=http://www.baidu.com/bdorz/login.gif?login&amp;tpl=mn&amp;u=http%3A%2F%2Fwww.baidu.com%2f%3fbdorz_come%3d1 name=tj_login class=lb>登录</a> </noscript> <script>document.write('<a href="http://www.baidu.com/bdorz/login.gif?login&tpl=mn&u='+ encodeURIComponent(window.location.href+ (window.location.search === "" ? "?" : "&")+ "bdorz_come=1")+ '" name="tj_login" class="lb">登录</a>');</script> <a href=//www.baidu.com/more/ name=tj_briicon class=bri style="display: block;">更多产品</a> </div> </div> </div> <div id=ftCon> <div id=ftConw> <p id=lh> <a href=http://home.baidu.com>关于百度</a> <a href=http://ir.baidu.com>About Baidu</a> </p> <p id=cp>&copy;2017&nbsp;Baidu&nbsp;<a href=http://www.baidu.com/duty/>使用百度前必读</a>&nbsp; <a href=http://jianyi.baidu.com/ class=cp-feedback>意见反馈</a>&nbsp;京ICP证030173号&nbsp; <img src=//www.baidu.com/img/gs.gif> </p> </div> </div> </div> </body> </html>
root@nginx-86546d6646-d2222:/# curl 10.244.180.194   # 测试pod网络
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
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
root@nginx-86546d6646-d2222:/# curl 10.105.192.153  # 测试service网络
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
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
```

### 6. 使用命令初始化集群

```sh
之所用init文件初始化集群是因为ETCD是外置的，不是以pod方式交付到集群内的，而ETCD内置的话可以用下面的方式初始化集群
[root@k8s-cluster-master01 k8s-init]# kubeadm init \
--apiserver-advertise-address=192.168.1.124 \
--control-plane-endpoint=192.168.1.200:16443 \
--apiserver-bind-port=6443 \
--kubernetes-version=v1.18.19 \
--pod-network-cidr=10.100.0.0/16 \
--image-repository=registry.cn-hangzhou.aliyuncs.com/google_containers \
--ignore-preflight-errors=swap
```

然后生成加入master角色key，用来其他节点加入master并成为master角色的时候使用，所以这里就不需要拷贝pki证书文件到其他机器了
```sh
[root@k8s-cluster-master01 k8s-init]# kubeadm init phase upload-certs --upload-certs
.........
[upload-certs] Using certificate key:
c420b5dd3c732d4211742096868df8fdb73858907e5994dde187749e47af7e53
```
```sh

初始化其他节点为master角色
[root@k8s-cluster-master02 ~]# kubeadm join 192.168.1.200:16443 --token 9037x2.tcaqnpaqkra9vsbw \
--discovery-token-ca-cert-hash sha256:23e4b3729d998e3a97d3dd72989080572a0e5ca9e9a2cd708b5a8cc7bfd09f36 \
--control-plane \
--certificate-key c420b5dd3c732d4211742096868df8fdb73858907e5994dde187749e47af7e53
```
最后在`kubectl edit cm kube-proxy -n kube-system` 修改mode为`"ipvs"`即可

```sh
[root@k8s-cluster-master02]# kubectl edit cm kube-proxy -n kube-system
```

### 7. 安装metrics server

Metrics Server是Kubernetes内置自动伸缩管道的一个可伸缩、高效的容器资源度量来源。

Metrics Server从Kubelets收集资源指标，并通过Metrics API将它们暴露在Kubernetes apiserver中，供水平Pod Autoscaler和垂直Pod Autoscaler使用。kubectl top还可以访问Metrics API，这使得调试自动伸缩管道变得更容易。

Metrics Server不是用于非自动伸缩的目的。例如，不要将其用于将指标转发给监视解决方案，或者作为监视解决方案指标的来源。在这种情况下，请直接从Kubelet /metrics/resource端点收集度量。

Metrics Server提供

- 在大多数集群上工作的单个部署
- 快速自动缩放，每15秒收集一次指标。
- 资源效率，为集群中的每个节点使用1毫秒的CPU内核和2 MB的内存。
- 可扩展支持多达5000个节点群集。

> 下载地址：https://github.com/kubernetes-sigs/metrics-server

```sh
[root@k8s-cluster-master01 k8s-init]# wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.5.2/components.yaml
[root@k8s-cluster-master01 k8s-init]# vim components.yaml
...........
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        - --kubelet-insecure-tls    # 添加这一条参数，不然会报错
        image: bitnami/metrics-server:0.5.2    # 镜像修改为国内能拉取下来的镜像
[root@k8s-cluster-master01 k8s-init]# kubectl apply -f components.yaml
```
