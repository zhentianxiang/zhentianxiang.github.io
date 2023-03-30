---
layout: post
title: Linux-Kubernetes-深入了解-02-内部网络实现
date: 2022-04-01
tags: Linux-Kubernetes-深入了解
---

## 一、pod 特性

Pod 是 K8S 的最小工作单元。每个 Pod 包含一个或多个容器。K8S 管理的也是 Pod 而不是直接管理容器。Pod 中的容器会作为一个整体被 Master 调度到一个 Node 上运行。
Pod 的设计理念是支持多个容器在一个 Pod 中共享网络地址和文件系统，可以通过进程间通信和文件共享这种简单高效的方式组合完成服务。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-02-内部网络实现/1.png)

一个 Pod 中可以包含多个容器，而一个 Pod 只有一个 IP 地址。那么多个容器之间互相访问和访问外网是如何使用这一个 IP 地址呢？
答案是：多个容器共享同一个底层的网络命名空间 Net（网络设备、网络栈、端口等）。

## 二、共享网络探究

下面以一个小例子说明，创建一个 Pod 包含两个容器，yaml 文件如下：

```yaml
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: Pod-two-container
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: busybox
        image: busybox
        command:
        - "/bin/sh"
        - "-c"
        - "while true;do echo hello;sleep 1;done"
      - name: nginx
        image: nginx
```
![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-02-内部网络实现/2.png)

创建 1 个 Pod 中包含 2 个 Container，实际会创建 3 个 Container。多出的一个是“Pause”容器。

该 Container 是 Pod 的基础容器，为其他容器提供网络功能。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-02-内部网络实现/3.png)

查看 Pause 容器的基础信息：

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-02-内部网络实现/4.png)

使用命令 docker inspect 容器 _ID 查看 Nginx 详细信息，其网络命令空间使用了 Pause 容器的命名空间，同样还有进程间通信的命名空间。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-02-内部网络实现/5.png)

再查看 Busybox，可以发现其网络命令空间使用了 Pause 容器的命名空间，进程通信的命名空间也是 Pause 容器的命名空间。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-02-内部网络实现/6.png)

实现方式：Nginx 和 Busybox 之所以能够和 Pause 的命名空间连通是因为 Docker 有一个特性：能够在创建时使用指定 Docker 的网络命名空间。

在 Docker 的官网上有一段描述：https://docs.docker.com/engine/reference/run/

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-02-内部网络实现/7.png)

## 三、手动实现 pod 网络


所以如果要手动完成一个上面的 Pod，可以先创建 Pause，再创建 Nginx 和 Busybox，同时将网络指定为 Pause 的网络命名空间即可。

```sh
docker run --name pause mirrorgooglecontainers/pause-amd64:3.1
docker run --name=nginx --network=container:pause nginx
docker run --name=busybox --network=container:pause busybox
```

上述步骤由 K8S 帮助我们完成，所以 Pod 命名空间应该是这样的：

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-02-内部网络实现/8.png)

转自：https://www.cnblogs.com/goldsunshine/p/15485226.html
