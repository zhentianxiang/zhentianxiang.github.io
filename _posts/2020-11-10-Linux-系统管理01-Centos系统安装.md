---
layout: post
title: Linux-系统管理01-Centos系统安装
date: 2020-11-10 
tags: Linux-系统管理
---

### 1.安装操作系统

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/1.png)

### 2.选择语言

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/2.png)

### 3.选择安装类型

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/3.png)

### 4.选择安装环境

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/4.png)

### 5.选择安装软件

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/5.png)

### 6.选择安装位置

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/6.png)

### 7.选择自动分区

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/7.png)

### 8.设置网络（未联网也行）

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/8.png)

### 9.点击打开按钮

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/9.png)

### 10.点击开始安装

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/10.png)

### 11.设置root密码（管理员密码，与windows的adminstart同意思）

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/11.png)

### 12.设置密码（强弱自愿）

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/12.png)

### 13.点击重启完成安装系统

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/13.png)

### 14.重启看到此界面完成安装系统

输如用户名：root
密码：

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/14.png)

### 15.优化基础系统环境

1、安装 vim编辑器、wget下载工具、bash-completion命令补齐工具、net-tools网络工具

```
$ yum install -y epel-release chrony bash-completion wget net-tools telnet tree nmap sysstat lrzsz dos2unix bind-utils vim less    //下载安装
```
2、关闭Selinux服务（控制文件、进程、服务的权限）

```
$ vim /etc/selinux/config      //打开selinux服务配置文件
```
进入配置文件默认情况下输如i字母按键，即可进入编辑模式，光标移动到指定字符位置修改

SELINUX=enforcing

修改为SELINUX=disabled

修改完之后按键盘左上角ESC按键，退出编辑模式，按住shift+:,就是按住晒夫特加冒号，输如x或者wq保存退出。

![](/images/posts/Linux-系统管理/Linux-系统管理01-Centos系统安装/15.png)

3、修改防火墙为开机自动关闭状态

```
$ systemctl disable firewalld.service    //开机自动关闭

$ reboot        //重启系统

$ systemctl status firewalld       //查看防火墙状态
```
