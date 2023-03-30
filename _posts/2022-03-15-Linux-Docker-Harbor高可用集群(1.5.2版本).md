---
layout: post
title: Linux-Docker-Harbor高可用集群(1.5.2版本)
date: 2022-03-15
tags: Linux-Docker
---

## 一、Harbor仓库介绍

> 我们在日常Docker容器使用和管理过程中，渐渐发现部署企业私有仓库往往是很有必要的, 它可以帮助你管理企业的一些敏感镜像, 同时由于Docker Hub的下载速度和GFW的原因, 往往需要将一些无法直接下载的镜像导入本地私有仓库. 而Harbor就是部署企业私有仓库的一个不二之选。Harbor是由VMware公司开源的企业级的Docker Registry管理项目，Harbor主要提供Dcoker Registry管理UI，提供的功能包括：基于角色访问的控制权限管理(RBAC)、AD/LDAP集成、日志审核、管理界面、自我注册、镜像复制和中文支持等。Harbor的目标是帮助用户迅速搭建一个企业级的Docker registry服务。它以Docker公司开源的registry为基础，额外提供了如下功能:

- 基于角色的访问控制(Role Based Access Control)
- 基于策略的镜像复制(Policy based image replication)
- 镜像的漏洞扫描(Vulnerability Scanning)
- AD/LDAP集成(LDAP/AD support)
- 镜像的删除和空间清理(Image deletion & garbage collection)
- 友好的管理UI(Graphical user portal)
- 审计日志(Audit logging)
- RESTful API
-  部署简单(Easy deployment)

> Harbor的所有组件都在Dcoker中部署，所以Harbor可使用Docker Compose快速部署。**需要特别注意：**由于**Harbor是基于Docker Registry V2版本**，所以**docker必须大于等于1.10.0版本**，**docker-compose必须要大于1.6.0版本**！

## 二、Harbor仓库结构

> Harbor的每个组件都是以Docker容器的形式构建的，可以使用Docker Compose来进行部署。如果环境中使用了kubernetes，Harbor也提供了kubernetes的配置文件。**Harbor大概需要以下几个容器组成**：**ui**(Harbor的核心服务)、**log**(运行着rsyslog的容器，进行日志收集)、**mysql**(由官方mysql镜像构成的数据库容器)、**Nginx**(使用Nginx做反向代理)、**registry**(官方的Docker registry)、**adminserver**(Harbor的配置数据管理器)、**jobservice**(Harbor的任务管理服务)、**redis**(用于存储session)。
>
> 注意：不过在1.6.0版本以后，harbor的数据库采用的是postgres

**多harbor实例共享后端存储**

共享后端存储算是一种比较标准的方案，就是多个Harbor实例共享同一个后端存储，任何一个实例持久化到存储的镜像，都可被其他实例中读取。通过前置LB进来的请求，可以分流到不同的实例中去处理，这样就实现了负载均衡，也避免了单点故障：

![](/images/posts/Harbor高可用集群/1.png)

这个方案在实际生产环境中部署需要考虑三个问题：

1. 共享存储的选取，Harbor的后端存储目前支持AWS S3、Openstack Swift, Ceph等，在我们的实验环境里，就直接使用nfs
2. Session在不同的实例上共享，这个现在其实已经不是问题了，在最新的harbor中，默认session会存放在redis中，我们只需要将redis独立出来即可。可以通过redis sentinel或者redis cluster等方式来保证redis的可用性。在我们的实验环境里，仍然使用单台redis
3. Harbor多实例数据库问题，这个也只需要将harbor中的数据库拆出来独立部署即可。让多实例共用一个外部数据库，数据库的高可用也可以通过数据库的高可用方案保证。

## 三、Harbor高可用环境部署

