---
layout: post
title:  Linux-安全02-iptables防火墙（二）
date: 2020-11-19
tags: Linux-安全
---

## 一、隐含匹配

常见的隐含匹配条件:

### 1.端口匹配:–sport 源端口、–dport 目的端口

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/1.png)

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/2.png)

### 2.TCP 标记匹配:–tcp-flags 检查范围 被设置的标记

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/3.png)

### 3.ICMP 类型匹配:–icmp-type ICMP 类型

> 常见的 icmp 类型
>
> 8 Echo request-回显请求(Ping 请求)
>
> 0 Echo Reply-回显应答(Ping 应答)
>
> 3 错误回显

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/4.png)

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/5.png)

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/6.png)

> 获取帮助:iptables -p icmp -h

## 二、显式匹配

常用的显示匹配条件:

### 1.多端口匹配:-m multiport –sports 源端口列表、-m multiport –dports 目的端口列表

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/7.png)

### 2.IP 范围匹配:-m iprange –src-range IP 范围

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/8.png)

### 3.MAC 地址匹配:-m mac –mac-source MAC 地址

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/9.png)

### 4.状态匹配:-m state –state 连接状态 常见的连接状态:

> NEW:新连接，与任何连接无关
>
> ESTABLISHED:响应请求或已建立连接的
>
> RELATED:与已连接有相关性的，如 FTP 数据连接

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/10.png)

**常见匹配条件汇总表**

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/11.png)

## 三、案例-基于 IP 和端口的防火墙控制

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/12.png)

> 实验环境:为网关、Web 服务器配置防火墙规则 需求描述:

### 1.为网站服务器编写入站规则

- (1)允许接受响应本机 ping 测试请求的各种 ICMP 数据包
- (2)允许访问本机中位于 80 端口的 Web 服务，禁止访问其他端口的 TCP 请求
- (3)允许发往本机以建立连接或与已有连接相关的各种 TCP 数据包
- (4)禁止其他任何形式的入站访问数据

**搭建实验环境，结果如下:**

**internet用桥接网络模拟：ip为dhcp**

**internet客户端网关需指向网关服务器的internet的ip地址**

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/13.png)

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/14.png)

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/15.png)

**允许接受响应本机 ping 测试请求的各种 ICMP 数据包**

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/16.png)

> 禁止其他任何形式的入站访问数据

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/17.png)

> 内网服务器 ping 网关测试:

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/18.png)

> 网关 ping 内网服务器测试:

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/19.png)

**允许访问本机中位于 80 端口的 Web 服务，禁止访问其他端口的 TCP 请求**

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/20.png)

**允许发往本机以建立连接或与已有连接相关的各种 TCP 数据包**

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/21.png)

### 3.保存 iptables 设置

```
[root@tianxaing ~]# service iptables save
```

如果命令报错，则执行以下命令后重试

```
[root@tianxaing ~]# yum -y install iptables-services

[root@tianxaing ~]# service iptables save
```

### 4.测试

> 需在网关服务器上开启路由转发，才能实现俩个网段互通

```
[root@tianxaing_gw ~]# vim /etc/sysctl.conf

net.ipv4.ip_forward = 1					//添加此行内容

[root@tianxaing_gw ~]# sysctl -p
```

> 内网web服务器安装httpd并启动

```
[root@tianxaing ~]# yum -y install httpd

[root@tianxaing ~]# vim /etc/httpd/conf/httpd.conf

 42 Listen 192.168.100.100:80
 
[root@tianxaing ~]# systemctl restart httpd

[root@tianxaing ~]# netstat -utpln
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 127.0.0.1:25            0.0.0.0:*               LISTEN      1052/master
tcp        0      0 192.168.100.100:80      0.0.0.0:*               LISTEN      3228/httpd
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      928/sshd
tcp6       0      0 ::1:25                  :::*                    LISTEN      1052/master
tcp6       0      0 :::22                   :::*                    LISTEN      928/sshd
udp        0      0 127.0.0.1:323           0.0.0.0:*                           666/chronyd
udp        0      0 0.0.0.0:68              0.0.0.0:*                           728/dhclient
udp6       0      0 ::1:323                 :::*                                666/chronyd
```

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/22.png)

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/23.png)

测试机安装测试工具

```
[root@internet ~]# yum -y install elinks

[root@internet ~]# elinks 192.168.100.100
```

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/24.png)

### 5.为网关服务器编写转发规则

- (1)允许局域网中的主机访问 Internet 中是 Web、FTP、DNS、邮件服务
- (2)禁止局域网中的主机访问 web.qq.com、w.qq.com、im.qq.com 等网站，以防止通过 WebQQ 的方式进行在线聊天

**允许局域网中的主机访问 Internet 中是 Web、FTP、DNS、邮件服务**

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/25.png)

**禁止局域网中的主机访问 web.qq.com、w.qq.com、im.qq.com 等网站**

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/26.png)

![img](/images/posts/Linux-安全/Linux-安全02-iptables防火墙/27.png)

### 6.保存 iptables 规则配置

```
[root@tianxaing_gw ~]# service iptables save
```

如果命令报错，则执行以下命令后重试

```
[root@tianxaing_gw ~]# yum -y install iptables-services

[root@tianxaing_gw ~]# service iptables save
```