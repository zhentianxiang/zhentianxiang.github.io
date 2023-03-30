---
layout: post
title: Linux-网络服务08-Postfix_邮件系统服务_2
date: 2020-11-16
tags: Linux-网络服务
---

## 一、启用 SMTP 发信认证

### 1.SMTP 发信认证概述

> 在Postfix邮件系统中，可以使用Cyrus SASL(Cyrus Simple Authentication and Security Layer)简单认证安全层软件来实现基本的 SMTP 认证机制。Postfix 通过调用 Cyrus SASL 的函 数库，使用 Cyrus SASL 提供的认证服务 saslauthd 来核对系统账号和密码。

![](/images/posts/Linux-网络服务/Linux-网络服务08-Postfix_邮件系统服务_2/1.png)

### 2.配置 SMTP 发信认证

#### (1)设置 Cyrus SASL 函数库，并启动 saslauthd 服务

```
[root@mail named]# vim /usr/lib64/sasl2/smtpd.conf

pwcheck_method: saslauthd

[root@mail named]# yum -y install cyrus-sasl*

[root@mail named]# vim /etc/sysconfig/saslauthd

# Directory in which to place saslauthd's listening socket, pid file, and so
# on.  This directory must already exist.
SOCKETDIR=/run/saslauthd

# Mechanism to use when checking passwords.  Run "saslauthd -v" to get a list
# of which mechanism your installation was compiled with the ablity to use.
MECH=shadow					////将sasl验证方式改为系统用户密码验证

# Additional flags to pass to saslauthd on the command line.  See saslauthd(8)
# for the list of accepted flags.
FLAGS=

[root@mail named]# systemctl start saslauthd.service

[root@mail named]# systemctl enable saslauthd.service

Created symlink from /etc/systemd/system/multi-user.target.wants/saslauthd.service to /usr/lib/systemd/system/saslauthd.service.
```

#### (2)修改 main.cf 配置文件，添加 SMTP 认证配置，并重载服务

> 手动添加:

```
[root@mail named]# vim /etc/postfix/main.cf

680 smtpd_sasl_auth_enable = yes
681 smtpd_sasl_security_options = noanonymous
682 mynetworks = 127.0.0.0/8
683 smtpd_recipient_restrictions = permit_mynetworks,permit_sasl_authenticated,reject_unauth_destination
```

> smtpd_sasl_auth_enable = yes //开启 smtpd 的发信认证

> smtpd_sasl_security_options = noanonymous //不允许匿名用户的发信

> mynetworks = 127.0.0.0/8 //我的网段

> smtpd_recipient_restrictions = //发信限制

> permit_mynetworks, //允许我的网络

> permit_sasl_authenticated, //允许通过验证的

> reject_unauth_destination //拒绝未通过验证的

```
[root@mail named]# systemctl reload postfix
```

### 测试使用 SMTP 发信认证

> 客户端telnet测试

```
[root@mail named]# printf "lisi" |openssl base64			//生成加密的用户字符串
bGlzaQ==

[root@mail named]# printf "123123" |openssl base64			//生成加密的密码字符串
MTIzMTIz

telnet mail.linuxli.com 25

ehlo mail.linuxli.com

auth login

bGlzaQ==

MTIzMTIz

mail from:lisi@linuxli.com

rcpt to:lisir10@163.com

data

subject:smtp auth test!
hahahahaha
.

quit
```

![](/images/posts/Linux-网络服务/Linux-网络服务08-Postfix_邮件系统服务_2/2.png)

### Outlook 2010 测试使用 SMTP 发信认证(略)

> 设置步骤:

> 文件-账户设置-更改-其他设置-发送服务器-勾选我的发送服务 器，使用与接收邮件服务器相同的设置

## 二、构建 Web 邮件系统

> SquirrelMail 是使用 PHP 开发的一套网页程序，可以与 Postfix、Dovecot 很好地协作，通 过 Web 界面提供邮件发送、接受和管理操作。

![](/images/posts/Linux-网络服务/Linux-网络服务08-Postfix_邮件系统服务_2/3.jpg)

