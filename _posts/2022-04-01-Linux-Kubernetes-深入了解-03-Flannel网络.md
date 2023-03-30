---
layout: post
title: Linux-Kubernetes-深入了解-03-Flannel网络
date: 2022-04-01
tags: Linux-Kubernetes-深入了解
---

## 一、 简介

Flannel是CoreOS团队针对Kubernetes设计的一个网络规划服务，简单来说，它的功能是让集群中的不同节点主机创建的Docker容器都具有全集群唯一的虚拟IP地址。

在默认的Docker配置中，每个节点上的Docker服务会分别负责所在节点容器的IP分配。这样导致的一个问题是，不同节点上容器可能获得相同的内外IP地址。并使这些容器之间能够之间通过IP地址相互找到，也就是相互ping通。

Flannel的设计目的就是为集群中的所有节点重新规划IP地址的使用规则，从而使得不同节点上的容器能够获得“同属一个内网”且”不重复的”IP地址，并让属于不同节点上的容器能够直接通过内网IP通信。

Flannel实质上是一种“覆盖网络(overlaynetwork)”，也就是将TCP数据包装在另一种网络包里面进行路由转发和通信，目前已经支持udp、vxlan、host-gw、aws-vpc、gce和alloc路由等数据转发方式，默认的节点间数据通信方式是UDP转发。

### 1. 简单总结 flannel 的特点

1. 使集群中的不同Node主机创建的Docker容器都具有全集群唯一的虚拟IP地址。

2. 建立一个覆盖网络（overlay network），通过这个覆盖网络，将数据包原封不动的传递到目标容器。覆盖网络是建立在另一个网络之上并由其基础设施支持的虚拟网络。覆盖网络通过将一个分组封装在另一个分组内来将网络服务与底层基础设施分离。在将封装的数据包转发到端点后，将其解封装。

3. 创建一个新的虚拟网卡flannel0接收docker网桥的数据，通过维护路由表，对接收到的数据进行封包和转发（vxlan）。

4. etcd保证了所有node上flanned所看到的配置是一致的。同时每个node上的flanned监听etcd上的数据变化，实时感知集群中node的变化。

## 二、flannel 对网络要求提出来的解决办法

### 1. 互相不冲突的 ip

1. flannel利用Kubernetes API或者etcd用于存储整个集群的网络配置，根据配置记录集群使用的网段。

2. flannel在每个主机中运行flanneld作为agent，它会为所在主机从集群的网络地址空间中，获取一个小的网段subnet，本主机内所有容器的IP地址都将从中分配。

如测试环境中ip分配：

- master 节点

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/1.png)

- node1

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/2.png)

- node2

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/3.png)

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/4.png)

在flannel network中，每个pod都会被分配唯一的ip地址，且每个K8s node的subnet各不重叠，没有交集

### 2. pod 之间互相访问

1. flanneld将本主机获取的subnet以及用于主机间通信的Public IP通过etcd存储起来，需要时发送给相应模块。

2. flannel利用各种backend mechanism，例如udp，vxlan等等，跨主机转发容器间的网络流量，完成容器间的跨主机通信。

## 三、Flannel 架构原理

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/5.png)

各个组件的解释：

### 1. Cni0 网桥设备

每创建一个pod都会创建一对 veth pair。其中一端是pod中的eth0，另一端是Cni0网桥中的端口（网卡）。Pod中从网卡eth0发出的流量都会发送到Cni0网桥设备的端口（网卡）上。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/6.png)

Cni0 设备获得的ip地址是该节点分配到的网段的第一个地址。

### 2. Flannel.1 overlay网络的设备

用来进行 vxlan 报文的处理（封包和解包）。不同node之间的pod数据流量都从overlay设备以隧道的形式发送到对端。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/7.png)

### 3. Flanneld agent端

flannel在每个主机中运行flanneld作为agent，它会为所在主机从集群的网络地址空间中，获取一个小的网段subnet，本主机内所有容器的IP地址都将从中分配。同时Flanneld监听K8s集群数据库，为flannel.1设备提供封装数据时必要的mac，ip等网络数据信息。

## 四、Node 之间 pod 通信流程

1. pod中产生数据，根据pod的路由信息，将数据发送到Cni0

2. Cni0 根据节点的路由表，将数据发送到隧道设备flannel.1

3. Flannel.1查看数据包的目的ip，从flanneld获得对端隧道设备的必要信息，封装数据包。

4. Flannel.1将数据包发送到对端设备。对端节点的网卡接收到数据包，发现数据包为overlay数据包，解开外层封装，并发送内层封装到flannel.1设备。

