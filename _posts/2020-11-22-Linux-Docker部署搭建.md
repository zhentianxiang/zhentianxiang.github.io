---
layout: post
title: Linux-Docker部署搭建
date: 2020-11-22
tags: Linux-Docker
---

## 一、Docker基本操作（一）

### 1. 安装Docker

```sh
[root@tianxiang ~]# wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
[root@tianxiang ~]# yum -y install docker-ce-19.03.15 docker-ce-cli-19.03.15 containerd.io
[root@tianxiang ~]# systemctl enable docker --now
# docker存储目录根据实际情况修改
[root@tianxiang ~]# vim /etc/docker/daemon.json
{
  "graph": "/home/docker",
  "storage-driver": "overlay2",
  "insecure-registries": ["registry.access.redhat.com","quay.io"],
  "registry-mirrors": ["https://q2gr04ke.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true
}
[root@tianxiang ~]# systemctl daemon-reload
[root@tianxiang ~]# systemctl restart docker
```

如果需要配置nvidia作为默认运行时环境，需要参考下面的配置
```sh
[root@tianxiang ~]# yum -y install nvidia-docker2
[root@tianxiang ~]# vim /etc/docker/daemon.json

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
  "registry-mirrors": ["https://q2gr04ke.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true
}
[root@tianxiang ~]# systemctl daemon-reload docker
[root@tianxiang ~]# systemctl restart docker
```

### 2. 安装harbor仓库

仓库官方地址：https://github.com/goharbor/harbor/releases/

```#!/bin/sh
[root@tianxiang ~]# mkdir /home/k8s-data && cd /home/k8s-data
[root@tianxiang ~]# tar xf  harbor-offline-installer-v2.1.5.tgz
[root@tianxiang ~]# cp /home/k8s-data/harbor/harbor.yml.tmpl /home/k8s-data/harbor/harbor.yml
# 修改harbor仓库的访问IP地址或者域名
[root@tianxiang ~]# sed -i 's/hostname: reg.mydomain.com/hostname: 'blog.linuxtian.top'/g' /home/k8s-data/harbor/harbor.yml
[root@tianxiang ~]# sed -i 's/port: 80/port: 180/g' /home/k8s-data/harbor/harbor.yml
[root@tianxiang ~]# sed -i 's/https:/#https:/g' /home/k8s-data/harbor/harbor.yml
[root@tianxiang ~]# sed -i 's/port: 443/#port: 443/g' /home/k8s-data/harbor/harbor.yml
[root@tianxiang ~]# sed -i 's/data_volume: \/data/data_volume: \/home\/k8s-data\/harbor\/data/g' /home/k8s-data/harbor/harbor.yml
[root@tianxiang ~]# wget https://github.com/docker/compose/releases/download/1.28.6/docker-compose-Linux-x86_64
[root@tianxiang ~]# chmod +x docker-compose-Linux-x86_64 && mv docker-compose-Linux-x86_64 /usr/bin/docker-compose
[root@tianxiang ~]# ./install.sh
[root@tianxiang ~]# docker-compose ps
```

配置开机自启

```#!/bin/sh
[root@tianxiang ~]# vim /lib/systemd/system/harbor.service
[Unit]
Description=Harbor
Requires=docker.service
After=syslog.target network.target

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

```#!/bin/sh
[root@tianxiang ~]# systemctl enable harbor
[root@tianxiang ~]# systemctl restart harbor
[root@tianxiang ~]# docker-compose ps
      Name                     Command                       State                     Ports          
