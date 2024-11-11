---
layout: post
title: 2024-03-11-Kubernetes部署Nextcloud
date: 2024-03-11
tags: 实战-Kubernetes
music-id: 4876355
---

# 部署 nextcloud

## 一、Docker-compose 部署

参考链接：https://zhengyu.tech/archives/zai-docker-zhong-nextcloud-bu-shu-jiao-cheng

- 首先创建文件夹 nextcloud ，这里将会放 nextcloud 的配置与运行文件

```SH
$ mkdir ~/data
```
### 1. 部署

- 创建 docker-compose 文件

```sh
version: '3.3'

services:
  mysql-nextcloud:
    container_name: mysql-nextcloud
    image: mysql:8.0
    volumes:
      - ./data/mysql:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=RootPassw0rd
      - MYSQL_PASSWORD=nextcloud
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - TZ=Asia/Shanghai
    networks:
      - docker-app
    restart: unless-stopped

  redis-nextcloud:
    container_name: redis-nextcloud
    image: redis:6.0
    environment:
      - TZ=Asia/Shanghai
    command: ["redis-server", "/usr/local/etc/redis/redis.conf"]
    volumes:
      - ./data/redis/data:/data
      - ./data/redis/conf/redis.conf:/usr/local/etc/redis/redis.conf
    networks:
      - docker-app
    restart: unless-stopped

  nextcloud:
    container_name: nextcloud
    image: nextcloud:21
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ./data/nextcloud/config:/var/www/html/config
      - ./data/nextcloud/data:/var/www/html/data
      - ./data/nextcloud/apps:/var/www/html/apps
    networks:
      - docker-app
    restart: unless-stopped

  onlyoffice:
    container_name: onlyoffice
    image: onlyoffice/documentserver
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ./data/onlyoffice/conf:/etc/onlyoffice/
    networks:
      - docker-app
    restart: unless-stopped

networks:
  docker-app:
    external: true
```

首先手动 run 启动一下 onlyoffice 拿到配置文件
```sh
$ docker run -dit --name onlyoffice onlyoffice/documentserver

$ docker cp onlyoffice:/etc/onlyoffice data/onlyoffice/conf

$ ls data/onlyoffice/conf/

$ docker rm -f onlyoffice
```
- 启动

```sh
$ docker-compose up -d
$ docker-compose ps
   Name                 Command               State                  Ports                
------------------------------------------------------------------------------------------
mysql        docker-entrypoint.sh mysqld      Up      3306/tcp, 33060/tcp                 
nextcloud    /entrypoint.sh apache2-for ...   Up      0.0.0.0:8800->80/tcp,:::8800->80/tcp
onlyoffice   /app/ds/run-document-server.sh   Up      443/tcp, 80/tcp                     
redis        docker-entrypoint.sh redis ...   Up      6379/tcp
```
配置 cron 计划任务

```sh
$ crontab -e
*/5 * * * * docker exec --user www-data nextcloud  php /var/www/html/cron.php
```

### 2. nginx 反向代理

