---
layout: post
title:  Web-服务07-Apache+Nginx_部署动静分离
date: 2020-11-18
tags: Linux-站点服务
---

# 实验环境

> 192.168.0.40 nginx服务器 nginx.linuxli.com
>
> 192.168.0.41 LAMP服务器 LAMP.linuxli.com
>
> 实验时注意观察是在哪台服务器上进行的配置！看清主机名！

## 一、搭建 LAMP，实现处理动态资源

```
[root@lamp ~]# yum -y install httpd httpd-devel mariadb mariadb-server mariadb-devel php php-devel php-mysql

[root@lamp ~]# vim /etc/httpd/conf/httpd.conf

95 ServerName www.linuxli.com:80

164 	DirectoryIndex index.php index.html

[root@lamp ~]# systemctl start httpd

[root@lamp ~]# systemctl start mariadb.service

[root@lamp ~]# mysql_secure_installation

NOTE: RUNNING ALL PARTS OF THIS SCRIPT IS RECOMMENDED FOR ALL MariaDB
      SERVERS IN PRODUCTION USE!  PLEASE READ EACH STEP CAREFULLY!

In order to log into MariaDB to secure it, we'll need the current
password for the root user.  If you've just installed MariaDB, and
you haven't set the root password yet, the password will be blank,
so you should just press enter here.

Enter current password for root (enter for none):
OK, successfully used password, moving on...

Setting the root password ensures that nobody can log into the MariaDB
root user without the proper authorisation.

Set root password? [Y/n] y
New password:
Re-enter new password:
Password updated successfully!
Reloading privilege tables..
 ... Success!


By default, a MariaDB installation has an anonymous user, allowing anyone
to log into MariaDB without having to have a user account created for
them.  This is intended only for testing, and to make the installation
go a bit smoother.  You should remove them before moving into a
production environment.

Remove anonymous users? [Y/n] y
 ... Success!

Normally, root should only be allowed to connect from 'localhost'.  This
ensures that someone cannot guess at the root password from the network.

Disallow root login remotely? [Y/n] y
 ... Success!

By default, MariaDB comes with a database named 'test' that anyone can
access.  This is also intended only for testing, and should be removed
before moving into a production environment.

Remove test database and access to it? [Y/n] y
 - Dropping test database...
 ... Success!
 - Removing privileges on test database...
 ... Success!

Reloading the privilege tables will ensure that all changes made so far
will take effect immediately.

Reload privilege tables now? [Y/n] y
 ... Success!

Cleaning up...

All done!  If you've completed all of the above steps, your MariaDB
installation should now be secure.

Thanks for using MariaDB!

[root@lamp ~]# mysql -uroot -p123123

Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 10
Server version: 5.5.60-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> exit
Bye

[root@lamp ~]# vim /var/www/html/test.php

<?php
$link=mysql_connect('localhost','root','123123');
if($link) echo "数据库连接成功！";
mysql_close();
?>
```

### 宿主机测试

![img](/images/posts/Web-服务/Web-服务07-Apache+Nginx_部署动静分离/1.png)

## 二、搭建 Nginx，实现静态资源

### 1.源码包编译安装 Nginx

```
[root@nginx ~]# yum -y install pcre-devel zlib-devel openssl-devel

[root@nginx ~]# useradd -M -s /sbin/nologin nginx

[root@nginx-server ~]# tar -xvf nginx-1.12.0.tar.gz -C /usr/src/

[root@nginx-server ~]# cd /usr/src/nginx-1.12.0/

[root@nginx nginx-1.12.0]# ./configure --prefix=/usr/local/nginx --user=nginx --group=nginx &&make &&make install

[root@nginx nginx-1.12.0]# ln -s /usr/local/nginx/sbin/nginx /usr/local/sbin/
```

### 2.修改 nginx.conf 主配置文件

```
[root@nginx ~]# vim /usr/local/nginx/conf/nginx.conf

 60         location ~ \.php$ {			//区分大小写匹配，以php结尾的网页去下面的服务器访问
 61             proxy_pass   http://192.168.0.41:80;
 62         }
 63         location ~ \.(gif|jpg|jpeg|bmp|png|swf){			//区分大小写匹配，以gif、jpg....swf结尾的文件，到下面路径去找
 64             root html;
 65         }

[root@nginx ~]# echo "<h1>www.linuxli.com<h1>" >/usr/local/nginx/html/index.html

[root@nginx ~]# nginx -t

nginx: the configuration file /usr/local/nginx/conf/nginx.conf syntax is ok
nginx: configuration file /usr/local/nginx/conf/nginx.conf test is successful

[root@nginx ~]# nginx
```

![img](/images/posts/Web-服务/Web-服务07-Apache+Nginx_部署动静分离/2.png)

![img](/images/posts/Web-服务/Web-服务07-Apache+Nginx_部署动静分离/3.png)

```
[root@nginx ~]# ls /usr/local/nginx/html/
123.jpeg  50x.html  index.html

[root@lamp ~]# vim /var/www/html/test.php

<img src="http://192.168.0.40/123.jpeg" />		//添加一行内容
```

![img](/images/posts/Web-服务/Web-服务07-Apache+Nginx_部署动静分离/4.png)

> 右键点击图片可以查看文件路径是“http://192.168.0.40/123.jpg”，由此，实现了动态 PHP 语言由 LAMP 服务器提供解析(192.168.0.41)，静态图片由 Nginx 服务器提供解析 (192.168.0.40)