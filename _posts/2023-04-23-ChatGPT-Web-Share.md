---
layout: post
title: 2023-04-23-ChatGPT-Web-Share
date: 2023-04-23
tags: 其他
music-id: 25640392
---

使用脚本检查该机器是否符合使用ChatGPT

```sh
$ bash <(curl -Ls https://raw.githubusercontent.com/missuo/OpenAI-Checker/main/openai.sh)
```

```sh
#!/bin/bash
###
 # @Author: Vincent Young
 # @Date: 2023-02-09 17:39:59
 # @LastEditors: Vincent Young
 # @LastEditTime: 2023-02-15 20:54:40
 # @FilePath: /OpenAI-Checker/openai.sh
 # @Telegram: https://t.me/missuo
 # 
 # Copyright © 2023 by Vincent, All Rights Reserved. 
### 

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
PLAIN='\033[0m'
BLUE="\033[36m"

SUPPORT_COUNTRY=(AL DZ AD AO AG AR AM AU AT AZ BS BD BB BE BZ BJ BT BO BA BW BR BN BG BF CV CA CL CO KM CG CR CI HR CY CZ DK DJ DM DO EC SV EE FJ FI FR GA GM GE DE GH GR GD GT GN GW GY HT VA HN HU IS IN ID IQ IE IL IT JM JP JO KZ KE KI KW KG LV LB LS LR LI LT LU MG MW MY MV ML MT MH MR MU MX FM MD MC MN ME MA MZ MM NA NR NP NL NZ NI NE NG MK NO OM PK PW PS PA PG PY PE PH PL PT QA RO RW KN LC VC WS SM ST SN RS SC SL SG SK SI SB ZA KR ES LK SR SE CH TW TZ TH TL TG TO TT TN TR TV UG UA AE GB US UY VU ZM)
echo -e "${BLUE}OpenAI Access Checker. Made by Vincent${PLAIN}"
echo -e "${BLUE}https://github.com/missuo/OpenAI-Checker${PLAIN}"
echo "-------------------------------------"
if [[ $(curl -sS https://chat.openai.com/ -I | grep "text/plain") != "" ]]
then
	echo "Your IP is BLOCKED!"
else
	echo -e "[IPv4]"
	check4=`ping 1.1.1.1 -c 1 2>&1`;
	if [[ "$check4" != *"received"* ]] && [[ "$check4" != *"transmitted"* ]];then
		echo -e "\033[34mIPv4 is not supported on the current host. Skip...\033[0m";
	else
		# local_ipv4=$(curl -4 -s --max-time 10 api64.ipify.org)
		local_ipv4=$(curl -4 -sS https://chat.openai.com/cdn-cgi/trace | grep "ip=" | awk -F= '{print $2}')
		local_isp4=$(curl -s -4 --max-time 10  --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36" "https://api.ip.sb/geoip/${local_ipv4}" | grep organization | cut -f4 -d '"')
		#local_asn4=$(curl -s -4 --max-time 10  --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36" "https://api.ip.sb/geoip/${local_ipv4}" | grep asn | cut -f8 -d ',' | cut -f2 -d ':')
		echo -e "${BLUE}Your IPv4: ${local_ipv4} - ${local_isp4}${PLAIN}"
		iso2_code4=$(curl -4 -sS https://chat.openai.com/cdn-cgi/trace | grep "loc=" | awk -F= '{print $2}')
		if [[ "${SUPPORT_COUNTRY[@]}"  =~ "${iso2_code4}" ]]; 
		then
			echo -e "${GREEN}Your IP supports access to OpenAI. Region: ${iso2_code4}${PLAIN}" 
		else
			echo -e "${RED}Region: ${iso2_code4}. Not support OpenAI at this time.${PLAIN}"
		fi
	fi
	echo "-------------------------------------"
	echo -e "[IPv6]"
	check6=`ping6 240c::6666 -c 1 2>&1`;
	if [[ "$check6" != *"received"* ]] && [[ "$check6" != *"transmitted"* ]];then
		echo -e "\033[34mIPv6 is not supported on the current host. Skip...\033[0m";    
	else
		# local_ipv6=$(curl -6 -s --max-time 20 api64.ipify.org)
		local_ipv6=$(curl -6 -sS https://chat.openai.com/cdn-cgi/trace | grep "ip=" | awk -F= '{print $2}')
		local_isp6=$(curl -s -6 --max-time 10 --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36" "https://api.ip.sb/geoip/${local_ipv6}" | grep organization | cut -f4 -d '"')
		#local_asn6=$(curl -s -6 --max-time 10  --user-agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.87 Safari/537.36" "https://api.ip.sb/geoip/${local_ipv6}" | grep asn | cut -f8 -d ',' | cut -f2 -d ':')
		echo -e "${BLUE}Your IPv6: ${local_ipv6} - ${local_isp6}${PLAIN}"
		iso2_code6=$(curl -6 -sS https://chat.openai.com/cdn-cgi/trace | grep "loc=" | awk -F= '{print $2}')
		if [[ "${SUPPORT_COUNTRY[@]}"  =~ "${iso2_code6}" ]]; 
		then
			echo -e "${GREEN}Your IP supports access to OpenAI. Region: ${iso2_code6}${PLAIN}" 
		else
			echo -e "${RED}Region: ${iso2_code6}. Not support OpenAI at this time.${PLAIN}"
		fi
	fi
	echo "-------------------------------------"
fi
```

