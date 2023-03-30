---
layout: post
title:  Web-服务08-Tomcat+Nginx_负载均衡
date: 2020-11-18
tags: Linux-站点服务
---

> Tomcat：一种Web软件，Nginx解析静态页面，而Tomcat解析动态页面，作为Servlet、JSP容器(Java、ASP)；一般用Tomcat作为Java容器
>
> 一般用于中小型业务，并需要动态解析情况

**中间件**

Tomcat：jdk（Java虚拟机）、war包(Java源代码导出的包)

![img](/images/posts/Web-服务/Web-服务08-Tomcat+Nginx_负载均衡/1.png)

## 一、部署Java环境

> 在安装Tomcat之前必须先安装JDK。JDK的全称是Java Development kit，是Sun公司免费提供的Java语言的软件开发工具包，其中包含java虚拟机（JVM）。编写好的java源程序经过编译可形成java字节码，jdk只需要解压之后就可以直接使用了，我虚进行安装，因为已经是安装好的了。
>
> 我们今天使用jdk的版本为jdk-7u65-linux-64.gz

### 1.将jdk-7u65-linux-64.gz解压

```
[root@tomcat1 ~]# tar zxf jdk-7u65-linux-x64.gz
```

### 2.将解压后生成的jdk1.7.0_65/文件夹 移动到 /usr/lcoal/目录下改名为java

```
[root@tomcat1 ~]# mkdir /usr/local/java

[root@tomcat1 ~]# mv jdk-7u65-linux-x64.gz/* /usr/local/java
```

### 3.修改profile环境变量以遍程序正常执行

```
[root@tomcat1 ~]# vim /etc/profile

export JAVA_HOME=/usr/local/java //这是java根目录

export PATH=$PATH:$JAVA_HOME/bin         //将java根目录下的bin目录添加为PATH环境变量的值
```

### 3.刷新profile环境变量并查看结果

```
[root@tomcat1 ~]# source /etc/profile

[root@tomcat1 ~]# echo "$PATH" /usr/lib64/qt-3.3/bin:/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin:/root/bin:/usr/local/java/bin
```

#### 运行java -version 或 javac -version查看java版本和之前安装的版本是否相同

```
[root@tomcat1 ~]# javac -version

javac 1.7.0_45
```

**到了这里java环境就部署好了。**

## 二、安装Tomcat

### 1.解压apache-tomcat-7.0.54.tar.gz软件包

```
[root@tomcat1 ~]# tar zxf apache-tomcat-7.0.54.tar.gz
```

### 2.解压后生成apache-tomcat-7.0.54目录，将该目录移动到/usr/local/下并改名为tomcat7

```
[root@tomcat1 ~]# mkdir /usr/local/tomcat7

[root@tomcat1 ~]# mv apache-tomcat-7.0.54/* /usr/local/tomcat7
```

### 3.启动tomcat

```
[root@tomcat1 ~]# /usr/local/tomcat7/bin/startup.sh

Using CATALINA_BASE:   /usr/local/tomcat7
Using CATALINA_HOME:   /usr/local/tomcat7

Using CATALINA_TMPDIR: /usr/local/tomcat7/temp

Using JRE_HOME:        /usr/local/java

Using CLASSPATH:       /usr/local/tomcat7/bin/bootstrap.jar:/usr/local/tomcat7/bin/tomcat-juli.jar

Tomcat started.
```

Tomcat默认监听8080端口，使用netstat命令查看端口监听状态验证是否启动成功

```
[root@tomcat1 ~]# netstat -anpt | grep 8080

tcp        0      0 :::8080                     :::*                        LISTEN      2284/java 
```

### 4.建立防火墙规则允许8080端口通过，或者关闭防火墙

```
[root@tomcat1 ~]# iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
```

