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
    #image: zhentianxiang/file-server-front:v1.13.2  #此版本没有使用用户鉴权
    image: zhentianxiang/file-server-front:v1.13.6  #此版本加入了用户鉴权以及数据独立数据存储互不干扰
    ports:
      - 80:80
    environment:
      TZ: "Asia/Shanghai"
      WS_SERVER_STATS: "wss://fileserver.tianxiang.love" # 如果没有https，则使用ws
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
    networks:
      - docker-app
    restart: always

  file-server:
    container_name: file-server
    #image: zhentianxiang/file-server:v1.13.2  #此版本没有使用用户鉴权
    image: zhentianxiang/file-server:v1.13.6  #此版本加入了用户鉴权以及数据独立数据存储互不干扰
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
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "file-mysql", "-u", "fileserver", "-pfileserver"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s

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

    client_max_body_size 20240M; #上传大小20G
    
server {
        listen 443 ssl;
        server_name fileserver.tianxiang.love;

        ssl_certificate /etc/nginx/file-server/fileserver.tianxiang.love_cert_chain.pem;
        ssl_certificate_key /etc/nginx/file-server/fileserver.tianxiang.love_key.key;
        ssl_session_timeout 5m;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_prefer_server_ciphers on;

        client_max_body_size 20240M; #上传大小20G

        proxy_read_timeout 1800s; # 超时时间30分钟,如果上传大文件,时间不够会报错
        proxy_connect_timeout 1800s;
        proxy_send_timeout 1800s;

        access_log /dev/stdout main;
        error_log /dev/stderr warn;

        # 处理根路径,用于检测用户是否登陆并重定向登陆页面
        location / {
            proxy_pass http://file-server:9000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }   
 
        location /login.html {
            index  login.html;
        }

        location /monitor.html {
            index  monitor.html;
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

        location /socket.io/ {
        proxy_pass http://file-server:9000/socket.io/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
       }
    } 
}
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
file-server         zhentianxiang/file-server:v1.13.6         "python run.py"           file-server         22 minutes ago       Up 22 minutes       0.0.0.0:9000->9000/tcp, :::9000->9000/tcp
file-server-front   zhentianxiang/file-server-front:v1.13.6   "/docker-entrypoint.…"   file-server-front   About a minute ago   Up About a minute   0.0.0.0:8800->80/tcp, :::8800->80/tcp
```

```sh
$ docker-compose logs -f
```

### 4. 配套脚本

#### 1. 创建用户

- curl 方法

```sh
# 创建用户
$ curl -s -X POST http://fileserver.tianxiang.love/api/register \
     -H "Content-Type: application/json" \
     -d '{
           "username": "user_1",
           "password": "password123",
           "email": "user1@example.com"
         }'|
     jq -r '.message'

# 登录用户并保存 Cookie
$ curl -s -X POST http://fileserver.tianxiang.love/api/login \
     -H "Content-Type: application/json" \
     -d '{
           "username": "user_1",
           "password": "password123"
         }' \
     -c cookies.txt|
     jq -r '.message'
     

# 删除用户
$ curl -s -X DELETE http://fileserver.tianxiang.love/api/delete_user \
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

# 函数：登录并返回cookies和user_directory
def login(base_url, username, password):
    url = f"{base_url}/api/login"
    payload = {
        "username": username,
        "password": password
    }
    response = requests.post(url, json=payload)
    if response.status_code != 200:
        raise RuntimeError("登录失败")
    user_directory = response.json().get('user_dir')
    return response.cookies, user_directory

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
    parser.add_argument('--remote-path', help='要上传到的服务器相对目录，默认为服务器用户根目录')

    args = parser.parse_args()
    base_url = args.base_url.rstrip('/')  # 移除末尾的斜杠
    username = args.username
    password = args.password
    file_path = args.file
    remote_path = args.remote_path

    try:
        # 登录获取cookies和user_directory
        cookies, user_directory = login(base_url, username, password)

        # 如果有指定目录，则拼接用户目录和指定目录
        if remote_path:
            upload_directory = os.path.join(user_directory, remote_path)
        else:
            upload_directory = user_directory

        # 上传文件
        url = f"{base_url}/api/upload_file"
        response = upload_file(url, file_path, cookies, upload_directory)
        print(f"上传完成，状态码: {response.status_code}")
    except Exception as e:
        print(f"错误: {e}")
