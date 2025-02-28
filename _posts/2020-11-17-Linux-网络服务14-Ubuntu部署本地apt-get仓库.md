---
layout: post
title: Linux-网络服务14-Ubuntu部署本地apt-get仓库
date: 2020-11-17
tags: Linux-网络服务
---

由于有些办公情况下没有网络，所以下载东西就很麻烦，为此可以搭建一个源仓库

## 一、仓库端

### 1. 安装apt-mirror

```sh
root@tianxiang:~# apt-get install apt-mirror
```

###  2. 修改apt-mirror配置文件

```sh
root@tianxiang:~# vim /etc/apt/mirror.list
```

```sh
############# config ##################
# 以下注释的内容都是默认配置，如果需要自定义，取消注释修改即可
set base_path /var/spool/apt-mirror
#
# 镜像文件下载地址
# set mirror_path $base_path/mirror
# 临时索引下载文件目录，也就是存放软件仓库的dists目录下的文件（默认即可）
# set skel_path $base_path/skel
# 配置日志（默认即可）
# set var_path $base_path/var
# clean脚本位置
# set cleanscript $var_path/clean.sh
# 架构配置，i386/amd64，默认的话会下载跟本机相同的架构的源
set defaultarch amd64
# set postmirror_script $var_path/postmirror.sh
# set run_postmirror 0
# 下载线程数
set nthreads 20
set _tilde 0
#
############# end config ##############
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
# kubernetes
deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
# docker-ce
deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu bionic stable
# deb-src [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu bionic stable
clean https://mirrors.aliyun.com/ubuntu
clean https://mirrors.aliyun.com/kubernetes/apt
clean https://mirrors.aliyun.com/docker-ce/linux/ubuntu
```

确认一下自己的系统版本是什么，我的是：Ubuntu 20.04 LTS（Focal Fossa），所以配置文件中使用的是，focal

bionic 是 18.04的，所以不同的版本对应不同的配置文件，不要一味的复制粘贴


###  3. 开始同步

```sh
root@tianxiang:~# apt-mirror
```

 然后等待很长时间（该镜像差不多300G左右，具体时间看网络环境，我当时同步了20个小时左右），同步的镜像文件目录为/var/spool/apt-mirror/mirror/mirrors.aliyun.com/ubuntu/，当然如果增加了其他的源，在/var/spool/apt-mirror/mirror目录下还有其他的地址为名的目录。

注意：当apt-mirror 被意外中断时，只需要重新运行即可，apt-mirror支持断点续存；另外，意外关闭，需要在/var/spool/apt-mirror/var目录下面删除 apt-mirror.lock文件【 sudo rm apt-mirror.lock 】，之后执行apt-mirror重新启动

### 4. 安装nginx作为可视化页面

