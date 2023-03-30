---
layout: post
title: kubernetes-报错分析-01-PLEG 故障问题
date: 2023-02-24
tags: kubernetes-报错分析
music-id: 5257205
---
## PLEG 故障问题

![](/images/posts/kubernetes-报错分析/1.png)

### 背景

研发工作人员反馈该节点上的 pod init 初始化有问题，说要停止调度并驱逐 pod 检查该节点，于是驱逐 pod 该节点上的 pod 后又遇到 pod 全部都 Terminating 状态

### 处理过程

首先手动把 Terminating 的 pods 全部给清除掉，然后又发现节点 NotReady ，查看该节点的 CNI 网络组件明面上是 Running 状态，然后试着 delete 重启一下  calico-node pod 服务，发现出现 pending 状态，于是乎 describe 该 node 节点发现出现了污点，正是因为该节点非正常 NotReady 才会被系统打上污点，然后  CNI 组件就无法被调度，为此查看 10.135.139.125 节点上的 kubelet 日志发现如上图所标注出来的问题

### 分析 PLEG

首先说明一下什么是 PLEG，PLEG指的是pod lifecycle event generator。是kubelet用来检查容器runtime的健康检查机制。

Kubelet中的NodeStatus机制会定期检查集群节点状况，并把节点状况同步到API Server。而NodeStatus判断节点就绪状况的一个主要依据，就是PLEG。PLEG定期检查节点上Pod运行情况，并且会把pod 的变化包装成Event发送给Kubelet的主同步机制syncLoop去处理。但是，在PLEG的Pod检查机制不能定期执行的时候，NodeStatus机制就会认为这个节点的状况是不对的，从而把这种状况同步到API Server，我们就会看到 not ready。

PLEG有两个关键的时间参数，一个是检查的执行间隔，另外一个是检查的超时时间。以默认情况为准，PLEG检查会间隔一秒，换句话说，每一次检查过程执行之后，PLEG会等待一秒钟，然后进行下一次检查；而每一次检查的超时时间是三分钟，如果一次PLEG检查操作不能在三分钟内完成，那么这个状况，会被NodeStatus机制当做集群节点NotReady的凭据，同步给API Server

### 解决

一般遇到 PLEG 的解决办法就是找到对应出问题的容器然后将其进程杀掉，但是对于本地的故障排查没有去查找有问题的容器，因为 Terminating 状态的 pod 太多了，所以因为该节点是 node 节点，并且没有业务服务在运行，因此直接 reboot 重启了

如果下次遇到这种问题，可以先把 Terminating 的pod 全部给删除掉，然后再观察出问题节点上的 kubelet 日志
