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
[root@k8s-master openvpn]# docker pull zhentianxiang/openvpn:2.4.8
```

### 2. 创建挂载目录

```sh
[root@k8s-master openvpn]# mkdir -pv /etc/openvpn/conf
[root@k8s-master openvpn]# cd /etc/openvpn/
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
[root@k8s-master openvpn]# docker run -v $(pwd):/etc/openvpn --rm zhentianxiang/openvpn:2.4.8 ovpn_genconfig -u udp://1.1.1.1
```

- 配置文件

```sh
# 监听地址
local 0.0.0.0

# 协议
proto udp

# 端口
port 1194

# 虚拟网卡设备
dev tun0

# 证书与密钥
key /etc/openvpn/pki/private/47.120.62.2.key
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/47.120.62.2.crt
dh /etc/openvpn/pki/dh.pem
tls-auth /etc/openvpn/pki/ta.key
key-direction 0

# 连接保持
persist-tun
persist-key

# 表示禁用 OpenVPN 对缓冲区大小的显式设置
sndbuf 0 
rcvbuf 0

# 日志级别
verb 5
status /tmp/openvpn-status.log

# 运行用户权限
user nobody
group nogroup

# 客户端配置目录
client-config-dir /etc/openvpn/ccd

# 允许客户端之间互相访问
client-to-client

# 限制最大客户端数量
max-clients 10

# 保持连接时间
keepalive 20 120

# 禁止多客户端使用相同证书
; duplicate-cn

# vpn服务端为自己和客户端分配IP的地址池
server 10.100.255.0 255.255.255.0

# 子网路由
push "route 172.16.180.0 255.255.255.0"  # 办公室网络1
push "route 192.168.180.0 255.255.255.0" # 办公室网络2
push "route 192.168.200.0 255.255.255.0" # 办公室网络2
push "route 192.168.50.0 255.255.255.0"  # 办公室网络3

# DNS 配置
push "dhcp-option DNS 223.5.5.5"
push "dhcp-option DNS 114.114.114.114"
push "block-outside-dns"
```

### 4. 生成密钥文件

```sh
[root@k8s-master openvpn]# docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 ovpn_initpki

init-pki complete; you may now create a CA or requests.
Your newly created PKI dir is: /etc/openvpn/pki


Using SSL: openssl OpenSSL 1.1.1g  21 Apr 2020 (Library: OpenSSL 1.1.1d  10 Sep 2019)

Enter New CA Key Passphrase: 123456  # 跟证书密码
Re-Enter New CA Key Passphrase: 123456  # 跟证书密码
Generating RSA private key, 2048 bit long modulus (2 primes)
...............................................+++++
...................................+++++
e is 65537 (0x010001)
Can't load /etc/openvpn/pki/.rnd into RNG
140461893008712:error:2406F079:random number generator:RAND_load_file:Cannot open file:crypto/rand/randfile.c:98:Filename=/etc/openvpn/pki/.rnd
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Common Name (eg: your user, host, or server name) [Easy-RSA CA]: # 回车

CA creation complete and you may now import and sign cert requests.
Your new CA certificate file for publishing is at:
/etc/openvpn/pki/ca.crt


Using SSL: openssl OpenSSL 1.1.1g  21 Apr 2020 (Library: OpenSSL 1.1.1d  10 Sep 2019)
Generating DH parameters, 2048 bit long safe prime, generator 2
This is going to take a long time
......................................................+...................................................+.....................................................................................................................+......+.........................+................................................................................+.......+.....................................................................................................+......+..........................................................................+.......................................+.............................................................................................................+...............................+........................................................................................................................................................................................................................................+.................................+.........................+......................+..............................................................................+................................................................+.+........+..................................................................................................................................................................................................................................................................+...........................................+..................................................................................................................................................................................................................................................................................................................................................................................................................................................+........................................................................................................................+..................................................+.........................................................................................................................................................+...............................................................................................................................................................+.................................................+.............................................+...+........+........................................................................................+.....................................................+...............................................................................................................+...........................................................................................................................................................+......+.......................+....................................................................................................................+.............................................................+................................................................................................................................................................+......................................+....................+.........................................................................................+..........+.+.................................................+................................................................................................................+................................................................................+.+...................................................+......................................................+...................................................++*++*++*++*

