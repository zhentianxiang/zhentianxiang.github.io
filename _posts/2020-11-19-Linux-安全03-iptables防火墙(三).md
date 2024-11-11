---
layout: post
title:  Linux-安全03-iptables防火墙（三）
date: 2020-11-19
tags: Linux-安全
---

## 一、SNAT 策略

### 1.作用:

> 局域网主机共享单个公网 IP 地址接入 Internet

### 2.SNAT 策略的原理

> 源地址转换，Source Network Address Translation
>
> 修改数据包的源地址
>
> 说白了就是，我客户机访问公网中web的服务器要经过网关服务做转发，客户机先访问到网关服务器，通过网关服务器把数据转发到公网web服务器中

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/1.png)

### 3.企业共享上网案例

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/2.png)

### 3.前提条件:

> 局域网各主机正确设置 IP 地址/子网掩码
>
> 局域网各主机正确设置默认网关地址
>
> Linux 网关支持 IP 路由转发

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/3.png)

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/4.png)

#### (1)网关开启路由转发

```
[root@tianxiang_gw ~]# vim /etc/sysctl.conf

net.ipv4.ip_forward = 1					//添加此行内容

[root@tianxiang_gw ~]# sysctl -p
```

#### (2)固定的外网 IP 地址

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/5.png)

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/6.png)

### (3)非固定外网 IP 地址或 ADSL

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/7.png)

## 二、DNAT 策略

### 1.DNAT 原理

> 在 Internet 环境中，通过网关服务器中正确设置 DNAT 策略可实现企业所注册的网站或 域名必须对应公网 IP 地址。
>
> 说白了就是，内网服务器IP在公网路由器上做了路由转发，把内网IP转发到公网上，客户端访问公网即可访问到对应的内网。

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/8.png)

### 2.前提条件

> 局域网的 Web 服务器能够访问 Internet
>
> 网关的外网 IP 地址有正确的 DNS 解析记录
>
> Linux 网关支持 IP 路由转发

#### (1)DNAT 转发规则 1:发内网 Web 服务

公网是192.168.0.54，内网是192.168.100.100

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/9.png)

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/10.png)

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/11.png)

#### (2)DNAT 转换规则 2:发布时修改目标端口

修改完转发端口之后，httpd配置文件也要修改监听端口

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/12.png)

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/13.png)

## 三、iptables 防火墙规则的备份与还原

> 设置完防火墙规则后，可备份规则到文件中，以便日后进行还原，或以备份规则为依据 编写防火墙脚本

### 1.导出(备份)规则

> iptables-save 工具

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/14.png)

### 2.导入(还原)规则

> iptables-restore 工具

![img](/images/posts/Linux-安全/Linux-安全03-iptables防火墙/15.png)

> 重定向出的文件也可以是任意自定义的文件，若将规则保存到/etc/sysconfig/iptables 中， iptables 启动时自动还原规则。