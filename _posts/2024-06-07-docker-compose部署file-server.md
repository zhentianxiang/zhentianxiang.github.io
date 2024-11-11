---
layout: post
title: 2024-06-07-docker-compose部署file-server
date: 2024-06-07
tags: Linux-Docker
music-id: 2138116445
---

### 1. yml 文件

```yaml
services:
  file-server-front:
    container_name: file-server-front
    image: zhentianxiang/file-server-front:v1.13.2
    ports:
      - 80:80
    environment:
      TZ: "Asia/Shanghai"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    networks:
      - docker-app
    restart: always

  file-server:
    container_name: file-server
    image: zhentianxiang/file-server:v1.13.2
    volumes:
      - /wd500G/file-server-data/:/data
    environment:
      LOG_LEVEL: "DEBUG"
      TZ: "Asia/Shanghai"
      #默认是9000
      PORT: "9000"
      #默认是/data
      UPLOADED_PATH: "/data"
      #默认是5G,如果nginx反向代理了,记得修改client_max_body_size 10240M;
      MAX_CONTENT_LENGTH: "10737418240"
      MYSQL_HOST: "file-mysql"
      MYSQL_PORT: "3306"
      MYSQL_USER: "fileserver"
      MYSQL_PASSWORD: "fileserver"
      MYSQL_DB: "fileserver"
      # 来加密和解密会话数据，可以防止客户端篡改会话数据
      SECRET_KEY: "6745e0efd28ee0848ae7506db194595d849d760998fbda8f"
      # 设置会话超时时间，默认30分钟
      SESSION_LIFETIME_MINUTES: "30"
      REDIS_HOST: "file-redis"
      REDIS_PORT: "6379"
      REDIS_DB: "0"
      REDIS_PASSWORD: "fileserver"
    networks:
      - docker-app
    restart: always
    depends_on:
      - file-mysql

  file-mysql:
    container_name: file-mysql
    image: mysql:8.0
    environment:
      TZ: "Asia/Shanghai"
      MYSQL_ROOT_PASSWORD: "fileserver"
      MYSQL_USER: "fileserver"
      MYSQL_PASSWORD: "fileserver"
      MYSQL_DATABASE: "fileserver"
    volumes:
    - ./mysql/my.cnf:/etc/my.cnf
    - ./sql-script/:/docker-entrypoint-initdb.d
    - mysql_data:/var/lib/mysql
    networks:
      - docker-app
    restart: always


volumes:
  mysql_data:

networks:
  docker-app:
    external: true
```
- mysql 配置文件

```sh
$ cat my.cnf 
[mysql]
default-character-set=utf8mb4

[mysqld]
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
skip-host-cache
skip-name-resolve
datadir=/var/lib/mysql
socket=/var/run/mysqld/mysqld.sock
secure-file-priv=/var/lib/mysql-files
user=mysql

pid-file=/var/run/mysqld/mysqld.pid
[client]
socket=/var/run/mysqld/mysqld.sock
default-character-set=utf8mb4

!includedir /etc/mysql/conf.d/
```

- nginx 配置文件

```sh
$ cat nginx/nginx.conf 
worker_processes auto;
events { worker_connections 1024; }

http {
    log_format basic '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 1800s; # 超时时间30分钟,如果上传大文件,时间不够会报错
    proxy_connect_timeout 1800s;
    proxy_read_timeout 1800s;
    proxy_send_timeout 1800s;
    send_timeout 1800s;

    types_hash_max_size 2048;
    
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    access_log /var/log/nginx/access.log basic;
    error_log /var/log/nginx/error.log;

    gzip on;
    gzip_disable "msie6";

    client_max_body_size 10240M; #上传大小10G
    
    server {
        listen 80;
        server_name fileserver.demo.com;
        
        root /usr/share/nginx/html;

        location / {
            root   /usr/share/nginx/html/;
            index  index.html index.htm;
        }

        # 处理静态文件
        location /static/ {
            alias /usr/share/nginx/html/static/;
        }

        # 处理 index.html 的请求，将其代理到 @app
        location /index.html {
            try_files $uri @app;
        }

        # 定义 @app 块
        location @app {
            # 将请求代理到 Flask 应用
            proxy_pass http://file-server:9000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # 处理 /api/ 开头的请求，将其代理到 Flask 应用
        location /api/ {
            proxy_pass http://file-server:9000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
```
- sql 语句脚本