```sh
$ mkdir nginx-proxy

$ cd nginx-proxy

$ cat docker-compose.yml
version: "3"

services:
   nginx-proxy:
    container_name: nginx-proxy
    image: zhentianxiang/nginx-plugin:1.20.1-alpha1
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./host-conf/nextcloud.conf:/etc/nginx/conf.d/nextcloud.conf
      - ./ssl/nextcloud/:/etc/nginx/nextcloud
    networks:
      - docker-app

networks:
  docker-app:
    external: true

$ mkdir host-conf

$ vim host-conf/nextcloud.conf
server {
        listen 443 ssl;
        server_name nextcloud.tianxiang.love;
        add_header Strict-Transport-Security "max-age=63072000;";

        ssl_certificate /etc/nginx/nextcloud/nextcloud.tianxiang.love.pem;
        ssl_certificate_key /etc/nginx/nextcloud/nextcloud.tianxiang.love.key;
        ssl_session_timeout 5m;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;

        error_page  403 /403.html;
        error_page  404 /404.html;
        error_page  500 502 503 504 /50.html;

        location = /403.html {
           root /etc/nginx/stylepage/html;
        }

        location = /404.html {
           root /etc/nginx/stylepage/html;
        }

        location = /50.html {
           root /etc/nginx/stylepage/html;
        }

        location / {
               sendfile off;
               proxy_pass         http://nextcloud:80;
               proxy_redirect     default;
               proxy_http_version 1.1;
               proxy_set_header   Connection        $connection_upgrade;
               proxy_set_header   Upgrade           $http_upgrade;
               proxy_set_header   Host              $http_host;
               proxy_set_header   X-Real-IP         $remote_addr;
               proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
               proxy_set_header   X-Forwarded-Proto $scheme;
               proxy_max_temp_file_size 0;
               client_max_body_size       0;
               client_body_buffer_size    2048k;
               proxy_connect_timeout      90;
               proxy_send_timeout         90;
               proxy_read_timeout         90;
               proxy_buffering            off;
               proxy_request_buffering    off;
               proxy_set_header Connection "";
               proxy_ignore_headers Set-Cookie Cache-Control;
               proxy_next_upstream http_502 http_504 error timeout invalid_header;
        }
}

server {
    listen 80;
    server_name  nextcloud.tianxiang.love;
        return   301 https://nextcloud.tianxiang.love$request_uri;
}

$ vim host-conf/onlyoffice.conf

server {
        listen 443 ssl;
        server_name onlyoffice.tianxiang.love;
        add_header Strict-Transport-Security "max-age=63072000;";

        ssl_certificate /etc/nginx/onlyoffice/onlyoffice.tianxiang.love.pem;
        ssl_certificate_key /etc/nginx/onlyoffice/onlyoffice.tianxiang.love.key;
        ssl_session_timeout 5m;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;

        error_page  403 /403.html;
        error_page  404 /404.html;
        error_page  500 502 503 504 /50.html;

        location = /403.html {
           root /etc/nginx/stylepage/html;
        }

        location = /404.html {
           root /etc/nginx/stylepage/html;
        }

        location = /50.html {
           root /etc/nginx/stylepage/html;
        }

        location / {
               sendfile off;
               proxy_pass         http://onlyoffice:80;
               proxy_redirect     default;
               proxy_http_version 1.1;
               proxy_set_header   Connection        $connection_upgrade;
               proxy_set_header   Upgrade           $http_upgrade;
               proxy_set_header   Host              $http_host;
               proxy_set_header   X-Real-IP         $remote_addr;
               proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
               proxy_set_header   X-Forwarded-Proto $scheme;
               proxy_max_temp_file_size 0;
               client_max_body_size       0;
               client_body_buffer_size    2048k;
               proxy_connect_timeout      90;
               proxy_send_timeout         90;
               proxy_read_timeout         90;
               proxy_buffering            off;
               proxy_request_buffering    off;
               proxy_set_header Connection "";
               proxy_ignore_headers Set-Cookie Cache-Control;
               proxy_next_upstream http_502 http_504 error timeout invalid_header;
       }

}

server {
    listen 80;
    server_name  onlyoffice.tianxiang.love;
        return   301 https://onlyoffice.tianxiang.love$request_uri;
}

# 自签证书省略
$ mkdir ssl/nextcloud -pv
$ mkdir ssl/onlyoffice -pv

$ docker-compose up -d

$ docker-compose ps
   Name              Command           State                                   Ports                                 
---------------------------------------------------------------------------------------------------------------------
nginx-proxy   /bin/bash -c /start.sh   Up      0.0.0.0:443->443/tcp,:::443->443/tcp, 0.0.0.0:80->80/tcp,:::80->80/tcp
```

### 3. 优化

#### 1. 登录页面一步步完成

#### 2. 修改 config.php