------------------------------------------------------------------------------------------------------
harbor-core         /harbor/entrypoint.sh            Up (health: starting)                            
harbor-db           /docker-entrypoint.sh            Up (health: starting)                            
harbor-jobservice   /harbor/entrypoint.sh            Up (health: starting)                            
harbor-log          /bin/sh -c /usr/local/bin/ ...   Up (health: starting)   127.0.0.1:1514->10514/tcp
harbor-portal       nginx -g daemon off;             Up (health: starting)                            
nginx               nginx -g daemon off;             Up (health: starting)   0.0.0.0:180->8080/tcp    //这个就是暴露到本地的端口
redis               redis-server /etc/redis.conf     Up (health: starting)                            
registry            /home/harbor/entrypoint.sh       Up (health: starting)                            
registryctl         /home/harbor/start.sh            Up (health: starting)
```

### 3. Docker镜像

拉镜像

```#!/bin/sh
[root@tianxiang ~]# docker pull nginx
Using default tag: latest
latest: Pulling from library/nginx
e5ae68f74026: Pull complete
21e0df283cd6: Pull complete
ed835de16acd: Pull complete
881ff011f1c9: Pull complete
77700c52c969: Pull complete
44be98c0fab6: Pull complete
Digest: sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603
Status: Downloaded newer image for nginx:latest
docker.io/library/nginx:latest
# 指定版本拉取镜像
[root@tianxiang ~]# docker pull nginx:1.21.4
1.21.4: Pulling from library/nginx
Digest: sha256:9522864dd661dcadfd9958f9e0de192a1fdda2c162a35668ab6ac42b465f0603
Status: Downloaded newer image for nginx:1.21.4
docker.io/library/nginx:1.21.4
```

那么我们怎么知道镜像有哪些版本呢，可以从hub.docker.com仓库上去搜索

![](/images/posts/Docker/7.png)

![](/images/posts/Docker/8.png)

![](/images/posts/Docker/9.png)

查看镜像

```#!/bin/sh
[root@tianxiang ~]# docker images
REPOSITORY             TAG                 IMAGE ID            CREATED             SIZE
zhentianxiang/jekyll   1.1.0               4bd12f52b131        2 days ago          1.53GB
nginx                  1.21.4              f652ca386ed1        2 weeks ago         141MB    //我们刚拉取的
nginx                  latest              f652ca386ed1        2 weeks ago         141MB    //未指定版本拉取的话，就是默认的latest
```

修改镜像tag

```#!/bin/sh
[root@tianxiang ~]# docker tag nginx:1.21.4 zhentianxiang/nginx:1.21.4
[root@tianxiang ~]# docker images
REPOSITORY             TAG                 IMAGE ID            CREATED             SIZE
zhentianxiang/jekyll   1.1.0               4bd12f52b131        2 days ago          1.53GB
nginx                  1.21.4              f652ca386ed1        2 weeks ago         141MB
nginx                  latest              f652ca386ed1        2 weeks ago         141MB
zhentianxiang/nginx    1.21.4              f652ca386ed1        2 weeks ago         141MB
```

推送镜像

```#!/bin/sh
# 默认会推送到hub.docker.com仓库上去，前提是需要自己去官网注册docker账号，不然会报错
[root@tianxiang ~]# docker push  zhentianxiang/nginx:1.21.4
The push refers to repository [docker.io/zhentianxiang/nginx]
2bed47a66c07: Preparing
82caad489ad7: Preparing
d3e1dca44e82: Preparing
c9fcd9c6ced8: Preparing
0664b7821b60: Preparing
9321ff862abb: Waiting
denied: requested access to the resource is denied
[root@tianxiang ~]# docker login
Login with your Docker ID to push and pull images from Docker Hub. If you don't have a Docker ID, head over to https://hub.docker.com to create one.
Username: zhentianxiang
Password:
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
[root@tianxiang ~]# docker push  zhentianxiang/nginx:1.21.4
The push refers to repository [docker.io/zhentianxiang/nginx]
2bed47a66c07: Mounted from library/nginx
82caad489ad7: Mounted from library/nginx
d3e1dca44e82: Mounted from library/nginx
c9fcd9c6ced8: Mounted from library/nginx
0664b7821b60: Mounted from library/nginx
9321ff862abb: Mounted from library/nginx
1.21.4: digest: sha256:4424e31f2c366108433ecca7890ad527b243361577180dfd9a5bb36e828abf47 size: 1570
```

登录官网仓库查看镜像

![](/images/posts/Docker/10.png)

![](/images/posts/Docker/11.png)

![](/images/posts/Docker/12.png)

![](/images/posts/Docker/13.png)

![](/images/posts/Docker/14.png)


导出/导入镜像
```#!/bin/sh
[root@tianxiang home]# docker save zhentianxiang/nginx:1.21.4 |gzip > zhentianxiang_nginx_1.21.4.tar.gz
[root@tianxiang home]# ls
file  tianxiang  zhentianxiang_nginx_1.21.4.tar.gz
[root@tianxiang home]# docker load -i zhentianxiang_nginx_1.21.4.tar.gz
Loaded image: zhentianxiang/nginx:1.21.4
```

推送镜像到harbor私有仓库

上面已经安装好了一个私有仓库，然后暴露出来的端口是180

![](/images/posts/Docker/15.png)

![](/images/posts/Docker/16.png)

```#!/bin/sh
# 修改docker运行环境的配置文件，添加自己的私有仓库地址
[root@tianxiang ~]# cat /etc/docker/daemon.json
{
  "storage-driver": "overlay2",
  "insecure-registries": ["registry.access.redhat.com","quay.io","blog.linuxtian.top:180"],
  "registry-mirrors": ["https://q2gr04ke.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true
}
[root@tianxiang ~]# systemctl daemon-reload
[root@tianxiang ~]# systemctl restart docker
```
登录到仓库
```#!/bin/sh
[root@tianxiang ~]# docker login blog.linuxtian.top:180
Username: admin
Password:
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```

修改镜像tag

```#!/bin/sh
[root@tianxiang ~]# docker tag nginx:1.21.4 blog.linuxtian.top:180/library/nginx:1.21.4
[root@tianxiang ~]# docker push blog.linuxtian.top:180/library/nginx
The push refers to repository [blog.linuxtian.top:180/library/nginx]
2bed47a66c07: Pushed
82caad489ad7: Pushed
d3e1dca44e82: Pushed
c9fcd9c6ced8: Pushed
0664b7821b60: Pushed
9321ff862abb: Pushed
1.21.4: digest: sha256:4424e31f2c366108433ecca7890ad527b243361577180dfd9a5bb36e828abf47 size: 1570
```

查看仓库镜像

![](/images/posts/Docker/17.png)


### 3. Docker容器

查看当前存活容器

```#!/bin/sh
[root@tianxiang ~]# docker ps
CONTAINER ID        IMAGE                                COMMAND                  CREATED             STATUS                   PORTS                       NAMES
a7cad2643ef4        goharbor/nginx-photon:v2.1.5         "nginx -g 'daemon of…"   8 minutes ago       Up 8 minutes (healthy)   0.0.0.0:180->8080/tcp       nginx
0835e2f0e460        goharbor/harbor-jobservice:v2.1.5    "/harbor/entrypoint.…"   8 minutes ago       Up 8 minutes (healthy)                               harbor-jobservice
dc0898121f46        goharbor/harbor-core:v2.1.5          "/harbor/entrypoint.…"   8 minutes ago       Up 8 minutes (healthy)                               harbor-core
17238b0e2592        goharbor/redis-photon:v2.1.5         "redis-server /etc/r…"   9 minutes ago       Up 8 minutes (healthy)                               redis
0f2b4c969559        goharbor/harbor-db:v2.1.5            "/docker-entrypoint.…"   9 minutes ago       Up 8 minutes (healthy)                               harbor-db
715a40d4df14        goharbor/registry-photon:v2.1.5      "/home/harbor/entryp…"   9 minutes ago       Up 8 minutes (healthy)                               registry
51b6f984119f        goharbor/harbor-portal:v2.1.5        "nginx -g 'daemon of…"   9 minutes ago       Up 8 minutes (healthy)                               harbor-portal
c9aa5a5260a7        goharbor/harbor-registryctl:v2.1.5   "/home/harbor/start.…"   9 minutes ago       Up 8 minutes (healthy)                               registryctl
3879dfca4ed2        goharbor/harbor-log:v2.1.5           "/bin/sh -c /usr/loc…"   9 minutes ago       Up 9 minutes (healthy)   127.0.0.1:1514->10514/tcp   harbor-log
```

启动、停止、删除容器

```#!/bin/sh
[root@tianxiang ~]# docker run -itd --name nginx-test blog.linuxtian.top:180/library/nginx:1.21.4
4c086373573b194913f3157a8cd33c023459939d9611cb410e3c5e345cac58a8
```

- **-a stdin:** 指定标准输入输出内容类型，可选 STDIN/STDOUT/STDERR 三项；
- **-d:** 后台运行容器，并返回容器ID；
- **-i:** 以交互模式运行容器，通常与 -t 同时使用；
- **-P:** 随机端口映射，容器内部端口**随机**映射到主机的端口
- **-p:** 指定端口映射，格式为：**主机(宿主)端口:容器端口**
- **-t:** 为容器重新分配一个伪输入终端，通常与 -i 同时使用；
- **--name="nginx-lb":** 为容器指定一个名称；
- **--dns 8.8.8.8:** 指定容器使用的DNS服务器，默认和宿主一致；
- **--dns-search example.com:** 指定容器DNS搜索域名，默认和宿主一致；
- **-h "mars":** 指定容器的hostname；
- **-e username="ritchie":** 设置环境变量；
- **--env-file=[]:** 从指定文件读入环境变量；
- **--cpuset="0-2" or --cpuset="0,1,2":** 绑定容器到指定CPU运行；
- **-m :**设置容器使用内存最大值；
- **--net="bridge":** 指定容器的网络连接类型，支持 bridge/host/none/container: 四种类型；
- **--link=[]:** 添加链接到另一个容器；
- **--expose=[]:** 开放一个端口或一组端口；
- **--volume , -v:** 绑定一个卷

```#!/bin/sh
[root@tianxiang ~]# docker ps |grep nginx
4c086373573b        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   2 minutes ago       Up 2 minutes              80/tcp                      nginx-test
# 这里的bash充当一个命令，就是进入sh界面的意思，
[root@tianxiang ~]# docker exec -it nginx-test bash
# exit 可以退出容器
root@4c086373573b:/# exit
[root@tianxiang ~]# docker exec -it nginx-test cat /etc/nginx/nginx.conf

user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}
```

我们再试试映射一下端口

```#!/bin/sh
[root@tianxiang ~]# docker run -dit --name nginx-test-01 -p 30001:80 blog.linuxtian.top:180/library/nginx:1.21.4
05134529c90cc362fc103fb8857a3db491fd0f1841c239746bc7139bc75238da
[root@tianxiang ~]# docker ps -l
CONTAINER ID        IMAGE                                         COMMAND                  CREATED             STATUS              PORTS                   NAMES
05134529c90c        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   3 seconds ago       Up 2 seconds        0.0.0.0:30001->80/tcp   nginx-test-01
[root@tianxiang ~]# netstat -lntp |grep 30001
tcp6       0      0 :::30001                :::*                    LISTEN      6254/docker-proxy
```

测试没问题

```#!/bin/sh
[root@tianxiang ~]# curl 127.0.0.1:30001
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