| 主机名       | IP            | 用途                  | VIP           |
| ------------ | ------------- | --------------------- | ------------- |
| harbor01     | 192.168.20.51 | Harbor镜像仓库-主     |               |
| harbor02     | 192.168.20.52 | Harbor镜像仓库-备     |               |
| harbor03     | 192.168.20.53 | Harbor镜像仓库-备     |               |
| keepalived01 | 192.168.20.54 | 高可用漂移地址        | 192.168.20.60 |
| keepalived02 | 192.168.20.55 | 高可用漂移地址        |               |
| storage-nfs  | 192.168.20.56 | harbor共享存储+mysql+redis |               |

### 1. NFS机器配置

```sh
[root@storage-nfs ~]# yum -y install nfs-utils
[root@storage-nfs ~]# mkdir /data
[root@storage-nfs ~]# systemctl enable nfs
[root@storage-nfs ~]# vim /etc/exports
/data 192.168.20.0/24(rw,no_root_squash,async)
[root@storage-nfs ~]# systemctl restart nfs
```

**安装harbor外置MySQL和redis**

```
[root@storage-nfs ~]# wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
[root@storage-nfs ~]# yum -y install docker-ce-19.03.15 docker-ce-cli-19.03.15 containerd.io
[root@storage-nfs ~]# systemctl start docker
[root@storage-nfs ~]# systemctl enable docker
[root@storage-nfs ~]# vim /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "insecure-registries": ["registry.access.redhat.com","quay.io"],
  "registry-mirrors": ["https://q2gr04ke.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true
}
[root@storage-nfs ~]# systemctl daemon-reload && systemctl restart docker
```

**编写docker-compose文件**

```sh
[root@storage-nfs ~]# vim docker-compose.yml
version: '3'
services:
  mysql-server:
    hostname: mysql-server
    container_name: mysql-server
    image: mysql:5.7
    restart: always
    network_mode: host
    volumes:
      - /var/lib/mysql57/data:/var/lib/mysql
    command: --character-set-server=utf8
    environment:
      MYSQL_ROOT_PASSWORD: 123456
  redis:
    hostname: redis-server
    container_name: redis-server
    image: redis:3
    restart: always
    network_mode: host
[root@storage-nfs ~]# wget https://github.com/docker/compose/releases/download/1.28.6/docker-compose-Linux-x86_64
[root@storage-nfs ~]# chmod +x docker-compose-Linux-x86_64 && mv docker-compose-Linux-x86_64 /usr/bin/docker-compose
[root@storage-nfs ~]# docker-compose up -d
[root@storage-nfs ~]# docker ps
e0ac0dcd2bc4        mysql:5.7           "docker-entrypoint.s…"   7 hours ago         Up 7 hours                              mysql-server
caf02a27fd69        redis:3             "docker-entrypoint.s…"   7 hours ago         Up 7 hours                              redis-server
```

**导入registry数据库**

配置好了mysql以后，还需要往mysql数据库中导入harbor registry库，我们安装了一个单机版harbor，启动了一个mysql，里面有一个registry数据库，直接导出来，然后再导入到新数据库中：



这里可以不用再单独启动harbor了，我这里直接贴一个链接拿去用即可

```sh
[root@storage-nfs ~]# wget http://blog.linuxtian.top:8080/6-harbor/releases/registry/registry.dump
[root@storage-nfs ~]# docker cp registry.dump mysql-server:/registry.dump
[root@storage-nfs ~]# docker exec -it mysql-server bash
root@mysql-server:/# mysql -uroot -p
Enter password: 123456
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 59
Server version: 5.7.36 MySQL Community Server (GPL)

Copyright (c) 2000, 2021, Oracle and/or its affiliates.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql> source /registry.dump
```

### 3. 部署harbor机器

**挂在NFS共享存储**

```sh
[root@harbor01 ~]# mkdir -pv /data/cert && mount -t nfs 192.168.20.56:/data /data
[root@harbor01 ~]# vim /etc/fstab
192.168.20.56:/data /data nfs defaults 0 0
```

**自签证书**