```sh
# 关闭验证
$ docker exec -it onlyoffice sed -i 's/"rejectUnauthorized": true/"rejectUnauthorized": false/' /etc/onlyoffice/documentserver/default.json

# 修改Authorization为AuthorizationJwt
$ docker exec -it onlyoffice sed -i 's/Authorization/AuthorizationJwt/g' /etc/onlyoffice/documentserver/local.json

# 获取密钥
$ docker exec -it onlyoffice  grep -oP '(?<="string": ")[^"]+'  /etc/onlyoffice/documentserver/local.json

# 重启服务
$ docker exec -it onlyoffice supervisorctl restart all

# 修改 nextcloud 配置文件
$ cd nextcloud/data/nextcloud/config/

$ cp config.php config.php.bak

$ vim config.php
<?php
$CONFIG = array (
  'htaccess.RewriteBase' => '/',
  'memcache.local' => '\\OC\\Memcache\\APCu',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' =>
     array(
       'host' => 'redis-nextcloud',
       'port' => 6379,
       'password' => 'redis',
     ),
  'apps_paths' =>
  array (
    0 =>
    array (
      'path' => '/var/www/html/apps',
      'url' => '/apps',
      'writable' => false,
    ),
    1 =>
    array (
      'path' => '/var/www/html/custom_apps',
      'url' => '/custom_apps',
      'writable' => true,
    ),
  ),
  'instanceid' => 'ocink25vwmez',
  'passwordsalt' => 'av1fCdq6/IjRE1BvXhy5SSqOGLZ3df',
  'secret' => '9D6hPgGznsTsxauynDpvT79Uhht+JAkTAEILwQv3aGgY8Aul',
  'trusted_domains' =>
  array (
    0 => 'nextcloud.tianxiang.love',
  ),
  'datadirectory' => '/var/www/html/data',
  'dbtype' => 'mysql',
  'version' => '21.0.9.1',
  'overwritehost' => 'nextcloud.tianxiang.love',
  'overwriteprotocol' => 'https',
  'overwrite.cli.url' => 'https://nextcloud.tianxiang.love',
  'dbname' => 'nextcloud',
  'dbhost' => 'mysql-nextcloud:3306',
  'dbport' => '',
  'dbtableprefix' => 'oc_',
  'mysql.utf8mb4' => true,
  'dbuser' => 'nextcloud',
  'dbpassword' => 'nextcloud',
  'installed' => true,
  'check_for_working_wellknown_setup' => false,
  'default_phone_region' => 'CN',
  'mail_smtpmode' => 'smtp',
  'mail_smtpsecure' => 'ssl',
  'mail_sendmailmode' => 'smtp',
  'mail_from_address' => '2099xxxxxx',
  'mail_domain' => 'qq.com',
  'mail_smtpauthtype' => 'LOGIN',
  'mail_smtpauth' => 1,
  'mail_smtphost' => 'smtp.qq.com',
  'mail_smtpport' => '465',
  'mail_smtpname' => '2099xxxxxxx',
  'mail_smtppassword' => 'xxxxxxxxx',
  'enabledPreviewProviders' =>
  array (
    0 => 'OC\\Preview\\PNG',
    1 => 'OC\\Preview\\JPEG',
    2 => 'OC\\Preview\\GIF',
    3 => 'OC\\Preview\\HEIC',
    4 => 'OC\\Preview\\BMP',
    5 => 'OC\\Preview\\XBitmap',
    6 => 'OC\\Preview\\MP3',
    7 => 'OC\\Preview\\TXT',
    8 => 'OC\\Preview\\MarkDown',
    9 => 'OC\\Preview\\MP4',
  ),
  'onlyoffice' =>
  array (
    'jwt_secret' => 'vj9VQGEMQezcrTApuw3bGVMgp6x2FFdh',
    'jwt_header' => 'AuthorizationJwt'
  ),
);
```
#### 3. 解决模块不支持 SVG

```sh
$ docker exec -it nextcloud apt update

$ docker exec -it nextcloud apt -y install imagemagick ffmpeg ghostscript
```

#### 4. 重启服务

以上内容修改好之后重启一下服务

```sh
$ cd nextcloud
$ docker-compose restart
```

这里解释一下都添加修改了些什么配置

首先从上往下 redis 缓存

```#!/bin/sh
'memcache.locking' => '\\OC\\Memcache\\Redis',
'redis' =>
   array(
     'host' => 'redis-nextcloud',
     'port' => 6379,
     'password' => 'redis',
   ),
```
开启 https 客户端访问，本地端口还是监听 80
```#!/bin/sh
'overwriteprotocol' => 'https',
'overwrite.cli.url' => 'https://nextcloud.tianxiang.love',
```
关闭wellknown检查
```#!/bin/sh
'check_for_working_wellknown_setup' => false,
```
电话时区
```#!/bin/sh
  'default_phone_region' => 'CN',
```
设置邮箱信息，当然在页面上自己设置也行
```#!/bin/sh
'mail_smtpmode' => 'smtp',
'mail_smtpsecure' => 'ssl',
'mail_sendmailmode' => 'smtp',
'mail_from_address' => '2099xxxxxx',
'mail_domain' => 'qq.com',
'mail_smtpauthtype' => 'LOGIN',
'mail_smtpauth' => 1,
'mail_smtphost' => 'smtp.qq.com',
'mail_smtpport' => '465',
'mail_smtpname' => '2099xxxxxx',
'mail_smtppassword' => 'odvodhixxxxxx',
```
添加一些关于打开各种文件的功能
```#!/bin/sh
'enabledPreviewProviders' =>
array (
  0 => 'OC\\Preview\\PNG',
  1 => 'OC\\Preview\\JPEG',
  2 => 'OC\\Preview\\GIF',
  3 => 'OC\\Preview\\HEIC',
  4 => 'OC\\Preview\\BMP',
  5 => 'OC\\Preview\\XBitmap',
  6 => 'OC\\Preview\\MP3',
  7 => 'OC\\Preview\\TXT',
  8 => 'OC\\Preview\\MarkDown',
  9 => 'OC\\Preview\\MP4',
),
```
添加 onlyoffice 插件，有助于打开 docx 文件，这个密钥就是上面你用命令获取到的
```#!/bin/sh
'onlyoffice' =>
array (
  'jwt_secret' => 'vj9VQGEMQezcrTApuw3bGVMgp6x2FFdh',
  'jwt_header' => 'AuthorizationJwt'
),
```

