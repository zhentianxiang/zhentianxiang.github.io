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
print_sql: false
host: "127.0.0.1"
port: 8000
data_dir: /data # <------ v0.3.0 以上新增
database_url: "sqlite+aiosqlite:////data/database.db" # 特别注意：这里有四个斜杠，代表着文件位于 /data 目录，使用的是绝对路径
run_migration: false # 是否在启动时运行数据库迁移，目前没有必要启用

jwt_secret: "test" # 用于生成 jwt token，自行填写随机字符串
jwt_lifetime_seconds: 86400 # jwt token 过期时间
cookie_max_age: 86400 # cookie 过期时间
user_secret: "test" # 用于生成用户密码，自行填写随机字符串

sync_conversations_on_startup: true # 是否在启动时同步同步 ChatGPT 对话，建议启用。启用后，将会自动将 ChatGPT 中新增的对话同步到数据库中，并把已经不在 ChatGPT 中的对话标记为无效
create_initial_admin_user: true # 是否创建初始管理员用户
initial_admin_username: admin # 初始管理员用户名
initial_admin_password: password # 初始管理员密码
ask_timeout: 600    # 用于限制对话的最长时间

chatgpt_access_token: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6Ik1UaEVOVUpHTkVNMVFURTRNMEZCTWpkQ05UZzVNRFUxUlRVd1FVSkRNRU13UmtGRVFrRXpSZyJ9.eyJodHRwczovL2FwaS5vcGVuYWkuY29tL3Byb2ZpbGUiOnsiZW1haWwiOiJ6aGVubW91cmVuZXJAZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWV9LCJodHRwczovL2FwaS5vcGVuYWkuY29tL2F1dGgiOnsidXNlcl9pZCI6InVzZXItUDdZYUpBRVhxQm1oaThJdXRwbTM2S3JiIn0sImlzcyI6Imh0dHBzOi8vYXV0aDAub3BlbmFpLmNvbS8iLCJzdWIiOiJnb29nbGUtb2F1dGgyfDExMDQ5Njg3ODQ5ODYxMTI4MzUzOSIsImF1ZCI6WyJodHRwczovL2FwaS5vcGVuYWkuY29tL3YxIiwiaHR0cHM6Ly9vcGVuYWkub3BlbmFpLmF1dGgwYXBwLmNvbS91c2VyaW5mbyJdLCJpYXQiOjE2ODA5NTQ0OTAsImV4cCI6MTY4MjE2NDA5MCwiYXpwIjoiVGRKSWNiZTE2V29USHROOTVueXl3aDVFNHlPbzZJdEciLCJzY29wZSI6Im9wZW5pZCBwcm9maWxlIGVtYWlsIG1vZGVsLnJlYWQgbW9kZWwucmVxdWVzdCBvcmdhbml6YXRpb24ucmVhZCBvZmZsaW5lX2FjY2VzcyJ9.xLSeptVDPBMdC72T70PyrbxFS1-Bj9ZRm3OCaKwjyyyH3WU6zClw99E1bjNYTIenI9GMzjGZwFajj1BpAT61c18vmR5H7Idi3_IUJ3ZdrVipAhR5LQk1bZGVk2W34i4w-LzK4H3qN-5Eg0d8_EsJJzDea3yhNgs81bU-tplbBHM2JRCNe8cWjaltdMVJzSgTcxeWduBfoFclIK7RmCM-sHpAMy_JcmNKJafEycBqxJUp8rOjKUd3444Y8HBH7VETmZBEUIYkFoPS4onaT9Xkw-N5zUMlE5u2hxrRHfdAcZqQN2049DGUG3myk4k3_hxdnfNf42BWmjPjWcG0bT7eRQ" # 需要从 ChatGPT 获取，见后文
chatgpt_paid: false # 是否为 ChatGPT Plus 用户

# 注意：如果你希望使用公共代理，或使用整合的 go-proxy-api，请保持注释；如果需要自定义，注意最后一定要有一个斜杠
# 在实际请求时，chatgpt_base_url 优先级为：config 内定义 > 环境变量 > revChatGPT 内置的公共代理
# chatgpt_base_url: http://127.0.0.1:8080/

log_dir: /app/logs # 日志存储位置，不要随意修改
console_log_level: DEBUG # 日志等级，设置为 DEBUG 能够获得更多信息