DH parameters of size 2048 created at /etc/openvpn/pki/dh.pem


Using SSL: openssl OpenSSL 1.1.1g  21 Apr 2020 (Library: OpenSSL 1.1.1d  10 Sep 2019)
Generating a RSA private key
.......................................................................................................................+++++
.....................................+++++
writing new private key to '/etc/openvpn/pki/private/47.120.62.2.key.XXXXoEPaiN'
-----
Using configuration from /etc/openvpn/pki/safessl-easyrsa.cnf
Enter pass phrase for /etc/openvpn/pki/private/ca.key: 123456  # 跟证书密码
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'1.1.1.1'
Certificate is to be certified until Jan  1 05:45:05 2028 GMT (1080 days)

Write out database with 1 new entries
Data Base Updated

Using SSL: openssl OpenSSL 1.1.1g  21 Apr 2020 (Library: OpenSSL 1.1.1d  10 Sep 2019)
Using configuration from /etc/openvpn/pki/safessl-easyrsa.cnf
Enter pass phrase for /etc/openvpn/pki/private/ca.key: 123456  # 跟证书密码

An updated CRL has been created.
CRL file: /etc/openvpn/pki/crl.pem
```

### 5. 生成客户端证书

```sh
# vpn-client 证书名称
# nopass 表示不使用密码，去掉表示使用密码
[root@k8s-master openvpn]# docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 easyrsa build-client-full vpn-client nopass
	Enter pass phrase for /etc/openvpn/pki/private/ca.key: 123456		# 输入刚才设置的密码

# 以下表示客户端登陆时需要输入客户端证书的密码
[root@k8s-master openvpn]# docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 easyrsa build-client-full vpn-client

Using SSL: openssl OpenSSL 1.1.1g  21 Apr 2020 (Library: OpenSSL 1.1.1d  10 Sep 2019)
Generating a RSA private key
...............................................................+++++
...............+++++
writing new private key to '/etc/openvpn/pki/private/vpn-client.key.XXXXCphCkK'
Enter PEM pass phrase: 654321              # 输入客户端证书登陆密码
Verifying - Enter PEM pass phrase: 654321        # 输入客户端证书登陆密码
-----
Using configuration from /etc/openvpn/pki/safessl-easyrsa.cnf
Enter pass phrase for /etc/openvpn/pki/private/ca.key:      # 输入 ca 证书密码
Check that the request matches the signature
Signature ok
The Subject's Distinguished Name is as follows
commonName            :ASN.1 12:'vpn-client'
Certificate is to be certified until Jan  1 02:18:50 2028 GMT (1080 days)

Write out database with 1 new entries
Data Base Updated
```

### 6. 导出客户端配置

```sh
[root@k8s-master openvpn]# mkdir client
[root@k8s-master openvpn]# docker run -v $(pwd):/etc/openvpn --rm zhentianxiang/openvpn:2.4.8 ovpn_getclient vpn-client > $(pwd)/client/vpn-client.ovpn
[root@k8s-master openvpn]# ls -l client/
total 8
-rw-r--r-- 1 root root 5091 Jan 16 10:21 vpn-client.ovpn
```

### 7. 启动openvpn

```sh
[root@k8s-master openvpn]# docker run -dit --name openvpn -v /etc/localtime:/etc/localtime -v $(pwd):/etc/openvpn -p 1194:1194/tcp --cap-add=NET_ADMIN --restart=always zhentianxiang/openvpn:2.4.8
```

### 8. 用户管理

#### 1.1 添加用户

```sh
#!/bin/bash
mkdir -p client
read -p "please your username: " NAME
docker run -v $(pwd):/etc/openvpn --rm -it zhentianxiang/openvpn:2.4.8 easyrsa build-client-full $NAME
docker run -v $(pwd):/etc/openvpn --rm zhentianxiang/openvpn:2.4.8 ovpn_getclient $NAME > $(pwd)/client/"$NAME".ovpn
sed -i "s/redirect-gateway def1//g" client/"$NAME".ovpn
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
rm -rf client/"$NAME".ovpn
docker restart openvpn
```

**添加用户**

```sh
[root@k8s-master openvpn]# ./add_user.sh	#  输入要添加的用户名，回车后输入刚才创建的私钥密码
```

### 9. 客户端文件配置


```sh
[root@k8s-master openvpn]# vim client/vpn-client.ovpn
# 最后一行删除 `redirect-gateway def1` 这个配置是截取当前主机所有路由，并且全部转发到 openvpn 网关上