```sh
root@tianxiang:~# apt-get install -y nginx
root@tianxiang:~# vim /etc/nginx/conf.d/mirrors.conf
server {
    listen       80;
    server_name  mirrors.aliyun.com;
    client_max_body_size 0m;

    location / {
               default_type text/plain;
               autoindex on;
               autoindex_exact_size off;
               autoindex_localtime on;
               charset utf-8,gbk;
               index index.html;
        root /var/www/mirrors/;
    }
}
root@tianxiang:~# mkdir -pv /var/www/mirrors && cd /var/www/mirrors
root@tianxiang:~# vim index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ubuntu 镜像源 - 内网快速配置</title>
    <style>
        /* 样式重置 */
        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: Arial, sans-serif;
            background-color: #f4f7f6;
            color: #333;
            line-height: 1.6;
        }

        h1 {
            background-color: #4CAF50;
            color: white;
            padding: 20px;
            text-align: center;
            font-size: 2em;
        }

        .container {
            width: 80%;
            margin: 20px auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 0 15px rgba(0, 0, 0, 0.1);
        }

        .alert {
            background-color: #f9f9f9;
            border-left: 5px solid #4CAF50;
            margin-bottom: 20px;
            padding: 10px;
            font-size: 1.1em;
        }

        h2 {
            font-size: 1.5em;
            margin-bottom: 10px;
        }

        a {
            color: #007BFF;
            text-decoration: none;
        }

        a:hover {
            color: #0056b3;
        }

        .code-container {
            background-color: #f4f4f4;
            border: 1px solid #ddd;
            padding: 15px;
            border-radius: 5px;
            font-family: monospace;
            white-space: pre-wrap;
            word-wrap: break-word;
        }

        .button {
            background-color: #4CAF50;
            color: white;
            border: none;
            padding: 10px;
            font-size: 1em;
            border-radius: 5px;
            cursor: pointer;
        }

        .button:hover {
            background-color: #45a049;
        }

        .copy-btn {
            background-color: #007BFF;
            margin-top: 10px;
        }

        .copy-btn:hover {
            background-color: #0056b3;
        }

        /* 响应式设计 */
        @media (max-width: 768px) {
            .container {
                width: 95%;
            }

            h1 {
                font-size: 1.5em;
            }
        }
    </style>
</head>
<body>

    <h1>Ubuntu 镜像源 - 内网快速配置</h1>

    <div class="container">

        <p>此镜像站包括 Ubuntu、Kubernetes 和 Docker 镜像源。请根据需要配置相关的 GPG 密钥和源列表。</p>

        <!-- 1. Ubuntu -->
        <div class="alert">
            <h2>Ubuntu 软件包</h2>
            <p>点击查看镜像包内容并配置：</p>
            <a href="/ubuntu">点击查看 Ubuntu 软件包</a>
        </div>

        <!-- 2. Kubernetes -->
        <div class="alert">
            <h2>Kubernetes 软件包</h2>
            <p>点击查看 Kubernetes 镜像包：</p>
            <a href="/kubernetes">点击查看 Kubernetes 软件包</a>
        </div>

        <!-- 3. Docker-ce -->
        <div class="alert">
            <h2>Docker-ce 软件包</h2>
            <p>点击查看 Docker 镜像包：</p>
            <a href="/docker-ce">点击查看 Docker 软件包</a>
        </div>

        <h2>配置命令</h2>
        <div class="code-container">

            <h3>1. 更新基础镜像源</h3>
            <p>运行以下命令更新基础镜像源：</p>
            <pre>apt update</pre>

            <h3>2. 安装加密和签名数据的工具</h3>
            <p>运行以下命令安装加密和签名数据的工具：</p>
            <pre>apt -y install ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common</pre>

            <h3>3. 添加 Docker GPG 密钥</h3>
            <p>运行以下命令添加 Docker GPG 密钥：</p>
            <pre>curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg |apt-key add -</pre>

            <h3>4. 添加 Kubernetes GPG 密钥</h3>
            <p>运行以下命令添加 Kubernetes GPG 密钥：</p>
            <pre>curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -</pre>

            <h3>5. 配置 apt 源列表</h3>
            <p>运行以下命令配置 apt 源列表：</p>
            <pre>curl -o /etc/apt/sources.list http://mirrors-apt.tianxiang.love/sources.list</pre>
        </div>

        <h2>复制命令</h2>
        <button class="button copy-btn" onclick="copyToClipboard()">复制所有命令</button>

    </div>

    <script>
        function copyToClipboard() {
            // 创建一个隐藏的 textarea 元素来临时保存要复制的文本
const copyText = `
apt update
apt -y install ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common
curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg |apt-key add -
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
curl -o /etc/apt/sources.list http://mirrors-apt.tianxiang.love/sources.list
apt update
`;
            
            const textarea = document.createElement('textarea');
            textarea.value = copyText;
            document.body.appendChild(textarea);
            textarea.select();
            document.execCommand('copy');
            document.body.removeChild(textarea);
            
            alert('命令已复制到剪贴板！');
        }
    </script>

</body>
</html>
root@tianxiang:~# vim sources.list
# mirrors.aliyun.com
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
# kubernetes
deb http://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
# docker-ce
deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu bionic stable
```
由于nginx的默认网页文件目录位于/var/www/html，因此，可以做个软链接
```sh
root@tianxiang:~# ln -s /var/spool/apt-mirror/mirror/mirrors.aliyun.com/ubuntu /var/www/mirrors
root@tianxiang:~# ln -s /var/spool/apt-mirror/mirror/mirrors.aliyun.com/docker-ce/ /var/www/mirrors
root@tianxiang:~# ln -s /var/spool/apt-mirror/mirror/mirrors.aliyun.com/kubernetes /var/www/mirrors
root@tianxiang:~# nginx -s reload
```

 然后就可以通过如下地址访问了

> http://mirrors.aliyun.com/

## 二、客户端配置

### 1.修改默认的源为自己的源

```sh

root@tianxiang:~# curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
root@tianxiang:~# curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
root@tianxiang:~# curl -o /etc/apt/sources.list http://mirrors-apt.tianxiang.love/sources.list
            
```

### 2. 更新apt-get源并测试源是否生效