```sh
$ cat sql-script/create_table.sh 
#!/bin/bash  
  
# 设置默认的 MySQL root 密码  
MYSQL_ROOT_PASSWORD=${MASTER_SYNC_PASSWORD:-fileserver}  
  
# 定义 SQL 语句  
CREATE_USERS_TABLE_SQL="  
CREATE TABLE users (  
    id INT AUTO_INCREMENT PRIMARY KEY,  
    username VARCHAR(50) NOT NULL UNIQUE,  
    password VARCHAR(255) NOT NULL,  
    email VARCHAR(100) NOT NULL UNIQUE,  
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP  
);  
"

CREATE_UPLOADED_CHUNKS_TABLE_SQL="  
CREATE TABLE uploaded_chunks (
    id INT AUTO_INCREMENT PRIMARY KEY,
    file_name VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    total_chunks INT NOT NULL,
    current_path VARCHAR(255) NOT NULL,
    uploaded TINYINT(1) DEFAULT 0,
    chunk_index INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (file_name, total_chunks, current_path, chunk_index)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
"  
  
# 执行 SQL 语句  
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "$CREATE_USERS_TABLE_SQL" fileserver
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "$CREATE_UPLOADED_CHUNKS_TABLE_SQL" fileserver
```


### 2. 启动

```sh
$ docker-compose up -d
[+] Running 4/0
 ✔ Container file-server-front  Running                                                                                                                                               0.0s 
 ✔ Container file-mysql         Running                                                                                                                                               0.0s 
 ✔ Container file-server        Running                                                                                                                                               0.0s
```

### 3. 查看启动的状态和日志

```sh
$ docker-compose ps
NAME                IMAGE                                     COMMAND                  SERVICE             CREATED              STATUS              PORTS
file-mysql          mysql:8.0                                 "docker-entrypoint.s…"   file-mysql          32 hours ago         Up 51 minutes       3306/tcp, 33060/tcp
file-server         zhentianxiang/file-server:v1.12.1         "python run.py"          file-server         22 minutes ago       Up 22 minutes       0.0.0.0:9000->9000/tcp, :::9000->9000/tcp
file-server-front   zhentianxiang/file-server-front:v1.12.9   "/docker-entrypoint.…"   file-server-front   About a minute ago   Up About a minute   0.0.0.0:8800->80/tcp, :::8800->80/tcp
```