### 5. 解除上传大小限制

```sh
$ docker exec --user www-data nextcloud php occ config:app:set files max_chunk_size --value 0
```

### 6. 安装onlyoffice 插件

进入页面安装

配置的时候使用 https 连接

关闭证书校验安全

填写密钥

## 二、k8s 部署

### 1. 部署 mysql

```sh
$ cat mysql-8.0.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql
  namespace: nextcloud
  annotations:
    volume.beta.kubernetes.io/storage-class: "nfs-provisioner-storage"
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
  namespace: nextcloud
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: rootPassW0rd
        - name: MYSQL_DATABASE
          value: nextcloud
        - name: MYSQL_USER
          value: nextcloud
        - name: MYSQL_PASSWORD
          value: nextcloud
        ports:
        - name: server
          containerPort: 3306
          protocol: TCP
        livenessProbe:
          exec:
            command:
            - mysql
            - --user=root
            - --password=rootPassW0rd
            - --execute=SELECT 1
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - mysql
            - --user=root
            - --password=rootPassW0rd
            - --execute=SELECT 1
          initialDelaySeconds: 5
          periodSeconds: 10
        volumeMounts:
        - name: db
          mountPath: /var/lib/mysql
      volumes:
      - name: db
        persistentVolumeClaim:
          claimName: mysql
      restartPolicy: Always

---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: nextcloud
spec:
  selector:
    app: mysql
  ports:
  - name: server
    protocol: TCP
    port: 3306
    targetPort: 3306
```

启动

```sh
$ kubectl apply -f mysql-8.0.yaml
```

### 2. 部署 nextcloud

准备 tls 证书文件，可以去云厂商免费申请

这边我先自签一个用来测试

```sh
$ vim script.sh
#!/bin/bash
openssl req  -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 -out ca.crt -subj "/C=CN/L=Beijing/O=lisea/CN=nextcloud.tianxiang.love"
openssl req -newkey rsa:4096 -nodes -sha256 -keyout tls.key -out tls.csr -subj "/C=CN/L=Beijing/O=lisea/CN=nextcloud.tianxiang.love"
# IP地址可以多预留一些，主要是域名能解析到的地址，其他的地址写进去也没用
echo subjectAltName = IP:192.168.1.100, IP:127.0.0.1, DNS:tianxiang.love, DNS:nextcloud.tianxiang.love > extfile.cnf
openssl x509 -req -days 3650 -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out tls.crt

$ bash script.sh

$ kubectl create secret tls nextcloud-tls --cert=tls.crt --key=tls.key -n nextcloud
```

```sh
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nextcloud
  namespace: nextcloud
  annotations:
    # Ingress Controller类别
    kubernetes.io/ingress.class: "nginx"
    # 正则表达式来匹配路径
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    nginx.ingress.kubernetes.io/server-snippet: |
      location = /.well-known/carddav {
          return 301 $scheme://$host:$server_port/remote.php/dav;
      }
      location = /.well-known/caldav {
          return 301 $scheme://$host:$server_port/remote.php/dav;
      }
    nginx.ingress.kubernetes.io/configuration-snippet: |
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
spec:
  tls:
  - hosts:
    - nextcloud.tianxiang.love
    secretName: nextcloud-tls
  rules:
  - host: nextcloud.tianxiang.love  # 将 "yourdomain.com" 替换为你的域名
    http:
      paths:
      - path: /nextcloud/
        pathType: Prefix
        backend:
          service:
            name: nextcloud  # 将 "your-service-name" 替换为你的服务名称
            port:
              number: 80
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nextcloud  # 将 "your-service-name" 替换为你的服务名称
            port:
              number: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nextcloud
  namespace: nextcloud
spec:
  type: NodePort
  selector:
    app: nextcloud
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nextcloud
  name: nextcloud
  namespace: nextcloud
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nextcloud
  template:
    metadata:
      labels:
        app: nextcloud
    spec:
      containers:
      - name: nextcloud
        image: nextcloud:21
        ports:
        - containerPort: 80
        env:
        - name: TZ
          value: "Asia/Shanghai"
        volumeMounts:
        - name: data
          mountPath: /var/www/html/
        resources:
          limits:
            memory: "2Gi"  # 设置内存上限为 2GB
            cpu: "2000m"    # 设置 CPU 上限为 2 核心
          requests:
            memory: "512Mi"  # 设置内存请求为 512MB
            cpu: "500m"      # 设置 CPU 请求为 0.5 核心
      - name: nextcloud-cron
        image: nextcloud:20
        args:
        - /cron.sh
        env:
        - name: TZ
          value: "Asia/Shanghai"
        volumeMounts:
        - name: data
          mountPath: /var/www/html/
        resources:
          limits:
            memory: "1G"  # 设置内存上限为 1GB
            cpu: "1000m"      # 设置 CPU 上限为 1 核心
          requests:
            memory: "500Mi"  # 设置内存请求为 512MB
            cpu: "500m"      # 设置 CPU 请求为 0.5 核心
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: nextcloud-pvc
      terminationGracePeriodSeconds: 60
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-pvc
  namespace: nextcloud
  annotations:
    volume.beta.kubernetes.io/storage-class: "nfs-provisioner-storage"
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
```