# 如果你的 openvpn 不是用的 1194 端口，接的修改你的客户端证书文件里面的端口
```

### 10. 静态路由配置

由于我们是在docker中启动的服务，难免会遇到一些网络问题，我就把我遇到的写到这里

```sh
# 1. 客户端连接登陆后无法 ping 通局域网地址，只能 ping 通 vpn 提供的 TUN0 网卡的地址，解决办法如下

# 开启 ipv4 net 转发
[root@k8s-master openvpn]# sysctl -w net.ipv4.ip_forward=1
# 允许所有目标（更通用的 MASQUERADE）,使其客户端能访问到openvpn服务端所在的内网中所有局域网地址,如果最限制可以使用 -d 指局域网地址
[root@k8s-master openvpn]# iptables -t nat -A POSTROUTING -s 10.100.255.0/24 -j MASQUERADE
# 增加一条静态路由 172.17.0.2 是 openvpn 容器地址
[root@k8s-master openvpn]# ip route add 10.100.255.0/24 via 172.17.0.2 dev docker0
```

```sh
# 2. 局域网内的机器想要访问 vpn 客户端地址配置如下

# 局域网内其他机器添加静态路由访问 vpn 的网段（注意，这条指令是在其他的机器上配置的）192.168.1.16 是宿主机本机IP
[root@k8s-master openvpn]# ip route add 192.168.255.0/24 via 192.168.1.16

# openvpn 宿主机添加 iptables 规则允许来自外部的流量通过防火墙，以确保它可以流经 Docker 网络
[root@k8s-master openvpn]# iptables -A FORWARD -i eth0 -o docker0 -j ACCEPT
[root@k8s-master openvpn]# iptables -A FORWARD -i docker0 -o eth0 -j ACCEPT
```

### 11. 监控脚本

用来监控容器是否退出，如果退出则重新启动容器

```python
$ cat alert.py 
import smtplib
import os
import argparse
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.header import Header

def send_alert_email(subject, body):
    """发送告警邮件"""
    # 从环境变量获取配置
    sender_email = os.getenv("SENDER_EMAIL", "xiahediyijun@163.com")
    sender_name = os.getenv("SENDER_NAME", "OpenVPN 监控告警")
    receiver_email = os.getenv("RECEIVER_EMAIL", "2099637909@qq.com")
    password = os.getenv("EMAIL_PASSWORD", "xxxxxxxxx")
    smtp_server = os.getenv("SMTP_SERVER", "smtp.163.com")
    smtp_port = int(os.getenv("SMTP_PORT", "465"))

    # 构建邮件内容
    msg = MIMEMultipart()
    msg['From'] = Header(f"{sender_name} <{sender_email}>", 'utf-8')
    msg['To'] = receiver_email
    msg['Subject'] = Header(subject, 'utf-8')
    msg.attach(MIMEText(body, 'plain', 'utf-8'))

    try:
        # 连接 SMTP 服务器并发送
        with smtplib.SMTP_SSL(smtp_server, smtp_port) as server:
            server.login(sender_email, password)
            server.sendmail(sender_email, [receiver_email], msg.as_string())
            print(f"[ALERT] 告警邮件发送成功: {subject}")
            return True
    except Exception as e:
        print(f"[ALERT] 告警邮件发送失败: {e}")
        return False

def parse_arguments():
    """解析命令行参数"""
    parser = argparse.ArgumentParser(description='发送告警邮件工具')
    parser.add_argument('--alert', nargs=2, metavar=('SUBJECT', 'BODY'), 
                       required=True, help='发送告警邮件的主题和内容')
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_arguments()
    send_alert_email(args.alert[0], args.alert[1])
```

邮件发送叫脚本需要 python3.0 以上支持

```sh
$ cat monitor_openvpn.sh 
#!/bin/bash

# 配置日志文件和检查间隔
LOG_FILE="/var/log/monitor_openvpn_container.log"
CHECK_INTERVAL=60
CONTAINER_NAME_PATTERN="openvpn"
PYTHON_SCRIPT="/data/docker-app/openvpn/monitor/alert.py"  # 替换为真实路径
ALERT_COUNT=0  # 告警触发次数

