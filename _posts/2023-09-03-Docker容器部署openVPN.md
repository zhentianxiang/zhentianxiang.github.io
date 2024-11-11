---
layout: post
title: 2023-09-03-Docker容器部署openVPN
date: 2023-09-03
tags: 其他
music-id: 1905004937
---

## 一、OpenVPN 简介

VPN 直译就是虚拟专用通道，是提供给企业之间或者个人与公司之间**安全数据传输**的隧道，OpenVPN 无疑是 Linux 下开源 VPN 的先锋，提供了良好的性能和友好的用户 GUI。

OpenVPN 是一个基于 OpenSSL 库的应用层 VPN 实现。和传统 VPN 相比，它的优点是**简单易用**。

OpenVPN 允许参与建立 VPN 的单点使用共享金钥，电子证书，或者用户名/密码来进行身份验证。它大量使用了 OpenSSL 加密库中的 SSLv3 /TLSv1 协议函式库。OpenVPN 能在 Solaris、Linux、OpenBSD、FreeBSD、NetBSD、Mac OS X 与 Windows 上运行，并包含了许多安全性的功能。它并不是一个基于 Web 的 VPN 软件，也不与 IPSec 及其他 VPN 软件包兼容。

虚拟私有网络（VPN）隧道是通过 Internet 隧道技术将两个不同地理位置的网络安全的连接起来的技术。当两个网络是使用私有 IP 地址的私有局域网络时，它们之间是不能相互访问的，这时使用隧道技术就可以使得两个子网内的主机进行通讯。例如，VPN 隧道技术经常被用于大型机构中不同办公区域子网的连接。有时，使用 VPN 隧道仅仅是因为它很安全。服务提供商与公司会使用这样一种方式架设网络，他们将重要的服务器（如，数据库，VoIP，银行服务器）放置到一个子网内，仅仅让有权限的用户通过 VPN 隧道进行访问。如果需要搭建一个安全的 VPN 隧道，通常会选用 **IPSec**，因为 IPSec VPN 隧道被多重安全层所保护。

VPN (虚拟专用网)发展至今已经不在是一个单纯的经过加密的访问隧道了，它已经融合了**访问控制**、**传输管理**、**加密**、**路由选择**、**可用性管理**等多种功能，并在全球的信息安全体系中发挥着重要的作用。也在网络上，有关各种 VPN 协议优缺点的比较是仁者见仁，智者见智，很多技术人员由于出于使用目的考虑，包括访问控制、 安全和用户简单易用，灵活扩展等各方面，权衡利弊，难以取舍；尤其在 VOIP 语音环境中，网络安全显得尤为重要，因此现在越来越多的网络电话和语音网关支持 VPN 协议。

## 二、部署

### 1. 拉取镜像

```sh
$ docker pull zhentianxiang/openvpn:2.4.8
```

### 2. 创建挂载目录

```sh
$ mkdir -pv /etc/openvpn/conf
$ cd /etc/openvpn/
```

### 3. 生成配置文件

选择使用 OpenVPN 的 UDP 还是 TCP 取决于您的特定需求和情况。每个协议都有自己的优点和缺点，以下是一些考虑因素：

**UDP：**

1. **速度快：** UDP 通常比 TCP 更快，因为它不进行连接建立和错误恢复的复杂过程。这使得 UDP 成为处理实时流量（如音频和视频传输）的理想选择。
2. **较少的开销：** UDP 头部较小，因此它产生的额外开销较少，适用于网络连接较慢的情况。
3. **适用于游戏和流媒体：** 由于速度快且开销低，UDP 通常用于在线游戏、流媒体以及其他需要快速数据传输和低延迟的应用。
4. **不稳定网络：** 在不稳定的网络环境中，UDP 可能更可靠，因为它不会试图重传丢失的数据包，从而减少了延迟。

**TCP：**

1. **可靠性：** TCP 是一种可靠的协议，它确保数据包的有序传输和丢失包的重传。这使得它在不太可靠的网络环境中更适合，如公共 Wi-Fi 或有防火墙和代理的网络。
2. **适用于文件传输：** 由于可靠性，TCP 通常用于文件传输和下载，因为它可以确保文件完整性。
3. **穿越防火墙：** 由于通常的 HTTP 流量也使用 TCP，因此 TCP 通常可以更容易穿越防火墙和代理服务器，这使得它在某些网络环境中更可用。
4. **保密性：** 在某些情况下，TCP 可能更容易混淆和伪装，以保护数据的隐私。

总结来说，UDP 通常更适合需要高速传输和低延迟的应用，而 TCP 更适合需要可靠性和穿越防火墙的应用。选择哪种协议应取决于您的特定需求以及您所在网络环境的性质。有时，将两者结合使用也是一个可行的解决方案，以满足不同类型的流量需求。