**在客户端打开游览器进行测试输入[http://ip](http://ip/):8080的方式访问，如果看到图2的界面则表示tomcat安装成功**

![img](/images/posts/Web-服务/Web-服务08-Tomcat+Nginx_负载均衡/2.png)

### 5.Tomcat配置相关说明

```
[root@tomcat1 ~]# cd /usr/local/tomcat7/

[root@tomcat1 tomcat7]# ll

总用量 116

drwxr-xr-x. 2 root root  4096 11月  2 00:04 bin

drwxr-xr-x. 3 root root  4096 11月  2 00:06 conf

drwxr-xr-x. 2 root root  4096 11月  2 00:04 lib

-rw-r--r--. 1 root root 56812 5月  20 2014 LICENSE

drwxr-xr-x. 2 root root  4096 11月  2 00:06 logs

-rw-r--r--. 1 root root  1192 5月  20 2014 NOTICE

-rw-r--r--. 1 root root  8974 5月  20 2014 RELEASE-NOTES

-rw-r--r--. 1 root root 16204 5月  20 2014 RUNNING.txt

drwxr-xr-x. 2 root root  4096 11月  2 00:04 temp

drwxr-xr-x. 7 root root  4096 5月  20 2014 webapps

drwxr-xr-x. 3 root root  4096 11月  2 00:06 work
```

#### (1)主要目录说明

```
|-—bin/：存放windows或linux平台上启动和关闭tomcat的脚本文件

|-—conf/：存放Tomcat服务器的各种全局配置文件

|-—logs/：存放Tomcat执行时的LOG文件

|-—webapps/:Tomcat的主要web发布目录（包括应用程序示例）

|-—work/:存放jsp编译后产生的class文件
```

#### (2)配置文件说明

```
[root@tomcat1 tomcat7]# ll conf/

总用量 204

drwxr-xr-x. 3 root root   4096 11月  2 00:06 Catalina

-rw-------. 1 root root  12257 5月  20 2014 catalina.policy

-rw-------. 1 root root   6294 5月  20 2014 catalina.properties

-rw-------. 1 root root   1394 5月  20 2014 context.xml

-rw-------. 1 root root   3288 5月  20 2014 logging.properties

-rw-------. 1 root root   6536 5月  20 2014 server.xml

-rw-------. 1 root root   1530 5月  20 2014 tomcat-users.xml

-rw-------. 1 root root 163385 5月  20 2014 web.xml

server.xml就是tomcat的主配置文件

catalina.policy：权限控制配置文件

catalina.properties：tomcat属性配置文件

context.xml上下文配置文件

logging.properties：日志log相关配置文件

tomcat-users.xml:manager-gui管理用户配置文件

web.xml为tomcat的serlet、servlet-mapping、filter、MIME等相关配置
```

### 6.Tomcat主配置文件说明

```
server.xml为Tomcat的主要配置文件，通过配置文件、可以修改Tomcat的启动端口、网站目录、虚拟主机、开启https等重要工能

整个server.xml的结构如下

<Server>

<Service>

<Connector>……</Connector>（可以有多个）

<Engine>

<Host>……<Host>（可以有多个）

<Context>

</Context>

</Engine>

</Service>

</Server>

我们来看一下详细的配置信息

省略部分信息……

<Server port="8005" shutdown="SHUTDOWN">

//Tocat关闭端口，默认只对本机地址开放，可以通过127.0.0.1 8005对其进行关闭操作

省略部分信息……

<Connector port="8080" protocol="HTTP/1.1"

               connectionTimeout="20000"

               redirectPort="8443" />

//Tomcat启动的默认端口，可以根据需求进行修改

省略部分信息……

<Connector port="8009" protocol="AJP/1.3" redirectPort="8443" />

//Tomcat启动AJP 1.3连接器是的默认端口号，可以根据需求进行更改

省略部分信息……

以下为Tomcat定义虚拟主机时的配置及日志配置

<Host name="localhost"  appBase="webapps"

            unpackWARs="true" autoDeploy="true">

  <!-- SingleSignOn valve, share authentication between web applications

             Documentation at: /docs/config/valve.html -->

        <!--

        <Valve className="org.apache.catalina.authenticator.SingleSignOn" />

        -->

        <!-- Access log processes all example.

             Documentation at: /docs/config/valve.html

             Note: The pattern used is equivalent to using pattern="common" -->

        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"

               prefix="localhost_access_log." suffix=".txt"

               pattern="%h %l %u %t "%r" %s %b" />
```

```
注意：以<!--开头， -->结尾为注释
```

### 7.Tomcat Server的组成部分

```
(1)server
Server元素代表了整个Cataling的servlet的容器也就是说一个server就代表了一个Tomcat实例也就是一个Tomcat服务器

(2)service
Service是这样的一个集合：他由一个或多个Connector组成，以及一个Engine负责处理所有connector所获得的客户请求。

(3)Connector
一个Connector在一个指定端口上侦听客户端请求，并交给Engine来处理从Engine处获得会应并返回给客户。

Tomcat有两个典型的connector，一个侦听来自客户的请求一个侦听来自其他web服务器的请求

Coyote Http/1.1 Connector在8080端口侦听来自客户端的请求

Coyte Jk2 Connector 在8009端口侦听来自其他web服务器的代理请求

(4)Engine
Engine下可以配置多个Virtual Host，每个虚拟主机都有一个域名

当Engine获得一个请求时，他将该请求匹配到摸个host上去，然后把该请求交给Host来处理

Engine有一个默认的host主机，当匹配不到主机的时候就会交给默认的host主机（Engine就是一个引擎用来搜索匹配的主机）

(5)Host
代表一个virtual host 虚拟主机，每隔虚拟主机和某个网络域名Domain Nmae相匹配

每个虚拟主机下都可以部署（depoly）一个或多个web app ，每个web app 对应一个context，有一个Context path

(6)Context
一个Context对应一个web application，一个webapplication由一个或多个servlet组成
```

### 8.建立java的web站点

#### (1)首先在根目录下建立一个web目录，并在里面建立一个webapp1目录，用于存放网站文件。

```
[root@tomcat1 tomcat7]# mkdir -p /web/webaap1
```

#### (2)在webapp1上建立一个index.jsp的测试页面

```
[root@tomcat1 tomcat7]# vim /web/webaap1/index.jsp

<%@ page language="java" import="java.util.*" pageEncoding="UTF-8"%>

<html>

   <head>

      <title> JSP tomcat page</title>

   </head>

   <body>

        <% out.println("wecome to tomcat  site.http://www.tomcat1.com");%>

   </body>

</html>
```

#### (3)修改Tomcat的server.xml文件

定义一个虚拟主机，并将网站文件路径指向已经建立的/web/webapp1 在host段增加context段

```
[root@tomcat1 tomcat7]# vim /usr/local/tomcat7/conf/server.xml

<Host name="localhost"  appBase="webapps"

            unpackWARs="true" autoDeploy="true">

            <Context docBase="/web/webaap1" path="" reloadable="false">

            </Context>
```

修改之后的host段

//docBse:web文档的基本目录也就是根目录

//reloadable设置监视"类"是否变化

//path=""设置默认类（也就是指定虚拟目录）

#### (4)关闭并启动tomcat

```
[root@tomcat1 tomcat7]# bin/shutdown.sh

[root@tomcat1 tomcat7]# bin/startup.sh
```

#### (5)通过游览器进行测试是否能够访问当建立的测试页面

![img](/images/posts/Web-服务/Web-服务08-Tomcat+Nginx_负载均衡/3.png)

**看见这个测试页面证明我们的jsp已经没有任何问题了**

> 整个理论部分我们就讲完了，接下来部署图1 的实验环境。由于已经部署完成一个tonmcat了，部署第二个tomcat参考1、2、3、7步骤就可以了，这里我就不去部署了

------

## 三、部署nginx实现tomcat的负载均衡

### 1.安装相关软件并创建程序用户

```
[root@nginx ~]# yum -y install pcre-devel openssl openssl-devel gcc c++ make

[root@nginx ~]# useradd -M -s /sbin/nologin   nginx
```

### 2.解压并安装nginx

```
[root@nginx ~]# tar zxf nginx-1.6.2.tar.gz

[root@nginx ~]# cd nginx-1.6.2

[root@tomcat1 nginx-1.6.2]# ./configure  --prefix=/usr/local/nginx --with-http_stub_status_module --with-http_gzip_static_module --with-http_flv_module --with-http_ssl_module --user=nginx --group=nginx --with-file-aio  && make && make install
```

- --user --group  指定程序用户和组

- --with-http_stub_status_module  启用状态统计

- --with-http_ssl_module  启用ssl模块

- --with-http_gzip_static_module  启用静态压缩

- --with-http_flv_module    启用flv模块，提供内存使用基于时间的偏移量文件

- --withfile-aio   启用文件修改功能

### 3.配置nginx

```
[root@nginx nginx-1.6.2]# vim /usr/local/nginx/conf/nginx.conf

（1）在http{}中添加一下代码，设定负载均衡服务器列表，weight参数值表示权重，权重越大分配的请求越多。（建议在最后一个大括号前面添加）

upstream tomcat_server {

        server 192.168.1.2:8080 weight=1;

        server 192.168.1.3:8080 weight=1;

  }

upstream为字段名  tomcat_server为列表名（随便起，但是注意需要形象）

权重都为1表示分配的请求一样，

server定义的就是服务器地址注意端口号

（2）在http{…}-server{…}-location / {…}中加入一行"proxy_pass http://tomcat_server;"

location / {

            root   html;

            index  index.html index.htm;

            proxy_pass  http://tomcat_server;

如果这个server中存在其他location字段则不能启动服务，最好将它单独建立一个虚拟主机并绑定域名。

之后启动nginx服务  
[root@nginx nginx-1.6.2]# ln -s /usr/local/nginx/sbin/nginx /usr/local/sbin/nginx

[root@nginx nginx-1.6.2]# nginx      //启动（nginx -s stop 停止）
```

### 4.验证负载均衡 效果

这时访问[http://192.168.1.1就能转发到tomcat服务器的另外一个](http://192.168.1.xn--1tomcat-cu3kgm665ay9a95gbi143abokd1ms48beg8ccu0bplyd/)，为了验证试验效果将tonmcat_2的测试页稍微调整一下

![img](/images/posts/Web-服务/Web-服务08-Tomcat+Nginx_负载均衡/4.png)

![img](/images/posts/Web-服务/Web-服务08-Tomcat+Nginx_负载均衡/5.png)

## 