# 通过环境变量传递密码（更安全）
export EMAIL_PASSWORD="xxxxxxxxxxxx"

# 日志记录函数
function log_message {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
}

# 告警发送函数
function send_alert {
    local subject="$1"
    local body="$2"
    log_message "触发告警: $subject - $body"
    python3.9 "$PYTHON_SCRIPT" --alert "$subject" "$body" >> "$LOG_FILE" 2>&1
}

# 获取容器的最后 20 行日志
function get_container_logs {
    local container_name=$1
    docker logs --tail 20 "$container_name"
}

# 获取容器的详细信息
function get_container_info {
    local container_name=$1
    CONTAINER_IMAGE=$(docker inspect --format '{{.Config.Image}}' "$container_name")
    CONTAINER_NAME=$(docker inspect --format '{{.Name}}' "$container_name" | sed 's/\///')
}

# 主监控循环
while true; do
    # 获取容器的 ID
    CONTAINER_ID=$(docker ps -qf "name=$CONTAINER_NAME_PATTERN")

    if [ -z "$CONTAINER_ID" ]; then
        log_message "容器不存在，尝试重启..."

        # 尝试重启容器
        if ! docker restart "$CONTAINER_NAME_PATTERN"; then
            get_container_info "$CONTAINER_NAME_PATTERN"
            LOGS=$(get_container_logs "$CONTAINER_NAME_PATTERN")
            ALERT_COUNT=$((ALERT_COUNT + 1))
            send_alert "OpenVPN 容器重启失败" "
            时间: $(date '+%Y-%m-%d %H:%M:%S')
            触发次数: $ALERT_COUNT
            容器名称: $CONTAINER_NAME
            容器镜像: $CONTAINER_IMAGE
            容器日志: 
            $LOGS"
        else
            # 容器重启后等待 5 秒，检查容器是否成功启动
            sleep 5
            CONTAINER_ID=$(docker ps -qf "name=$CONTAINER_NAME_PATTERN")

            if [ -z "$CONTAINER_ID" ]; then
                get_container_info "$CONTAINER_NAME_PATTERN"
                LOGS=$(get_container_logs "$CONTAINER_NAME_PATTERN")
                ALERT_COUNT=$((ALERT_COUNT + 1))
                send_alert "OpenVPN 容器重启失败" "
                时间: $(date '+%Y-%m-%d %H:%M:%S')
                触发次数: $ALERT_COUNT
                容器名称: $CONTAINER_NAME
                容器镜像: $CONTAINER_IMAGE
                容器日志: 
                $LOGS"
            else
                get_container_info "$CONTAINER_NAME_PATTERN"
                LOGS=$(get_container_logs "$CONTAINER_NAME_PATTERN")
                ALERT_COUNT=$((ALERT_COUNT + 1))
                send_alert "OpenVPN 容器重启成功" "
                时间: $(date '+%Y-%m-%d %H:%M:%S')
                触发次数: $ALERT_COUNT
                容器名称: $CONTAINER_NAME
                容器镜像: $CONTAINER_IMAGE
                容器日志: 
                $LOGS"
            fi
        fi
    else
        # 获取容器状态信息
        CONTAINER_STATUS=$(docker inspect --format '{{.State.Status}}' "$CONTAINER_ID")

        if [ "$CONTAINER_STATUS" == "restarting" ]; then
            get_container_info "$CONTAINER_NAME_PATTERN"
            LOGS=$(get_container_logs "$CONTAINER_NAME_PATTERN")
            ALERT_COUNT=$((ALERT_COUNT + 1))
            send_alert "OpenVPN 容器重启" "
            时间: $(date '+%Y-%m-%d %H:%M:%S')
            触发次数: $ALERT_COUNT
            容器名称: $CONTAINER_NAME
            容器镜像: $CONTAINER_IMAGE
            容器日志: 
            $LOGS"
        fi
    fi

    sleep $CHECK_INTERVAL
done

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
手动触发测试

![](/images/posts/Linux-Kubernetes/2023-09-03-Docker容器部署openVPN/1.png)

![](/images/posts/Linux-Kubernetes/2023-09-03-Docker容器部署openVPN/2.png)

真实效果如下

![](/images/posts/Linux-Kubernetes/2023-09-03-Docker容器部署openVPN/3.png)

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