```sh
$ docker-compose logs -f
file-mysql         | 2024-06-07 13:56:31+08:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.37-1.el9 started.
file-mysql         | 2024-06-07 13:56:32+08:00 [Note] [Entrypoint]: Switching to dedicated user 'mysql'
file-mysql         | 2024-06-07 13:56:32+08:00 [Note] [Entrypoint]: Entrypoint script for MySQL Server 8.0.37-1.el9 started.
file-server        |  * Serving Flask app 'app'
file-server        |  * Debug mode: on
file-server        | INFO:werkzeug:WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
file-server        |  * Running on all addresses (0.0.0.0)
file-server        |  * Running on http://127.0.0.1:9000
file-server        |  * Running on http://172.18.0.17:9000
file-server        | INFO:werkzeug:Press CTRL+C to quit
file-server        | INFO:werkzeug: * Restarting with stat
file-server        | WARNING:werkzeug: * Debugger is active!
file-server        | INFO:werkzeug: * Debugger PIN: 684-742-933
file-mysql         | '/var/lib/mysql/mysql.sock' -> '/var/run/mysqld/mysqld.sock'
file-mysql         | 2024-06-07T05:56:33.870799Z 0 [Warning] [MY-011068] [Server] The syntax '--skip-host-cache' is deprecated and will be removed in a future release. Please use SET GLOBAL host_cache_size=0 instead.
file-mysql         | 2024-06-07T05:56:33.875903Z 0 [System] [MY-010116] [Server] /usr/sbin/mysqld (mysqld 8.0.37) starting as process 1
file-mysql         | 2024-06-07T05:56:33.906862Z 1 [System] [MY-013576] [InnoDB] InnoDB initialization has started.
file-mysql         | 2024-06-07T05:56:34.531423Z 1 [System] [MY-013577] [InnoDB] InnoDB initialization has ended.
file-server-front  | /docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
file-server-front  | /docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
file-server-front  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
file-server-front  | 10-listen-on-ipv6-by-default.sh: info: /etc/nginx/conf.d/default.conf is not a file or does not exist
file-server-front  | /docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
file-server-front  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
file-server-front  | /docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
file-server-front  | /docker-entrypoint.sh: Configuration complete; ready for start up
file-mysql         | 2024-06-07T05:56:34.941923Z 0 [Warning] [MY-010068] [Server] CA certificate ca.pem is self signed.
file-mysql         | 2024-06-07T05:56:34.942288Z 0 [System] [MY-013602] [Server] Channel mysql_main configured to support TLS. Encrypted connections are now supported for this channel.
file-mysql         | 2024-06-07T05:56:34.950445Z 0 [Warning] [MY-011810] [Server] Insecure configuration for --pid-file: Location '/var/run/mysqld' in the path is accessible to all OS users. Consider choosing a different directory.
file-mysql         | 2024-06-07T05:56:34.993927Z 0 [System] [MY-011323] [Server] X Plugin ready for connections. Bind-address: '::' port: 33060, socket: /var/run/mysqld/mysqlx.sock
file-mysql         | 2024-06-07T05:56:34.994198Z 0 [System] [MY-010931] [Server] /usr/sbin/mysqld: ready for connections. Version: '8.0.37'  socket: '/var/run/mysqld/mysqld.sock'  port: 3306  MySQL Community Server - GPL.
```

### 4. 配套脚本

#### 1. 创建用户

- curl 方法

```sh
# 创建用户
$ curl -X POST http://fileserver.tianxiang.love/api/register \
     -H "Content-Type: application/json" \
     -d '{
           "username": "user_1",
           "password": "password123",
           "email": "user1@example.com"
         }'|
     jq -r '.message'

# 登录用户并保存 Cookie
$ curl -X POST http://fileserver.tianxiang.love/api/login \
     -H "Content-Type: application/json" \
     -d '{
           "username": "user_1",
           "password": "password123"
         }' \
     -c cookies.txt|
     jq -r '.message'
     

# 删除用户
$ curl -X DELETE http://fileserver.tianxiang.love/api/delete_user \
     -H "Content-Type: application/json" \
     -b cookies.txt|
     jq -r '.message'
```

- python 方法

