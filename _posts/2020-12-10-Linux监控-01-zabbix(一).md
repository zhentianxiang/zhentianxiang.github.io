---
layout: post
title: Linux监控-01-zabbix（一）
date: 2020-12-10
tags: Linux-监控
---

# Zabbix监控部署（一）

## 一、Zabbix概念与部署

### 1.Zabbix简介

Zabbix 是一个高度集成的网络监控解决方案，可以提供企业级的开源分布式监控解决 方案，由一个国外的团队持续维护更新，软件可以自由下载使用，运作团队靠提供收费的技 术支持赢利。

官方网站:http://www.zabbix.com

Zabbix 通过 C/S 模式采集数据，通过 B/S 模式在 web 端展示和配置。

- 被监控端:主机通过安装 agent 方式采集数据，网络设备通过 SNMP 方式采集数据
- Server端:通过收集SNMP和agent发送的数据，写入数据库(MySQL，ORACLE等)， 再通过 php+apache 在 web 前端展示。

Zabbix 运行条件:

- Server:Zabbix Server 需运行在 LAMP(Linux+Apache+Mysql+PHP)环境下(或者 LNMP)，对硬件要求低
- Agent:目前已有的 agent 基本支持市面常见的 OS，包含 Linux、HPUX、Solaris、Sun、 windows
- SNMP:支持各类常见的网络设备

监控过程逻辑如图示：

![img](/images/posts/Linux-监控/zabbix1/1.png)

![img](/images/posts/Linux-监控/zabbix1/2.png)

### 2.Zabbix功能

具备常见的商业监控软件所具备的功能(主机的性能监控、网络设备性能监控、数据库 性能监控、FTP 等通用协议监控、多种告警方式、详细的报表图表绘制)

支持自动发现网络设备和服务器(可以通过配置自动发现服务器规则来实现) 支持自动发现(low discovery)key 实现动态监控项的批量监控(需写脚本) 支持分布式，能集中展示、管理分布式的监控点

扩展性强，server 提供通用接口(api 功能)，可以自己开发完善各类监控(根据相关接 口编写程序实现)

编写插件容易，可以自定义监控项，报警级别的设置。

- 数据收集
- 可用和性能检测 支持 snmp(包括 trapping and polling)，IPMI，JMX，SSH，TELNET
- 自定义的检测 自定义收集数据的频率 服务器/代理和客户端模式
- 灵活的触发器 您可以定义非常灵活的问题阈值，称为触发器，从后端数据库的参考值
- 高可定制的报警 发送通知，可定制的报警升级，收件人，媒体类型 通知可以使用宏变量有用的变量 自动操作包括远程命令
- 实时的绘图功能 监控项实时的将数据绘制在图形上面 WEB 监控能力 ZABBIX 可以模拟鼠标点击了一个网站，并检查返回值和响应时间 Api 功能 应用 api 功能，可以方便的和其他系统结合，包括手机客户端的使用。

更多功能请查看 https://www.zabbix.com/documentation/2.0/manual/introduction/features

## 二、安装部署

> Server 可以运行在 CentOS、RedHat Linux、Debain 等 Linux 系统上，这里以 centos7.0_X64 作为部署环境。
>
> 俩台服务器：一台Server ， 一台Client ，Server俩块网卡，一块vmnet1，一块桥接，Client俩块网卡，一块为VMnet1 ，一块桥接

### 1.部署Zabbix_Server

```
[root@zabbix_server ~]# vim /etc/sysconfig/network-scripts/ifcfg-ens32

DEVICE=ens32
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=static
IPADDR=192.168.1.101
NETMASK=255.255.255.0


[root@zabbix_server ~]# cp /etc/sysconfig/network-scripts/ifcfg-ens32 /etc/sysconfig/network-scripts/ifcfg-ens33

DEVICE=ens33
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=dhcp

[root@zabbix_server ~]# systemctl restart network
```

### 配置yum源

```
[root@zabbix_server ~]# rm -rf /etc/yum.repos.d/*

[root@zabbix_server ~]# wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo

[root@zabbix_server ~]# vim /etc/yum.repos.d/zabbix.repo
[zabbix]
name=zabbix
baseurl=https://repo.zabbix.com/zabbix/4.4/rhel/7/x86_64/
gpgckeck=0
enabled=1
gpgkey=https://repo.zabbix.com/zabbix-official-repo.key

//安装zabbix源
```

### 安装zabbix_Server并配置