## 一、准备配置文件


Token获取: https://chat.openai.com/api/auth/session

config.yaml

```yaml
penai_web:
  is_plus_account: true
  # 注意用户名密码和地址，这里配置了的话环境变量就不需要指定了
  chatgpt_base_url: http://10.0.16.9:8080/chatgpt/backend-api/
  common_timeout: 10
  ask_timeout: 600
openai_api:
  openai_base_url: https://api.openai.com/v1/
  proxy:
  connect_timeout: 10
  read_timeout: 20
common:
  print_sql: true
  create_initial_admin_user: true
  initial_admin_user_username: admin
  initial_admin_user_password: password
  sync_conversations_on_startup: true
  sync_conversations_regularly: true
http:
  host: 127.0.0.1
  port: 8000
  cors_allow_origins:
  - http://localhost
  - http://127.0.0.1
data:
  data_dir: /data
  database_url: sqlite+aiosqlite:///data/database.db
  # 注意用户密码和地址
  mongodb_url: mongodb://cws:password@chatgpt-mongodb:27017
  run_migration: true
auth:
  jwt_secret: MODIFY_THIS_TO_RANDOM_SECRET
  jwt_lifetime_seconds: 86400
  cookie_max_age: 86400
  cookie_name: user_auth
  user_secret: MODIFY_THIS_TO_RANDOM_SECRET
stats:
  ask_stats_ttl: 7776000
  request_stats_ttl: 2592000
  request_stats_filter_keywords:
  - /status
log:
  console_log_level: INFO
```

## 二、docker 启动

### 1. 手动启动

启动 mongodb

```sh
$ docker run -dti --name chatgpt-mongodb -p 27017:27017 -e MONGO_INITDB_DATABASE=cws -e MONGO_INITDB_ROOT_USERNAME=cws -e MONGO_INITDB_ROOT_PASSWORD=password --restart=always mongo:6.0
```

因为我的机器无法正常访问外网，所以添加了环境变量进行代理http

启动 api-server

```sh
$ docker run -dti --name chatgpt-api-server -p 8080:8080 -e PROXY="socks5://10.0.16.9:7890" -e TZ=Asia/Shanghai --restart=always linweiyuan/go-chatgpt-api:latest
```

启动 share-web

```sh
$ mkdir data/config -pv
$ docker run -dit --name chatgpt-web-share -p 80:80 -v `pwd`/data:/app/backend/data/config/ -e TZ=Asia/Shanghai -e CHATGPT_BASE_URL=http://10.0.16.9:8080/ --restart=always moeakwak/chatgpt-web-share:0.4.0-alpha4.4
```

```sh
$ docker ps |grep -E "web-share|proxy-server|api-server"
```

### 2. docker-compose 启动

```sh
$ mkdir data/config -pv
```