5. Flannel.1设备查看数据包，根据路由表匹配，将数据发送给Cni0设备。

6. Cni0匹配路由表，发送数据给网桥上对应的端口。

### 1. pod1 中的容器到cni0

Pod1与Pod3能够互相ping通

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/8.png)

Ping包的dst ip 为192.20.1.43，根据路由匹配到最后一条路由表项，去往192.20.0.0/12的包都转发给192.20.0.1

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/9.png)

192.20.0.1为cni0的ip地址

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/10.png)

### 2. 从 cni0 网卡到 flannel1.1

当icmp包达到cni0之后，cni0发现dst为192.20.1.43，cni根据主机路由表来查找匹配项

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/11.png)

根据最小匹配原则，匹配到图上的一条路由表项。去往192.20.1.0/24 网段的包，发送192.20.1.0网关，网关设备是flannel.1

### 3. Flannel.1

flannel.1为vxlan设备，当数据包来到flannel.1时，需要将数据包封装起来。此时的dst ip 为192.20.1.43，src ip为192.20.0.51。数据包继续封装需要知道192.20.1.43 ip地址对应的mac地址。此时，flannel.1不会发送arp请求去获得192.20.1.42的mac地址，而是由Linux kernel将一个“L3 Miss”事件请求发送的用户空间的flanned程序。Flanned程序收到内核的请求事件之后，从etcd查找能够匹配该地址的子网的flannel.1设备的mac地址，即发往的pod所在host中flannel.1设备的mac地址。Flannel在为Node节点分配ip网段时记录了所有的网段和mac等信息，所以能够知道。交互流程如下图所示：

而且，最上面一开始就提到过，etcd会存储各个节点上面flannel创建出来的subnet自网络，所以etcd能够查到并匹配到相对应的 dst ip mac 信息

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/12.png)

flanned将查询到的信息放入master node host的arp cache表中

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/13.png)

到这里，vxlan的内层数据包就完成了封装。格式是这样的：

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/14.png)

### 4. 简单总结这个流程

1. 数据包到达flannel.1，通过查找路由表，知道数据包要通过flannel.1发往192.20.1.0
2. 通过arp cache表，知道了目的ip192.20.1.0的mac地址。

kernel需要查看node上的fdb(forwarding database)以获得内层封包中目的vtep设备所在的node地址。因为已经从arp table中查到目的设备mac地址为52:77:71:e6:4f:58，同时在fdb中存在该mac地址对应的node节点的IP地址。如果fdb中没有这个信息，那么kernel会向用户空间的flanned程序发起”L2 MISS”事件。flanneld收到该事件后，会查询etcd，获取该vtep设备对应的node的”Public IP“，并将信息注册到fdb中。

当内核获得了发往机器的ip地址后，arp得到mac地址，之后就能完成vxlan的外层封装。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/15.png)

### 5. 对端 flannel.1

Node节点的eth0网卡接收到vxlan设备包，kernal将识别出这是一个vxlan包，将包拆开之后转给节点上的flannel.1设备。这样数据包就从发送节点到达目的节点，flannel.1设备将接收到一个如下的数据包：

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/16.png)

目的地址为192.20.1.43，flannel.1查找自己的路由表，根据路由表完成转发。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/17.png)

根据最下匹配原则，flannel.1将去往192.20.1.0/24的流量转发到cni0上去。

### 6. cni0 到 pod

cni0是一个网桥设备。当cni0拿到数据包之后，通过veth pair，将数据包发送给pod。查看Node节点中的网桥

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/18.png)

在node节点上通过arp解析可以开出，192.20.1.43的mac地址为 66:57:8e:3d:00:85

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/19.png)

该地址为pod的网卡eth0的地址

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/20.png)

同时通过veth pair的配对关系可以看出，pod中的eth0是veth pair的一端，另一端在node节点行上，对应的网卡是vethd356ffc1@if3。所以，在cni0网桥上挂载的pod的veth pair为vethd356ffc1，即：

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/21.png)

eth0@if50和vethd356ffc1@if3组成的一对veth-pair。其效果相当于将pod中的eth0直接插在到cni0上。

所以简单总结cni0转发流量的原理：

1. 首先通过arp查找出ip地址对应的mac地址
2. 将流量转发给mac地址所在eth0网的对应的veth pair端口
3. veth pair端口接收到流量，直接将流量注入到pod的eth0网卡上。

## 五、不同后端的封装

Flannel可以指定不同的转发后端网络，常用的有hostgw，udp，vxlan等

### 1. Hostgw


hostgw是最简单的backend，它的原理非常简单，直接添加路由，将目的主机当做网关，直接路由原始封包。