```python
$ cat create_user_script.py
import argparse
import requests

# 创建参数解析器
parser = argparse.ArgumentParser(description='API Test Script')
parser.add_argument('--base-url', type=str, required=True, help='Base URL of the API')
parser.add_argument('--username', type=str, required=True, help='Username for registration and login')
parser.add_argument('--password', type=str, required=True, help='Password for registration and login')
parser.add_argument('--email', type=str, required=True, help='Email for registration')

# 解析命令行参数
args = parser.parse_args()

# 基于命令行参数的URL
base_url = args.base_url

# 测试注册接口
def test_register():
    url = f'{base_url}/api/register'
    data = {
        'username': args.username,
        'password': args.password,
        'email': args.email
    }
    response = requests.post(url, json=data)
    print("Register response:", response.json())
    return response

# 测试登录接口
def test_login():
    url = f'{base_url}/api/login'
    data = {
        'username': args.username,
        'password': args.password
    }
    response = requests.post(url, json=data)
    print("Login response:", response.json())
    return response

# 测试登出接口
def test_logout(token):
    url = f'{base_url}/api/logout'
    headers = {
        'Authorization': f'Bearer {token}'
    }
    response = requests.get(url, headers=headers)
    print("Logout response:", response.json())
    return response

# 调用测试函数
if __name__ == "__main__":
    # 测试注册
    register_response = test_register()
    
    # 检查注册是否成功并获取注册结果
    if register_response.status_code == 201:  # 假设201是成功注册的状态码
        print("Registration successful")
    else:
        print("Registration failed")

    # 测试登录
    login_response = test_login()
    
    # 检查登录是否成功并获取token
    if login_response.status_code == 200:  # 假设200是成功登录的状态码
        print("Login successful")
        token = login_response.json().get('token')  # 假设token在响应的JSON中
    else:
        print("Login failed")
        token = None

    # 测试登出
    if token:
        logout_response = test_logout(token)
        
        # 检查登出是否成功
        if logout_response.status_code == 200:  # 假设200是成功登出的状态码
            print("Logout successful")
        else:
            print("Logout failed")
```

```sh
$  python create_user_script.py --base-url http://127.0.0.1:9000 --username zhentianxiang --password zhentianxiang --email 2099637909@qq.com
Register response: {'message': '注册成功，请登录'}
Registration failed
Login response: {'message': '登录成功'}
Login successful
```

#### 2. 删除用户

```python
$ cat delete_user_script.py 
import argparse
import requests

def login(base_url, username, password):
    url = f"{base_url}/api/login"
    payload = {
        "username": username,
        "password": password
    }
    response = requests.post(url, json=payload)
    if response.status_code == 200:
        print("登录成功")
        return response.cookies  # 返回登录后的cookies
    else:
        print(f"登录失败: {response.json()['message']}")
        return None

def delete_user(base_url, cookies):
    url = f"{base_url}/api/delete_user"
    response = requests.delete(url, cookies=cookies)
    if response.status_code == 200:
        print("用户删除成功")
    else:
        print(f"删除用户失败: {response.json()['message']}")

def main(base_url, username, password):
    # 登录用户
    cookies = login(base_url, username, password)
    if not cookies:
        return

    # 删除用户
    delete_user(base_url, cookies)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Delete a user from a Flask app")
    parser.add_argument("--base-url", required=True, help="The base URL of the Flask app")
    parser.add_argument("--username", required=True, help="The username of the user to delete")
    parser.add_argument("--password", required=True, help="The password of the user to delete")
    args = parser.parse_args()

    main(args.base_url, args.username, args.password)
```

```sh
$ python delete_user_script.py --base-url http://127.0.0.1:9000 --username zhentianxiang --password zhentianxiang
登录成功
用户删除成功
```

#### 3. 普通上传文件