再试试映射挂载目录
```#!/bin/sh
[root@tianxiang ~]# mkdir test
[root@tianxiang ~]# touch test/test.txt
[root@tianxiang ~]# docker run -dit --name nginx-test-02 -p 30002:80 -v /root/test/test.txt:/home/test.txt blog.linuxtian.top:180/library/nginx:1.21.4
2875e75fa0fbb42c8a1b5ec8cbfc6dba6177a3b872af6551e2220d9fe95936e2
[root@tianxiang ~]# docker exec -it nginx-test-02 ls /home
test.txt
```

停止容器

```#!/bin/sh
[root@tianxiang ~]# docker ps |grep nginx-test
2875e75fa0fb        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   About a minute ago   Up About a minute         0.0.0.0:30002->80/tcp       nginx-test-02
05134529c90c        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   7 minutes ago        Up 7 minutes              0.0.0.0:30001->80/tcp       nginx-test-01
4c086373573b        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   13 minutes ago       Up 13 minutes             80/tcp                      nginx-test
[root@tianxiang ~]# docker stop nginx-test
nginx-test
[root@tianxiang ~]# docker ps |grep nginx-test
2875e75fa0fb        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   About a minute ago   Up About a minute         0.0.0.0:30002->80/tcp       nginx-test-02
05134529c90c        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   7 minutes ago        Up 7 minutes              0.0.0.0:30001->80/tcp       nginx-test-01
[root@tianxiang ~]# docker ps -a |grep nginx-test
2875e75fa0fb        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   2 minutes ago       Up 2 minutes                0.0.0.0:30002->80/tcp       nginx-test-02
05134529c90c        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   7 minutes ago       Up 7 minutes                0.0.0.0:30001->80/tcp       nginx-test-01
4c086373573b        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   13 minutes ago      Exited (0) 16 seconds ago                               nginx-test
```
启动容器

