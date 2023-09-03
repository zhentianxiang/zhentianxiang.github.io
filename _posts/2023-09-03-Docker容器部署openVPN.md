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

# 客户端连接时运行脚本
client-connect ovpns.script

# 客户端断开连接时运行脚本
client-disconnect ovpns.script

# 保持连接时间
keepalive 20 120

# 开启vpn压缩
comp-lzo

# 允许多人使用同一个证书连接VPN，不建议使用，注释状态
duplicate-cn

### vpn服务端向客户端推送vpn服务端内网网段的路由配置，以便让客户端能够找到服务端内网。多条路由就写多个Push指令
push "route 192.168.1.0 255.255.255.0"

### 路由规则，告诉 OpenVPN 服务器要将流量路由到目标网络 192.168.254.0/24
route 192.168.254.0 255.255.255.0

# vpn服务端为自己和客户端分配IP的地址池
server 192.168.255.0 255.255.255.0

### VPN 客户端的DNS，如果内网环境有自己的DNS服务可以替换为DNS服务，这样你连接到内网环境中直接可以使用内网DNS服务器
push "block-outside-dns"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "comp-lzo no"
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
# 建议使用第二条命令，使用 host 网络模式启动容器
$ docker run -dit --name openvpn -v /etc/localtime:/etc/localtime -v $(pwd):/etc/openvpn -p 1194:1194/tcp --cap-add=NET_ADMIN restart=always zhentianxiang/openvpn:2.4.8

$ docker run -dit --network=host --name openvpn -v /etc/localtime:/etc/localtime -v $(pwd):/etc/openvpn --cap-add=NET_ADMIN --restart=always zhentianxiang/openvpn:2.4.8
```

### 8. 添加 IP tables 规则

> **MASQUERADE:**
>
> - `MASQUERADE` 操作将数据包的源地址替换为 NAT 路由器的出口接口的 IP 地址。这意味着 NAT 路由器使用自己的 IP 地址（通常是公共 IP 地址）作为数据包的源地址。
> - `MASQUERADE` 操作特别适用于动态 IP 地址环境，因为它自动选择出口接口的 IP 地址，而无需手动配置。
> - 它通常用于家庭网络或移动网络，其中 NAT 路由器的公共 IP 地址可能经常变化。
>
> **SNAT:**
>
> 总结
>
> - `MASQUERADE` 自动选择出口接口的 IP 地址作为源地址，适用于动态 IP 地址环境。
> - `SNAT` 允许手动指定源 IP 地址，适用于静态 IP 地址环境。

```sh
# 两种方式根据自己需求选择使用

# 192.168.255.0/24 是VPN分配给的客户端地址段，em1 内网网卡
$ iptables -t nat -A POSTROUTING -s 192.168.255.0/24 -o em1 -j MASQUERADE

# 192.168.1.16 是vpn服务端内网地址
$ iptables -t nat -A POSTROUTING -s 192.168.255.0/24 -o em1 -j SNAT --to-source 192.168.1.16
```

### 9. 用户管理

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