```sh
[root@harbor01 ~]# cd /data/cert/
[root@harbor01 cert]#
[root@harbor01 cert]# openssl genrsa -des3 -out server.key 1024
Generating RSA private key, 1024 bit long modulus
.................++++++
.............++++++
e is 65537 (0x10001)
Enter pass phrase for server.key:123456
Verifying - Enter pass phrase for server.key:123456
[root@harbor01 cert]# openssl rsa -in server.key -out server.key
Enter pass phrase for server.key:123456
writing RSA key
[root@harbor01 cert]# openssl req -new -key server.key -out server.csr
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [XX]:CN           ########
State or Province Name (full name) []:Beijing       ########
Locality Name (eg, city) [Default City]:Beijing       ########
Organization Name (eg, company) [Default Company Ltd]:tianxiang         #########
Organizational Unit Name (eg, section) []:tianxiang
Common Name (eg, your name or your server's hostname) []:hub.tianxiang.com           #######
Email Address []:2099637909@qq.com          ######

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

**配置harbor**

harbor版本：https://github.com/goharbor/harbor/releases/tag/v1.5.2

```sh
[root@harbor01 src]# pwd
/usr/local/src
[root@harbor01 src]# wget https://storage.googleapis.com/harbor-releases/harbor-offline-installer-v1.5.2.tgz
[root@harbor01 src]# ls
harbor-offline-installer-v1.5.2.tgz
[root@harbor01 src]# tar xvf harbor-offline-installer-v1.5.2.tgz
[root@harbor01 src]# cd harbor
[root@harbor01 harbor]# cp harbor.cfg harbor.cfg.bak
[root@harbor01 harbor]# cat harbor.cfg |grep -v '^$' |grep -v '^#'
_version = 1.5.0
hostname = hub.tianxiang.com      ##访问域名
ui_url_protocol = https    ##https请求
max_job_workers = 50
customize_crt = on
ssl_cert = /data/cert/server.crt        ##证书位置
ssl_cert_key = /data/cert/server.key   ##证书位置
secretkey_path = /data     ##数据存储目录
admiral_url = NA
log_rotate_count = 50
log_rotate_size = 200M
http_proxy =
https_proxy =
no_proxy = 127.0.0.1,localhost,ui
email_identity =
email_server = smtp.mydomain.com
email_server_port = 25
email_username = sample_admin@mydomain.com
email_password = abc
email_from = admin <sample_admin@mydomain.com>
email_ssl = false
email_insecure = false
harbor_admin_password = Harbor12345
auth_mode = db_auth
ldap_url = ldaps://ldap.mydomain.com
ldap_basedn = ou=people,dc=mydomain,dc=com
ldap_uid = uid
ldap_scope = 2
ldap_timeout = 5
ldap_verify_cert = true
ldap_group_basedn = ou=group,dc=mydomain,dc=com
ldap_group_filter = objectclass=group
ldap_group_gid = cn
ldap_group_scope = 2
self_registration = on
token_expiration = 30
project_creation_restriction = everyone
db_host = 192.168.20.54      ##mysql数据库地址
db_password = 123456        ##mysql数据库密码
db_port = 3306            ##端口号
db_user = root        ##root用户
redis_url = 192.168.20.54:6379      ##redis数据库地址和端口
clair_db_host = postgres
clair_db_password = password
clair_db_port = 5432
clair_db_username = postgres
clair_db = postgres
uaa_endpoint = uaa.mydomain.org
uaa_clientid = id
uaa_clientsecret = secret
uaa_verify_cert = true
uaa_ca_cert = /path/to/ca.pem
registry_storage_provider_name = filesystem
registry_storage_provider_config =
```

**启动harbor**

```sh
[root@harbor01 harbor]# cp docker-compose.yml docker-compose.yml.bak
[root@harbor01 harbor]# cp ha/docker-compose.yml .
[root@harbor01 harbor]# ./prepare
Clearing the configuration file: ./common/config/adminserver/env
Clearing the configuration file: ./common/config/ui/env
Clearing the configuration file: ./common/config/ui/app.conf
Clearing the configuration file: ./common/config/ui/private_key.pem
Clearing the configuration file: ./common/config/db/env
Clearing the configuration file: ./common/config/jobservice/env
Clearing the configuration file: ./common/config/jobservice/config.yml
Clearing the configuration file: ./common/config/registry/config.yml
Clearing the configuration file: ./common/config/registry/root.crt
Clearing the configuration file: ./common/config/nginx/cert/server.crt
Clearing the configuration file: ./common/config/nginx/cert/server.key
Clearing the configuration file: ./common/config/nginx/nginx.conf
Clearing the configuration file: ./common/config/log/logrotate.conf
loaded secret from file: /data/secretkey
Generated configuration file: ./common/config/nginx/nginx.conf
Generated configuration file: ./common/config/adminserver/env
Generated configuration file: ./common/config/ui/env
Generated configuration file: ./common/config/registry/config.yml
Generated configuration file: ./common/config/db/env
Generated configuration file: ./common/config/jobservice/env
Generated configuration file: ./common/config/jobservice/config.yml
Generated configuration file: ./common/config/log/logrotate.conf
Generated configuration file: ./common/config/jobservice/config.yml
Generated configuration file: ./common/config/ui/app.conf
Generated certificate, key file: ./common/config/ui/private_key.pem, cert file: ./common/config/registry/root.crt
The configuration files are ready, please use docker-compose to start the service.
[root@harbor01 harbor]# ./install.sh
·····················
·····················
[Step 3]: checking existing instance of Harbor ...


