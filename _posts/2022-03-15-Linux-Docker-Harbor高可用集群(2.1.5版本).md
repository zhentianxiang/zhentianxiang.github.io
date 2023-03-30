---
layout: post
title: Linux-Docker-Harbor高可用集群(2.1.5版本)
date: 2022-03-15
tags: Linux-Docker
---

----------------------------------------------



## 一、部署高版本harbor2.1.5

> 接上篇文章，本篇只是换了一个高版本的harbor做高可用实验，大体流程一样，只是针对于外置组件不同而已

## 二、集群信息

| 主机名       | IP            | 用途                         | VIP           |
| ------------ | ------------- | ---------------------------- | ------------- |
| harbor01     | 192.168.20.51 | Harbor镜像仓库-主            |               |
| harbor02     | 192.168.20.52 | Harbor镜像仓库-备            |               |
| harbor03     | 192.168.20.53 | Harbor镜像仓库-备            |               |
| keepalived01 | 192.168.20.54 | 高可用漂移地址+postgre+redis | 192.168.20.60 |
| keepalived02 | 192.168.20.55 | 高可用漂移地址+postgre+redis |               |
| storage-nfs  | 192.168.20.56 | harbor共享存储              |              |

## 三、准备部署

### 1. 准备NFS共享存储

```sh
[root@storage-nfs ~]# yum -y install nfs-utils
[root@storage-nfs ~]# vim /etc/exports
/nfs/harbor_storage 192.168.20.0/24(rw,no_root_squash,async)
[root@storage-nfs ~]# mkdir -pv /nfs/{harbor_storage,docker_compose}
[root@storage-nfs ~]# systemctl enable nfs && systemctl restart nfs
```
客户端挂载 即harbor01，harbor02，harbor03，keepalived01，keepalived02

### 2. 启动外置postgre和redis

首先单节点启动harbor，查看各个组件的镜像版本，争取使用一致的版本，然后就可以废掉这个harbor了，只需要了解用的什么版本的镜像即可

```sh
[root@localhost ~]# docker-compose ps
      Name                     Command                       State                     Ports          
------------------------------------------------------------------------------------------------------
harbor-core         /harbor/entrypoint.sh            Up (health: starting)                            
harbor-db           /docker-entrypoint.sh            Up (health: starting)                            
harbor-jobservice   /harbor/entrypoint.sh            Up (health: starting)                            
harbor-log          /bin/sh -c /usr/local/bin/ ...   Up (healthy)            127.0.0.1:1514->10514/tcp
harbor-portal       nginx -g daemon off;             Up (healthy)                                     
nginx               nginx -g daemon off;             Up (health: starting)   0.0.0.0:80->8080/tcp     
redis               redis-server /etc/redis.conf     Up (healthy)                                     
registry            /home/harbor/entrypoint.sh       Up (healthy)                                     
registryctl         /home/harbor/start.sh            Up (healthy)
```

**查看DB的版本信息**

```sh
[root@localhost ~]# docker exec -it harbor-db bash
postgres [ / ]$ psql
psql (9.6.21)
Type "help" for help.
```

那么为此我们也是用9.6.21版本的

**查看redis版本信息**

```sh
[root@localhost1 ~]# docker exec -it redis bash
redis [ ~ ]$ redis-server --version
Redis server v=4.0.14 sha=00000000:0 malloc=jemalloc-4.0.3 bits=64 build=9d6e4bf0eac9888
```

同样用一致的

```sh
[root@keepalived01 ~]# mkdir /var/lib/harbor_DB && cd /var/lib/harbor_DB && vim docker-compose.yml
```

