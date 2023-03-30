---
layout: post
title: Windows服务-win2012R2安装配置VPN服务
date: 2021-05-25
tags: Windows
---

前言就是，需要有一台境外地区的服务器，比如百度云香港地区的服务器。

### 1. 添加角色和功能

![](/images/posts/windows/win2012R2安装配置VPN服务/1.png)

### 2. 选择网络策略和访问服务以及远程访问

![](/images/posts/windows/win2012R2安装配置VPN服务/2.png)

默认下一步下一步......

### 3. 选择DirectAccess和路由

![](/images/posts/windows/win2012R2安装配置VPN服务/3.png)

下一步下一步...........

### 4. 完成服务的安装

![](/images/posts/windows/win2012R2安装配置VPN服务/4.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/5.png)

### 5. 打开“开始向导”进行配置

![](/images/posts/windows/win2012R2安装配置VPN服务/6.png)

### 6. 选择第三项

![](/images/posts/windows/win2012R2安装配置VPN服务/7.png)

### 7. 右键配置并启用路由和远程访问

![](/images/posts/windows/win2012R2安装配置VPN服务/8.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/9.png)

### 8. 自定义配置

![](/images/posts/windows/win2012R2安装配置VPN服务/10.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/11.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/12.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/13.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/14.png)

### 9. 配置IPv4网络模式，新增网络接口

![](/images/posts/windows/win2012R2安装配置VPN服务/15.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/16.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/17.png)

### 10. 配置一下客户端的可用地址池

![](/images/posts/windows/win2012R2安装配置VPN服务/18.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/19.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/20.png)

### 11. 创建一个用于登陆VPN的用户

![](/images/posts/windows/win2012R2安装配置VPN服务/21.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/22.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/23.png)

### 12. 配置用户的登陆权限

![](/images/posts/windows/win2012R2安装配置VPN服务/24.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/25.png)

### 13. 客户端本地配置VPN连接

![](/images/posts/windows/win2012R2安装配置VPN服务/26.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/27.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/28.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/29.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/30.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/31.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/32.png)

### 14. 服务器添加防火墙策略

建议关闭防火墙

![](/images/posts/windows/win2012R2安装配置VPN服务/33.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/34.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/35.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/36.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/37.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/38.png)

### 15. 客户端连接VPN

![](/images/posts/windows/win2012R2安装配置VPN服务/39.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/40.png)

此时不出意外的话应该是能访问的，但是个别情况下本地区的网络可能被运营上和谐掉了关于VPN的一些传输协议，所以对于pptp协议的VPN，可能会无法进行连通。

这时就需要把VPN协议修改为l2tp二层传输加密的，这样的协议一般是可以访问的。

建议关闭防火墙

### 16. 配置l2tp协议

![](/images/posts/windows/win2012R2安装配置VPN服务/41.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/42.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/43.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/44.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/45.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/46.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/47.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/48.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/49.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/50.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/51.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/52.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/53.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/54.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/55.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/56.png)

测试访问访问Google

![](/images/posts/windows/win2012R2安装配置VPN服务/57.png)

测试ping VPN服务器中的内网地址

![](/images/posts/windows/win2012R2安装配置VPN服务/58.png)

查看一下自己客户端地址，然后从VPN服务器端王客户端进行ping测试

![](/images/posts/windows/win2012R2安装配置VPN服务/59.png)

![](/images/posts/windows/win2012R2安装配置VPN服务/60.png)

至此！VPN搭建完成，并且可以为所欲为的翻墙了~

### 17. Linux系统连接pptp协议

如果你配置了l2tp协议的VPN，下面这个可能不管用
如下：

```sh
[root@host0-200 ~]# yum install pptp-setup ppp pptp
[root@host0-200 ~]# vim /etc/ppp/options
lock
refuse-pap
refuse-eap
refuse-chap
refuse-mschap
require-mppe
[root@host0-200 ~]# pptpsetup --create 连接名称(自定义) --server 服务器IP --username 用户名 --password 密码 -start
[root@host0-200 ~]# ifconfig
ens33: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 10.0.0.200  netmask 255.255.255.0  broadcast 10.0.0.255
        inet6 fe80::20c:29ff:fea8:8707  prefixlen 64  scopeid 0x20<link>
        ether 00:0c:29:a8:87:07  txqueuelen 1000  (Ethernet)
        RX packets 45090  bytes 64108576 (61.1 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 5658  bytes 912989 (891.5 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 72  bytes 6232 (6.0 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 72  bytes 6232 (6.0 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ppp0: flags=4305<UP,POINTOPOINT,RUNNING,NOARP,MULTICAST>  mtu 1396
        inet 192.168.0.14  netmask 255.255.255.255  destination 192.168.0.10
        ppp  txqueuelen 3  (Point-to-Point Protocol)
        RX packets 19  bytes 876 (876.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 10  bytes 174 (174.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

```