[Step 4]: starting Harbor ...
Creating network "harbor_harbor" with the default driver
Creating harbor-log ... done
Creating registry           ... done
Creating harbor-adminserver ... done
Creating harbor-ui          ... done
Creating harbor-jobservice  ... done
Creating nginx              ... done

✔ ----Harbor has been installed and started successfully.----

Now you should be able to visit the admin portal at https://hub.tianxiang.com.
For more details, please visit https://github.com/vmware/harbor .
[root@harbor01 harbor]# docker-compose ps
       Name                     Command                  State                                    Ports                              
-------------------------------------------------------------------------------------------------------------------------------------
harbor-adminserver   /harbor/start.sh                 Up (healthy)                                                                   
harbor-jobservice    /harbor/start.sh                 Up                                                                             
harbor-log           /bin/sh -c /usr/local/bin/ ...   Up (healthy)   127.0.0.1:1514->10514/tcp                                       
harbor-ui            /harbor/start.sh                 Up (healthy)                                                                   
nginx                nginx -g daemon off;             Up (healthy)   0.0.0.0:443->443/tcp, 0.0.0.0:4443->4443/tcp, 0.0.0.0:80->80/tcp
registry             /entrypoint.sh serve /etc/ ...   Up (healthy)   5000/tcp
```

**配置开机自启动harbor**

```sh
[root@harbor01 harbor]# vim /etc/systemd/system/harbor.service

[Unit]
Description=Harbor
After=docker.service systemd-networkd.service systemd-resolved.service
Requires=docker.service
Documentation=http://github.com/vmware/harbor

[Service]
Type=oneshot
ExecStartPre=/usr/bin/docker-compose -f /usr/local/src/harbor/docker-compose.yml down
# #需要注意harbor的安装位置
ExecStart=/usr/bin/docker-compose -f /usr/local/src/harbor/docker-compose.yml up -d
ExecStop=/usr/bin/docker-compose -f /usr/local/src/harbor/docker-compose.yml down
# This service shall be considered active after start
RemainAfterExit=yes