启动

```sh
$ kubectl apply -f nextcloud.yaml
```

### 3. 部署 redis

redis yaml 文件

```sh
kind: ConfigMap
apiVersion: v1
metadata:
  name: redis-config
  namespace: nextcloud
  labels:
    app: redis
data:
  redis.conf: |-
    dir /data
    port 6379
    bind 0.0.0.0
    appendonly yes
    protected-mode no
    requirepass redis
    pidfile /data/redis-6379.pid
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: nextcloud
  labels:
    app: redis
spec:
  ports:
    - name: redis
      port: 6379
  selector:
    app: redis
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: nextcloud
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
        logging: "true"
    spec:
      # 进行初始化操作，修改系统配置，解决 Redis 启动时提示的警告信息
      initContainers:
      - name: system-init
        image: busybox:1.32
        imagePullPolicy: IfNotPresent
        command:
          - "sh"
          - "-c"
          - "echo 2048 > /proc/sys/net/core/somaxconn && echo never > /sys/kernel/mm/transparent_hugepage/enabled"
        securityContext:
          privileged: true
          runAsUser: 0
        volumeMounts:
        - name: sys
          mountPath: /sys
      containers:
      - name: redis
        image: sameersbn/redis:latest
        imagePullPolicy: IfNotPresent
        command:
         - "sh"
         - "-c"
         - "redis-server /usr/local/etc/redis/redis.conf"
        ports:
        - containerPort: 6379
        resources:
          limits:
            cpu: 1000m
            memory: 2Gi
          requests:
            cpu: 500m
            memory: 512Mi
        livenessProbe:
          tcpSocket:
            port: 6379
          initialDelaySeconds: 300
          timeoutSeconds: 1
          periodSeconds: 10
          successThreshold: 1
          failureThreshold: 3
        readinessProbe:
          tcpSocket:
            port: 6379
          initialDelaySeconds: 5
          timeoutSeconds: 1
          periodSeconds: 10
          successThreshold: 1
          failureThreshold: 3
        volumeMounts:
        - name: timezone
          mountPath: /etc/localtime
        - name: data
          mountPath: /data
        - name: config
          mountPath: /usr/local/etc/redis/redis.conf
          subPath: redis.conf
      volumes:
        - name: timezone
          hostPath:
            path: /usr/share/zoneinfo/Asia/Shanghai
        - name: config
          configMap:
            name: redis-config
        - name: sys
          hostPath:
            path: /sys
        - name: data
          persistentVolumeClaim:
            claimName: redis-pvc
      restartPolicy: Always
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: redis-pvc
  namespace: nextcloud
  annotations:
    volume.beta.kubernetes.io/storage-class: "nfs-provisioner-storage"
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
```

```sh
$ kubectl apply -f redis.yaml
```

### 4. 优化内容

- 解决：数据库丢失了一些索引

```sh
$ kubectl exec -it -n nextcloud nextcloud-5df94cb48-779ff -c nextcloud -- bash

$ su - www-data

$ php occ db:add-missing-indices
```

- 解决：反向代理头部配置错误，或者您正在通过可信的代理访问 Nextcloud

```sh
# 进入到挂载的目录中
$ pwd
/home/tianxiang/k8s_pvc/nextcloud-nextcloud-pvc-pvc-2984752b-422d-45af-a9e0-3fac10c10ede/

# 首先我们打开 config.php 文件, 修改或添加如下内容
# trusted_proxies，用于指定哪些代理服务器是可信的
# 因为我是用的是 ingress 所以也就是本机去代理的，所以写 192.168.1.100


 20   'trusted_domains' => array (
 21     0 => 'nextcloud.tianxiang.love',
 22   ),
 23   'trusted_proxies' => array('192.168.1.100'),
 24   'overwritehost'     => 'nextcloud.tianxiang.love',
 25   'overwriteprotocol' => 'https',
 26   'overwrite.cli.url' => 'https://nextcloud.tianxiang.love',
```

- 解决：您的安装没有设置默认的电话区域

```sh
 # 添加
 38   'default_phone_region' => 'CN',
```

- 解决：此实例中的 php-imagick 模块不支持 SVG。为了获得更好的兼容性，建议安装它。