# 以下用于统计，如不清楚可保持默认
request_log_counter_time_window: 2592000 # 请求日志时间范围，默认为最近 30 天
request_log_counter_interval: 1800 # 请求日志统计粒度，默认为 30 分钟
ask_log_time_window: 2592000 # 对话日志时间范围，默认为最近 7 天
sync_conversations_regularly: yes # 是否定期（每隔12小时）从账号中同步一次对话
```

## 二、docker 启动

### 1. 手动启动

启动 proxy

因为我的机器无法正常访问外网，所以添加了环境变量进行代理http

如果使用环境变量还是不行的话只能用境外服务器了,重要的一个服务是chatgpt-proxy-server,只要这个服务能正常启动平台就ok

我自己是将chatgpt-proxy-server这个服务部署到境外服务器上了,然后后面的容器修改对应的启动参数去连接这个服务的9515端口即可

```sh
$ docker run -dti --name chatgpt-proxy-server -p 9515:9515 -e http_proxy="http://10.0.16.9:7890" -e https_proxy="http://10.0.16.9:7890" -e all_proxy="socks5://10.0.16.9:7890" --restart=always zhentianxiang/chatgpt-proxy-server:v0.3.14
```

启动 api-server

```sh
$ docker run -dti --name chatgpt-api-server -p 8080:8080 -e GIN_MODE=release -e CHATGPT_PROXY_SERVER=http://10.0.16.9:9515 -e http_proxy="http://10.0.16.9:7890" -e https_proxy="http://10.0.16.9:7890" -e all_proxy="socks5://10.0.16.9:7890" --restart=always zhentianxiang/go-chatgpt-api:v0.3.14
```

启动 share-web

```sh
$ docker run -dit --name chatgpt-web-share -p 80:80 -v `pwd`/data:/data -v `pwd`/logs:/app/logs -v `pwd`/config.yaml:/app/backend/api/config/config.yaml -e TZ=Asia/Shanghai -e CHATGPT_BASE_URL=http://10.0.16.9:8080/ -e http_proxy="http://10.0.16.9:7890" -e https_proxy="http://10.0.16.9:7890" -e all_proxy="socks5://10.0.16.9:7890" --restart=always zhentianxiang/chatgpt-web-share:v0.3.14
```

```sh
$ docker ps |grep -E "web-share|proxy-server|api-server"
```

### 2. docker-compose 启动

```yaml
version: "3"

services:
  chatgpt-web-share:
    image: zhentianxiang/chatgpt-web-share:v0.3.14
    restart: always
    ports:
      - 8080:80 # web 端口号
    volumes:
      - ./data:/data # 存放数据库文件以及统计数据
      - ./config.yaml:/app/backend/api/config/config.yaml # 后端配置文件
      - ./logs:/app/logs # 存放日志文件
    environment:
      - http_proxy="http://10.0.16.9:7890"
      - https_proxy="http://10.0.16.9:7890"
      - all_proxy="socks5://10.0.16.9:7890"
      - TZ=Asia/Shanghai
      - CHATGPT_BASE_URL=http://10.0.16.9:8081/
    depends_on:
      - chatgpt-api-server

  chatgpt-api-server:
    image: zhentianxiang/go-chatgpt-api:v0.3.14
    ports:
      - 8081:8080 # 如果你需要暴露端口如一带多，可以取消注释
    environment:
      - http_proxy="http://10.0.16.9:7890"
      - https_proxy="http://10.0.16.9:7890"
      - all_proxy="socks5://10.0.16.9:7890"
      - GIN_MODE=release
      - CHATGPT_PROXY_SERVER=http://10.0.16.9:9515
      # - NETWORK_PROXY_SERVER=http://host:port
    depends_on:
      - chatgpt-proxy-server
    restart: unless-stopped

  chatgpt-proxy-server:
    image: zhentianxiang/chatgpt-proxy-server:v0.3.14
    ports:
      - 9515:9515
    environment:
      - http_proxy="http://10.0.16.9:7890"
      - https_proxy="http://10.0.16.9:7890"
      - all_proxy="socks5://10.0.16.9:7890"
    restart: unless-stopped
```

```sh
$ docker-compose up -d
```

## 三、k8s 启动

proxy 服务

```sh
[root@VM-16-9-centos chatgpt-proxy]# cat chatgpt-proxy-dp.yaml 
apiVersion: apps/v1
kind: Deployment
metadata:
  name: chatgpt-proxy
  namespace: chatgpt