> 官网:www.squirrelmail.org

> 源码包:squirrelmail-1.4.22.tar.gz

> 中文语言包:zh_CN-1.4.22-20110425.tar.gz

### 1.搭建 php 环境

```
[root@mail ~]# yum -y install httpd php		//使用yum安装httpd和php软件包
```

### 2.部署 SquirrelMail 系统

```
[root@mail ~]# ls

squirrelmail-webmail-1.4.22.zip  zh_CN-1.4.18-20090526.tar.gz

[root@mail ~]# unzip squirrelmail-webmail-1.4.22.zip

[root@mail ~]# ls

Readme-╦╡├ў.htm  squirrelmail-webmail-1.4.22  squirrelmail-webmail-1.4.22.zip

[root@mail ~]# cp -rf squirrelmail-webmail-1.4.22/* /var/www/html/

[root@mail ~]# tar -xvf zh_CN-1.4.18-20090526.tar.gz -C /var/www/html/

[root@mail ~]# chown  -R apache:apache /var/www/html/

[root@mail ~]# cp /var/www/html/config/config_default.php /var/www/html/config/config.php

[root@mail ~]# vim /var/www/html/config/config.php

 118 $domain = 'linuxli.com';				//当前域
 
 211 $popServerAddress = 'localhost';     //新增，POP服务IP

 212 $popPort = 110;             			//新增，POP服务端口    
 
 231 $imap_server_type = 'dovecot';    //指定imap服务器类型

 257 $smtp_auth_mech = 'login';			//更改smtp认证方式
 
 499 $data_dir = '/var/www/html/data/';  //默认邮件数据存放位置

 1013 $squirrelmail_default_language = 'zh_CN';  //默认语言
 
 1028 $default_charset = 'zh_CN.UTF-8';	 //字符集类型

[root@mail ~]# systemctl start httpd
```

### 访问

> 浏览器 –> 192.168.60.29 –>输入用户名密码登录–>使用

![](/images/posts/Linux-网络服务/Linux-网络服务08-Postfix_邮件系统服务_2/4.png)

![](/images/posts/Linux-网络服务/Linux-网络服务08-Postfix_邮件系统服务_2/5.png)

> 给 xiahediyijun@163.com发送一封测试邮件

![](/images/posts/Linux-网络服务/Linux-网络服务08-Postfix_邮件系统服务_2/6.png)

> 以 lisi 账号登录查收邮件

![](/images/posts/Linux-网络服务/Linux-网络服务08-Postfix_邮件系统服务_2/7.png)

## 三、通过别名设置邮件组

### 编辑别名配置文件

```
[root@mail ~]# vim /etc/aliases

#
#  Aliases in this file will NOT be expanded in the header from
#  Mail, but WILL be visible over networks or from /bin/mail.
#
#       >>>>>>>>>>      The program "newaliases" must be run after
#       >> NOTE >>      this file is updated for any changes to
#       >>>>>>>>>>      show through to sendmail.
#

# Basic system aliases -- these MUST be present.
mailer-daemon:  postmaster
postmaster:     root
students:       zhangsan,lisi				//设置别名

[root@mail ~]# newaliases					//让别名生效

[root@mail ~]# systemctl reload postfix.service
```

### 测试群发邮件:

![](/images/posts/Linux-网络服务/Linux-网络服务08-Postfix_邮件系统服务_2/8.png)

![](/images/posts/Linux-网络服务/Linux-网络服务08-Postfix_邮件系统服务_2/9.png)

> 发现用户 lisi 与 zhangsan 都收到了邮件

## 四、邮件大小及邮箱空间限制

### 1.限制用户可发送的邮件大小

```
[root@mail ~]# vim /etc/postfix/main.cf

message_size_limit = 5120000

[root@mail ~]# systemctl restart postfix.service
```

### 用户测试:

![](/images/posts/Linux-网络服务/Linux-网络服务08-Postfix_邮件系统服务_2/10.png)

### 2.使用磁盘配额限制用户的邮箱空间大小(详细解释命令请参见磁盘配额部分)

> 略