我是用了一个 shell 脚本来帮我完成这个容器内的安装工作的，并且使用 k8s 的 job 来托管的

```sh
# 准备脚本文件
$ vim install-imagemagick.sh
#!/bin/bash

# ANSI 颜色码
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # 恢复默认颜色

# 定义保存重启计数的数组变量
declare -A restart_counts

# 定义 Nextcloud Pod 的标签和命名空间
pod_label="app=nextcloud"
namespace="nextcloud"

while true; do
    # 获取具有指定标签的 Pod 的名称
    pod_name=$(kubectl get pods -n $namespace -l $pod_label -o jsonpath='{.items[0].metadata.name}')

    if [[ -z "$pod_name" ]]; then
        echo -e "${RED}错误：在命名空间 $namespace 中找不到带有标签 $pod_label 的 Pod。${NC}"
        exit 1
    fi

    # 读取保存的重启计数到数组中
    while IFS= read -r line; do
        key=$(echo $line | cut -d'=' -f1)
        value=$(echo $line | cut -d'=' -f2)
        restart_counts["$key"]="$value"
    done < restart_counts.txt

    # 获取容器的重启计数
    current_restart_count=$(kubectl get pods -n $namespace $pod_name -o jsonpath='{.status.containerStatuses[*].restartCount}')

    # 如果上次保存的计数存在且与当前计数相等，则说明 Pod 未重启过
    if [[ "${restart_counts[$pod_name]}" == "$current_restart_count" ]]; then
        echo -e "${GREEN}Nextcloud Pod 未重启。${NC}"
    else
        echo -e "${YELLOW}Nextcloud Pod 已重启。运行更新和安装...${NC}"

        # 执行命令
        kubectl exec -it -n $namespace $pod_name -c nextcloud -- apt update
        kubectl exec -it -n $namespace $pod_name -c nextcloud -- apt -y install imagemagick ffmpeg ghostscript

        echo -e "${YELLOW}命令执行成功。${NC}"
    fi

    # 更新数组中的重启计数
    restart_counts["$pod_name"]="$current_restart_count"

    # 将更新后的重启计数保存到文件中
    for key in "${!restart_counts[@]}"; do
        echo "$key=${restart_counts[$key]}" > restart_counts.txt
    done

    # 休眠 300 秒
    sleep 300
done
```

制作镜像

```sh
$ touch restart_counts.txt
$ cp /usr/bin/kubectl .
$ vim Dockerfile
# 使用官方的 Ubuntu 作为基础镜像
FROM ubuntu:latest

# 将脚本文件和kubectl命令复制到镜像中
COPY install-imagemagick.sh /
COPY kubectl /usr/bin/
COPY restart_counts.txt /
# 设置脚本文件为可执行权限
RUN chmod +x /install-imagemagick.sh

# 指定脚本文件为容器启动时的默认命令
CMD ["/install-imagemagick.sh"]

$ docker build . -t install-imagemagick:v1
```

编写 yaml 文件

```sh
$ vim install-imagemagick.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: install-imagemagick
  namespace: nextcloud
spec:
  template:
    spec:
      initContainers:  
      - name: service-check  
        image: curlimages/curl:latest  
        command:  
        - sh  
        - -c  
        - 'until curl --fail --silent --show-error --connect-timeout 5 http://nextcloud:80/; do echo "Waiting for nextcloud service to start..."; sleep 2; done'
      containers:
      - name: ubuntu
        image: install-imagemagick:v1
        volumeMounts:
        - name: kube
          mountPath: /root/.kube
      volumes:
      - name: kube
        hostPath:
          path: /root/.kube
      restartPolicy: OnFailure
```

- 解决视频不显示缩略图

```sh
#配置文件中增加
  'enabledPreviewProviders' => array (
    0 => 'OC\\Preview\\PNG',
    1 => 'OC\\Preview\\JPEG',
    2 => 'OC\\Preview\\GIF',
    3 => 'OC\\Preview\\HEIC',
    4 => 'OC\\Preview\\BMP',
    5 => 'OC\\Preview\\XBitmap',
    6 => 'OC\\Preview\\MP3',
    7 => 'OC\\Preview\\TXT',
    8 => 'OC\\Preview\\MarkDown',
    9 => 'OC\\Preview\\Movie',
    9 => 'OC\\Preview\\PDF',
    9 => 'OC\\Preview\\MP4',
  ),
```

- 使用redis缓存提高效率

```sh
# 继续修改配置文件，添加如下，

'memcache.locking' => '\OC\Memcache\Redis',
'filelocking.enabled' => 'true',
'redis' => array(
    'host' => 'redis',
    'port' => 6379,
    'password' => 'redis',
),
```

重启服务