```

```sh
# 上传至服务器的默认用户存储目录
$ python upload_file.py \
 -f ubuntu-20.04.6-live-server-amd64.iso \
 --base-url https://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password 123456789 \
ubuntu-20.04.6-live-server-amd64.iso: 100%|███████████████████████████████████████████████████████████████████████████████████████| 1.49G/1.49G [00:14<00:00, 98.5MB/s]
```

```sh
# 上传至服务器的用户目录的iso相对路径中
$ python upload_file.py \
 -f ubuntu-20.04.6-live-server-amd64.iso \
 --base-url https://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password 123456789 \
 --remote-path iso
```

```sh
# 配合 nohup 使其后台运行,将标准错误也重定向到标准输出，这样所有的输出都会写入到 custom_output.log 文件中
$ nohup python upload_file.py \
 -f ubuntu-20.04.6-live-server-amd64.iso \
 --base-url https://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password 123456789 \
 --remote-path iso \
 > custom_output.log 2>&1 &
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

def delete_file(base_url, cookies, remote_path):
    encoded_remote_path = urllib.parse.quote(remote_path)
    url = f"{base_url}/api/delete/{encoded_remote_path}"
    response = requests.delete(url, cookies=cookies)
    response.raise_for_status()
    return response

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Delete a file or directory from the server.")
    parser.add_argument("--base-url", required=True, help="The base URL of the Flask app")
    parser.add_argument("--username", required=True, help="The username for authentication")
    parser.add_argument("--password", required=True, help="The password for authentication")
    parser.add_argument("--remote-path", required=True, help="The path to the file or directory to delete on the server")

    args = parser.parse_args()
    base_url = args.base_url.rstrip('/')
    username = args.username
    password = args.password
    remote_path = args.remote_path

    try:
        cookies = login(base_url, username, password)
        response = delete_file(base_url, cookies, remote_path)
        print(f"删除成功，状态码: {response.status_code}")
    except requests.exceptions.RequestException as e:
        print(f"请求失败: {e}")
```

```sh
$ python delete_file.py \
 --base-url https://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password 123456789 \
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
import unicodedata

def login(base_url, username, password):
    url = f"{base_url}/api/login"
    payload = {
        "username": username,
        "password": password
    }
    response = requests.post(url, json=payload)
    if response.status_code != 200:
        raise RuntimeError("登录失败")
    user_directory = response.json().get('user_dir')
    return response.cookies, user_directory

def normalize_filename(filename):
    """
    处理文件名，确保能正确处理中文文件名
    """
    return unicodedata.normalize('NFKD', filename)

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
                'file': (normalize_filename(os.path.basename(file_path)), chunk_data, 'application/octet-stream'),
                'fileName': normalize_filename(os.path.basename(file_path)),
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

def upload_file(base_url, file_path, cookies, user_dir, provided_path):
    url = f"{base_url}/api/upload_file_chunk"
    file_size = os.path.getsize(file_path)
    total_chunks = (file_size + CHUNK_SIZE - 1) // CHUNK_SIZE
    file_name = normalize_filename(os.path.basename(file_path))

    # 使用提供的路径或用户目录
    current_path = os.path.join(user_dir, provided_path) if provided_path else user_dir

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
    parser = argparse.ArgumentParser(description='分块上传文件到指定的URL。')
    parser.add_argument('-f', '--file', required=True, help='要上传的文件路径')
    parser.add_argument('-b', '--base-url', required=True, help='服务器的基础URL')
    parser.add_argument('-u', '--username', required=True, help='认证用的用户名')
    parser.add_argument('-p', '--password', required=True, help='认证用的密码')
    parser.add_argument('-r', '--remote-path', help='服务器上要上传文件的目录')
    parser.add_argument('-c', '--chunk-size', type=int, default=5, help='分块大小（MB），默认值为5MB')
    
    args = parser.parse_args()
    file_path = args.file
    base_url = args.base_url
    username = args.username
    password = args.password
    provided_path = args.remote_path
    CHUNK_SIZE = args.chunk_size * 1024 * 1024  # Convert chunk size to bytes

    cookies, user_dir = login(base_url, username, password)

    # Use the provided path if given, otherwise use the user directory
    upload_file(base_url, file_path, cookies, user_dir, provided_path)