```yaml
version: "3"

services:
  chatgpt-web-share:
    container_name: web-share
    image: zhentianxiang/chatgpt-web-share:0.4.0-alpha4.4
    ports:
      - 8080:80
    volumes:
      - ./data:/app/backend/data/
    environment:
      - TZ=Asia/Shanghai
      - CWS_CONFIG_DIR=/app/backend/data/config
    depends_on:
      - chatgpt-api-server
    restart: always

  chatgpt-api-server:
    container_name: api-server
    image: zhentianxiang/go-chatgpt-api:0.4.0-alpha4.4
    ports:
      - 8081:8080
    restart: always

  chatgpt-mongodb:
    container_name: mongodb
    image: mongo:6.0
    ports:
      - 27017:27017
    volumes:
      - ./mongo_data:/data/db
    environment:
      MONGO_INITDB_DATABASE: cws
      MONGO_INITDB_ROOT_USERNAME: cws
      MONGO_INITDB_ROOT_PASSWORD: password
    restart: always
```

```sh
$ docker-compose up -d
```

## 三、k8s 启动

api-server

```sh
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chatgpt-api
  namespace: chatgpt
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chatgpt-api
  template:
    metadata:
      labels:
        app: chatgpt-api
    spec:
      containers:
      - name: chatgpt-api
        image: zhentianxiang/go-chatgpt-api:0.4.0-alpha4.4
        imagePullPolicy: IfNotPresent
        env:
        - name: PROXY
          value: "socks5://10.0.16.9:7890"
        ports:
        - name: chatgpt-api
          protocol: TCP
          containerPort: 8080
        # 存活探针
        livenessProbe:
          tcpSocket:
            port: 8080
          initialDelaySeconds: 15  # 指定探针后多少秒后启动，也可以是容器启动15秒后开始探测
          periodSeconds: 3     # 第一次探测结束后，等待多少时间后对容器再次进行探测
          successThreshold: 1 # 探测失败到成功的重试次数，也就是1次失败后直接重启容器，针对于livenessProbe
          timeoutSeconds: 10    # 单次探测超时时间
        # 就绪性探针
        readinessProbe:
          tcpSocket:
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 3
          failureThreshold: 3  # 探测成功到失败的重试次数，3次失败后会将容器挂起，不提供访问流量
          timeoutSeconds: 10
        volumeMounts:
          - name: host-time
            mountPath: /etc/localtime
            readOnly: true              
      volumes:
      - name: host-time
        hostPath:
          path: /etc/localtime
      restartPolicy: Always
```

```sh
[root@VM-16-9-centos chatgpt-api]# cat chatgpt-api-svc.yaml 
apiVersion: v1
kind: Service
metadata:
  name: chatgpt-api
  namespace: chatgpt
spec:
  type: NodePort
  selector:
    app: chatgpt-api
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
```

web-share

```sh
[root@VM-16-9-centos chatgpt-web-share]# kubectl label nodes vm-16-9-centos chatgpt=yes
[root@VM-16-9-centos chatgpt-web-share]# cat chatgpt-web-share-dp.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chatgpt-web-share
  namespace: chatgpt
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chatgpt-web-share
  template:
    metadata:
      labels:
        app: chatgpt-web-share
    spec:
      nodeSelector:
        chatgpt: yes
      containers:
      - name: chatgpt-web-share
        image: zhentianxiang/chatgpt-web-share:0.4.0-alpha4.4
        imagePullPolicy: IfNotPresent
        ports:
        - name: web
          protocol: TCP
          containerPort: 80
        resources:
          limits:
            cpu: 1000m
            memory: 1Gi
          requests:
            cpu: 50m
            memory: 50Mi
        # 存活探针
        livenessProbe:
          httpGet:    # httpGet请求方式
            path: /
            port: 80 # 请求端口
          initialDelaySeconds: 15  # 指定探针后多少秒后启动，也可以是容器启动15秒后开始探测
          periodSeconds: 3     # 第一次探测结束后，等待多少时间后对容器再次进行探测
          successThreshold: 1 # 探测失败到成功的重试次数，也就是1次失败后直接重启容器，针对于livenessProbe
          timeoutSeconds: 10    # 单次探测超时时间
        # 就绪性探针
        readinessProbe:
          httpGet:
            path: /
            port: 80
            scheme: HTTP
          initialDelaySeconds: 15
          periodSeconds: 3
          failureThreshold: 3  # 探测成功到失败的重试次数，3次失败后会将容器挂起，不提供访问流量
          timeoutSeconds: 10
        volumeMounts:
          - name: config
            mountPath: /app/backend/data/
          - name: host-time
            mountPath: /etc/localtime
            readOnly: true              
      volumes:
      - name: config
        hostPath:
          path: /data/chatgpt-web/data
      - name: host-time
        hostPath:
          path: /etc/localtime
      restartPolicy: Always
```