```sh
root@tianxiang:~# apt-get update
root@tianxiang:~# apt-cache madison nginx
     nginx | 1.4.6-1ubuntu3.9 | http://mirrors-apt.tianxiang.love/ubuntu trusty-security/main amd64 Packages
     nginx | 1.4.6-1ubuntu3.9 | http://mirrors-apt.tianxiang.love/ubuntu trusty-updates/main amd64 Packages
     nginx | 1.4.6-1ubuntu3 | http://mirrors-apt.tianxiang.love/ubuntu trusty/main amd64 Packages
root@tianxiang:~# apt-cache madison kubeadm
   kubeadm |  1.21.2-00 | http://192.168.1.110/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.21.1-00 | http://192.168.1.110/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.21.0-00 | http://192.168.1.110/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.20.8-00 | http://192.168.1.110/kubernetes/apt kubernetes-xenial/main amd64 Packages
root@tianxiang:~# apt-cache madison docker-ce
 docker-ce | 5:20.10.7~3-0~ubuntu-bionic | http://mirrors-apt.tianxiang.love/docker-ce/linux/ubuntu bionic/stable amd64 Packages
 docker-ce | 5:20.10.6~3-0~ubuntu-bionic | http://mirrors-apt.tianxiang.love/docker-ce/linux/ubuntu bionic/stable amd64 Packages
 docker-ce | 5:20.10.5~3-0~ubuntu-bionic | http://mirrors-apt.tianxiang.love/docker-ce/linux/ubuntu bionic/stable amd64 Packages
 docker-ce | 5:20.10.4~3-0~ubuntu-bionic | http://mirrors-apt.tianxiang.love/docker-ce/linux/ubuntu bionic/stable amd64 Packages
```

## 三、Docker 启动内网源服务

### 1. 制作镜像

- 准备 Dockerfile 文件

```sh
root@tianxiang:~# cat Dockerfile 
# 使用官方的 Ubuntu 镜像作为基础镜像
FROM ubuntu:20.04

# 设置环境变量，避免交互式安装
ENV DEBIAN_FRONTEND=noninteractive

# 更新 apt 并安装 apt-mirror 工具
COPY sources.list /etc/apt/sources.list
RUN apt update && \
    apt install -y apt-mirror curl nginx && \
    apt clean

RUN sed -i '451i\            add_url_to_download( $url . $_ . "/cnf/Commands-" . $arch . ".xz" );' /usr/bin/apt-mirror
# 创建 apt-mirror 配置文件的默认目录
RUN mkdir -pv /var/spool/apt-mirror

# 默认的工作目录
WORKDIR /etc/apt

# 复制自定义的 apt-mirror 配置文件到容器中
COPY mirror.list /etc/apt/mirror.list

# 复制启动脚本
COPY start.sh /home/start.sh

# 运行
CMD ["/bin/bash", "/home/start.sh"]
```

- 准备 sources.list 文件

```sh
root@tianxiang:~# cat sources.list
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
root@big-server:/data/k8s-app/ubuntu-20.04-apt# ls
apt-mirror  deployment.yaml  Dockerfile  ingress.yaml  mirror.list  service.yaml  sources.list  start.sh  ubuntu-mirror-web.conf
root@big-server:/data/k8s-app/ubuntu-20.04-apt# cat sources.list 
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
# deb-src http://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
```

- 准备 mirror.list 文件

```sh
root@tianxiang:~# cat mirror.list 
############# config ##################
# 以下注释的内容都是默认配置，如果需要自定义，取消注释修改即可
set base_path /var/spool/apt-mirror
#
# 镜像文件下载地址
# set mirror_path $base_path/mirror
# 临时索引下载文件目录，也就是存放软件仓库的dists目录下的文件（默认即可）
# set skel_path $base_path/skel
# 配置日志（默认即可）
# set var_path $base_path/var
# clean脚本位置
# set cleanscript $var_path/clean.sh
# 架构配置，i386/amd64，默认的话会下载跟本机相同的架构的源
set defaultarch amd64
# set postmirror_script $var_path/postmirror.sh
# set run_postmirror 0
# 下载线程数
set nthreads 20
set _tilde 0
#
############# end config ##############
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ focal main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-updates main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-backports main restricted universe multiverse
deb https://mirrors.aliyun.com/ubuntu/ focal-security main restricted universe multiverse
# kubernetes
deb https://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main
# docker-ce
deb [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu bionic stable
# deb-src [arch=amd64] https://mirrors.aliyun.com/docker-ce/linux/ubuntu bionic stable
clean https://mirrors.aliyun.com/ubuntu
clean https://mirrors.aliyun.com/kubernetes/apt
clean https://mirrors.aliyun.com/docker-ce/linux/ubuntu
```