```yaml
version: "3"

networks:
  harbor:
    driver: bridge

services:
  registry:
    image: postgres:9.6.21
    container_name: harbor-registry
    restart: always
    environment:
      POSTGRES_DB: registry
      POSTGRES_PASSWORD: root123
    volumes:
      - $PWD/postgres/registry:/var/lib/postgresql/data
    networks:
      - harbor
    ports:
      - 20010:5432
  clair:
    image: postgres:9.6.21
    container_name: harbor-clair
    restart: always
    environment:
      POSTGRES_DB: clair
      POSTGRES_PASSWORD: root123
    volumes:
      - $PWD/postgres/clair:/var/lib/postgresql/data
    networks:
      - harbor
    ports:
      - 20011:5432
  notarysigner:
    image: postgres:9.6.21
    container_name: harbor-notarysigner
    restart: always
    environment:
      POSTGRES_DB: notarysigner
      POSTGRES_PASSWORD: root123
    volumes:
      - $PWD/postgres/notarysigner:/var/lib/postgresql/data
    networks:
      - harbor
    ports:
      - 20012:5432
  notaryserver:
    image: postgres:9.6.21
    container_name: harbor-notaryserver
    restart: always
    environment:
      POSTGRES_DB: notaryserver
      POSTGRES_PASSWORD: root123
    volumes:
      - $PWD/postgres/notaryserver:/var/lib/postgresql/data
    networks:
      - harbor
    ports:
      - 20013:5432
  Redis:
    image: redis:4.0.14
    container_name: harbor-redis
    restart: always
    volumes:
      - $PWD/redis/:/var/lib/redis
    networks:
      - harbor
    ports:
      - 20000:6379
```

**安装docker和docker-compose**

harbor机器和keepalived都安装

```sh
[root@keepalived01 ~]# wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
[root@keepalived01 ~]# yum -y install docker-ce-19.03.15 docker-ce-cli-19.03.15 containerd.io
[root@keepalived01 ~]# systemctl start docker && systemctl enable docker
[root@keepalived01 ~]# vim /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "insecure-registries": ["registry.access.redhat.com","quay.io","hub.tianxiang.com"],
  "registry-mirrors": ["https://q2gr04ke.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true
}
[root@keepalived01 ~]# systemctl daemon-reload && systemctl restart docker
[root@keepalived01 ~]# wget https://github.com/docker/compose/releases/download/1.28.6/docker-compose-Linux-x86_64
[root@keepalived01 ~]# chmod +x docker-compose-Linux-x86_64 && mv docker-compose-Linux-x86_64 /usr/bin/docker-compose
```

**启动服务**

```sh
[root@keepalived01 docker_compose]# docker-compose up -d
Status: Downloaded newer image for redis:4.0.14
Creating harbor-redis        ... done
Creating harbor-registry     ... done
Creating harbor-notarysigner ... done
Creating harbor-clair        ... done
Creating harbor-notaryserver ... done
[root@keepalived01 docker_compose]# docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                     NAMES
f6223d262323        postgres:9.6.21     "docker-entrypoint.s…"   43 seconds ago      Up 23 seconds       0.0.0.0:20013->5432/tcp   harbor-notaryserver
6a0c2abf8e9f        postgres:9.6.21     "docker-entrypoint.s…"   43 seconds ago      Up 23 seconds       0.0.0.0:20010->5432/tcp   harbor-registry
f255dcf446d5        postgres:9.6.21     "docker-entrypoint.s…"   43 seconds ago      Up 23 seconds       0.0.0.0:20011->5432/tcp   harbor-clair
768dc04aa25d        redis:4.0.14        "docker-entrypoint.s…"   43 seconds ago      Up 23 seconds       0.0.0.0:20000->6379/tcp   harbor-redis
be959d4f9b2d        postgres:9.6.21     "docker-entrypoint.s…"   43 seconds ago      Up 23 seconds       0.0.0.0:20012->5432/tcp   harbor-notarysigner
```