```

```sh
# 测试上传一半断开
$ python upload_chunk_file.py \
 -f ubuntu-20.04.6-live-server-amd64.iso \
 --base-url http://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password zhentianxiang \
 --remote-path iso目录/ \
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
 --base-url https://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password 123456789 \
 --remote-path iso目录/ \
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
 --base-url https://fileserver.tianxiang.love/ \
 --username zhentianxiang \
 --password 123456789 \
 --remote-path iso目录/ \
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

#### 6. 上传目录脚本

```python
$ cat upload_directory.py

#!/usr/bin/python3
import os
import requests
import argparse
from tqdm import tqdm
from requests_toolbelt.multipart.encoder import MultipartEncoder, MultipartEncoderMonitor
import logging

logging.basicConfig(level=logging.INFO)

# 函数：登录并返回cookies和user_directory
def login(base_url, username, password):
    url = f"{base_url}/api/login"
    payload = {
        "username": username,
        "password": password
    }
    response = requests.post(url, json=payload)
    if response.status_code != 200:
        raise RuntimeError("登录失败")
    user_directory = response.json().get('user_dir')
    return response.cookies, user_directory

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

# 函数：上传目录中的所有文件，保留目录结构
def upload_directory(directory_path, base_url, cookies, user_directory, remote_path=None):
    # 检查目录是否存在
    if not os.path.isdir(directory_path):
        print(f"目录不存在: {directory_path}")
        return

    url = f"{base_url}/api/upload_directory"
    
    # 设置目标路径
    if remote_path:
        target_path = os.path.join(user_directory, remote_path)
    else:
        target_path = user_directory

    # 读取目录中的所有文件
    files_to_upload = []
    for root, dirs, files in os.walk(directory_path):
        for file in files:
            file_path = os.path.join(root, file)
            relative_path = os.path.relpath(file_path, os.path.dirname(directory_path))  # 相对路径基于父目录
            files_to_upload.append((relative_path, file_path))

    for relative_path, file_path in files_to_upload:
        # 构建上传路径
        upload_path = os.path.join(target_path, os.path.dirname(relative_path))
        print(f"上传文件: {file_path} 到 {upload_path}")
        response = upload_file(url, file_path, cookies, upload_path)
        if response.status_code != 200:
            print(f"上传失败: {response.status_code}, {response.text}")
            return
        else:
            logging.info(f"保存文件成功: {os.path.join(upload_path, os.path.basename(file_path))}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='登录并上传目录到指定的URL和目录，显示加载状态的进度条和上传速度。')
    parser.add_argument('--base-url', required=True, help='Flask应用的基础URL，例如 https://fileserver.tianxiang.love')
    parser.add_argument('--username', required=True, help='登录用户名')
    parser.add_argument('--password', required=True, help='登录密码')
    parser.add_argument('--directory', required=True, help='要上传的目录路径')
    parser.add_argument('--remote-path', help='服务器上的相对路径')

    args = parser.parse_args()
    base_url = args.base_url.rstrip('/')  # 移除末尾的斜杠
    username = args.username
    password = args.password
    directory_path = args.directory
    remote_path = args.remote_path

    try:
        # 登录获取cookies和user_directory
        cookies, user_directory = login(base_url, username, password)

        # 上传目录
        upload_directory(directory_path, base_url, cookies, user_directory, remote_path)
    except Exception as e:
        print(f"错误: {e}")
```

```sh
# 把当前【我的音乐】目录上传到默认的服务器存储目录中
$ python3 upload_directory.py \
--directory 我的音乐 \
--base-url https://fileserver.tianxiang.love \
--username zhentianxiang \
--password 123456789
```

```sh
# 把当前【我的音乐】目录上传到服务器的 music 存储目录中
$ python3 upload_directory.py \
--directory 我的音乐 \
--base-url https://fileserver.tianxiang.love \
--username zhentianxiang \
--password 123456789
--remote-path music
```

#### 7. 下载文件脚本

