---
layout: post
title: Linux-Docker基本原理讲解
date: 2020-11-21
tags: Linux-Docker
---

## 一、Docker原理介绍

### 1. 什么是Docker

>Docker是一个用于开发，交付和运行应用程序的开放平台。Docker使您能够将应用程序与基础架构分开，从而可以快速交付软件。
>
>是一个开源的应用容器引擎，让开发者可以打包大门的应用以及依赖包到一个可移植的镜像中，然后发布到任何流行的Linux或者Windows机器上，也可以实现虚拟化。容器是完全使用沙箱机制，相互之间不会有任何接口
>沙箱(Sandbox)：在计算机安全领域，沙箱是一种程序的隔离运行机制
>
>Docker在2013年一炮而红，直到现在，已经成为容器技术的代名词。
>
>Docker从一开始就以提供标准化的运行时环境为目标，真正做到“build once, run anywhere”，可以将同一个构建版本用于开发、测试、预发布、生产等任何环境，并且做到了与底层操作系统的解耦。在此
基础上还进一步发展出了CaaS（容器即服务）技术。

### 2. 使用场景

>打包应用程序简单部署 （就是制作镜像）
>
可脱离底层硬件任意迁移（实现了应用的隔离，将应用拆分并进行解耦），例如：服务器从腾讯云迁移到阿里云
>
持续集成和持续交付（CI/CD）：开发到测试发布
>
部署微服务
>
>提供PAAS产品（平台即服务）{OpenStack的云主机类似于阿里云的ECS，属于IAAS、Docker（K8S） 属于PAAS}


### 3. Docker引擎（Docker Engine）

>Docker Engine是具有以下主要组件的客户端-服务器应用程序：
>
>服务器是一种长期运行的程序，称为守护程序进程（ dockerd命令）。
>
>REST API，它指定程序可以用来与守护程序进行通信并指示其操作的接口。
>
>命令行界面（CLI）客户端（docker命令）

![](/images/posts/Docker/1.png)

### 4. Docker的架构（Docker architecture）

>Docker使用客户端-服务器架构。Docker 客户端与Docker 守护进程进行对话，该守护进程完成了构建，运行和分发Docker容器的繁重工作。
>
>Docker区别于传统的虚拟化，不需要虚拟硬件资源，直接使用容器引擎，所以速度快
>
>Docker Client：客户端
>
>Docker客户端（docker）是许多Docker用户与Docker交互的主要方式。当您使用诸如之类的命令时docker run，客户端会将这些命令发送到dockerd，以执行这些命令。该docker命令使用Docker API。Docker客户端可以与多个守护程序通信。
>
>Docker daemon：守护进程
>
>Docker守护程序（dockerd）侦听Docker API请求并管理Docker对象，例如图像，容器，网络和卷。守护程序还可以与其他守护程序通信以管理Docker服务。
>
>Docker images：镜像
>
>容器可以被打包成镜像
>
>Docker container：容器
>
>Docker registry：镜像仓库
>
>存储镜像的地方，默认在公共的Docker Hub上查找，可以搞个人仓库

![](/images/posts/Docker/2.png)

### 5. 容器与虚拟机的区别

![](/images/posts/Docker/3.png)

![](/images/posts/Docker/4.png)

### 6. 名称空间（Namespaces）

>Docker使用一种称为namespaces提供容器的隔离工作区的技术。运行容器时，Docker会为该容器创建一组 名称空间
>
>这些名称空间提供了一层隔离。容器的每个方面都在单独的名称空间中运行，并且其访问仅限于该名称空间
>
>Docker Engine在Linux上使用以下名称空间：
>
>**该pid命名空间：**进程隔离（PID：进程ID）
>
>**该net命名空间：**管理网络接口（NET：网络）
>
>**该ipc命名空间：**管理访问IPC资源（IPC：进程间通信）
>
>**该mnt命名空间：**管理文件系统挂载点（MNT：mount）
>
>**该uts命名空间：**隔离内核和版本标识符。（UTS：Unix时间共享系统）


### 7. 控制组（Control groups）

>Linux上的Docker引擎还依赖于另一种称为控制组 （cgroups）的技术。cgroup将应用程序限制为一组特定的资源。控制组允许Docker Engine将可用的硬件资源共享给容器，并有选择地实施限制和约束。例如，您可以限制特定容器可用的内存。


## 二、Docker基本问题

### 1. 容器和镜像

>镜像（Image）就是一个只读的模板。镜像可以用来创建 Docker 容器，一个镜像可以创建很多容器。
>
>容器是镜像启动的一个程序，它可以被启动、重启、停止、删除。每个容器都是相互隔离的，容器可以说是一个单独的Linux环境，但是不能拿虚拟机来论述，虚拟机毕竟是一个全新的系统环境，docker只是一个文件系统。

### 2.docker是怎么工作的

>实际上docker使用了常见的CS架构，也就是client-server模式，docker client负责处理用户输入的各种命令，比如docker build、docker run，真正工作的其实是server，也就是docker demon，值得注意的是，docker client和docker demon可以运行在同一台机器上。
>
>Docker是一个Client-Server结构的系统，Docker守护进程运行在主机上， 然后通过Socket连接从客户端访问，守护进程从客户端接受命令并管理运行在主机上的容器。守护进程和客户端可以运行在同一台机器上。

### 3. docker容器之间怎么隔离

>其实关于这个问题上面已经提到了，容器之间的隔离就是靠NameSpace来完成的
>
>虽然有了NameSpace技术可以实现资源隔离，但进程还是可以不受控的访问系统资源，比如CPU、内存、磁盘、网络等，为了控制容器中进程对资源的访问，Docker采用control groups技术(也就是cgroup)，有了cgroup就可以控制容器中进程对系统资源的消耗了，比如你可以限制某个容器使用内存的上限、可以在哪些CPU上运行等等

### 4. 联合文件系统（UnionFS）

docker的镜像实际上由一层一层的文件系统组成，这种层级的文件系统就是UnionFS。UnionFS是一种分层、轻量级并且高性能的文件系统。联合加载会把各层文件系统叠加起来，这样最终的文件系统会包含所有底层的文件和目录。

![](/images/posts/Docker/5.jpg)

### 5. Dockerfile

Dockerfile是用来构建Docker镜像的构建文件，是由一系列命令和参数构成的脚本。每条指令都会创建一个新的镜像层，并对镜像进行提交。

![](/images/posts/Docker/6.jpg)