例如，我们从etcd中监听到一个EventAdded事件subnet为10.1.15.0/24被分配给主机Public IP 192.168.0.100，hostgw要做的工作就是在本主机上添加一条目的地址为10.1.15.0/24，网关地址为192.168.0.100，输出设备为上文中选择的集群间交互的网卡即可。

优点：简单，直接，效率高

缺点：要求所有的pod都在一个子网中，如果跨网段就无法通信。

### 2. UDP

如何应对Pod不在一个子网里的场景呢？将Pod的网络包作为一个应用层的数据包，使用UDP封装之后在集群里传输。即overlay。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/22.png)

上图来自flannel官方，其中右边Packer的封装格式就是使用udp完成overlay的格式

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/23.png)

当容器10.1.15.2/24要和容器10.1.20.2/24通信时，

1. 因为该封包的目的地不在本主机subnet内，因此封包会首先通过网桥转发到主机中。

2. 在主机上经过路由匹配，进入网卡flannel.1。(需要注意的是flannel.1是一个tun设备，它是一种工作在三层的虚拟网络设备，而flanneld是一个proxy，它会监听flannel.1并转发流量。)

3. 当封包进入flannel.1时，flanneld就可以从flanne.1中将封包读出，由于flanne.1是三层设备，所以读出的封包仅仅包含IP层的报头及其负载。

4. 最后flanneld会将获取的封包作为负载数据，通过udp socket发往目的主机。

5. 在目的主机的flanneld会监听Public IP所在的设备，从中读取udp封包的负载，并将其放入flannel.1设备内。

6. 容器网络封包到达目的主机，之后就可以通过网桥转发到目的容器了。

优点：Pod能够跨网段访问

缺点：隔离性不够，udp不能隔离两个网段。

### 3. Vxlan

vxlan和上文提到的udp backend的封包结构是非常类似的，不同之处是多了一个vxlan header，以及原始报文中多了个二层的报头

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-03-flannel网络/24.png)

当初始化集群里，vxlan网络的初始化工作：

主机B加入flannel网络时,它会将自己的三个信息写入etcd中，分别是：subnet 10.1.16.0/24、Public IP 192.168.0.101、vtep设备flannel.1的mac地址 MAC B。之后，主机A会得到EventAdded事件，并从中获取上文中B添加至etcd的各种信息。这个时候，它会在本机上添加三条信息：

1) 路由信息：所有通往目的地址10.1.16.0/24的封包都通过vtep设备flannel.1设备发出，发往的网关地址为10.1.16.0，即主机B中的flannel.1设备。

2) fdb信息：MAC地址为MAC B的封包，都将通过vxlan发往目的地址192.168.0.101，即主机B

3）arp信息：网关地址10.1.16.0的地址为MAC B

> 事实上，flannel只使用了vxlan的部分功能，由于VNI被固定为1，本质上工作方式和udp backend是类似的，区别无非是将udp的proxy换成了内核中的vxlan处理模块。而原始负载由三层扩展到了二层，但是这对三层网络方案flannel是没有意义的，这么做也仅仅只是为了适配vxlan的模型。vxlan详细的原理参见文后的参考文献，其中的分析更为具体，也更易理解。

> 总的来说，flannel更像是经典的桥接模式的扩展。我们知道，在桥接模式中，每台主机的容器都将使用一个默认的网段，容器与容器之间，主机与容器之间都能互相通信。要是，我们能手动配置每台主机的网段，使它们互不冲突。接着再想点办法，将目的地址为非本机容器的流量送到相应主机：如果集群的主机都在一个子网内，就搞一条路由转发过去；若是不在一个子网内，就搞一条隧道转发过去。这样以来，容器的跨网络通信问题就解决了。而flannel做的，其实就是将这些工作自动化了而已。

## 六、存在问题

1. 不支持pod之间的网络隔离。Flannel设计思想是将所有的pod都放在一个大的二层网络中，所以pod之间没有隔离策略。

2. 设备复杂，效率不高。Flannel模型下有三种设备，数量经过多种设备的封装、解析，势必会造成传输效率的下降。

对于flannel网络介绍的文章也很多，其中有一个点有明显的分歧，就是对于flanned的作用。分歧点在于：使用UDP作为后端网络时，flanned会将flanne.1设备的流量经过自己的处理发送给对端的flanned。但是在分析vxlan作为后端网络时明显不是这么做的，在vxlan中flanned作用是获取必要的mac地址，ip地址信息，没有直接处理数据流。这里要存疑，如果有读者能告知，欢迎留言。

转自：https://www.cnblogs.com/goldsunshine/p/10740928.html