```python
$ cat download_file.py
#!/usr/bin/python3
import os
import requests
import argparse
from tqdm import tqdm

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

# 函数：下载文件，支持断点续传
def download_file(url, file_path, cookies):
    headers = {}
    file_mode = 'wb'
    resume_header = False

    if os.path.exists(file_path):
        file_size = os.path.getsize(file_path)
        headers['Range'] = f'bytes={file_size}-'
        file_mode = 'ab'
        resume_header = True
    else:
        file_size = 0

    response = requests.get(url, headers=headers, cookies=cookies, stream=True)
    
    if response.status_code == 416:  # 处理已下载文件完整的情况
        print(f"文件 {file_path} 已经完整下载。")
        return

    total_size = int(response.headers.get('content-length', 0))
    total_size += file_size

    with open(file_path, file_mode) as f, tqdm(
        total=total_size, unit='B', unit_scale=True, initial=file_size, desc=os.path.basename(file_path)
    ) as pbar:
        for chunk in response.iter_content(chunk_size=1024):
            if chunk:
                f.write(chunk)
                pbar.update(len(chunk))

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='登录并下载文件到指定路径，支持断点续传。')
    parser.add_argument('--base-url', required=True, help='Flask应用的基础URL，例如 https://fileserver.tianxiang.love')
    parser.add_argument('--username', required=True, help='登录用户名')
    parser.add_argument('--password', required=True, help='登录密码')
    parser.add_argument('--file-url', required=True, help='要下载的文件URL')
    parser.add_argument('--output', required=True, help='保存下载文件的路径')

    args = parser.parse_args()
    base_url = args.base_url.rstrip('/')  # 移除末尾的斜杠
    username = args.username
    password = args.password
    file_url = args.file_url
    output_path = args.output

    try:
        # 登录获取cookies
        cookies = login(base_url, username, password)

        # 下载文件
        download_file(file_url, output_path, cookies)
        print("下载完成")
    except Exception as e:
        print(f"错误: {e}")
```

```sh
$ python3 download_file.py \
--base-url https://fileserver.tianxiang.love \
--username zhentianxiang --password 123456789 \
--file-url "https://fileserver.tianxiang.love/api/download/移动硬盘/3-Linux文件/2-部署工具/K8S自动化部署/kubernetes-install-CentOS-7.tar.gz?as_attachment=true" \
--output kubernetes-install-CentOS-7.tar.gz
```

### 5. SQL语句用法

#### 1. 查询表
```sh
# 查询表中全部字段信息
select * from files;

# 查询指定用户信息

SELECT * FROM files WHERE username = 'zhentianxiang';

# 查询指定 file_path 信息

SELECT * FROM files WHERE file_path = '/data/zhentianxiang/test';

# 匹配关键字查询

SELECT * FROM files WHERE file_path LIKE '%abc%';

# 指定具体的字段查询

SELECT username, file_path FROM files WHERE username = 'zhentianxiang';

SELECT username, file_path FROM files WHERE file_path = '/data/zhentianxiang/centos7';

# 指定具体字段然后关键字查询

SELECT username, file_path FROM files WHERE file_path LIKE '%centos7%';
```
#### 2. 删除表中的信息

```sh
# 删除 username 所有信息

DELETE FROM files WHERE username = 'zhentianxiang';

# 删除指定的 file_ptah 信息

DELETE FROM files WHERE file_path = '/data/zhentianxiang/test';

# 删除匹配到的关键字信息

DELETE FROM files WHERE file_path LIKE '%abc%';

# 删除指定的id

DELETE FROM files WHERE id = 1035;
```

#### 3. 插入一条数据

```sh
# 插入一条文件类型的记录

INSERT INTO files (username, file_path, item_type) VALUES ('zhentianxiang', '/data/zhentianxiang/file.txt', 'file');

# 插入一条目录类型的记录

INSERT INTO files (username, file_path, item_type) VALUES ('zhentianxiang', '/data/zhentianxiang/directory', 'directory');
```

### 6. 视频演示

<video width="1200" height="600" controls>
    <source src="https://fileserver.tianxiang.love/api/view?file=%2Fdata%2Fzhentianxiang%2F%E8%A7%86%E9%A2%91%E6%95%99%E5%AD%A6%E7%9B%AE%E5%BD%95%2Ffile-server%E6%96%87%E4%BB%B6%E7%AE%A1%E7%90%86%E6%9C%8D%E5%8A%A1%E5%99%A8.mp4" type="video/mp4">