```#!/bin/sh
[root@tianxiang ~]# docker start nginx-test
nginx-test
[root@tianxiang ~]# docker ps |grep nginx-test
2875e75fa0fb        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   2 minutes ago       Up 2 minutes              0.0.0.0:30002->80/tcp       nginx-test-02
05134529c90c        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   8 minutes ago       Up 8 minutes              0.0.0.0:30001->80/tcp       nginx-test-01
4c086373573b        blog.linuxtian.top:180/library/nginx:1.21.4   "/docker-entrypoint.…"   14 minutes ago      Up 2 seconds              80/tcp                      nginx-test
```

删除容器，删除容器山需要先stop，如果不stop，需要-f强制删除

```#!/bin/sh
[root@tianxiang ~]# docker rm -f nginx-test
nginx-test
```

查看容器日志

```#!/bin/sh
[root@tianxiang ~]# docker logs nginx-test-01
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: Enabled listen on IPv6 in /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2021/12/21 02:47:59 [notice] 1#1: using the "epoll" event method
2021/12/21 02:47:59 [notice] 1#1: nginx/1.21.4
2021/12/21 02:47:59 [notice] 1#1: built by gcc 10.2.1 20210110 (Debian 10.2.1-6)
2021/12/21 02:47:59 [notice] 1#1: OS: Linux 3.10.0-1160.15.2.el7.x86_64
2021/12/21 02:47:59 [notice] 1#1: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2021/12/21 02:47:59 [notice] 1#1: start worker processes
2021/12/21 02:47:59 [notice] 1#1: start worker process 30
172.17.0.1 - - [21/Dec/2021:02:48:33 +0000] "GET / HTTP/1.1" 200 615 "-" "curl/7.29.0" "-"
```

