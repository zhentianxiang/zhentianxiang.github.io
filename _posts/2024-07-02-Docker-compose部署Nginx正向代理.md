---
layout: post
title: 	2024-07-02-Docker-compose部署Nginx正向代理
date: 2024-06-07
tags: Linux-Docker
music-id: 2051548110
---

## Docker 部署 Nginx 正向代理

### 1. 正向代理简介

> `nginx`不仅可以做反向代理，还能用作正向代理来进行上网等功能。如果把局域网外的`Internet`想象成一个巨大的资源库，则局域网中的客户端要访问`Internet`，则需要通过代理服务器来访问，这种代理服务就称为正向代理（也就是大家常说的，通过正向代理进行上网功能）

**示例**

> 如下图所示，内网机器`10.212.4.35`处于办公内网中，无法访问外部`Internet`；外网机器`10.211.1.6`处于另一个网络环境中，也就是可以上互联网的机器。内网机器和外网机器之间的数据传输通过网闸进行摆渡。在下面图中的环境，已将网络打通，内网机器`10.212.4.35`可以访问外网机器`10.211.1.6`的`8080`端口。则内网机器如果想上互联网，则只能通过外网机器代理实现。

![](/images/posts/Docker-compose部署Nginx正向代理/1.png)

### 2. 制作镜像

```sh
$ cat Dockerfile 
# 第一阶段: 构建 Nginx
FROM ubuntu:20.04 as builder

# 设置环境变量以防止交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 安装构建所需的依赖工具
RUN apt-get update && \
    apt-get install -y \
    curl \
    patch \
    gcc \
    libc6-dev \
    make \
    libssl-dev \
    libpcre3-dev \
    zlib1g-dev \
    libgd-dev \
    libgeoip-dev \
    perl \
    git && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 定义工作目录
WORKDIR /workdir

# 下载并编译 Nginx 和 ngx_http_proxy_connect_module
RUN curl -o nginx-1.19.2.tar.gz http://nginx.org/download/nginx-1.19.2.tar.gz && \
    tar -zxvf nginx-1.19.2.tar.gz && \
    git clone https://github.com/chobits/ngx_http_proxy_connect_module && \
    cd ngx_http_proxy_connect_module && \
    git checkout v0.0.2 && \
    cd ../nginx-1.19.2 && \
    patch -p1 < ../ngx_http_proxy_connect_module/patch/proxy_connect_rewrite_1018.patch && \
    ./configure --add-module=../ngx_http_proxy_connect_module \
                --prefix=/etc/nginx \
                --sbin-path=/usr/sbin/nginx \
                --conf-path=/etc/nginx/nginx.conf \
                --error-log-path=/var/log/nginx/error.log \
                --http-log-path=/var/log/nginx/access.log \
                --pid-path=/var/run/nginx.pid \
                --lock-path=/var/run/nginx.lock \
                --http-client-body-temp-path=/var/cache/nginx/client_temp \
                --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
                --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
                --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
                --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
                --user=nginx \
                --group=nginx \
                --with-compat \
                --with-file-aio \
                --with-threads \
                --with-http_addition_module \
                --with-http_auth_request_module \
                --with-http_dav_module \
                --with-http_flv_module \
                --with-http_gunzip_module \
                --with-http_gzip_static_module \
                --with-http_mp4_module \
                --with-http_random_index_module \
                --with-http_realip_module \
                --with-http_secure_link_module \
                --with-http_slice_module \
                --with-http_ssl_module \
                --with-http_stub_status_module \
                --with-http_sub_module \
                --with-http_v2_module \
                --with-mail \
                --with-mail_ssl_module \
                --with-stream \
                --with-stream_realip_module \
                --with-stream_ssl_module \
                --with-stream_ssl_preread_module && \
    make -j 4 && make install

# 第二阶段: 创建最小化的运行环境
FROM ubuntu:20.04

# 设置环境变量以防止交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 安装运行时所需的依赖工具
RUN apt-get update && \
    apt-get install -y \
    libssl1.1 \
    libpcre3 \
    zlib1g \
    libgd3 \
    libgeoip1 \
    perl \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 添加 nginx 用户组和用户，用来启动 nginx 的用户
RUN if ! getent group nginx >/dev/null; then groupadd -g 101 nginx; fi && \
    if ! id -u nginx >/dev/null 2>&1; then useradd -u 101 -d /var/cache/nginx -s /sbin/nologin -g nginx nginx; fi

# 创建必要的目录
RUN mkdir -p /var/log/nginx /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp /var/cache/nginx/fastcgi_temp /var/cache/nginx/uwsgi_temp /var/cache/nginx/scgi_temp

# 从构建阶段复制 Nginx 二进制文件到运行阶段
COPY --from=builder /etc/nginx /etc/nginx
COPY --from=builder /usr/sbin/nginx /usr/sbin/nginx

# 复制自定义配置文件（确保 nginx.conf 文件在 Dockerfile 同一目录下）
COPY nginx.conf /etc/nginx/nginx.conf
COPY Dockerfile /workdir

# 暴露端口
EXPOSE 80

# 设置 Nginx 为前台运行
CMD ["/usr/sbin/nginx", "-g", "daemon off;"]
```

