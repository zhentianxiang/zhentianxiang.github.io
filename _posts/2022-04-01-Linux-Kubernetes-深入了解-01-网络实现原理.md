---
layout: post
title: Linux-Kubernetes-深入了解-01-网络实现原理
date: 2022-04-01
tags: Linux-Kubernetes-深入了解
---

K8s网络设计与实现是在学习k8s网络过程中总结的内容。在学习k8s网络各种插件之前我觉得有必要先搞清楚其设计思路是怎样的，在知道其规范的情况下肯定能跟深刻理解k8s网络的各种插件。就像拥有指南针的船，才不会跑偏。

## 一、k8s 网络设计

1.每个Pod都拥有一个独立IP地址，Pod内所有容器共享一个网络命名空间

2.集群内所有Pod都在一个直接连通的扁平网络中，可通过IP直接访问

1. 所有容器之间无需NAT就可以直接互相访问

2. 所有Node和所有容器之间无需NAT就可以直接互相访问

3. 容器自己看到的IP跟其他容器看到的一样

## 二、k8s 网络要求

K8s对网络的要求总的来讲主要有两个最基本的要求，分别是：

1. 要能够为每一个Node上的Pod分配互相不冲突的IP地址；

2. 要所有Pod之间能够互相访问；

## 三、k8s 网络规范

CNI是由CoreOS提出的一个容器网络规范。已采纳规范的包括Apache Mesos, Cloud Foundry, Kubernetes, Kurma 和 rkt。另外 Contiv Networking, Project Calico 和 Weave这些项目也为CNI提供插件。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-01-k8s网络实现原理/1.png)

> CNI 的规范比较小巧。它规定了一个容器runtime和网络插件之间的简单的契约。这个契约通过JSON的语法定义了CNI插件所需要提供的输入和输出。一个容器可以被加入到被不同插件所驱动的多个网络之中。一个网络有自己对应的插件和唯一的名称。CNI 插件需要提供两个命令：一个用来将网络接口加入到指定网络，另一个用来将其移除。这两个接口分别在容器被创建和销毁的时候被调用。
>
> 容器runtime首先需要分配一个网络命名空间以及一个容器ID。然后连同一些CNI配置参数传给网络驱动。接着网络驱动会将该容器连接到网络并将分配的IP地址以JSON的格式返回给容器runtime。

## 四、k8s 网络实现

### 1. 隧道方案

隧道方案在IaaS层的网络中应用也比较多，将pod分布在一个大二层的网络规模下。网络拓扑简单，但随着节点规模的增长复杂度会提升。

Weave：UDP广播，本机建立新的BR，通过PCAP互通

Open vSwitch（OVS）：基于VxLan和GRE协议，但是性能方面损失比较严重

Flannel：UDP广播，VxLan

Racher：IPsec

### 2. 路由方案

路由方案一般是从3层或者2层实现隔离和跨主机容器互通的，出了问题也很容易排查。

Calico：基于BGP协议的路由方案，支持很细致的ACL控制，对混合云亲和度比较高。

Macvlan：从逻辑和Kernel层来看隔离性和性能最优的方案，基于二层隔离，所以需要二层路由器支持，大多数云服务商不支持，所以混合云上比较难以实现。

## 五、k8s pod 网络创建流程

1. 每个Pod除了创建时指定的容器外，都有一个kubelet启动时指定的基础容器

2. kubelet创建基础容器，生成network namespace

3. kubelet调用网络CNI driver，由它根据配置调用具体的CNI 插件

4. CNI 插件给基础容器配置网络

5. Pod 中其他的容器共享使用基础容器的网络

转自：https://www.cnblogs.com/goldsunshine/p/10740090.html
