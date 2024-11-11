---
layout: post
title:  Linux-安全01-iptables防火墙（一）
date: 2020-11-19
tags: Linux-安全
---

## 一、防火墙概述

### 1.概念与作用

> 网络中的防火墙，是一种将内部网络和外部网络分开的方法，是一种隔离技术。防火墙在内网与外网通信时进行访问控制，依据所设置的规则对数据包作出判断，最大限度地阻止 网络中的黑客破坏企业网络，从而加强企业网络安全。

### 2.防火墙的分类

> (1)硬件防火墙:如思科的 ASA 防火墙，H3C 的 Sepath 防火墙等。
>
> (2)软件防火墙:如 iptables 等
>
> 按架设的位置，可以分为主机防火墙、网关防火墙

### 3.iptables 防火墙

Linux 操作系统中默认内置一个软件防火墙，即 iptables 防火墙

> (1)netfilter 位于 Linux 内核中的包过滤功能体系，称为 Linux 防火墙的“内核态”
>
> (2)iptables 位于/sbin/iptables，用来管理防火墙规则的工具，称为 Linux 防火墙的“用户态”

### 4.包过滤的工作层次

> 主要是网络层，针对 IP 数据包，体现在对包内的 IP 地址、端口等信息的处理上。

## 二、iptables 规则链

### 1.规则链

**规则的作用:**

对数据包进行过滤或处理 链的作用:容纳各种防火墙规则 链的分类依据:处理数据包的不同时机

### 2.默认包括 5 种规则链

> INPUT:处理入站数据包
>
> OUTPUT:处理出站数据包
>
> FORWARD:处理转发数据包
>
> POSTROUTING:在进行路由选择后处理数据包
>
> PREROUTING:在进行路由选择前处理数据包

## 三、iptables 规则表

### 1.规则表

表的作用:容纳各种规则链 表的划分依据:防火墙规则的动作相似

### 2.默认包括 4 个规则表

> raw 表:确定是否对该数据包进行状态跟踪
>
> mangle 表:为数据包设置标记
>
> nat 表:修改数据包中的源、目标 IP 地址或端口
>
> filter 表:确定是否被放行该数据包(过滤)

### 3.链表结构关系图

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/1.png)

## 四、iptables 匹配流程

### 1.规则表之间的顺序:

> raw→mangle→nat→filter

### 2.规则链之间的顺序:

> 入站:PREROUTING→INPUT
>
> 出站:OUTPUT→POSTROUTING
>
> 转发:PREROUTING→FORWARD→POSTROUTING

### 3.规则链内的匹配顺序

- 按顺序依次检查，匹配即停止(LOG 策略例外)
- 若找不到相匹配规则，按该链的默认策略处理

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/2.png)

## 五、iptables 命令

### 1.语法构成

iptables [-t 表名] 选项 [链名] [条件] [-j 控制类型]

**注意事项:**

> 不指定表名时，默认指 filter 表
>
> 不指定链名时，默认指表内的所有链
>
> 除非设置链的默认策略，否则必须指定匹配条件
>
> 选项、链名、控制类型使用大写字母，其余均为小写

### 2.数据包的常见控制类型

> ACCEPT:允许通过
>
> DROP:直接丢弃，不给出任何回应
>
> REJECT:拒绝通过，必要时会给出提示
>
> LOG:记录日志信息，然后传给下一条规则继续匹配

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/3.png)

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/4.png)

- 由此可看出 DROP 与 REJECT 的区别，DROP 无回复，REJECT 拒绝，但有回复

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/5.png)

- 由此可见，LOG 会在/var/log/messages 内记录信息，然后交给下一条规则。

### 3.常用选项

> (1)增加新的规则
>
> -A:在链的末尾追加一条规则
>
> -I:在链的开头(或指定序号)插入一条规则

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/6.png)

> (2)查看规则列表
>
> -L:列出所有的规则条目
>
> -n:以数字形式显示地址、端口等信息
>
> -v:以更详细的方式显示规则信息
>
> –line-numbers:查看规则时，显示规则的序号。–line 与之同效

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/7.png)

> (3)删除、清空规则
>
> -D:删除链内指定序号(或内容)的一条规则
>
> -F:清空所有的规则

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/8.png)