- nginx.conf

```sh
$ cat nginx.conf 
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

    access_log /dev/stdout main;
    error_log /dev/stdout;

    keepalive_timeout  65;

    include /etc/nginx/conf.d/*.conf;

    server {
        listen 80 default_server;
        server_name _;
        location / {
            root   html;
            index  index.html index.htm;
        }
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
```

- forward.conf

```sh
cat forward.conf 
server {
    listen                         8080;

    resolver                      223.5.5.5 ipv6=off;

    proxy_connect;
    proxy_connect_allow all;
    proxy_connect_connect_timeout 30s;
    proxy_connect_read_timeout 600s;
    proxy_connect_send_timeout 600s;

    # 访问控制：只允许特定客户端 IP
    allow 172.18.0.1;  # 因为我这个是 docker 部署的，所以我要把 docker 的桥接网卡地址加上
    allow 47.120.62.100;
    deny all;

    location / {
        proxy_pass http://$host;
        proxy_set_header Host $host;
    }
}
```

```sh
$ docker build . -t registry.cn-hangzhou.aliyuncs.com/tianxiang_app/nginx-forward-proxy:latest
```

### 3. 启动服务

```sh
# 服务器端启动
# docker-app 是我自己定义的网络设备,你们可以删除掉用默认的
$ cat docker-compose.yaml 
services:
  file-front:
    container_name: nginx-forward-proxy
    image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/nginx-forward-proxy:latest
    ports:
      - 3129:8080
    environment:
      TZ: "Asia/Shanghai"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./forward.conf:/etc/nginx/conf.d/forward.conf
    restart: always
    networks:
      - docker-app

networks:
  docker-app:
    external: true
$ docker-compose up -d
```

### 3. 客户端配置代理

```sh
$ vim ~/.bashrc

export http_proxy="http://47.120.62.100:3129"
export https_proxy="http://47.120.62.100:3129"
export all_proxy="socks5://47.120.62.100:3129"
export no_proxy=localhost,127.0.0.1::1
```

### 4. 测试

#### 1. 系统代理