</video>

### 7. k8s yaml

- file-server

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: file-server-pvc
  namespace: 
  annotations:
    volume.beta.kubernetes.io/storage-class: "nfs-provisioner-storage"
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
---
apiVersion: v1
kind: Service
metadata:
  name: file-server
  namespace:
spec:
  selector:
    app: file-server
  ports:
    - name: file-server
      protocol: TCP
      port: 9000
      targetPort: 9000
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: file-server
  namespace: 
  annotations:
spec:
  replicas: 1
  selector:
    matchLabels:
      app: file-server
  template:
    metadata:
      labels:
        app: file-server
    spec:
      initContainers:
      - name: init-mysql
        image: busybox  # 使用busybox作为轻量级容器
        command: ['/bin/sh', '-c']
        args:
          - |
            until nc -zv file-mysql 3306; do
              echo '等待 MySQL 服务启动';
              sleep 2;
            done
      containers:
      - name: file-server
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/file-server:v1.13.6
        imagePullPolicy: IfNotPresent
       # command:
       # - '/bin/bash'
       # - '-c'
       # - |
       #   sleep 9999
        env:
        - name: LOG_LEVEL
          value: "DEBUG"
        - name: TZ 
          value: "Asia/Shanghai"
        - name: PORT
          value: "9000"
        - name: UPLOADED_PATH
          value: "/data"
        - name: MAX_CONTENT_LENGTH
          value: "10737418240"
        - name: MYSQL_HOST
          value: "file-mysql"
        - name: MYSQL_PORT
          value: "3306"
        - name: MYSQL_USER
          value: "fileserver"
        - name: MYSQL_PASSWORD
          value: "fileserver"
        - name: MYSQL_DB
          value: "fileserver"
        - name: SECRET_KEY
          value: "6745e0efd28ee0848ae7506db194595d849d760998fbda8f"
        - name: SESSION_LIFETIME_MINUTES
          value: "30"
        ports:
        - name: file-server
          containerPort: 9000
          protocol: TCP
        # 存活探针
        livenessProbe:
          tcpSocket:
            port: 9000
          initialDelaySeconds: 10  # 指定探针后多少秒后启动，也可以是容器启动15秒后开始探测
          periodSeconds: 1     # 第一次探测结束后，等待多少时间后对容器再次进行探测
          successThreshold: 1 # 探测失败到成功的重试次数，也就是1次失败后直接重启容器，针对于livenessProbe
          timeoutSeconds: 10    # 单次探测超时时间
        # 就绪性探针
        readinessProbe:
          tcpSocket:
            port: 9000
          initialDelaySeconds: 10
          periodSeconds: 1
          failureThreshold: 3  # 探测成功到失败的重试次数，3次失败后会将容器挂起，不提供访问流量
          timeoutSeconds: 10
        volumeMounts:
          - name: file-server-data
            mountPath: /data
      volumes:
      - name: file-server-data
        persistentVolumeClaim:
          claimName: file-server-pvc
      restartPolicy: Always
```

- mysql

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: file-mysql-pvc
  namespace:
  annotations:
    volume.beta.kubernetes.io/storage-class: "nfs-provisioner-storage"
spec:
  accessModes:
  - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: file-mysql-config
  namespace: 
  labels:
    app: file-mysql
data:
  my.cnf: |-
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
---
apiVersion: v1
kind: Service
metadata:
  name: file-mysql
  namespace:
spec:
  selector:
    app: file-mysql
  ports:
    - name: file-mysql
      protocol: TCP
      port: 3306
      targetPort: 3306
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: file-mysql
  namespace: 
  annotations:
spec:
  replicas: 1
  selector:
    matchLabels:
      app: file-mysql
  template:
    metadata:
      labels:
        app: file-mysql
    spec:
      containers:
      - name: file-mysql
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/mysql:8.0
        imagePullPolicy: IfNotPresent
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: MYSQL_ROOT_PASSWORD
          value: "fileserver"
        - name: MYSQL_USER
          value: "fileserver"
        - name: MYSQL_PASSWORD
          value: "fileserver"
        - name: MYSQL_DATABASE
          value: "fileserver"
        ports:
        - name: file-mysql
          containerPort: 3306
          protocol: TCP
        # 存活探针
        livenessProbe:
          tcpSocket:
            port: 3306
          initialDelaySeconds: 10  # 指定探针后多少秒后启动，也可以是容器启动15秒后开始探测
          periodSeconds: 1     # 第一次探测结束后，等待多少时间后对容器再次进行探测
          successThreshold: 1 # 探测失败到成功的重试次数，也就是1次失败后直接重启容器，针对于livenessProbe
          timeoutSeconds: 10    # 单次探测超时时间
        # 就绪性探针
        readinessProbe:
          tcpSocket:
            port: 3306
          initialDelaySeconds: 10
          periodSeconds: 1
          failureThreshold: 3  # 探测成功到失败的重试次数，3次失败后会将容器挂起，不提供访问流量
          timeoutSeconds: 10
        volumeMounts:
          - name: config
            mountPath: /etc/my.cnf
            subPath: my.cnf
          - name: file-mysql-data
            mountPath: /var/lib/mysql
      volumes:
      - name: config
        configMap:
          name: file-mysql-config
      - name: file-mysql-data
        persistentVolumeClaim:
          claimName: file-mysql-pvc
      restartPolicy: Always
```