```sh
[root@VM-16-9-centos chatgpt-web-share]# cat chatgpt-web-share-svc.yaml 
apiVersion: v1
kind: Service
metadata:
  name: chatgpt-web-share
  namespace: chatgpt
spec:
  type: NodePort
  selector:
    app: chatgpt-web-share
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
```

```sh
[root@VM-16-9-centos chatgpt-web-share]# mkdir /data/chatgpt-web/data/config -pv
[root@VM-16-9-centos chatgpt-web-share]# vim /data/chatgpt-web/data/config/config.yaml
openai_web:
  is_plus_account: true
  chatgpt_base_url: http://10.111.46.87:8080/chatgpt/backend-api/
  common_timeout: 10
  ask_timeout: 600
openai_api:
  openai_base_url: https://api.openai.com/v1/
  proxy:
  connect_timeout: 10
  read_timeout: 20
common:
  print_sql: true
  create_initial_admin_user: true
  initial_admin_user_username: admin
  initial_admin_user_password: password
  sync_conversations_on_startup: true
  sync_conversations_regularly: true
http:
  host: 127.0.0.1
  port: 8000
  cors_allow_origins:
  - http://localhost
  - http://127.0.0.1
data:
  data_dir: /data
  database_url: sqlite+aiosqlite:///data/database.db
  mongodb_url: mongodb://cws:password@chatgpt-mongodb:27017
  run_migration: true
auth:
  jwt_secret: MODIFY_THIS_TO_RANDOM_SECRET
  jwt_lifetime_seconds: 86400
  cookie_max_age: 86400
  cookie_name: user_auth
  user_secret: MODIFY_THIS_TO_RANDOM_SECRET
stats:
  ask_stats_ttl: 7776000
  request_stats_ttl: 2592000
  request_stats_filter_keywords:
  - /status
log:
  console_log_level: INFO
[root@VM-16-9-centos chatgpt-web-share]# vim /data/chatgpt-web/data/config/credentials.yaml
openai_web_access_token: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6Ik1UaEVOVUpHTkVNMVFURTRNMEZCTWpkQ05UZzVNRFUxUlRVd1FVSkRNRU13UmtGRVFrRXpSZyJ9.eyJodHRwczovL2FwaS5vcGVuYWkuY29tL3Byb2ZpbGUiOnsiZW1haWwiOiJ6aGVubW91cmVuZXJAZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWV9LCJodHRwczovL2FwaS5vcGVuYWkuY29tL2F1dGgiOnsidXNlcl9pZCI6InVzZXItUDdZYUpBRVhxQm1oaThJdXRwbTM2S3JiIn0sImlzcyI6Imh0dHBzOi8vYXV0aDAub3BlbmFpLmNvbS8iLCJzdWIiOiJnb29nbGUtb2F1dGgyfDExMDQ5Njg3ODQ5ODYxMTI4MzUzOSIsImF1ZCI6WyJodHRwczovL2FwaS5vcGVuYWkuY29tL3YxIiwiaHR0cHM6Ly9vcGVuYWkub3BlbmFpLmF1dGgwYXBwLmNvbS91c2VyaW5mbyJdLCJpYXQiOjE2OTAwMzExNTIsImV4cCI6MTY5MTI0MDc1MiwiYXpwIjoiVGRKSWNiZTE2V29USHROOTVueXl3aDVFNHlPbzZJdEciLCJzY29wZSI6Im9wZW5pZCBwcm9maWxlIGVtYWlsIG1vZGVsLnJlYWQgbW9kZWwucmVxdWVzdCBvcmdhbml6YXRpb24ucmVhZCBvcmdhbml6YXRpb24ud3JpdGUgb2ZmbGluZV9hY2Nlc3MifQ.iVPCaEUsDyhilFjfcjVFjR3k1SdAX1Ah-dK4wQKEXQcuDEPmroKVdnVNjW3Qhs81Q4a6qLkx77fyH2JNwQXSYttsbFNYPmzLlUwvm4Jc2vwy6PLPMDY63HUFOqE9_iX0VjyuKuafwcZun_0O4OxcF9KwDiiKwo6mkPPWD5w7kJe43bdmYsCI8bSAMPmbAqCFxAd0p41Z4MA8e6ZI7a_ogdllkjxG_EXnTNP9fHuyGiaZV4FBVNZrWb6obW6VXO1x_ZiL4nNjM4O3AITOLM_yFHQ6Ze50XV1py-cOpoKRH1RYUG1cPATrhcD3Yy9tOZG_T4dD2UiblVuWenTcsO_hEg"
openai_api_key: ""
[root@VM-16-9-centos chatgpt-web-share]# kubectl apply -f .
```