```sh
# 1.1.1.1 是公网IP，根据实际需求切换自己的公网IP
# 默认是udp协议，我这边使用的是tcp协议
$ docker run -v $(pwd):/etc/openvpn --rm zhentianxiang/openvpn:2.4.8 ovpn_genconfig -u tcp://1.1.1.1

# 简单修改一下配置文件，当然直接使用默认的也是可以的
$ cat openvpn.conf
# 监听地址
local 0.0.0.0

# 协议
proto tcp

# 端口
port 1194

# 虚拟网卡设备
dev tun0

key /etc/openvpn/pki/private/1.1.1.1.key
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/1.1.1.1.crt
dh /etc/openvpn/pki/dh.pem
tls-auth /etc/openvpn/pki/ta.key
key-direction 0

# 通过ping得知超时时，当重启vpn后将使用同一个密钥文件以及保持tun连接状态
persist-tun
persist-key

# 日志记录的详细级别
verb 3
status /tmp/openvpn-status.log

# 运行用户
user nobody
group nogroup

# 允许客户端之间互相访问
client-to-client

# 限制最大客户端数量
max-clients 10

# 保持连接时间
keepalive 20 120

# 允许多人使用同一个证书连接VPN，不建议使用，注释状态
duplicate-cn

# 路由规则，告诉 OpenVPN 服务器要将流量路由到目标网络 192.168.255.0/24
route 192.168.255.0 255.255.255.0

# vpn服务端为自己和客户端分配IP的地址池
server 192.168.255.0 255.255.255.0

### VPN 客户端的DNS，如果内网环境有自己的DNS服务可以替换为DNS服务，这样你连接到内网环境中直接可以使用内网DNS服务器
#push "block-outside-dns"
#push "dhcp-option DNS 223.5.5.5"
#push "dhcp-option DNS 114.114.114.114"
```

### 4. 生成密钥文件

```sh
$ docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 ovpn_initpki
	Enter PEM pass phrase: 123456										# 输入私钥密码
	Verifying - Enter PEM pass phrase: 123456							# 重新输入一次密码
	Common Name (eg: your user,host,or server name) [Easy-RSA CA]: 		# 输入一个CA名称。可以不用输入，直接回车
	Enter pass phrase for /etc/openvpn/pki/private/ca.key: 123456		# 输入刚才设置的私钥密码，完成后在输入一次
```

### 5. 生成客户端证书

```sh
# vpn-client 证书名称
# nopass 表示不使用密码，去掉表示使用密码
$ docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 easyrsa build-client-full vpn-client nopass
	Enter pass phrase for /etc/openvpn/pki/private/ca.key: 123456		# 输入刚才设置的密码
```

### 6. 导出客户端配置

```sh
$ docker run -v $(pwd):/etc/openvpn --rm zhentianxiang/openvpn:2.4.8 ovpn_getclient vpn-client > $(pwd)/conf/vpn-client.ovpn
```

### 7. 启动openvpn

```sh
$ docker run -dit --name openvpn -v /etc/localtime:/etc/localtime -v $(pwd):/etc/openvpn -p 1194:1194/tcp --cap-add=NET_ADMIN --restart=always zhentianxiang/openvpn:2.4.8
```
### 8. 用户管理

#### 1.1 添加用户

```sh
#!/bin/bash
read -p "please your username: " NAME
# 需要密码验证就把 nopass 去掉
docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 easyrsa build-client-full $NAME nopass
docker run -v $(pwd):/etc/openvpn --rm zhentianxiang/openvpn:2.4.8 ovpn_getclient $NAME > $(pwd)/conf/"$NAME".ovpn
docker restart openvpn
```

#### 1.2 删除用户

```sh
#!/bin/bash
read -p "Delete username: " DNAME
docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 easyrsa revoke $DNAME
docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 easyrsa gen-crl
docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 rm -f /etc/openvpn/pki/reqs/"DNAME".req
docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 rm -f /etc/openvpn/pki/private/"DNAME".key
docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 rm -f /etc/openvpn/pki/issued/"DNAME".crt
docker restart openvpn
```

**添加用户**

```sh
$ ./add_user.sh	#  输入要添加的用户名，回车后输入刚才创建的私钥密码
```

### 9. 客户端文件配置


```sh
# 编辑 ovpn 文件，添加下面两行，第一行是拒绝服务端下发的路由配置，第二行是设定服务器短的路由
# 比如服务器端内网地址192.168.1.0网段
route-nopull
route 192.168.1.0 255.255.255.0 vpn_gateway

# 最后一行删除 `redirect-gateway def1` 这个配置是截取当前主机所有路由，并且全部转发到 openvpn 网关上
```