[Install]
# Components of this application should be started at boot time
WantedBy=multi-user.target
[root@harbor01 harbor]# systemctl enable harbor
```

![](/images/posts/Harbor高可用集群/2.png)

其余两台harbor02和harbor03同样方法部署

### 4. 配置LB负载机器

**两台机器同样操作**

```sh
[root@keepalived01 ~]# touch /etc/yum.repos.d/nginx.repo
[root@keepalived01 ~]# cat > /etc/yum.repos.d/nginx.repo <<EOF
# nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/7/x86_64/
gpgcheck=0
enabled=1
EOF
[root@keepalived01 ~]# yum install -y nginx nginx-all-modules
[root@keepalived01 ~]# cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
[root@keepalived01 ~]# cat /etc/nginx/nginx.conf
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {

    log_format  main  '$remote_addr - $upstream_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/harbor-access.log  main;

    client_max_body_size 2G;   #配置请求体缓存区大小,不配置这个，推送镜像会报413错误

    client_body_buffer_size 128k;  #设置客户端请求体最大值

    fastcgi_intercept_errors on;

upstream harbor{

       #ip_hash; 这里禁用注释掉了ip_hash算法，因为我们的目的是要求的负载轮询，如果用ip_hash就起不到负载的作用了。
       #上游服务器节点，权重 5(数字越大权重越大)，30 秒内访问失败次数大于等于 2 次，将 在 30 秒内停止访问此节点，30 秒后计数器清零，可以重新访问
       server 192.168.20.51:443 weight=5 max_fails=2 fail_timeout=30s;   # harbor01
       server 192.168.20.52:443 weight=3 max_fails=2 fail_timeout=30s;   # harbor02
       server 192.168.20.53:443 weight=1 max_fails=2 fail_timeout=30s;   # harbor03
    }


    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    server {
        listen       443 ssl;
        server_name  _;
        ssl_certificate /etc/nginx/cert/server.crt;
        ssl_certificate_key /etc/nginx/cert/server.key;
        location / {
             #设置主机头和客户端真实地址，以便服务器获取客户端真实IP
             proxy_set_header Host $http_host;
             proxy_set_header X-Real-IP $remote_addr;
             proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
             proxy_set_header X-Nginx-Proxy true;
             # 如果后端服务器返回502、504、错误等错误，自动跳转到upstream负载均衡池中的另一台服务器，实现故障转移
             # 不过上面用的ip_hash，不用配置这个也行，此配置针对于普通的轮询算法
             proxy_next_upstream http_502 http_504 error timeout invalid_header;
             # 指定跳转服务器池，名字要与upstream设定的相同，还要注意是http协议还是https协议，如果做了强跳转不用区分也行
             proxy_pass https://harbor;
             proxy_redirect off;
        }
    }
}
[root@keepalived01 ~]# mkdir -pv /etc/nginx/cert
[root@keepalived01 ~]# scp 192.168.20.51:/data/cert/* /etc/nginx/cert
[root@keepalived01 ~]# systemctl start nginx
[root@keepalived01 ~]# systemctl enable nginx.service
Created symlink from /etc/systemd/system/multi-user.target.wants/nginx.service to /usr/lib/systemd/system/nginx.service.
```
> 注意：用上面的加权轮询算法做负载可能会出现以下问题
- docker login 可能会报错`failed with status: 401 Unauthorized`
- 推送镜像或拉取镜像报错`unauthorized: authentication required`
>
> 如果遇到以上问题，那么需要取消`ip_hash`的注释，并且这里要粗略的解释一下为什么要用`ip_hash`负载均衡，因为如果使用的轮询算法，每次访问的时候都会以负载的方式访问harbor节点，如果要用命令行去`docker login`登陆你会发现只有第一次登陆成功，之后所有次数的登陆都会提示`Error response from daemon: login attempt to https://hub.tianxiang.com/v2/ failed with status: 401 Unauthorized`包括你推送镜像都无法推送，那是因为，你第一次login可能是login的harbor01机器，然后你推送或者拉取镜像的时候，有可能是从harbor02或者harbor03进行操作的，然后就会提示`unauthorized: authentication required`
>
> 注意：stream 模块里面不支持ip_hash算法