> (4)修改、替换规则
>
> -R:修改替换规则

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/9.png)

> (4)设置默认规则
>
> -P:为指定的链设置默认规则

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/10.png)

- 需要注意的是，若要设置 filter 表中 INPUT 链或者 OUTPUT 链的默认规则为 DROP 时， 要先设置 tcp 协议 22 端口(ssh 远程连接)为 ACCEPT，否则通过远程操控的主机将断开连 接，若在真实生产环境中，需要到服务器所在机房重新设置才可以，造成不必要的麻烦。

## 六、规则的匹配类型

### 1.通用匹配

可直接使用，不依赖与其他条件或扩展 包括网络协议、IP 地址、网络接口等条件

### 2.隐含匹配

要求以特定的协议匹配作为前提 包含端口、TCP 标记、ICMP 类型等条件

### 3.显式匹配

要求以“-m 扩展模块”的形式明确指出类型 包括多端口、MAC 地址、IP 范围、数据包状态等条件

**常用管理选项汇总表**

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/11.png)

## 七、通用匹配

### 常见的通用匹配条件:

### 1.协议匹配: -p 协议名

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/12.png)

- 上图为，除了 icmp 协议，其他都丢弃

### 2.地址匹配: -s 源地址、-d 目的地址

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/13.png)

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/14.png)

### 3.接口匹配: -i 入站网卡、-o 出站网卡

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/15.png)

> 丢弃从 eth0 入站的三个知名私有网段的包，但要保证可以通过 ssh 远程连接

![img](/images/posts/Linux-安全/Linux-安全01-iptables防火墙/16.png)

## 八、系统安全优化

CentOS7默认的防火墙不是iptables,而是firewalld.

安装iptable iptable-service

### 1.先检查是否安装了iptables

```
systemctl status iptables
```

### 2.安装iptables

```
yum install -y iptables
```

### 3.升级iptables

```
yum update iptables
```

### 4.安装iptables-services

```
yum install iptables-services
```

### 5.禁止默认开启的firewalld

```
systemctl stop firewalld

systemctl mask firewalld
```

### 6.查看iptables现有规则

```
iptables -L -n
```

### 7.允许所有规则进入

```
iptables -P INPUT -j ACCEPT
```

### 8.清空所有默认规则

```
iptables -F
```

### 9.清空所有自定义规则

```
iptables -X
```

### 10.所有计数器归0

```
iptables -Z
```

### 11.允许来自于lo接口的数据包(本地访问)

```
iptables -A INPUT -i lo -j ACCEPT
```

### 12.开放22端口

```
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

### 13.开放21端口(FTP)

```
iptables -A INPUT -p tcp --dport 21 -j ACCEPT
```

### 14.开放80端口(HTTP)

```
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```

### 15.开放443端口(HTTPS)

```
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

### 16.允许ping，反之就是禁止ping

```
iptables -A INPUT -p icmp --icmp-type 8 -j ACCEPT  //运行

iptables -A INPUT -p icmp --icmp-type 8 -j DROP   //禁止
```

### 17.允许接受本机请求之后的返回数据 RELATED,是为FTP设置的

```
iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
```

### 18.其他入站一律丢弃

```
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
```

### 19.所有出站一律绿灯

```
iptables -I OUTPUT -o eth0 -d 0.0.0.0/0 -j ACCEPT
iptables -I INPUT -i eth0 -m state --state ESTABLISHED,RELATED -j ACCEPT
```

### 20.允许本地内部访问

```
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
```

### 21.如果要添加内网ip信任（接受其所有TCP请求,白名单）

```
iptables -A INPUT -p tcp -s 192.168.1.1 -j ACCEPT
```

### 22.要封停一个IP

```
iptables -I INPUT -s 192.168.100.1 -j DROP   //封停192.168.100.1
```

### 23.要解封一个IP

```
iptables -D INPUT -s 192.168.100.1 -j DROP  //其实-D，就是删除了这条规则
```

### 24.保存上述规则

```
iptables-save > /etc/sysconfig/iptables
```

### 25.启动iptables服务并设置为开机自启

```
systemctl start iptables

systemctl enable iptables
```