### 4. Docker网络

>现在我们查看网卡信息，发现有很多的veth这种网卡设备，而这种设备就是docker0网卡桥接给容器的网络设备，docker0地址是172.17.0.1，容器里的ip地址应该也是172开头的

```#!/bin/sh
[root@tianxiang ~]# ifconfig
br-0f63929313ce: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.18.0.1  netmask 255.255.0.0  broadcast 172.18.255.255
        inet6 fe80::42:21ff:feab:c280  prefixlen 64  scopeid 0x20<link>
        ether 02:42:21:ab:c2:80  txqueuelen 0  (Ethernet)
        RX packets 24458  bytes 1893407 (1.8 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 39823  bytes 24869763 (23.7 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

docker0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.1  netmask 255.255.0.0  broadcast 172.17.255.255
        inet6 fe80::42:c1ff:fe51:412d  prefixlen 64  scopeid 0x20<link>
        ether 02:42:c1:51:41:2d  txqueuelen 0  (Ethernet)
        RX packets 4398  bytes 12567202 (11.9 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 4116  bytes 406799 (397.2 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.0.4  netmask 255.255.240.0  broadcast 192.168.15.255
        inet6 fe80::f820:20ff:fe15:309b  prefixlen 64  scopeid 0x20<link>
        ether fa:20:20:15:30:9b  txqueuelen 1000  (Ethernet)
        RX packets 8088624  bytes 2331237017 (2.1 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 7467570  bytes 2128966414 (1.9 GiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 3789498  bytes 3536959792 (3.2 GiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 3789498  bytes 3536959792 (3.2 GiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

veth0d9e76e: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet6 fe80::44f4:c7ff:feb4:4542  prefixlen 64  scopeid 0x20<link>
        ether 46:f4:c7:b4:45:42  txqueuelen 0  (Ethernet)
        RX packets 40615  bytes 59764596 (56.9 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 35357  bytes 59764865 (56.9 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

进入容器查看网络

```#!/bin/sh
[root@tianxiang ~]# docker exec -it nginx-test-01 bash
root@05134529c90c:/# ip a
bash: ip: command not found
# 因为一般容器很简洁，连常用的命令都没有，所以需要自己安装
root@05134529c90c:/# apt-get update  && apt-get install -y iproute2 iputils-ping
# 默认情况下拉取的是国外的源，非常慢，所以需要修改一下国内镜像源，这里使用的是清华源
root@05134529c90c:/# cp /etc/apt/sources.list /etc/apt/sources.list.bak
root@05134529c90c:/# cat > /etc/apt/sources.list <<EOF
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye main contrib non-free
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-updates main contrib non-free

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ bullseye-backports main contrib non-free