**浏览测试访问**

![](/images/posts/Harbor高可用集群/3.png)

**查看日志**

发现源流量是harbor01机器提供的，输出正确

![](/images/posts/Harbor高可用集群/4.png)

配置keepalived

- 主节点

```sh
[root@keepalived01 ~]# yum -y install keepalived
[root@keepalived01 ~]# cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak
cat /etc/keepalived/keepalived.conf
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
    interface ens33  # 修改为实际网卡名
    virtual_router_id 51 # VRRP 路由 ID实例，每个实例是唯一的
    priority 100    # 优先级，备服务器设置 90
    advert_int 1    # 指定VRRP 心跳包通告间隔时间，默认1秒
    authentication {
        auth_type PASS      
        auth_pass 1111
    }  
    # 虚拟IP
    virtual_ipaddress {
        192.168.20.60/24
    }
    track_script {
        check_nginx
    }
}
[root@keepalived01 ~]# vim /etc/keepalived/check_nginx.sh
#!/bin/bash
count=$(ss -antp |grep 443 |egrep -cv "grep|$$")

if [ "$count" -eq 0 ];then
    exit 1
else
    exit 0
fi
[root@keepalived01 ~]# chmod +x /etc/keepalived/check_nginx.sh
```

- 备节点

```sh
[root@keepalived02 ~]# vim /etc/keepalived/keepalived.conf
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
    interface ens33
    virtual_router_id 51 # VRRP 路由 ID实例，每个实例是唯一的
    priority 90
    advert_int 1
    authentication {
        auth_type PASS      
        auth_pass 1111
    }  
    virtual_ipaddress {
        192.168.20.60/24
    }
    track_script {
        check_nginx
    }
}
[root@keepalived02 ~]# vim /etc/keepalived/check_nginx.sh
#!/bin/bash
count=$(ss -antp |grep 443 |egrep -cv "grep|$$")

if [ "$count" -eq 0 ];then
    exit 1
else
    exit 0
fi
[root@keepalived02 ~]# chmod +x /etc/keepalived/check_nginx.sh
```

**启动keepalived**

```sh
[root@keepalived01 ~]# systemctl start keepalived && systemctl enable keepalived
[root@keepalived01 ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:16:44:b4 brd ff:ff:ff:ff:ff:ff
    inet 192.168.20.55/24 brd 192.168.20.255 scope global noprefixroute ens33
       valid_lft forever preferred_lft forever
    inet 192.168.20.60/24 scope global secondary ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::f0df:3190:3fbb:cdf/64 scope link tentative noprefixroute dadfailed
       valid_lft forever preferred_lft forever
    inet6 fe80::f98:400:82e8:ae42/64 scope link noprefixroute
       valid_lft forever preferred_lft forever
    inet6 fe80::2e4c:a397:81:fa8f/64 scope link tentative noprefixroute dadfailed
       valid_lft forever preferred_lft forever
[root@keepalived02 ~]# systemctl start keepalived && systemctl enable keepalived
```

浏览器访问测试

https://192.168.20.60

也可以本地host解析配置域名访问

![](/images/posts/Harbor高可用集群/5.png)

### 5. 测试集群

**拉去推送镜像测试**

首先机器需要登录到私有仓库

```sh
[root@storage-nfs ~]# mkdir /etc/docker/certs.d/hub.tianxiang.com -pv
[root@storage-nfs ~]# cp /data/harbor/cert/server.crt /etc/docker/certs.d/hub.tianxiang.com
# 由于我们没有DNS服务器，所以需要将域名手动配置hosts解析
[root@storage-nfs ~]# vim /etc/hosts

127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.20.60 hub.tianxiang.com
[root@storage-nfs ~]# docker login hub.tianxiang.com -u admin -p Harbor12345
```

创建一些项目名称

![](/images/posts/Harbor高可用集群/6.png)

拉取公网镜像进行修改tag推送至私有仓库