spec:
  replicas: 1
  selector:
    matchLabels:
      app: chatgpt-proxy
  template:
    metadata:
      labels:
        app: chatgpt-proxy
    spec:
      containers:
      - name: chatgpt-proxy
        image: zhentianxiang/chatgpt-proxy-server:v0.3.14
        imagePullPolicy: IfNotPresent
        ports:
        - name: chatgpt-proxy
          containerPort: 9515
          protocol: TCP
        env:
        - name: all_proxy
          value: "socks5://10.0.16.9:7890"
        resources:
          limits:
            cpu: 50m
            memory: 500Mi
          requests:
            cpu: 50m
            memory: 50Mi
        # 存活探针
        livenessProbe:
          tcpSocket:
            port: 9515
          initialDelaySeconds: 15  # 指定探针后多少秒后启动，也可以是容器启动15秒后开始探测
          periodSeconds: 3     # 第一次探测结束后，等待多少时间后对容器再次进行探测
          successThreshold: 1 # 探测失败到成功的重试次数，也就是1次失败后直接重启容器，针对于livenessProbe
          timeoutSeconds: 10    # 单次探测超时时间
        # 就绪性探针
        readinessProbe:
          tcpSocket:
            port: 9515
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
[root@VM-16-9-centos chatgpt-proxy]# cat chatgpt-proxy-svc.yaml 
apiVersion: v1
kind: Service
metadata:
  name: chatgpt-proxy
  namespace: chatgpt
spec:
  type: NodePort
  selector:
    app: chatgpt-proxy
  ports:
    - protocol: TCP
      port: 9515
      targetPort: 9515