### 10. 静态路由配置

```sh
# 宿主机添加静态路由，使其宿主机能够访问到 vpn 的网段（172.17.0.3）是openvpn容器IP
$ ip route add 192.168.255.0/24 via 172.17.0.3

# 局域网内其他机器添加静态路由访问 vpn 的网段（注意，这条指令是在其他的机器上配置的）
$ ip route add 192.168.255.0/24 via 192.168.1.16

# 宿主机添加 iptables 规则允许来自外部的流量通过防火墙，以确保它可以流经 Docker 网络
$iptables -A FORWARD -i eth0 -o docker0 -j ACCEPT
$iptables -A FORWARD -i docker0 -o eth0 -j ACCEPT
```

### 11. 监控脚本

用来监控容器是否退出，如果退出则重新启动容器
```sh
$ cat monitor_openvpn.sh 
#!/bin/bash

# 设置日志文件路径
LOG_FILE="/var/log/monitor_openvpn_container.log"

# 设置检查间隔（秒）
CHECK_INTERVAL=300

# 容器名称或ID的搜索模式
CONTAINER_NAME_PATTERN="openvpn"

# 函数：记录日志
function log_message {
    echo "$(date): $1" >> "$LOG_FILE"
}

# 无限循环检查容器状态
while true; do
    # 使用docker ps -qf来查找匹配的容器ID
    CONTAINER_ID=$(docker ps -qf "name=$CONTAINER_NAME_PATTERN")

    # 如果找不到容器ID，则容器不存在
    if [ -z "$CONTAINER_ID" ]; then
        log_message "$CONTAINER_NAME_PATTERN 容器不存在，正在重启..."

        # 重启容器
        docker restart "$CONTAINER_NAME_PATTERN" || {
            log_message "重启 $CONTAINER_NAME_PATTERN 容器失败"
            sleep $CHECK_INTERVAL
            continue
        }

        # 等待一小段时间以确保容器已经启动
        sleep 5

        # 验证容器是否成功启动
        CONTAINER_ID=$(docker ps -qf "name=$CONTAINER_NAME_PATTERN")
        if [ -n "$CONTAINER_ID" ]; then
            log_message "$CONTAINER_NAME_PATTERN 容器已启动"
        else
            log_message "$CONTAINER_NAME_PATTERN 容器启动失败"
        fi
    fi

    # 等待下一个检查间隔
    sleep $CHECK_INTERVAL
done 2>&1 >> "$LOG_FILE" # 将所有输出（包括标准输出和标准错误）重定向到日志文件

$ vim /etc/systemd/system/monitor_openvpn.service

[Unit]
Description=Monitor openvpn Docker container
After=docker.service

[Service]
Type=simple
Restart=always
User=root
ExecStart=/home/docker-app/openvpn/monitor_openvpn.sh
ExecStop=  

[Install]
WantedBy=default.target

$ systemctl daemon-reload
$ systemctl enable monitor_openvpn.service --now
$ systemctl status monitor_openvpn.service 
● monitor_openvpn.service - Monitor openvpn Docker container
     Loaded: loaded (/etc/systemd/system/monitor_openvpn.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2024-05-02 22:57:41 CST; 7s ago
   Main PID: 1373453 (monitor_openvpn)
      Tasks: 2 (limit: 9374)
     Memory: 1.1M
     CGroup: /system.slice/monitor_openvpn.service
             ├─1373453 /bin/bash /home/docker-app/openvpn/monitor_openvpn.sh
             └─1373484 sleep 10
```


## 三、客户端使用

### 1. Windows

1. 下载Windows OpenVPN客户端（64位）：https://openvpn.net/client-connect-vpn-for-windows/
2. 安装客户端并打开OpenVPN GUI
3. 将.ovpn文件拖放到OpenVPN GUI窗口中
4. 输入用户名和密码
5. 点击"连接",即可开始使用OpenVPN连接

### 2. MacOS

1. 下载MacOS OpenVPN客户端：https://openvpn.net/client-connect-vpn-for-mac-os/
2. 安装客户端并打开OpenVPN Connect
3. 将.ovpn文件拖放到OpenVPN Connect窗口中
4. 输入用户名和密码
5. 点击"连接",即可开始使用OpenVPN连接

### 3. iOS

1. 下载iOS OpenVPN客户端：https://apps.apple.com/us/app/openvpn-connect/id590379981
2. 安装客户端并打开OpenVPN Connect
3. 将.ovpn文件发送到您的iOS设备
4. 在iOS设备上选择“打开方式”为“OpenVPN Connect”
5. 输入用户名和密码
6. 点击"连接",即可开始使用OpenVPN连接

