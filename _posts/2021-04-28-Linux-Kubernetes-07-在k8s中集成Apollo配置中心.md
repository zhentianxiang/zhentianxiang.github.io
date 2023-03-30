---
layout: post
title: Linux-Kubernetes-07-在k8s中集成Apollo配置中心
date: 2021-04-28
tags: 实战-Kubernetes
---

# 在k8s中集成Apollo配置中心

## 配置中心概述

> - 配置其实是独立于程序的可配变量，同一份程序在不同配置下会有不同的行为，常见的配置有连接字符串，应用配置和业务配置等。
> - 配置有多种形态，下面是一些常见的：
>   - 程序内部hardcode，这种做法是反模式，一般我们不建议！
>   - 配置文件，比如spring应用程序的配置一般放在application.properties文件中
>   - 环境变量，配置可以预配置在操作系统的环境变量里面，程序运行时读取。
>   - 启动参数，可以在程序启动时一次性提供参数，例如Java程序启动时可以通过java -D 方式配置启动参数
>   - 基于数据库，有经验的开发人员会把易变配置放在数据库中，这样可以在运行期灵活调整配置。

-----

> - 配置管理的现状：
>   - 配置散乱格式不标准（xml、ini、conf、yaml.....）
>   - 主要采用本地静态配置，应用多副本本集下配置修改麻烦
>   - 易引发生产事故（测试环境、生产环境配置混用）
>   - 配置缺乏安全审计和版本控制功能（config review）
>   - 不同环境的应用，配置不同，造成多次打包，测试失效
> - 配置中心是什么？
>   - 顾名思义就是集中管理应用程序配置的”中心“。

## 常见的配置中心

> - XDiamond：全局配置中心，存储应用的配置项，解决配置混乱分散的问题。名字来源于淘宝的开源项目diamond，前面加上一个字母X进行区别
> - Qconf：Qconfig是一个分布式配置管理工具。用来替代传统的配置文件，使得配置信息和程序代码分离，同时配置变化能够实时同步到客户端，而且保证用户高校读取配置，这使得工程师从琐碎的配置修改、代码提交、配置上线流程中解放出来，极大地简化了配置管理工作。
> - Disconf：专注于各种【分布式系统配置管理】的【通用组件】和【通用平台】，提供统一的【配置管理服务】
> - Spring Cloud Config：为分布式系统中的外部配置提供服务器和客户端支持。
> - K8S configMap：K8S的一种标准资源，专门用来集中管理应用的配置。
> - Apollo：携程框架部门开源的，分布式配置中心。

# 交付Apollo至k8s集群

## Apollo简介

> 携程框架部门研发的分布式配置中心，能够集中化管理应用不同环境、不同集群的配置，配置修改后能够实现实时推送到应用端，并且具备规范的权限、流程治理等特性，适用于微服务配置管理场景。

- Config Service 提供配置的读取、推送等功能，服务对象是Apollo客户端
- Admin Service 提供配置的修改、发布等功能，服务对象是Apollo Portal （管理界面）
- Config Service和Admin service都是多实例，无状态部署，所以需要将自己注册到Eureka中保持心跳
- 在Eureka之上，我们架了一层Meta Server用于封装Eureka的服务发现接口
- Client通过域名访问Meta Server获取Config Service服务列表（IP+Port），同时在client侧会做loadbalance错误重试
- Portal通过域名访问Meta Serve获取Admin service服务列表（IP+Port），而后直接通过IP+Port访问服务，同时在Portal侧会做loadbalance错误重试

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/12.png)

[Apollo官方地址](https://github.com/ctripcorp/apollo)