```
[root@zabbix_server ~]# yum -y install zabbix-server-mysql zabbix-web-mysql zabbix-agent mariadb-server

//安装zabbix_Server 以及Zabbix_Agent 以及所依赖的环境

[root@zabbix_server ~]# systemctl enable mariadb&&systemctl start mariadb

//启动mariadb

[root@zabbix_server ~]# mysql_secure_installation

//执行mysql初始化

[root@zabbix_server ~]# mysql -u root -p

create database zabbix character set utf8 collate utf8_bin;

grant all privileges on zabbix.* to zabbix@localhost identified by 'zabbix';

quit;

//登录数据库，创建zabbix所需要的数据库，以及权限设置

[root@zabbix_server ~]# zcat /usr/share/doc/zabbix-server-mysql-4.0.1/create.sql.gz |mysql -u zabbix -p zabbix

//导入数据库基础表结构

[root@zabbix_server ~]# vim /etc/zabbix/zabbix_server.conf

125 DBPassword=zabbix						//指定数据库登录密码

[root@zabbix_server ~]# vim /etc/httpd/conf.d/zabbix.conf

20         php_value date.timezone Asia/Shanghai		//设置正确的时区

[root@zabbix_server ~]# systemctl restart zabbix-server zabbix-agent httpd

[root@zabbix_server ~]# systemctl enable zabbix-server zabbix-agent httpd

[root@zabbix_server ~]# vim /var/www/html/index.html
<head>  
<meta http-equiv="refresh" content="0;url=/zabbix">
</head>
```

## 配置Zabbix前端

IE —> 192.168.1.10

### 第一步、在浏览器中打开http://192.168.1.10/zabbix，你应该看到前端向导的第一步屏幕

![img](/images/posts/Linux-监控/zabbix1/3.png)

### 第二步、确保满足所有必备软件

![img](/images/posts/Linux-监控/zabbix1/4.png)

### 第三步、输入连接数据库的详细信息，必须已创建zabbix数据库

![img](/images/posts/Linux-监控/zabbix1/5.png)

### 第四步、数据Zabbix服务器的详细信息

![img](/images/posts/Linux-监控/zabbix1/6.png)

### 第五步、查看设置摘要

![img](/images/posts/Linux-监控/zabbix1/7.png)

### 第六步、完成安装

![img](/images/posts/Linux-监控/zabbix1/8.png)

### 第七步、Zabbix前端准备好了，默认用户名为Admin，密码为zabbix

![img](/images/posts/Linux-监控/zabbix1/9.png)

### 第八步、设置Zabbix前端为中文

![img](/images/posts/Linux-监控/zabbix1/10.png)

![img](/images/posts/Linux-监控/zabbix1/11.png)

### Zabbix图形查看

### 查看图形

![img](/images/posts/Linux-监控/zabbix1/12.png)

### 2.解决图形中文字乱码情况

```
[root@zabbix_server ~]# yum -y install wqy-microhei-fonts

[root@zabbix_server ~]# cp /usr/share/fonts/wqy-microhei/wqy-microhei.ttc /usr/share/fonts/dejavu/DejaVuSans.ttf
```

![img](/images/posts/Linux-监控/zabbix1/13.png)

## 三、安装Zabbix_Client并配置（192.168.1.114）

### 1.网卡配置

```
[root@zabbix_client ~]# vim /etc/sysconfig/network-scripts/ifcfg-ens32

DEVICE=ens32
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=static
IPADDR=192.168.1.114
NETMASK=255.255.255.0

[root@zabbix_client ~]# cp /etc/sysconfig/network-scripts/ifcfg-ens32 /etc/sysconfig/network-scripts/ifcfg-ens33

DEVICE=ens33
TYPE=Ethernet
ONBOOT=yes
NM_CONTROLLED=no
BOOTPROTO=dhcp

[root@zabbix_client ~]# systemctl restart network
```

### 2.配置yum源

```
[root@zabbix_client ~]# rm -rf /etc/yum.repos.d/*

[root@zabbix_client ~]# wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo

//下载阿里云的yum源

[root@zabbix_client ~]# rpm -i https://repo.zabbix.com/zabbix/4.0/rhel/7/x86_64/zabbix-release-4.0-1.el7.noarch.rpm

//安装zabbix源
```

### 3.安装Zabbix客户端

```
[root@zabbix_client ~]# yum -y install zabbix-agent

[root@zabbix_client ~]# vim /etc/zabbix/zabbix_agentd.conf

98 Server=192.168.1.101				//指定服务器ip

[root@zabbix_client ~]# systemctl start zabbix-agent.service

[root@zabbix_client ~]# systemctl enable zabbix-agent.service
```

## Zabbix前端上添加客户端

### 1.依次点击–>配置–>主机–>创建主机

![img](/images/posts/Linux-监控/zabbix1/14.png)

主机名称： 要与主机名相同，这是zabbix server程序用的

可见名称： 显示在zabbix网页上的，给我们看的

![img](/images/posts/Linux-监控/zabbix1/15.png)