deb https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian-security bullseye-security main contrib non-free
EOF
root@05134529c90c:/# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
105: eth0@if106: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
# 测试ping公网，docker0网卡以及宿主机网卡
root@05134529c90c:/# ping 172.17.0.1
PING 172.17.0.1 (172.17.0.1) 56(84) bytes of data.
64 bytes from 172.17.0.1: icmp_seq=1 ttl=64 time=0.068 ms
64 bytes from 172.17.0.1: icmp_seq=2 ttl=64 time=0.077 ms
^C
--- 172.17.0.1 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1000ms
rtt min/avg/max/mdev = 0.068/0.072/0.077/0.004 ms
root@05134529c90c:/# ping 192.168.0.4
PING 192.168.0.4 (192.168.0.4) 56(84) bytes of data.
64 bytes from 192.168.0.4: icmp_seq=1 ttl=64 time=0.071 ms
^C
--- 192.168.0.4 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 0.071/0.071/0.071/0.000 ms
root@05134529c90c:/# ping www.baidu.com
PING www.a.shifen.com (182.61.200.6) 56(84) bytes of data.
64 bytes from 182.61.200.6 (182.61.200.6): icmp_seq=1 ttl=52 time=3.07 ms
64 bytes from 182.61.200.6 (182.61.200.6): icmp_seq=2 ttl=52 time=2.70 ms
64 bytes from 182.61.200.6 (182.61.200.6): icmp_seq=3 ttl=52 time=2.83 ms
```

以上网络搞清楚怎么回事了，原理就是我们每启动一个docker容器，docker就会给容器分配一个地址，这就是容器的使用的evth-pair技术！


然后我们发现宿主机上的容器网卡和容器内是网卡好像有些关联

```#!/bin/sh
# veth70a18f5@if105 网卡名称@后面的和容器里的是紧挨着的
[root@tianxiang ~]# ip a
.................
106: veth70a18f5@if105: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master docker0 state UP group default
    link/ether d6:17:36:ff:54:4c brd ff:ff:ff:ff:ff:ff link-netnsid 7
    inet6 fe80::d417:36ff:feff:544c/64 scope link
       valid_lft forever preferred_lft forever