我把 18.04 和 20.04 的全部添加进去了

- 准备 start.sh 启动脚本

```sh
root@tianxiang:~# cat start.sh
#!/bin/bash

# 脚本主体函数
main() {
    # 从环境变量获取更新时间，如果没有设置，则默认为每天0点
    UPDATE_TIME=${UPDATE_TIME:-"00:00"}

    # 获取更新时间的时间戳
    local next_run_time=$(date --date="today $UPDATE_TIME" "+%s")
    local current_time=$(date "+%s") # 获取当前时间的时间戳

    # 无限循环
    while true; do
        # 检查当前时间是否到了或过了更新时间
        if [ $current_time -ge $next_run_time ]; then
            echo "检查nginx服务状态..."
            if ! pgrep -x "nginx" > /dev/null; then
                echo "nginx 正在启动..."
                nginx
            else
                echo "nginx 进程已存在。"
            fi

            echo "准备同步 Ubuntu 镜像源"
            DATETIME=$(date +%F_%H-%M-%S)
            LOGFILE="/var/log/ubuntu_mirror_$DATETIME.log"

            {
                # 使用 apt-mirror 命令进行镜像同步
                apt-mirror
                if [ $? -eq 0 ]; then
                    echo "SUCCESS: $DATETIME Ubuntu 镜像源同步成功"
                else
                    echo "ERROR: $DATETIME apt-mirror update failed"
                fi
            } 2>&1 | tee -a "$LOGFILE"

            # 更新 next_run_time 为次日的更新时间的时间戳
            next_run_time=$(date --date="tomorrow $UPDATE_TIME" "+%s")
        fi

        # 等待直到 next_run_time
        sleep $((next_run_time - current_time))
        current_time=$(date "+%s")
    done
}

# 调用 main 函数
main
```

### 2. docker-compose 文件

```sh
root@tianxiang:~# cat docker-compose.yml 
services:
  Ubuntu-20.04-apt:
    container_name: Ubuntu-20.04-apt
    image: ubuntu-20.04-apt-mirror:latest
    ports:
      - 80:80
    environment:
      UPDATE_TIME: "1:30"
      TZ: "Asia/Shanghai"
    volumes:
      - ./apt-mirror:/var/spool/apt-mirror
      - ./mirror-web.conf:/etc/nginx/conf.d/mirrors-web.conf
    restart: always
```

- mirror-web.conf 文件

```sh
root@tianxiang:~# cat mirror-web.conf
server {
    listen       80;
    server_name  mirrors-apt.tianxiang.love;
    client_max_body_size 0m;

    location / {
               default_type text/plain;
               autoindex on;
               autoindex_exact_size off;
               autoindex_localtime on;
               charset utf-8,gbk;
               index index.html;
        root /var/spool/apt-mirror/mirror/mirrors.aliyun.com;
    }
}
```

### 3. 启动

首先创建一个存储目录，其次启动后暂停一下把两个文件放到目录中再次启动

