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
参考以下配置文件：
清空原有的配置文件，直接使用以下配置文件即可
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
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-updates main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-backports main restricted universe multiverse
deb https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse
# deb-src https://mirrors.tuna.tsinghua.edu.cn/ubuntu/ bionic-security main restricted universe multiverse
# kubernetes
deb https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt kubernetes-xenial main
# docker-ce
deb [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu bionic stable
# deb-src [arch=amd64] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu bionic stable
clean https://mirrors.tuna.tsinghua.edu.cn/ubuntu
clean https://mirrors.tuna.tsinghua.edu.cn/kubernetes/apt
clean https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu
```

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
    server_name  192.168.1.110;
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
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
    <head>
        <title>Ubuntu_1804-清华网络源</title>
        <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
        <style type="text/css">
            /*<![CDATA[*/
            body {
                background-color: #fff;
                color: #000;
                font-size: 0.9em;
                font-family: sans-serif,helvetica;
                margin: 0;
                padding: 0;
            }
            :link {
                color: #c00;
            }
            :visited {
                color: #c00;
            }
            a:hover {
                color: #f50;
            }
            h1 {
                text-align: center;
                margin: 0;
                padding: 0.6em 2em 0.4em;
                background-color: #294172;
                color: #fff;
                font-weight: normal;
                font-size: 1.75em;
                border-bottom: 2px solid #000;
            }
            h1 strong {
                font-weight: bold;
                font-size: 1.5em;
            }
            h2 {
                text-align: center;
                background-color: #3C6EB4;
                font-size: 1.1em;
                font-weight: bold;
                color: #fff;
                margin: 0;
                padding: 0.5em;
                border-bottom: 2px solid #294172;
            }
            hr {
                display: none;
            }
            .content {
                padding: 1em 5em;
            }
            .alert {
                border: 2px solid #000;
            }

            img {
                border: 2px solid #fff;
                padding: 2px;
                margin: 2px;
            }
            a:hover img {
                border: 2px solid #294172;
            }
            .logos {
                margin: 1em;
                text-align: center;
            }
            /*]]>*/
        </style>
    </head>

    <body>
        <h1>Ubuntu_1804-清华网络源！</h1>

        <div class="content">
            <p>此镜像站包括清华源、kubernetes源、docker-ce源</p>

            <div class="alert">
                <h2>Ubuntu</h2>
                <div class="content">
                    <p><a href="/ubuntu">点击查看软件包</a></p>
                </div>
            </div>
            <div class="alert">
                <h2>Kubernetes</h2>
                <div class="content">
                    <p><a href="/kubernetes">点击查看软件包</a></p>
                </div>
            </div>
            <div class="alert">
                <h2>Docker-ce</h2>
                <div class="content">
                    <p><a href="/docker-ce">点击查看软件包</a></p>
                </div>
            </div>

	    <h1>因为kubernetes和docker需要配置相关gpg证书，所以需要先添加证书</a></h1>
	    <h1>Usage: curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add - </a></h1>
	    <h1>Usage: curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add - </a></h1>
	    <h1>Usage: curl -o /etc/apt/sources.list <a href="/sources.list">http://192.168.1.110/sources.list</a></h1>
            </div>
        </div>
    </body>
</html>
root@tianxiang:~# vim sources.list
# mirrors.tuna.tsinghua.edu.cn
deb http://192.168.1.110/ubuntu/ bionic main restricted universe multiverse
deb http://192.168.1.110/ubuntu/ bionic-updates main restricted universe multiverse
deb http://192.168.1.110/ubuntu/ bionic-backports main restricted universe multiverse
deb http://192.168.1.110/ubuntu/ bionic-security main restricted universe multiverse
# kubernetes
deb http://192.168.1.110/kubernetes/apt kubernetes-xenial main
# docker-ce
deb [arch=amd64] http://192.168.1.110/docker-ce/linux/ubuntu bionic stable
```
由于nginx的默认网页文件目录位于/var/www/html，因此，可以做个软链接
```sh
root@tianxiang:~# ln -s /var/spool/apt-mirror/mirror/mirrors.tuna.tsinghua.edu.cn/ubuntu /var/www/mirrors
root@tianxiang:~# ln -s /var/spool/apt-mirror/mirror/mirrors.tuna.tsinghua.edu.cn/docker-ce/ /var/www/mirrors
root@tianxiang:~# ln -s /var/spool/apt-mirror/mirror/mirrors.tuna.tsinghua.edu.cn/kubernetes /var/www/mirrors
root@tianxiang:~# nginx -s reload
```

 然后就可以通过如下地址访问了

> http://192.168.1.110/

## 二、客户端配置

### 1.修改默认的源为自己的源

```sh
root@tianxiang:~# vim /etc/apt/source.list
# mirrors.tuna.tsinghua.edu.cn
deb http://192.168.1.110/ubuntu/ bionic main restricted universe multiverse
deb http://192.168.1.110/ubuntu/ bionic-updates main restricted universe multiverse
deb http://192.168.1.110/ubuntu/ bionic-backports main restricted universe multiverse
deb http://192.168.1.110/ubuntu/ bionic-security main restricted universe multiverse
# kubernetes
deb http://192.168.1.110/kubernetes/apt kubernetes-xenial main
# docker-ce
deb [arch=amd64] http://192.168.1.110/docker-ce/linux/ubuntu bionic stable
```

### 2. 更新apt-get源并测试源是否生效

```sh
# 添加docker和kubernetes源密钥，不然update会报错
root@tianxiang:~# curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
root@tianxiang:~# curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
# 如果此gpg使用报错，那么可以使用如下
root@tianxiang:~# curl -u admin:18332825309 -fsSL http://blog.linuxtian.top:8080/1-gpg_Public-key/2-docker/gpg | sudo apt-key add -
root@tianxiang:~# curl -u admin:18332825309 -fsSL http://blog.linuxtian.top:8080/1-gpg_Public-key/3-k8s/apt-key.gpg | sudo apt-key add -
root@tianxiang:~# apt-get update
root@tianxiang:~# apt-cache madison nginx
     nginx | 1.4.6-1ubuntu3.9 | http://192.168.1.110/ubuntu trusty-security/main amd64 Packages
     nginx | 1.4.6-1ubuntu3.9 | http://192.168.1.110/ubuntu trusty-updates/main amd64 Packages
     nginx | 1.4.6-1ubuntu3 | http://192.168.1.110/ubuntu trusty/main amd64 Packages
root@tianxiang:~# apt-cache madison kubeadm
   kubeadm |  1.21.2-00 | http://192.168.1.110/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.21.1-00 | http://192.168.1.110/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.21.0-00 | http://192.168.1.110/kubernetes/apt kubernetes-xenial/main amd64 Packages
   kubeadm |  1.20.8-00 | http://192.168.1.110/kubernetes/apt kubernetes-xenial/main amd64 Packages
root@tianxiang:~# apt-cache madison docker-ce
 docker-ce | 5:20.10.7~3-0~ubuntu-bionic | http://192.168.1.110/docker-ce/linux/ubuntu bionic/stable amd64 Packages
 docker-ce | 5:20.10.6~3-0~ubuntu-bionic | http://192.168.1.110/docker-ce/linux/ubuntu bionic/stable amd64 Packages
 docker-ce | 5:20.10.5~3-0~ubuntu-bionic | http://192.168.1.110/docker-ce/linux/ubuntu bionic/stable amd64 Packages
 docker-ce | 5:20.10.4~3-0~ubuntu-bionic | http://192.168.1.110/docker-ce/linux/ubuntu bionic/stable amd64 Packages
```