当然，针对上面提到的外置的 psql 方法，也可以使用高可用集群模式 psql 集群，可以参考[Linux-postgres-01-高可用集群部署](http://blog.linuxtian.top:4000/2022/04/Linux-postgres-01-%E9%AB%98%E5%8F%AF%E7%94%A8%E9%9B%86%E7%BE%A4%E9%83%A8%E7%BD%B2/)


同样 redis 也可以使用高可用的哨兵模式

### 3. 配置keepaived

- 主节点

```sh
[root@keepalived01 ~]# yum -y install keepalived
[root@keepalived01 ~]# cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak
[root@keepalived01 ~]# vim /etc/keepalived/keepalived.conf
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


### 4. 启动harbor

以harbor01机器为演示

**挂载共享存储nfs**

```sh
[root@harbor01 ~]# yum -y install nfs-utils
[root@harbor01 ~]# cat /etc/fstab

#
# /etc/fstab
# Created by anaconda on Thu Feb 24 19:14:58 2022
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/centos-root /                       xfs     defaults        0 0
UUID=f3ee650e-adaf-47d0-8d16-4c8240b28e54 /boot                   xfs     defaults        0 0
/dev/mapper/centos-swap swap                    swap    defaults        0 0
192.168.20.54:/nfs/harbor_storage /data nfs defaults 0 0
[root@harbor01 ~]# mkdir /data
[root@harbor01 ~]# mount -a
```

**自签证书**

```sh
[root@harbor01 ~]# mkdir -p /data/cert && cd /data/cert
# 创建 CA 根证书
[root@harbor01 cert]# openssl req  -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 -out ca.crt -subj "/C=CN/L=Beijing/O=lisea/CN=harbor-registry"
# 生成一个证书签名, 设置访问域名为tianxiang
[root@harbor01 cert]# openssl req -newkey rsa:4096 -nodes -sha256 -keyout server.key -out server.csr -subj "/C=CN/L=Beijing/O=lisea/CN=harbor-registry.com"
# 服务端证书生成时，因为正书中需要有 login 的地址信息，所以需要把每个 harbor 节点的地址添加进去，包括 VIP
[root@harbor01 cert]# echo subjectAltName = DNS:*,IP:192.168.20.51,IP:192.168.20.52,IP:192.168.20.53,IP:192.168.20.60,IP:127.0.0.1 > extfile.cnf
# 生成主机的证书
[root@harbor01 cert]# openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out server.crt
# 查看服务证书内容是否有设置的服务端IP地址
[root@harbor01 cert]# openssl x509 -in ./server.crt -noout -text
[root@harbor01 cert]# ls
ca.crt  ca.key  ca.srl  server.crt  server.key  server.csr
```

主要配置参数如下，由于我们这里使用外置PostgreSQL与Redis所以直接注释掉`database`相关配置改用`external_database`与`external_redis`

```sh
[root@harbor01 ~]# cd /usr/local/src/
[root@harbor01 src]# ls
harbor  harbor-offline-installer-v2.1.5.tgz
[root@harbor01 src]# cd harbor/
[root@harbor01 harbor]# cp harbor.yml.tmpl harbor.yml
[root@harbor01 harbor]# vim harbor.yml
# 修改为当前服务器内网IP地址即可
hostname: reg.mydomain.com
# HTTP相关配置
#http:
  #port: 80
https:
   #HTTPS端口
  port: 443
#  # TLS证书
  certificate: /data/cert/server.crt
#  # TLS私钥
  private_key: /data/cert/server.key
# 默认管理员密码
harbor_admin_password: Harbor12345
# Harbor DB配置，由于使用外部数据库，所以这里我们注释掉
# database:
#   password: root123
#   max_idle_conns: 50
#   max_open_conns: 100
...
# 外部PostgreSQL，由于Harbor使用了4个数据库，这里我们也需要对相应数据库地址进行配置
external_database:
  harbor:
    host: 192.168.20.54
    port: 20010
    db_name: registry
    username: postgres
    password: root123
    ssl_mode: disable
    max_idle_conns: 2
    max_open_conns: 0
  clair:
    host: 192.168.20.54
    port: 20011
    db_name: clair
    username: postgres
    password: root123
    ssl_mode: disable
  notary_signer:
    host: 192.168.20.54
    port: 20012
    db_name: notarysigner
    username: postgres
    password: root123
    ssl_mode: disable
  notary_server:
    host: 192.168.20.54
    port: 20013
    db_name: notaryserver
    username: postgres
    password: root123
    ssl_mode: disable
# 使用外部Redis，取消相应注释即可，需要注意的是，port端口不能在host下面，需要在地址的后面，如：192.168.20.60:20000
# 不然会报错：panic: dial tcp: address 192.168.20.60: missing port in address
external_redis:
  host: 192.168.20.54
  port: 20000
  password:
  registry_db_index: 1
  jobservice_db_index: 2
  chartmuseum_db_index: 3
...
```

**启动仓库**

```sh
[root@harbor01 harbor]# ./prepare
[root@harbor01 harbor]# ./install.sh
# 配置开机启动
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

**查看启动情况**

```sh
[root@harbor01 harbor]# docker-compose ps
      Name                     Command                  State                          Ports                   
---------------------------------------------------------------------------------------------------------------
harbor-core         /harbor/entrypoint.sh            Up (healthy)                                              
harbor-jobservice   /harbor/entrypoint.sh            Up (healthy)                                              
harbor-log          /bin/sh -c /usr/local/bin/ ...   Up (healthy)   127.0.0.1:1514->10514/tcp                  
harbor-portal       nginx -g daemon off;             Up (healthy)                                              
nginx               nginx -g daemon off;             Up (healthy)   0.0.0.0:80->8080/tcp, 0.0.0.0:443->8443/tcp
registry            /home/harbor/entrypoint.sh       Up (healthy)                                              
registryctl         /home/harbor/start.sh            Up (healthy)
```

没问题后，直接scp harbor 目录道其余两台机器上，然后启动仓库即可

### 5. 配置nginx负载均衡

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

# 四层负载均衡，为两台Master apiserver组件提供负载均衡
stream {

    log_format  main  '$remote_addr $upstream_addr - [$time_local] $status $upstream_bytes_sent';

    access_log  /var/log/nginx/harbor-access.log  main;

    upstream harbor {
       server 	192.168.20.51:443;   # harbor01
       server 	192.168.20.52:443;   # harbor02
       server 	192.168.20.53:443;   # harbor03
    }

    server {
       listen 443;
       proxy_pass harbor;
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
[root@keepalived01 ~]# mkdir -pv /etc/nginx/cert
[root@keepalived01 ~]# scp 192.168.20.51:/data/cert/* /etc/nginx/cert
[root@keepalived01 ~]# systemctl start nginx
[root@keepalived01 ~]# systemctl enable nginx.service
Created symlink from /etc/systemd/system/multi-user.target.wants/nginx.service to /usr/lib/systemd/system/nginx.service.
```

**配置keepalived健康检查**

两台机器都创建一个脚本

```sh
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

**重启keepalived**

```sh
[root@keepalived01 ~]# systemctl restart keepalived
[root@keepalived02 ~]# systemctl restart keepalived
```

### 6. 测试docker login登陆harborVIP

```sh
[root@harbor01 ~]# mkdir -pv /etc/docker/certs.d/hub.tianxiang.com
[root@harbor01 ~]# cp /data/cert/server.crt /etc/docker/certs.d/hub.tianxiang.com
[root@harbor01 ~]# docker login hub.tianxiang.com -uadmin -pHarbor12345
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```

配置 hub.tianxiang.com 的IP地址为192.168.20.60，然后浏览器访问harbor仓库，查看LB的nginx日志，观察流量变化，然后关闭harbor01，30秒内连续刷新harbor节点，观察会不会流量转发道harbor02机器上。

### 7. 补充命令

命令行创建harbor镜像库

```sh
[root@harbor01 ~]# curl -k -u 'admin:Harbor12345' -XPOST -H "Content-Type:application/json" -d '{"project_name": "mysql", "metadata": {"public": "true"}, "storage_limit": -1}' "https://hub.tianxiang.com/api/v2.0/projects"
```

```sh
\l                        #列出所有数据库
\c dbname                 #切换数据库
\d                        #列出当前数据库的所有表
\q                        #退出数据库
```

进入数据库查看

```sh
[root@harbor01 ~]# docker exec -it harbor-db bash
默认密码: root123
postgres [ / ]$ psql
psql (9.6.21)
Type "help" for help.

postgres=# \l
                                   List of databases
     Name     |  Owner   | Encoding |   Collate   |    Ctype    |   Access privileges   
--------------+----------+----------+-------------+-------------+-----------------------
 notaryserver | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =Tc/postgres         +
              |          |          |             |             | postgres=CTc/postgres+
              |          |          |             |             | server=CTc/postgres
 notarysigner | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =Tc/postgres         +
              |          |          |             |             | postgres=CTc/postgres+
              |          |          |             |             | signer=CTc/postgres
 postgres     | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 registry     | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 |
 template0    | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
              |          |          |             |             | postgres=CTc/postgres
 template1    | postgres | UTF8     | en_US.UTF-8 | en_US.UTF-8 | =c/postgres          +
              |          |          |             |             | postgres=CTc/postgres
(6 rows)
postgres=# \c registry
You are now connected to database "registry" as user "postgres".
registry=# \d
                      List of relations
 Schema |             Name             |   Type   |  Owner   
--------+------------------------------+----------+----------
 public | access                       | table    | postgres
 public | access_access_id_seq         | sequence | postgres
 public | admin_job                    | table    | postgres
 public | admin_job_id_seq             | sequence | postgres
 public | alembic_version              | table    | postgres
 public | artifact                     | table    | postgres
 public | artifact_blob                | table    | postgres
 public | artifact_blob_id_seq         | sequence | postgres
 public | artifact_id_seq              | sequence | postgres
 public | artifact_reference           | table    | postgres
registry=# select * from project;
 project_id | owner_id |  name   |       creation_time        |        update_time         | deleted | registry_id
------------+----------+---------+----------------------------+----------------------------+---------+-------------
          1 |        1 | library | 2022-06-16 07:17:46.387699 | 2022-06-16 07:17:46.387699 | f       |            
          2 |        1 | mysql   | 2022-09-13 14:22:20.178939 | 2022-09-13 14:22:20.178939 | f       |           0
(2 rows)
```

以上是查询数据库以及表内容，接下来可以用数据库创建表内容，也就是镜像仓库

```sh
registry=# insert into project(project_id,owner_id,name) values('3','1','redis');
INSERT 0 1
registry=# select * from project;
 project_id | owner_id |  name   |       creation_time        |        update_time         | deleted | registry_id
------------+----------+---------+----------------------------+----------------------------+---------+-------------
          1 |        1 | library | 2022-06-16 07:17:46.387699 | 2022-06-16 07:17:46.387699 | f       |            
          2 |        1 | redis#2 | 2022-09-13 14:20:31.468852 | 2022-09-13 14:21:13.898449 | t       |           0
          3 |        1 | mysql   | 2022-09-13 14:22:20.178939 | 2022-09-13 14:22:20.178939 | f       |           0
(3 rows)
```

删除library项目下面的nginx仓库

```sh
[root@harbor01 ~]# curl -k -u "admin:1qaz@WSX" -X  DELETE "https://10.135.139.130:30443/api/v2.0/projects/library/repositories/nginx/"
```

删除library项目下面的nginx仓库中的指定的tag，可以用sha256来表示

```sh
[root@harbor01 ~]# curl -k -u "admin:1qaz@WSX" -X  DELETE "https://10.135.139.130:30443/api/v2.0/projects/library/repositories/nginx/sha256:5d6b4b575cc30e91a85c129d29c14ebc5cf0ee1a98fc51e42e22748b63d5b339"
```