[root@tianxiang ~]# docker exec -it nginx-test-01 ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
105: eth0@if106: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
```

然后测试容器与容器之间也是没问题的

```#!/bin/sh
[root@tianxiang ~]# docker exec -it nginx-test-02 ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
101: eth0@if102: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:ac:11:00:04 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.4/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever
[root@tianxiang ~]# docker exec -it nginx-test-01 ping 172.17.0.4
PING 172.17.0.4 (172.17.0.4) 56(84) bytes of data.
64 bytes from 172.17.0.4: icmp_seq=1 ttl=64 time=0.114 ms
64 bytes from 172.17.0.4: icmp_seq=2 ttl=64 time=0.106 ms
64 bytes from 172.17.0.4: icmp_seq=3 ttl=64 time=0.085 ms
^C
--- 172.17.0.4 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2000ms
rtt min/avg/max/mdev = 0.085/0.101/0.114/0.012 ms
```

#### 4.1 Link网络

思考一个场景，我们编写了一个微服务，database url=ip，项目不能重启，数据库ip换掉了，我们希望可以处理这个问题，可以用系统名称来访问客户端。

```#!/bin/sh
# 把nginx-test-03 连接到nginx-test-02
[root@tianxiang ~]# docker run -dit --name nginx-test-03 --link nginx-test-02 blog.linuxtian.top:180/library/nginx:1.21.4
3bcac68525d37918ea7d7b0dd53495729731e58017e2751901ad7781fc26d219
[root@tianxiang ~]# docker exec -it nginx-test-03 ping nginx-test-02
PING nginx-test-02 (172.17.0.4) 56(84) bytes of data.
64 bytes from nginx-test-02 (172.17.0.4): icmp_seq=1 ttl=64 time=0.118 ms
64 bytes from nginx-test-02 (172.17.0.4): icmp_seq=2 ttl=64 time=0.087 ms
64 bytes from nginx-test-02 (172.17.0.4): icmp_seq=3 ttl=64 time=0.088 ms
64 bytes from nginx-test-02 (172.17.0.4): icmp_seq=4 ttl=64 time=0.114 ms
64 bytes from nginx-test-02 (172.17.0.4): icmp_seq=5 ttl=64 time=0.084 ms
^C
--- nginx-test-02 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4000ms
rtt min/avg/max/mdev = 0.084/0.098/0.118/0.014 ms
# 反之nginx-test-02 就无法使用主机名pingnginx-test-03
[root@tianxiang ~]# docker exec -it nginx-test-02 ping nginx-test-03
ping: nginx-test-03: Name or service not known
# 其实link也就是在容器启动的时候添加了一个hosts解析
[root@tianxiang ~]# docker exec -it nginx-test-03 cat /etc/hosts
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::0	ip6-localnet
ff00::0	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
172.17.0.4	nginx-test-02 2875e75fa0fb
172.17.0.3	3bcac68525d3
```

#### 4.2 自定义网络

查看当前的网络

```#!/bin/sh
[root@tianxiang ~]# docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
a86dfd4764b5        bridge              bridge              local
0f63929313ce        harbor_harbor       bridge              local
82c137d3bffe        host                host                local
2a8b994efd99        none                null                local
```

- bridge：桥接docker（默认）

- none：不配置网络host：和宿主机共享网络

- container：容器之间互联（用的少！局限很大）

创建一个自定义的桥接网络

```#!/bin/sh
[root@tianxiang ~]# docker network create --driver bridge --subnet 10.0.0.0/16 --gateway 10.0.0.1 mynet
d70b1971eb849745eee920ac25d0c649331418982db5b62992527d790e46403f
[root@tianxiang ~]# docker network ls
NETWORK ID          NAME                DRIVER              SCOPE
a86dfd4764b5        bridge              bridge              local
0f63929313ce        harbor_harbor       bridge              local
82c137d3bffe        host                host                local
d70b1971eb84        mynet               bridge              local
2a8b994efd99        none                null                local
```
```#!/bin/sh
[root@tianxiang ~]# docker network inspect mynet
[
    {
        "Name": "mynet",
        "Id": "d70b1971eb849745eee920ac25d0c649331418982db5b62992527d790e46403f",
        "Created": "2021-12-21T11:55:22.654829772+08:00",
        "Scope": "local",
        "Driver": "bridge",
        "EnableIPv6": false,
        "IPAM": {
            "Driver": "default",
            "Options": {},
            "Config": [
                {
                    "Subnet": "10.0.0.0/16",
                    "Gateway": "10.0.0.1"
                }
            ]
        },
        "Internal": false,
        "Attachable": false,
        "Ingress": false,
        "ConfigFrom": {
            "Network": ""
        },
        "ConfigOnly": false,
        "Containers": {},
        "Options": {},
        "Labels": {}
    }
]
```

使用自定义网络启动两个容器，测试连通性

```#!/bin/sh
[root@tianxiang ~]# docker run -dit --name nginx-test-04 --network mynet blog.linuxtian.top:180/library/nginx:1.21.4
9ee69ced981d0a7347d733b46ab73e4d61893831e7fadfd10404d24990c38f16
[root@tianxiang ~]# docker run -dit --name nginx-test-05 --network mynet blog.linuxtian.top:180/library/nginx:1.21.4
5a4d0317a3ebf48c5a171488c436c3c3cff66e1fa873a9de190039ca224a09c3
[root@tianxiang ~]# docker exec -it nginx-test-04 bash
root@9ee69ced981d:/# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
110: eth0@if111: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 02:42:0a:00:00:02 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.0.0.2/16 brd 10.0.255.255 scope global eth0
       valid_lft forever preferred_lft forever