```python
$ cat upload_file.py
#!/usr/bin/python3
import os
import requests
import argparse
from tqdm import tqdm
from requests_toolbelt.multipart.encoder import MultipartEncoder, MultipartEncoderMonitor

# 函数：登录并返回cookies
def login(base_url, username, password):
    url = f"{base_url}/api/login"
    payload = {
        "username": username,
        "password": password
    }
    response = requests.post(url, json=payload)
    if response.status_code != 200:
        raise RuntimeError("登录失败")
    return response.cookies

# 函数：上传文件到指定URL和目录，显示加载状态的进度条和上传速度
def upload_file(url, file_path, cookies, directory=None):
    file_size = os.path.getsize(file_path)
    tqdm_desc = os.path.basename(file_path)
    
    with open(file_path, 'rb') as f:
        encoder_fields = {'file': (os.path.basename(file_path), f, 'application/octet-stream')}
        if directory:
            encoder_fields['current_path'] = directory

        encoder = MultipartEncoder(fields=encoder_fields)
        
        with tqdm(total=file_size, unit='B', unit_scale=True, desc=tqdm_desc) as pbar:
            def create_callback(encoder):
                def callback(monitor):
                    pbar.update(monitor.bytes_read - pbar.n)
                return callback

            monitor = MultipartEncoderMonitor(encoder, create_callback(encoder))
            headers = {'Content-Type': monitor.content_type}
            response = requests.post(url, data=monitor, headers=headers, cookies=cookies)

    return response

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='登录并上传文件到指定的URL和目录，显示加载状态的进度条和上传速度。')
    parser.add_argument('--base-url', required=True, help='Flask应用的基础URL，例如 http://fileserver.tianxiang.love')
    parser.add_argument('--username', required=True, help='登录用户名')
    parser.add_argument('--password', required=True, help='登录密码')
    parser.add_argument('-f', '--file', required=True, help='要上传的文件路径')
    parser.add_argument('-d', '--directory', help='要上传到的服务器目录')

    args = parser.parse_args()
    base_url = args.base_url.rstrip('/')  # 移除末尾的斜杠
    username = args.username
    password = args.password
    file_path = args.file
    directory = args.directory

    try:
        # 登录获取cookies
        cookies = login(base_url, username, password)

        # 上传文件
        url = f"{base_url}/api/upload_file"
        response = upload_file(url, file_path, cookies, directory)
        print(f"上传完成，状态码: {response.status_code}")
    except Exception as e:
        print(f"错误: {e}")
```

```sh
# 注意 /data 目录是文件服务器的目录,启动file-server时候定义的数据存储目录,也就是文件服务器的根目录
$ python upload_file.py \
 -f ubuntu-20.04.6-live-server-amd64.iso \
 --base-url http://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password zhentianxiang \
 --directory /data/abc目录/
ubuntu-20.04.6-live-server-amd64.iso: 100%|███████████████████████████████████████████████████████████████████████████████████████| 1.49G/1.49G [00:14<00:00, 98.5MB/s]
```

#### 4. 删除文件脚本

```python
$ cat delete_file.py 
#!/usr/bin/python3
import requests
import argparse
import urllib.parse

def login(base_url, username, password):
    url = f"{base_url}/api/login"
    payload = {
        "username": username,
        "password": password
    }
    response = requests.post(url, json=payload)
    response.raise_for_status()
    return response.cookies

def delete_file(base_url, cookies, file_path):
    encoded_file_path = urllib.parse.quote(file_path)
    url = f"{base_url}/api/delete/{encoded_file_path}"
    response = requests.delete(url, cookies=cookies)
    response.raise_for_status()
    return response

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Delete a file or directory from the server.")
    parser.add_argument("--base-url", required=True, help="The base URL of the Flask app")
    parser.add_argument("--username", required=True, help="The username for authentication")
    parser.add_argument("--password", required=True, help="The password for authentication")
    parser.add_argument("--file-path", required=True, help="The path to the file or directory to delete on the server")

    args = parser.parse_args()
    base_url = args.base_url.rstrip('/')
    username = args.username
    password = args.password
    file_path = args.file_path

    try:
        cookies = login(base_url, username, password)
        response = delete_file(base_url, cookies, file_path)
        print(f"删除成功，状态码: {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"请求失败: {e}")
```

```sh
# 删除脚本,不用写/data/,默认就是那个根目录
$ python delete_file.py \
 --base-url http://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password zhentianxiang \
 --file-path abc目录/ubuntu-20.04.6-live-server-amd64.iso
删除成功，状态码: 200
```

#### 5. 分片文件 & 断点续传方式上传