```

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
        image: zhentianxiang/go-chatgpt-api:v0.3.14
        imagePullPolicy: IfNotPresent
        env:
        - name: GIN_MODE
          value: release
        - name: CHATGPT_PROXY_SERVER
        # 并且在k8s中不能使用service的DNS域名作为地址,只能用IP地址加端口方式
          value: http://107.172.5.13:9515
        - name: all_proxy
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
[root@VM-16-9-centos chatgpt-web-share]# cat chatgpt-web-share-cm.yaml 
apiVersion: v1
kind: ConfigMap
metadata:
  name: chatgpt-web-share-config
  namespace: chatgpt
data:
  config.yaml: |
    print_sql: false
    host: "127.0.0.1"
    port: 8000
    data_dir: /data # <------ v0.3.0 以上新增
    database_url: "sqlite+aiosqlite:////data/database.db" # 特别注意：这里有四个斜杠，代表着文件位于 /data 目录，使用的是绝对路径
    run_migration: false # 是否在启动时运行数据库迁移，目前没有必要启用
    jwt_secret: "test" # 用于生成 jwt token，自行填写随机字符串
    jwt_lifetime_seconds: 86400 # jwt token 过期时间
    cookie_max_age: 86400 # cookie 过期时间
    user_secret: "test" # 用于生成用户密码，自行填写随机字符串
    sync_conversations_on_startup: true # 是否在启动时同步同步 ChatGPT 对话，建议启用。启用后，将会自动将 ChatGPT 中新增的对话同步到数据库中，并把已经不在 ChatGPT 中的对话标记为无效
    create_initial_admin_user: true # 是否创建初始管理员用户
    initial_admin_username: admin # 初始管理员用户名
    initial_admin_password: password # 初始管理员密码
    ask_timeout: 600    # 用于限制对话的最长时间
    chatgpt_access_token: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6Ik1UaEVOVUpHTkVNMVFURTRNMEZCTWpkQ05UZzVNRFUxUlRVd1FVSkRNRU13UmtGRVFrRXpSZyJ9.eyJodHRwczovL2FwaS5vcGVuYWkuY29tL3Byb2ZpbGUiOnsiZW1haWwiOiJ6aGVubW91cmVuZXJAZ21haWwuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWV9LCJodHRwczovL2FwaS5vcGVuYWkuY29tL2F1dGgiOnsidXNlcl9pZCI6InVzZXItUDdZYUpBRVhxQm1oaThJdXRwbTM2S3JiIn0sImlzcyI6Imh0dHBzOi8vYXV0aDAub3BlbmFpLmNvbS8iLCJzdWIiOiJnb29nbGUtb2F1dGgyfDExMDQ5Njg3ODQ5ODYxMTI4MzUzOSIsImF1ZCI6WyJodHRwczovL2FwaS5vcGVuYWkuY29tL3YxIiwiaHR0cHM6Ly9vcGVuYWkub3BlbmFpLmF1dGgwYXBwLmNvbS91c2VyaW5mbyJdLCJpYXQiOjE2ODA5NTQ0OTAsImV4cCI6MTY4MjE2NDA5MCwiYXpwIjoiVGRKSWNiZTE2V29USHROOTVueXl3aDVFNHlPbzZJdEciLCJzY29wZSI6Im9wZW5pZCBwcm9maWxlIGVtYWlsIG1vZGVsLnJlYWQgbW9kZWwucmVxdWVzdCBvcmdhbml6YXRpb24ucmVhZCBvZmZsaW5lX2FjY2VzcyJ9.xLSeptVDPBMdC72T70PyrbxFS1-Bj9ZRm3OCaKwjyyyH3WU6zClw99E1bjNYTIenI9GMzjGZwFajj1BpAT61c18vmR5H7Idi3_IUJ3ZdrVipAhR5LQk1bZGVk2W34i4w-LzK4H3qN-5Eg0d8_EsJJzDea3yhNgs81bU-tplbBHM2JRCNe8cWjaltdMVJzSgTcxeWduBfoFclIK7RmCM-sHpAMy_JcmNKJafEycBqxJUp8rOjKUd3444Y8HBH7VETmZBEUIYkFoPS4onaT9Xkw-N5zUMlE5u2hxrRHfdAcZqQN2049DGUG3myk4k3_hxdnfNf42BWmjPjWcG0bT7eRQ" # 需要从 ChatGPT 获取，见后文
    chatgpt_paid: false # 是否为 ChatGPT Plus 用户
    # 注意：如果你希望使用公共代理，或使用整合的 go-proxy-api，请保持注释；如果需要自定义，注意最后一定要有一个斜杠
    # 在实际请求时，chatgpt_base_url 优先级为：config 内定义 > 环境变量 > revChatGPT 内置的公共代理
    # 并且在k8s中不能使用service的DNS域名作为地址,只能用IP地址加端口方式
    #chatgpt_base_url: http://10.0.16.9:32318/
    log_dir: /app/logs # 日志存储位置，不要随意修改
    console_log_level: DEBUG # 日志等级，设置为 DEBUG 能够获得更多信息
    # 以下用于统计，如不清楚可保持默认
    request_log_counter_time_window: 2592000 # 请求日志时间范围，默认为最近 30 天
    request_log_counter_interval: 1800 # 请求日志统计粒度，默认为 30 分钟
    ask_log_time_window: 2592000 # 对话日志时间范围，默认为最近 7 天
    sync_conversations_regularly: yes # 是否定期（每隔12小时）从账号中同步一次对话
```

```sh
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
      containers:
      - name: chatgpt-web-share
        image: zhentianxiang/chatgpt-web-share:v0.3.14
        imagePullPolicy: IfNotPresent
        env:
        # 并且在k8s中不能使用service的DNS域名作为地址,只能用IP地址加端口方式
        - name: CHATGPT_BASE_URL
          value: http://10.0.16.9:32318/
        - name: all_proxy
          value: "socks5://10.0.16.9:7890"
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
          - name: chatgpt-web-share-config
            mountPath: /app/backend/api/config/config.yaml
          - name: chatgpt-web-share-data
            mountPath: /data
          - name: host-time
            mountPath: /etc/localtime
            readOnly: true              
      volumes:
      - name: chatgpt-web-share-config
        configMap:
          name: chatgpt-web-share-config
          items:
            - key: 'config.yaml'
              path: 'config.yaml'
          defaultMode: 493
      - name: host-time
        hostPath:
          path: /etc/localtime
      - name: chatgpt-web-share-data
        persistentVolumeClaim:
          claimName: chatgpt-web-share-data                           
      restartPolicy: Always
```

```sh
[root@VM-16-9-centos chatgpt-web-share]# cat chatgpt-web-share-pvc.yaml 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: chatgpt-web-share-data
  namespace: chatgpt
  annotations:
    volume.beta.kubernetes.io/storage-class: "nfs-provisioner-storage"
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
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