root@9ee69ced981d:/# ping www.baidu.com
PING www.a.shifen.com (182.61.200.6) 56(84) bytes of data.
64 bytes from 182.61.200.6 (182.61.200.6): icmp_seq=1 ttl=52 time=3.11 ms
64 bytes from 182.61.200.6 (182.61.200.6): icmp_seq=2 ttl=52 time=2.71 ms
^C
--- www.a.shifen.com ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 2.708/2.908/3.108/0.200 ms
# ping nginx-test-03 地址
root@9ee69ced981d:/# ping 10.0.0.3
PING 10.0.0.3 (10.0.0.3) 56(84) bytes of data.
64 bytes from 10.0.0.3: icmp_seq=1 ttl=64 time=0.129 ms
64 bytes from 10.0.0.3: icmp_seq=2 ttl=64 time=0.089 ms
64 bytes from 10.0.0.3: icmp_seq=3 ttl=64 time=0.096 ms
^C
--- 10.0.0.3 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 1999ms
rtt min/avg/max/mdev = 0.089/0.104/0.129/0.017 ms
```

以上测试虽然容器地址发生改变，但还是以宿主机的docker0网卡做的nat转发

```#!/bin/sh
[root@tianxiang ~]# iptables -t nat -vnL
Chain PREROUTING (policy ACCEPT 451 packets, 25878 bytes)
 pkts bytes target     prot opt in     out     source               destination         
 2783  143K DOCKER     all  --  *      *       0.0.0.0/0            0.0.0.0/0            ADDRTYPE match dst-type LOCAL

Chain INPUT (policy ACCEPT 197 packets, 10492 bytes)
 pkts bytes target     prot opt in     out     source               destination         

Chain OUTPUT (policy ACCEPT 144 packets, 8792 bytes)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 DOCKER     all  --  *      *       0.0.0.0/0           !127.0.0.0/8          ADDRTYPE match dst-type LOCAL

Chain POSTROUTING (policy ACCEPT 383 packets, 23156 bytes)
 pkts bytes target     prot opt in     out     source               destination         
   15  1022 MASQUERADE  all  --  *      !br-d70b1971eb84  10.0.0.0/16          0.0.0.0/0           
    8   500 MASQUERADE  all  --  *      !br-0f63929313ce  172.18.0.0/16        0.0.0.0/0           
   46  2974 MASQUERADE  all  --  *      !docker0  172.17.0.0/16        0.0.0.0/0           
    0     0 MASQUERADE  tcp  --  *      *       172.18.0.2           172.18.0.2           tcp dpt:10514
    0     0 MASQUERADE  tcp  --  *      *       172.18.0.10          172.18.0.10          tcp dpt:8080
    0     0 MASQUERADE  tcp  --  *      *       172.17.0.4           172.17.0.4           tcp dpt:80
    0     0 MASQUERADE  tcp  --  *      *       172.17.0.2           172.17.0.2           tcp dpt:80

Chain DOCKER (2 references)
 pkts bytes target     prot opt in     out     source               destination         
    0     0 RETURN     all  --  br-d70b1971eb84 *       0.0.0.0/0            0.0.0.0/0           
    0     0 RETURN     all  --  br-0f63929313ce *       0.0.0.0/0            0.0.0.0/0           
    2   168 RETURN     all  --  docker0 *       0.0.0.0/0            0.0.0.0/0           
    0     0 DNAT       tcp  --  !br-0f63929313ce *       0.0.0.0/0            127.0.0.1            tcp dpt:1514 to:172.18.0.2:10514
   46  2744 DNAT       tcp  --  !br-0f63929313ce *       0.0.0.0/0            0.0.0.0/0            tcp dpt:180 to:172.18.0.10:8080
    0     0 DNAT       tcp  --  !docker0 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:30002 to:172.17.0.4:80
    1    40 DNAT       tcp  --  !docker0 *       0.0.0.0/0            0.0.0.0/0            tcp dpt:30001 to:172.17.0.2:80
```

### 5. 删除全部nginx-test容器

以容器名删除
```#!/bin/sh
[root@tianxiang ~]# docker ps -a |grep nginx-test |awk '{print $NF}' |xargs -n1 docker rm -f
nginx-test-05
nginx-test-04
nginx-test-03
nginx-test-02
nginx-test-01
[root@tianxiang ~]# docker ps -a |grep nginx-test
```

以容器ID删除就是
```#!/bin/sh
[root@tianxiang ~]# docker ps -a |grep nginx-test |awk '{print $1}' |xargs -n1 docker rm -f
```