```python
$ cat upload_chunk_file.py 
#!/usr/bin/python3
import os
import requests
import argparse
from tqdm import tqdm
from requests_toolbelt.multipart.encoder import MultipartEncoder, MultipartEncoderMonitor

def login(base_url, username, password):
    url = f"{base_url}/api/login"
    payload = {
        "username": username,
        "password": password
    }
    response = requests.post(url, json=payload)
    if response.status_code != 200:
        raise RuntimeError("登录失败")
    return response.cookies

def get_uploaded_chunks(base_url, cookies, file_name, total_chunks, current_path):
    url = f"{base_url}/api/uploaded_chunks"
    params = {
        'fileName': file_name,
        'totalChunks': total_chunks,
        'current_path': current_path
    }
    response = requests.get(url, cookies=cookies, params=params)
    if response.status_code != 200:
        raise RuntimeError(f"Failed to get uploaded chunks: {response.text}")
    return response.json().get("uploaded_chunks", [])

def upload_file_chunk(url, file_path, chunk_index, total_chunks, cookies, current_path):
    with open(file_path, 'rb') as f:
        f.seek(chunk_index * CHUNK_SIZE)
        chunk_data = f.read(CHUNK_SIZE)

        encoder = MultipartEncoder(
            fields={
                'file': (os.path.basename(file_path), chunk_data, 'application/octet-stream'),
                'fileName': os.path.basename(file_path),
                'chunkIndex': str(chunk_index),
                'totalChunks': str(total_chunks),
                'current_path': current_path
            }
        )

        pbar = tqdm(total=len(chunk_data), unit='B', unit_scale=True, unit_divisor=1024, desc=f"Uploading chunk {chunk_index+1}/{total_chunks}")

        def progress_callback(monitor):
            pbar.update(monitor.bytes_read - pbar.n)

        monitor = MultipartEncoderMonitor(encoder, progress_callback)

        headers = {'Content-Type': monitor.content_type}

        response = requests.post(url, data=monitor, headers=headers, cookies=cookies)

        pbar.close()

        return response

def upload_file(base_url, file_path, cookies, current_path):
    url = f"{base_url}/api/upload_file_chunk"
    file_size = os.path.getsize(file_path)
    total_chunks = (file_size + CHUNK_SIZE - 1) // CHUNK_SIZE
    file_name = os.path.basename(file_path)

    uploaded_chunks = get_uploaded_chunks(base_url, cookies, file_name, total_chunks, current_path)

    for chunk_index in range(total_chunks):
        if chunk_index in uploaded_chunks:
            print(f"Chunk {chunk_index+1}/{total_chunks} 已经上传，跳过")
            continue
        response = upload_file_chunk(url, file_path, chunk_index, total_chunks, cookies, current_path)
        if response.status_code != 200:
            raise RuntimeError(f"Chunk {chunk_index+1}/{total_chunks} 上传失败: {response.text}")
    
    print("文件上传成功")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Upload a file in chunks to a specified URL.')
    parser.add_argument('-f', '--file', required=True, help='Path to the file to upload')
    parser.add_argument('-b', '--base-url', required=True, help='Base URL of the server')
    parser.add_argument('-u', '--username', required=True, help='Username for authentication')
    parser.add_argument('-p', '--password', required=True, help='Password for authentication')
    parser.add_argument('-d', '--directory', required=True, help='Directory on the server to upload the file to')
    parser.add_argument('-c', '--chunk-size', type=int, default=5, help='Chunk size in MB (default: 5MB)')

    args = parser.parse_args()
    file_path = args.file
    base_url = args.base_url
    username = args.username
    password = args.password
    current_path = args.directory
    CHUNK_SIZE = args.chunk_size * 1024 * 1024  # Convert chunk size to bytes

    cookies = login(base_url, username, password)
    upload_file(base_url, file_path, cookies, current_path)
```

```sh
# 测试上传一半断开
$ python upload_chunk_file.py \
 -f ubuntu-20.04.6-live-server-amd64.iso \
 --base-url http://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password zhentianxiang \
 --directory /data/abc目录/ \
 --chunk-size 200
Uploading chunk 1/8: 200MB [00:04, 51.0MB/s]                                                                                                                                               
Uploading chunk 2/8: 200MB [00:05, 41.9MB/s]                                                                                                                                               
Uploading chunk 3/8: 200MB [00:04, 46.5MB/s]                                                                                                                                               
Uploading chunk 4/8:   8%|█████████▍                                                                                                  | 15.2M/200M [00:00<00:02, 77.1MB/s]
```