![img](/images/posts/Linux-监控/zabbix1/16.png)

### 2.然后给新添加的主机添加监控模板

![img](/images/posts/Linux-监控/zabbix1/17.png)

![img](/images/posts/Linux-监控/zabbix1/18.png)

### 3.查看新添加主机的图形

点击检测中–> 图形 –> 选择需要查看主机以及具体图形进行查看

![img](/images/posts/Linux-监控/zabbix1/19.png)

### 自定义监控与监控报警

> 说明：zabbix自带模板Template OS Linux (Template App Zabbix Agent)提供CPU、内存、磁盘、网卡等常规监控，只要新加主机关联此模板，就可自动添加这些监控项。

## 实验需求：服务器登陆人数不能超过三人，超过三人报警

预备知识

```
正确的key

[root@zabbix_server ~]# zabbix_get -s 172.16.1.21 -p 10050 -k "system.uname"

Linux cache01 3.10.0-693.el7.x86_64 #1 SMP Tue Aug 22 21:09:27 UTC 2017 x86_64

没有登记的，自定义的key

[root@zabbix_server ~]# zabbix_get -s 172.16.1.21 -p 10050 -k "login-user"

ZBX_NOTSUPPORTED: Unsupported item key.

写错的key

[root@zabbix_server ~]# zabbix_get -s 172.16.1.21 -p 10050 -k "system.uname1"

ZBX_NOTSUPPORTED: Unsupported item key.
```

## 实现自定义监控

### 1.自定义语法

```
UserParameter=<key>,<shell command>

//语法格式

UserParameter=login-user,who|wc -l

//使用命令定义

UserParameter=login-user,/bin/sh /server/scripts/login.sh

//使用shell脚本定义
```

### 2.在agent端注册

```
[root@zabbix_client ~]# cd /etc/zabbix/zabbix_agentd.d/

[root@zabbix_client ~]# vim userparameter_mysql.conf

19 UserParameter=login-user,who|wc -l

注意：key名字要唯一，多个key以行为分割
```

### 3.修改完成后重启服务

```
[root@zabbix_client ~]# systemctl restart zabbix-agent.service
```

### 4.在server端进行get测试

```
[root@zabbix_server ~]# yum -y install zabbix-get

[root@zabbix_server ~]# zabbix_get -s 192.168.1.114 -p 10050 -k "login-user"
```

### 5.在Server端注册（WEB操作）

**创建模板**

配置 –> 模板 –> 创建模板

![img](/images/posts/Linux-监控/zabbix1/20.png)

点击添加即可创建出模板

![img](/images/posts/Linux-监控/zabbix1/21.png)

![img](/images/posts/Linux-监控/zabbix1/22.png)

**创建应用集**

应用集类似(目录/文件夹)，其作用是给监控项分类。

点击刚刚创建的模板 –> 应用集 –> 创建应用集

![img](/images/posts/Linux-监控/zabbix1/23.png)

自定义应用集的名字，然后点添加

![img](/images/posts/Linux-监控/zabbix1/24.png)

**创建监控项**

点击监控项 –> 创建监控项

![img](/images/posts/Linux-监控/zabbix1/25.png)

键值 – key,即前面出创建的login-user，数据更新间隔在工作中一般为300s，这里测试所以30s

注意：创建监控项的时候，注意选择上应用集，即之前创建的安全。

**创建触发器**

触发器的作用：当监控项获取到的值达到一定条件时就触发报警

点击触发器 –> 创建触发器

创建触发器，自定义名称，该名称是报警时显示的名称。

表达式，点击右边的添加，选择表达式。

严重性自定义。

![img](/images/posts/Linux-监控/zabbix1/26.png)

![img](/images/posts/Linux-监控/zabbix1/27.png)

表达式的定义，选择之前创建的监控项，

最新的T值为当前获取到的值。

![img](/images/posts/Linux-监控/zabbix1/28.png)

添加完成，能够在触发器中看到添加的情况

![img](/images/posts/Linux-监控/zabbix1/29.png)

**创建图形**

以图形的方式展示出来监控信息

点击图形 –> 创建图形

名称自定义、关联上监控项

![img](/images/posts/Linux-监控/zabbix1/30.png)

![img](/images/posts/Linux-监控/zabbix1/31.png)

**主机管理模板**

点击配置 –> 主机

一个主机可以关联多个模板

建议：

zabbix服务端自监控使用的模板：（Template App Zabbix Server, Template OS Linux(Template App Zabbix Agent), ……自定义等）

zabbix客户端： Template OS Linux(Template App Zabbix Agent), 登录用户

![img](/images/posts/Linux-监控/zabbix1/32.png)

### 6.查看监控的图形

检测中 –> 图形

![img](/images/posts/Linux-监控/zabbix1/33.png)