```sh
root@tianxiang:~# mkdir apt-mirror
root@tianxiang:~# docker-compose up -d
root@tianxiang:~# docker-compose down
root@tianxiang:~# cd apt-mirror/mirror/mirrors.aliyun.com/
root@tianxiang:~# vim index.html 
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ubuntu 镜像源 - 内网快速配置</title>
    <style>
        /* 样式重置 */
        * { margin: 0; padding: 0; box-sizing: border-box; }

        body {
            font-family: Arial, sans-serif;
            background-color: #f4f7f6;
            color: #333;
            line-height: 1.6;
        }

        h1 {
            background-color: #4CAF50;
            color: white;
            padding: 20px;
            text-align: center;
            font-size: 2em;
        }

        .container {
            width: 80%;
            margin: 20px auto;
            background: white;
            padding: 30px;
            border-radius: 8px;
            box-shadow: 0 0 15px rgba(0, 0, 0, 0.1);
        }

        .alert {
            background-color: #f9f9f9;
            border-left: 5px solid #4CAF50;
            margin-bottom: 20px;
            padding: 10px;
            font-size: 1.1em;
        }

        h2 {
            font-size: 1.5em;
            margin-bottom: 10px;
        }

        a {
            color: #007BFF;
            text-decoration: none;
        }

        a:hover {
            color: #0056b3;
        }

        .code-container {
            background-color: #f4f4f4;
            border: 1px solid #ddd;
            padding: 15px;
            border-radius: 5px;
            font-family: monospace;
            white-space: pre-wrap;
            word-wrap: break-word;
        }

        .button {
            background-color: #4CAF50;
            color: white;
            border: none;
            padding: 10px;
            font-size: 1em;
            border-radius: 5px;
            cursor: pointer;
        }

        .button:hover {
            background-color: #45a049;
        }

        .copy-btn {
            background-color: #007BFF;
            margin-top: 10px;
        }

        .copy-btn:hover {
            background-color: #0056b3;
        }

        /* 响应式设计 */
        @media (max-width: 768px) {
            .container {
                width: 95%;
            }

            h1 {
                font-size: 1.5em;
            }
        }
    </style>
</head>
<body>

    <h1>Ubuntu 镜像源 - 内网快速配置</h1>

    <div class="container">

        <p>此镜像站包括 Ubuntu、Kubernetes 和 Docker 镜像源。请根据需要配置相关的 GPG 密钥和源列表。</p>

        <!-- 1. Ubuntu -->
        <div class="alert">
            <h2>Ubuntu 软件包</h2>
            <p>点击查看镜像包内容并配置：</p>
            <a href="/ubuntu">点击查看 Ubuntu 软件包</a>
        </div>

        <!-- 2. Kubernetes -->
        <div class="alert">
            <h2>Kubernetes 软件包</h2>
            <p>点击查看 Kubernetes 镜像包：</p>
            <a href="/kubernetes">点击查看 Kubernetes 软件包</a>
        </div>

        <!-- 3. Docker-ce -->
        <div class="alert">
            <h2>Docker-ce 软件包</h2>
            <p>点击查看 Docker 镜像包：</p>
            <a href="/docker-ce">点击查看 Docker 软件包</a>
        </div>

        <h2>配置命令</h2>
        <div class="code-container">

            <h3>1. 更新基础镜像源</h3>
            <p>运行以下命令更新基础镜像源：</p>
            <pre>apt update</pre>

            <h3>2. 安装加密和签名数据的工具</h3>
            <p>运行以下命令安装加密和签名数据的工具：</p>
            <pre>apt -y install ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common</pre>

            <h3>3. 添加 Docker GPG 密钥</h3>
            <p>运行以下命令添加 Docker GPG 密钥：</p>
            <pre>curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg |apt-key add -</pre>

            <h3>4. 添加 Kubernetes GPG 密钥</h3>
            <p>运行以下命令添加 Kubernetes GPG 密钥：</p>
            <pre>curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -</pre>

            <h3>5. 配置 apt 源列表</h3>
            <p>运行以下命令配置 apt 源列表：</p>
            <pre>curl -o /etc/apt/sources.list http://mirrors-apt.tianxiang.love/sources.list</pre>
        </div>

        <h2>复制命令</h2>
        <button class="button copy-btn" onclick="copyToClipboard()">复制所有命令</button>

    </div>

    <script>
        function copyToClipboard() {
            // 创建一个隐藏的 textarea 元素来临时保存要复制的文本
const copyText = `
apt update
apt -y install ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common
curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg |apt-key add -
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
curl -o /etc/apt/sources.list http://mirrors-apt.tianxiang.love/sources.list
apt update
`;
            
            const textarea = document.createElement('textarea');
            textarea.value = copyText;
            document.body.appendChild(textarea);
            textarea.select();
            document.execCommand('copy');
            document.body.removeChild(textarea);
            
            alert('命令已复制到剪贴板！');
        }
    </script>

</body>
</html>

root@tianxiang:~# vim sources.list 
# mirrors.aliyun.com
deb http://mirrors-apt.tianxiang.love/ubuntu/ focal main restricted universe multiverse
deb http://mirrors-apt.tianxiang.love/ubuntu/ focal-updates main restricted universe multiverse
deb http://mirrors-apt.tianxiang.love/ubuntu/ focal-backports main restricted universe multiverse
deb http://mirrors-apt.tianxiang.love/ubuntu/ focal-security main restricted universe multiverse

# kubernetes
deb http://mirrors-apt.tianxiang.love/kubernetes/apt kubernetes-xenial main
# docker-ce
deb [arch=amd64] http://mirrors-apt.tianxiang.love/docker-ce/linux/ubuntu bionic stable

root@tianxiang:~# cd ../../../
root@tianxiang:~# docker-compose up -d
```