```sh
$ kubectl delete pods -n nextcloud nextcloud-697b694c84-mhz98
```

- nextcloud基于curl下载share文件

```sh
$ curl -u "SHARE_ID":"SHARE_PASSWORD" -H "X-Requested-With: XMLHttpRequest" "https://nextcloud.tianxiang.love/public.php/webdav/" --output FILENAME
```

- nextcloud基于用户使用curl上传下载文件

```sh
# upload

$ curl -X PUT -u zhentianxiang:123123 https://nextcloud.tianxiang.love/remote.php/dav/files/zhentianxiang/ -T ./image.jpg

# download

$ curl -X GET -u zhentianxiang:123123 https://nextcloud.tianxiang.love/remote.php/dav/files/zhentianxiang/Nextcloud.png --output Nextcloud.png
```

### 5. 配置 smtp 邮件

![](/images/posts/Nextcloud/1.png)

![](/images/posts/Nextcloud/2.png)

![](/images/posts/Nextcloud/3.png)



### 6. 部署 onlyoffice

支持 office 在线编辑插件

```sh
$ vim script.sh
#!/bin/bash
openssl req  -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 3650 -out ca.crt -subj "/C=CN/L=Beijing/O=lisea/CN=nextcloud.tianxiang.love"
openssl req -newkey rsa:4096 -nodes -sha256 -keyout tls.key -out tls.csr -subj "/C=CN/L=Beijing/O=lisea/CN=nextcloud.tianxiang.love"
# IP地址可以多预留一些，主要是域名能解析到的地址，其他的地址写进去也没用
echo subjectAltName = IP:192.168.1.100, IP:127.0.0.1, DNS:tianxiang.love, DNS:nextcloud.tianxiang.love > extfile.cnf
openssl x509 -req -days 3650 -in tls.csr -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out tls.crt

$ bash script.sh

$ kubectl create secret tls nextcloud-tls --cert=tls.crt --key=tls.key -n nextcloud
```

```sh
$ apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: onlyoffice-pvc
  namespace: nextcloud
  annotations:
    volume.beta.kubernetes.io/storage-class: "nfs-provisioner-storage"
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: onlyoffice
  namespace: nextcloud
  labels:
    app: onlyoffice
spec:
  replicas: 1
  selector:
    matchLabels:
      app: onlyoffice
  template:
    metadata:
      labels:
        app: onlyoffice
    spec:
      containers:
      - name: onlyoffice
        image: onlyoffice/documentserver
        env:
        - name: TZ
          value: "Asia/Shanghai"
        ports:
        - name: server
          containerPort: 80
          protocol: TCP
        volumeMounts:
        - name: data
          mountPath: "/var/www/onlyoffice/data"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: onlyoffice-pvc
      restartPolicy: Always

---
apiVersion: v1
kind: Service
metadata:
  name: onlyoffice
  namespace: nextcloud
spec:
  selector:
    app: onlyoffice
  type: NodePort
  ports:
  - name: server
    protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: onlyoffice
  namespace: nextcloud
  annotations:
    # Ingress Controller类别
    kubernetes.io/ingress.class: "nginx"
    # 正则表达式来匹配路径
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  tls:
  - hosts:
    - onlyoffice.tianxiang.love
    secretName: onlyoffice-tls
  rules:
  - host: onlyoffice.tianxiang.love
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: onlyoffice
            port:
              number: 80
```

启动

```sh
$ kubectl apply -f onlyoffice.yaml
```

查看所有服务启动情况

```sh
$ kubectl get pod -n nextcloud
NAME                          READY   STATUS    RESTARTS   AGE
mysql-79b99dfbd-m66cz         1/1     Running   0          32m
nextcloud-5df94cb48-pfh98     2/2     Running   0          31m
onlyoffice-5b5cc6c798-g7jzt   1/1     Running   0          31m
```

### 7. 添加 onlyoffice 插件

```sh
$ ls
3rdparty  AUTHORS  console.php  core      custom_apps  index.html  lib  ocm-provider  ocs-provider  remote.php  robots.txt  themes
apps      config   COPYING      cron.php  data         index.php   occ  ocs           public.php    resources   status.php  version.php
$ cd apps/

# 进入到挂载的目录中
$ pwd
/home/tianxiang/k8s_pvc/nextcloud-nextcloud-pvc-pvc-2984752b-422d-45af-a9e0-3fac10c10ede/apps

# 网络问题的情况下可以通过此办法下载插件包，并安装
$ wget https://github.com/ONLYOFFICE/onlyoffice-nextcloud/releases/download/v7.3.0/onlyoffice.tar.gz

$ tar xvf onlyoffice.tar.gz
```

回到界面中

![](/images/posts/Nextcloud/4.png)

![](/images/posts/Nextcloud/5.png)