自动更新服务脚本,在控制台上修改openai会话token后自动检查后重启 pod

```sh
[root@VM-16-9-centos chatgpt-web-share]# vim chatgpt-web_monitor.sh 
#!/bin/bash

# 监测的配置文件路径
config_file="/data/chatgpt-web/data/config/config.yaml"
credentials_file="/data/chatgpt-web/data/config/credentials.yaml"

# 输出的log文件
log_file="/var/log/chatgpt-web_monitor.log"

# 初始化md5值为空
old_md5_config=""
old_md5_credentials=""

# 无限循环，每隔一分钟执行一次
while true; do
    # 获取当前config.yaml和credentials.yaml文件的md5值
    current_md5_config=$(md5sum "$config_file" | awk '{print $1}')
    current_md5_credentials=$(md5sum "$credentials_file" | awk '{print $1}')

    # 检查哪个文件被修改，并输出到日志
    if [[ "$current_md5_config" != "$old_md5_config" ]]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - $config_file 文件已修改" >> "$log_file"
    fi

    if [[ "$current_md5_credentials" != "$old_md5_credentials" ]]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - $credentials_file 文件已修改" >> "$log_file"
    fi

    # 如果任意文件md5值发生变化，则执行命令
    if [[ "$current_md5_config" != "$old_md5_config" || "$current_md5_credentials" != "$old_md5_credentials" ]]; then
        # pod 名称
        pod_name=$(kubectl get pods -n chatgpt | grep -o 'chatgpt-web-share-[^[:space:]]*' | tail -n 1)
        # 执行 kubectl delete 命令，并将结果输出到日志文件
        kubectl delete pods -n chatgpt $pod_name >> "$log_file" 2>&1
        wait
        if [ $? -eq 0 ]; then
            echo "$(date +'%Y-%m-%d %H:%M:%S') - 执行 kubectl delete 成功" >> "$log_file"
        else
            echo "$(date +'%Y-%m-%d %H:%M:%S') - 执行 kubectl delete 失败" >> "$log_file"
        fi

        # 更新old_md5的值为当前md5，以便下次比较
        old_md5_config="$current_md5_config"
        old_md5_credentials="$current_md5_credentials"
    fi

    # 等待60秒后再次执行
    sleep 60
done
```

## 四、Nginx 代理

使用 nginx 虚拟主机进行代理 chatgpt-web-share

