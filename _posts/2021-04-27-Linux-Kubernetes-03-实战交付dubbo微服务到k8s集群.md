---
layout: post
title: Linux-Kubernetes-03-实战交付dubbo微服务到k8s集群
date: 2021-04-27
tags: 实战-Kubernetes
---

# Dubbo是什么

- Dubbo是阿里巴巴SOA服务化治理方案的核心框架，每天为2000+个服务提供3000000000+次访问量的自持，并广泛用于阿里巴巴集团的各个成员站点

- Bubbo是一个分布式服务框架，致力于提供高性能和透明化的RPC远程服务调用方案，以及SOA服务治理方案
- 简单的说，dubbo就是个服务框架，如果没有分布式的需求，其实是不需要用的，只有在分布式的时候，才有dubbo这样的分布式服务框架需求，并且本质上是个服务调用的东东，说白了就是个远程服务调用的分布式框架

- 节点角色说明：
  - Provider: 暴露服务的服务提供方。
  - Consumer: 调用远程服务的服务消费方。
  - Registry: 服务注册与发现的注册中心。
  - Monitor: 统计服务的调用次调和调用时间的监控中心。
  - [Container](http://lib.csdn.net/base/docker): 服务运行容器。

# Dubbo能做什么

- 透明化的远程方法调用，就像调用本地方法一样调用远程方法，只需简单配置，没有任何api侵入
- 软负载均衡及容错机制，可在内网代替F6等硬件负载均衡器，降低成本减少单点
- 服务自动注册与发现，不再需要写死服务提供方地址，注册中心基于接口名查蓄奴服务提供者的IP地址，并且能够平滑添加或删除服务提供者



# Dubbo使用方法

Dubbo采用全Spring配置方式，透明化接入应用，对应用没有任何API侵入，只需用Spring加载Dubbo的配置即可，Dubbo基于Spring的Schema扩展进行加载。如果不想使用Spring配置，而希望通过API的方式进行调用（不推荐）

# 实验逻辑图
![](/images/posts/Linux-Kubernetes/交付dubbo/补充11.png)