```sh
# 客户端 curl
$ curl -I https://www.baidu.com
HTTP/1.1 200 Connection Established
Proxy-agent: nginx

HTTP/1.1 200 OK
Accept-Ranges: bytes
Cache-Control: private, no-cache, no-store, proxy-revalidate, no-transform
Connection: keep-alive
Content-Length: 277
Content-Type: text/html
Date: Tue, 02 Jul 2024 06:58:50 GMT
Etag: "575e1f60-115"
Last-Modified: Mon, 13 Jun 2016 02:50:08 GMT
Pragma: no-cache
Server: bfe/1.0.8.18

$ curl -I https://www.google.com
HTTP/1.1 200 Connection Established
Proxy-agent: nginx

HTTP/2 200 
content-type: text/html; charset=ISO-8859-1
content-security-policy-report-only: object-src 'none';base-uri 'self';script-src 'nonce-Zf5Uvyor2SkrBjOWQKAx6A' 'strict-dynamic' 'report-sample' 'unsafe-eval' 'unsafe-inline' https: http:;report-uri https://csp.withgoogle.com/csp/gws/other-hp
p3p: CP="This is not a P3P policy! See g.co/p3phelp for more info."
date: Tue, 02 Jul 2024 07:00:10 GMT
server: gws
x-xss-protection: 0
x-frame-options: SAMEORIGIN
expires: Tue, 02 Jul 2024 07:00:10 GMT
cache-control: private
set-cookie: AEC=AQTF6HyI-_ftNjY2G30Egx12s4rx5g3ph2ALWsW3Zu8O6hQqwht8ipY69AE; expires=Sun, 29-Dec-2024 07:00:10 GMT; path=/; domain=.google.com; Secure; HttpOnly; SameSite=lax
set-cookie: NID=515=mjoH0Hzc7QL1Wyctzdt43toyBfVWqE5uKd1mB-dsZqTBiJaeoyd2q_wJ6Hu2UAb-01EIhwb5U_q-20lxUzNLOhZmXW3FcDISrYSEIxC_pr4VWeIAdOa8Yi3Ml_t4Ujd4eqS9FSJDg-9w6by7iAaqK2LCq5BDluKBQvE2ShfF1Vo; expires=Wed, 01-Jan-2025 07:00:10 GMT; path=/; domain=.google.com; HttpOnly
alt-svc: h3=":443"; ma=2592000,h3-29=":443"; ma=2592000
```

#### 2. docker 代理

```sh
$ systemctl status docker
● docker.service - Docker Application Container Engine
     Loaded: loaded (/lib/systemd/system/docker.service; enabled; vendor preset: enabled)
    Drop-In: /etc/systemd/system/docker.service.d
             └─proxy.conf
     Active: active (running) since Tue 2024-07-02 13:58:41 CST; 1h 22min ago
TriggeredBy: ● docker.socket
       Docs: https://docs.docker.com
   Main PID: 2866623 (dockerd)
      Tasks: 10
     Memory: 77.8M
     CGroup: /system.slice/docker.service
             └─2866623 /usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
             
$ vim /etc/systemd/system/docker.service.d/proxy.conf
[Service]
Environment="HTTP_PROXY=http://47.120.62.2.100:3129"
Environment="HTTPS_PROXY=http://47.120.62.2.100:3129"
Environment="NO_PROXY=localhost,127.0.0.1"

$ docker pull k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.3.0
v2.3.0: Pulling from sig-storage/csi-node-driver-registrar
0d7d70899875: Pull complete 
7232e6157cf2: Pull complete 
Digest: sha256:f9bcee63734b7b01555ee8fc8fb01ac2922478b2c8934bf8d468dd2916edc405
Status: Downloaded newer image for k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.3.0
k8s.gcr.io/sig-storage/csi-node-driver-registrar:v2.3.0
```

### 5. 服务器端查看日志

```sh
$ docker-compose logs -f --tail=100
nginx-forward-proxy  | 172.18.0.1 - - [02/Jul/2024:07:06:55 +0000] "CONNECT www.baidu.com:443 HTTP/1.1" 200 5698 "-" "curl/7.68.0" "-"
nginx-forward-proxy  | 172.18.0.1 - - [02/Jul/2024:07:07:00 +0000] "HEAD http://www.google.com/ HTTP/1.1" 200 0 "-" 
"curl/7.68.0" "-"
nginx-forward-proxy  | 172.18.0.1 - - [02/Jul/2024:07:19:32 +0000] "CONNECT k8s.gcr.io:443 HTTP/1.1" 200 4877 "-" "Go-http-client/1.1" "-"
nginx-forward-proxy  | 172.18.0.1 - - [02/Jul/2024:07:19:34 +0000] "CONNECT k8s.gcr.io:443 HTTP/1.1" 200 4913 "-" "Go-http-client/1.1" "-"
nginx-forward-proxy  | 172.18.0.1 - - [02/Jul/2024:07:19:34 +0000] "CONNECT k8s.gcr.io:443 HTTP/1.1" 200 4903 "-" "Go-http-client/1.1" "-"
nginx-forward-proxy  | 172.18.0.1 - - [02/Jul/2024:07:19:34 +0000] "CONNECT k8s.gcr.io:443 HTTP/1.1" 200 4752 "-" "Go-http-client/1.1" "-"
```