```sh
[root@VM-16-9-centos conf.d]# vim /etc/nginx/nginx.conf
# http 段内添加后端server
upstream chatgpt-web-share {
    server 10.0.16.9:8081 weight=1 max_fails=2 fail_timeout=30s;
}
[root@VM-16-9-centos conf.d]# vim /etc/nginx/conf.d/chatgpt-web-share.conf
server {
    listen 80;
    server_name chatgpt.linuxtian.top;
    access_log  /var/log/nginx/chatgpt/access.log  main;
    error_log   /var/log/nginx/chatgpt/error.log;

  location / {
      sendfile off;
      proxy_pass         http://chatgpt-web-share;
      proxy_redirect     default;
      proxy_http_version 1.1;

      # Required for Jenkins websocket agents
      proxy_set_header   Connection        $connection_upgrade;
      proxy_set_header   Upgrade           $http_upgrade;

      proxy_set_header   Host              $http_host;
      proxy_set_header   X-Real-IP         $remote_addr;
      proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto $scheme;
      proxy_max_temp_file_size 0;

      #this is the maximum upload size
      client_max_body_size       10m;
      client_body_buffer_size    128k;

      proxy_connect_timeout      90;
      proxy_send_timeout         90;
      proxy_read_timeout         90;
      proxy_buffering            off;
      proxy_request_buffering    off; # Required for HTTP CLI commands
      proxy_set_header Connection ""; # Clear for keepalive
      }
}
[root@VM-16-9-centos conf.d]# systemctl restart nginx
```

如果想用 https，如下

```sh
# 使用ACME自签证书，更多详情请看：https://www.panyanbin.com/article/c44653d8.html
[root@VM-16-9-centos conf.d]# curl  https://get.acme.sh | sh
[root@VM-16-9-centos conf.d]# ln -s  /root/.acme.sh/acme.sh /usr/local/bin/acme.sh
[root@VM-16-9-centos conf.d]# acme.sh --set-default-ca  --server  letsencrypt
[root@VM-16-9-centos conf.d]# acme.sh  --issue -d chatgpt.linuxtian.top -k ec-256 --nginx
[root@VM-16-9-centos conf.d]# mkdir -pv /etc/nginx/certs/chatgpt.linuxtian.top
[root@VM-16-9-centos conf.d]# cp /root/.acme.sh/chatgpt.linuxtian.top_ecc/chatgpt.linuxtian.top.cer /etc/nginx/certs/chatgpt.linuxtian.top
[root@VM-16-9-centos conf.d]# cp /root/.acme.sh/chatgpt.linuxtian.top_ecc/chatgpt.linuxtian.top.key /etc/nginx/certs/chatgpt.linuxtian.top

# 配置conf文件
[root@VM-16-9-centos conf.d]# vim /etc/nginx/conf.d/chatgpt-web-share.conf
server {
        listen 80;
        server_name chatgpt.linuxtian.top;
        return 301 https://chatgpt.linuxtian.top$request_uri;
}

server {
        listen 443 ssl;
        server_name chatgpt.linuxtian.top;
        access_log  /var/log/nginx/chatgpt/access.log  main;
        error_log   /var/log/nginx/chatgpt/error.log;

        ssl_certificate /etc/nginx/cert/chatgpt.linuxtian.top/chatgpt.linuxtian.top.cer;
        ssl_certificate_key /etc/nginx/cert/chatgpt.linuxtian.top/chatgpt.linuxtian.top.key;
        ssl_session_timeout 5m;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;



  location / {
      sendfile off;
      proxy_pass         http://chatgpt-web-share;
      proxy_redirect     default;
      proxy_http_version 1.1;

      # Required for Jenkins websocket agents
      proxy_set_header   Connection        $connection_upgrade;
      proxy_set_header   Upgrade           $http_upgrade;

      proxy_set_header   Host              $http_host;
      proxy_set_header   X-Real-IP         $remote_addr;
      proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto $scheme;
      proxy_max_temp_file_size 0;

      #this is the maximum upload size
      client_max_body_size       10m;
      client_body_buffer_size    128k;

      proxy_connect_timeout      90;
      proxy_send_timeout         90;
      proxy_read_timeout         90;
      proxy_buffering            off;
      proxy_request_buffering    off; # Required for HTTP CLI commands
      proxy_set_header Connection ""; # Clear for keepalive
      }
}
[root@VM-16-9-centos conf.d]# nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
[root@VM-16-9-centos conf.d]# nginx -s reload
```
