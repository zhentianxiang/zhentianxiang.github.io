---
layout: post
title: Linux监控-02-zabbix（二）
date: 2020-12-10
tags: Linux-监控
---

## 一、配置邮件报警

### 1.在Zabbix前端配置邮件报警

点击管理 –> 报警媒介类型 –> 点击Email

![img](/images/posts/Linux-监控/zabbix2/1.png)

配置发件服务器以及发件人信息

![img](/images/posts/Linux-监控/zabbix2/2.png)

### 2.配置收件人信息

点击管理 –> 用户 –> 点击管理员用户

![img](/images/posts/Linux-监控/zabbix2/3.png)

点击报警媒介 –> 添加

![img](/images/posts/Linux-监控/zabbix2/4.png)

### 3.配置动作

点击配置 –> 动作 –> 启用默认动作

![img](/images/posts/Linux-监控/zabbix2/5.png)

只要状态发生变化就会报警

![img](/images/posts/Linux-监控/zabbix2/6.png)

## 二、监控可视化

### 1.聚合图形

可以将多个监控图形聚合在一起显示，方便查看

点击检测中 –> 聚合图形 –> 创建聚合图形

![img](/images/posts/Linux-监控/zabbix2/7.png)

![img](/images/posts/Linux-监控/zabbix2/8.png)

点击聚合同行的名称，进行更改，添加要显示的图形即可

![img](/images/posts/Linux-监控/zabbix2/9.png)

### 2.创建幻灯片

点击检测中 –> 聚合图形 –> 创建幻灯片

![img](/images/posts/Linux-监控/zabbix2/10.png)

![img](/images/posts/Linux-监控/zabbix2/11.png)

幻灯片根据设置的时间自动播放