```sh
[root@storage-nfs ~]# docker pull nginx
Using default tag: latest
latest: Pulling from library/nginx
a2abf6c4d29d: Pull complete
a9edb18cadd1: Pull complete
589b7251471a: Pull complete
186b1aaa4aa6: Pull complete
b4df32aa5a72: Pull complete
a0bcbecc962e: Pull complete
Digest: sha256:0d17b565c37bcbd895e9d92315a05c1c3c9a29f762b011a10c54a66cd53c9b31
Status: Downloaded newer image for nginx:latest
docker.io/library/nginx:latest
[root@storage-nfs ~]# docker tag nginx:latest hub.tianxiang.com/nginx/nginx:latest
[root@storage-nfs ~]# docker push hub.tianxiang.com/nginx/nginx
The push refers to repository [hub.tianxiang.com/nginx/nginx]
d874fd2bc83b: Layer already exists
32ce5f6a5106: Layer already exists
f1db227348d0: Layer already exists
b8d6e692a25e: Layer already exists
e379e8aedd4d: Pushed
2edcec3590a4: Pushed
latest: digest: sha256:ee89b00528ff4f02f2405e4ee221743ebc3f8e8dd0bfd5c4c20a2fa2aaa7ede3 size: 1570
```

![](/images/posts/Harbor高可用集群/7.png)

**关机测试集群**

关闭harbor01，浏览器访问harbor，查看LB nginx日志，发现流量切换到了harbor02上面

![](/images/posts/Harbor高可用集群/8.png)

此时你推送镜像应该是不可以的，因为当时的login登陆的是harbor01机器，现在01机器已经挂了，重新登陆的话应该就是harbor02机器

但是！我也不知道什么原因，直接推送竟然成功了。

```sh
[root@storage-nfs ~]# docker tag tomcat:latest hub.tianxiang.com/tomcat/tomcat:latest
[root@storage-nfs ~]# docker push hub.tianxiang.com/tomcat/tomcat:latest
The push refers to repository [hub.tianxiang.com/tomcat/tomcat]
3e2ed6847c7a: Pushed
bd2befca2f7e: Pushed
59c516e5b6fa: Pushed
3bb5258f46d2: Pushed
832e177bb500: Pushed
f9e18e59a565: Pushed
26a504e63be4: Pushed
8bf42db0de72: Pushed
31892cc314cb: Pushed
11936051f93b: Pushed
latest: digest: sha256:e6d65986e3b0320bebd85733be1195179dbce481201a6b3c1ed27510cfa18351 size: 2422
```

并且拉取镜像也没问题

```sh
[root@harbor02 ~]# docker pull hub.tianxiang.com/tomcat/tomcat:latest
latest: Pulling from tomcat/tomcat
0e29546d541c: Pull complete
9b829c73b52b: Pull complete
cb5b7ae36172: Pull complete
6494e4811622: Pull complete
668f6fcc5fa5: Pull complete
dc120c3e0290: Pull complete
8f7c0eebb7b1: Pull complete
77b694f83996: Pull complete
0f611256ec3a: Pull complete
4f25def12f23: Pull complete
Digest: sha256:e6d65986e3b0320bebd85733be1195179dbce481201a6b3c1ed27510cfa18351
Status: Downloaded newer image for hub.tianxiang.com/tomcat/tomcat:latest
hub.tianxiang.com/tomcat/tomcat:latest
[root@harbor02 ~]# docker pull hub.tianxiang.com/redis/redis:3
3: Pulling from redis/redis
f17d81b4b692: Pull complete
b32474098757: Pull complete
8980cabe8bc2: Pull complete
58af19693e78: Pull complete
a977782cf22d: Pull complete
9c1e268980b7: Pull complete
Digest: sha256:562e944371527d6e11d396fe43fde17c30e28c25c23561b2322db3905cbc71dd
Status: Downloaded newer image for hub.tianxiang.com/redis/redis:3
hub.tianxiang.com/redis/redis:3
```