```sh
# 查看数据库中的记录,只有3条
$ mysql> select * from uploaded_chunks;
+-----+--------------------------------------+--------------+----------+-------------+---------------------+
| id  | file_name                            | total_chunks | uploaded | chunk_index | created_at          |
+-----+--------------------------------------+--------------+----------+-------------+---------------------+
| 462 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        0 |           0 | 2024-06-13 19:14:13 |
| 463 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        0 |           1 | 2024-06-13 19:14:19 |
| 464 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        0 |           2 | 2024-06-13 19:14:23 |
+-----+--------------------------------------+--------------+----------+-------------+---------------------+
5 rows in set (0.00 sec)
```

```sh
# 继续上传
$ python upload_chunk_file.py \
 -f ubuntu-20.04.6-live-server-amd64.iso \
 --base-url http://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password zhentianxiang \
 --directory /data/abc目录/ \
 --chunk-size 200
Chunk 1/8 已经上传，跳过
Chunk 2/8 已经上传，跳过
Chunk 3/8 已经上传，跳过
Uploading chunk 4/8: 200MB [00:02, 71.0MB/s]                                                                                                                                               
Uploading chunk 5/8: 200MB [00:04, 48.2MB/s]                                                                                                                                               
Uploading chunk 6/8: 200MB [00:04, 47.9MB/s]                                                                                                                                               
Uploading chunk 7/8: 200MB [00:04, 48.8MB/s]                                                                                                                                               
Uploading chunk 8/8: 18.4MB [00:09, 2.05MB/s]                                                                                                                                              
文件上传成功
```

```sh
# 断开时间是19:14,重新开始时间是19:15
$ mysql> select * from uploaded_chunks;
+-----+--------------------------------------+--------------+----------+-------------+---------------------+
| id  | file_name                            | total_chunks | uploaded | chunk_index | created_at          |
+-----+--------------------------------------+--------------+----------+-------------+---------------------+
| 462 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        1 |           0 | 2024-06-13 19:14:13 |
| 463 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        1 |           1 | 2024-06-13 19:14:19 |
| 464 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        1 |           2 | 2024-06-13 19:14:23 |
| 465 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        1 |           3 | 2024-06-13 19:15:18 |
| 466 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        1 |           4 | 2024-06-13 19:15:23 |
| 467 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        1 |           5 | 2024-06-13 19:15:28 |
| 468 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        1 |           6 | 2024-06-13 19:15:32 |
| 469 | ubuntu-20.04.6-live-server-amd64.iso |            8 |        1 |           7 | 2024-06-13 19:15:33 |
+-----+--------------------------------------+--------------+----------+-------------+---------------------+
8 rows in set (0.00 sec)
```

```sh
# 在来一遍则会提示已经上传过
$ python upload_chunk_file.py \
 -f ubuntu-20.04.6-live-server-amd64.iso \
 --base-url http://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password zhentianxiang \
 --directory /data/abc目录/ \
 --chunk-size 200
Chunk 1/8 已经上传，跳过
Chunk 2/8 已经上传，跳过
Chunk 3/8 已经上传，跳过
Chunk 4/8 已经上传，跳过
Chunk 5/8 已经上传，跳过
Chunk 6/8 已经上传，跳过
Chunk 7/8 已经上传，跳过
Chunk 8/8 已经上传，跳过
文件上传成功
```

### 5. 视频演示

<video width="1200" height="600" controls>
    <source src="https://fileserver.tianxiang.love/api/view?file=%E8%A7%86%E9%A2%91%E6%95%99%E5%AD%A6%E7%9B%AE%E5%BD%95%2Ffile-server%E6%96%87%E4%BB%B6%E7%AE%A1%E7%90%86%E6%9C%8D%E5%8A%A1%E5%99%A8.mp4" type="video/mp4">
</video>