- file-front

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: file-front
  namespace:
spec:
  selector:
    app: file-front
  ports:
    - name: file-front
      protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: file-front-ingress
  namespace: 
  annotations:
    # Ingress Controller类别
    kubernetes.io/ingress.class: "nginx"
    # 正则表达式来匹配路径
    nginx.ingress.kubernetes.io/use-regex: "true"
    # 设置为"0"表示没有限制请求体的大小
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
spec:
  rules:
  - host: fileserver.tianxiang.com
    http:
      paths:
      - pathType: Prefix
        path: "/socket.io/"
        backend:
          service:
            name: file-server
            port:
              number: 9000
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: file-front
            port:
              number: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: file-front
  namespace: 
  annotations:
spec:
  replicas: 1
  selector:
    matchLabels:
      app: file-front
  template:
    metadata:
      labels:
        app: file-front
    spec:
      initContainers:
      - name: init-backend
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/busybox  # 使用busybox作为轻量级容器
        command: ['/bin/sh', '-c']
        args:
          - |
            until nc -zv file-server 9000; do
              echo '等待后端服务启动';
              sleep 2;
            done
      containers:
      - name: file-front
        image: registry.cn-hangzhou.aliyuncs.com/tianxiang_app/file-server-front:v1.13.6
        imagePullPolicy: IfNotPresent
        env:
        - name: TZ 
          value: "Asia/Shanghai"
        # ws 指的是http，wss是https
        # 如果使用的 nodeport 访问，请把域名替换为前端服务器能访问的IP地址+后端的nodeport端口
        - name: WS_SERVER_STATS
          value: "ws://fileserver.tianxiang.com"
        ports:
        - name: file-front
          containerPort: 80
          protocol: TCP
        volumeMounts:
          - name: config
            mountPath: /etc/nginx/nginx.conf
            subPath: nginx.conf
      volumes:
      - name: config
        configMap:
          name: file-front-config
      restartPolicy: Always
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: file-front-config
  namespace: 
  labels:
    app: file-front
data:
  nginx.conf: |-
    worker_processes auto;
    events { worker_connections 1024; }
    
    http {
        log_format basic '$remote_addr - $remote_user [$time_local] "$request" '
                          '$status $body_bytes_sent "$http_referer" '
                          '"$http_user_agent" "$http_x_forwarded_for"';
    
        sendfile on;
        tcp_nopush on;
        tcp_nodelay on;
        keepalive_timeout 1800s;
        proxy_connect_timeout 1800s;
        proxy_read_timeout 1800s; # 超时时间30分钟,如果上传大文件,时间不够会报错
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
            server_name localhost;
            root /usr/share/nginx/html;

            # 处理根路径,用于检测用户是否登陆并重定向登陆页面
            location / {
                proxy_pass http://file-server:9000;
                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
            }   
 
            location /login.html {
                index  login.html;
            }

            location /monitor.html {
                index  monitor.html;
            }

            location /register.html {
                index  register.html;
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

            location /socket.io/ {
            proxy_pass http://file-server:9000/socket.io/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
           }
        }
    }
```