```sh
# 查看 ingress
$ kubectl get ingress -n nextcloud
NAME         CLASS    HOSTS                       ADDRESS   PORTS   AGE
nextcloud    <none>   nextcloud.tianxiang.love              80      43m
onlyoffice   <none>   onlyoffice.tianxiang.love             80      34m
```

![](/images/posts/Nextcloud/5.png)

### 8. 测试功能是否健全

- 使用 job pod 来修改 onlyoffcie 配置文件，关闭 SSL 验证

```sh
$ vim sed-onlyoffice.sh
#!/bin/bash

# ANSI 颜色码
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # 恢复默认颜色

# 定义保存重启计数的数组变量
declare -A restart_counts

# 定义 Nextcloud Pod 的标签和命名空间
pod_label="app=onlyoffice"
namespace="nextcloud"

while true; do
    # 获取具有指定标签的 Pod 的名称
    pod_name=$(kubectl get pods -n $namespace -l $pod_label -o jsonpath='{.items[0].metadata.name}')

    if [[ -z "$pod_name" ]]; then
        echo -e "${RED}错误：在命名空间 $namespace 中找不到带有标签 $pod_label 的 Pod。${NC}"
        exit 1
    fi

    # 读取保存的重启计数到数组中
    while IFS= read -r line; do
        key=$(echo $line | cut -d'=' -f1)
        value=$(echo $line | cut -d'=' -f2)
        restart_counts["$key"]="$value"
    done < restart_counts.txt

    # 获取容器的重启计数
    current_restart_count=$(kubectl get pods -n $namespace $pod_name -o jsonpath='{.status.containerStatuses[*].restartCount}')

    # 如果上次保存的计数存在且与当前计数相等，则说明 Pod 未重启过
    if [[ "${restart_counts[$pod_name]}" == "$current_restart_count" ]]; then
        echo -e "${GREEN}OnlyOffice Pod 未重启。${NC}"
    else
        echo -e "${YELLOW}OnlyOffice Pod 已重启。运行更新和安装...${NC}"

        # 执行命令
        kubectl exec -it -n $namespace $pod_name -- sed -i 's/"rejectUnauthorized": true/"rejectUnauthorized": false/' /etc/onlyoffice/documentserver/default.json
        kubectl exec -it -n $namespace $pod_name -- supervisorctl restart all


        echo -e "${YELLOW}命令执行成功。${NC}"
    fi

    # 更新数组中的重启计数
    restart_counts["$pod_name"]="$current_restart_count"

    # 将更新后的重启计数保存到文件中
    for key in "${!restart_counts[@]}"; do
        echo "$key=${restart_counts[$key]}" > restart_counts.txt
    done

    # 休眠 300 秒
    sleep 300
done

$ vim Dockerfile
# 使用官方的 Ubuntu 作为基础镜像
FROM ubuntu:latest

# 将脚本文件复制到镜像中
COPY sed-onlyoffice.sh /
COPY kubectl /usr/bin/
COPY restart_counts.txt /

# 设置脚本文件为可执行权限
RUN chmod +x /sed-onlyoffice.sh

# 指定脚本文件为容器启动时的默认命令
CMD ["/sed-onlyoffice.sh"]

$ touch restart_counts.txt

$ docker build . -t sed-onlyoffice:v1

$ vim sed-onlyoffice.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: sed-onlyoffice
  namespace: nextcloud
spec:
  template:
    spec:
      initContainers:  
      - name: service-check  
        image: curlimages/curl:latest  
        command:  
        - sh  
        - -c  
        - 'until curl --fail --silent --show-error --connect-timeout 5 http://onlyoffice:80/; do echo "Waiting for nextcloud service to start..."; sleep 2; done'
      containers:
      - name: ubuntu
        image: sed-onlyoffice:v1
        volumeMounts:
        - name: kube
          mountPath: /root/.kube
      volumes:
      - name: kube
        hostPath:
          path: /root/.kube
      restartPolicy: OnFailure

$ kubectl apply -f sed-onlyoffice.yaml

$ kubectl logs -n nextcloud sed-onlyoffice-q5l2b
OnlyOffice Pod 已重启。运行更新和安装...
Unable to use a TTY - input is not a terminal or the right kind of file
Unable to use a TTY - input is not a terminal or the right kind of file
ds:docservice: stopped
ds:converter: stopped
ds:metrics: stopped
ds:docservice: started
ds:converter: started
ds:metrics: started
ds:example: started
命令执行成功。
OnlyOffice Pod 未重启。
```

![](/images/posts/Nextcloud/7.png)

![](/images/posts/Nextcloud/8.png)

![](/images/posts/Nextcloud/9.png)

- 使用应用市场直接安装

![](/images/posts/Nextcloud/11.png)
