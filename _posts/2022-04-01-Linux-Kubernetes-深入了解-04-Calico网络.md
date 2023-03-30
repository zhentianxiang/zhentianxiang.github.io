---
layout: post
title: Linux-Kubernetes-深入了解-04-Calico网络
date: 2022-04-01
tags: Linux-Kubernetes-深入了解
---

## 一、简介

Calico 是一种容器之间互通的网络方案。在虚拟化平台中，比如 OpenStack、Docker 等都需要实现 workloads 之间互连，但同时也需要对容器做隔离控制，就像在 Internet 中的服务仅开放80端口、公有云的多租户一样，提供隔离和管控机制。而在多数的虚拟化平台实现中，通常都使用二层隔离技术来实现容器的网络，这些二层的技术有一些弊端，比如需要依赖 VLAN、bridge 和隧道等技术，其中 bridge 带来了复杂性，vlan 隔离和 tunnel 隧道则消耗更多的资源并对物理环境有要求，随着网络规模的增大，整体会变得越加复杂。我们尝试把 Host 当作 Internet 中的路由器，同样使用 BGP 同步路由，并使用 iptables 来做安全访问策略，最终设计出了 Calico 方案。

**适用场景**：k8s环境中的pod之间需要隔离

**设计思想**：Calico 不使用隧道或 NAT 来实现转发，而是巧妙的把所有二三层流量转换成三层流量，并通过 host 上路由配置完成跨 Host 转发。

**设计优势**：

1.更优的资源利用

二层网络通讯需要依赖广播消息机制，广播消息的开销与 host 的数量呈指数级增长，Calico 使用的三层路由方法，则完全抑制了二层广播，减少了资源开销。

另外，二层网络使用 VLAN 隔离技术，天生有 4096 个规格限制，即便可以使用 vxlan 解决，但 vxlan 又带来了隧道开销的新问题。而 Calico 不使用 vlan 或 vxlan 技术，使资源利用率更高。

2.可扩展性

Calico 使用与 Internet 类似的方案，Internet 的网络比任何数据中心都大，Calico 同样天然具有可扩展性。

3.简单而更容易 debug

因为没有隧道，意味着 workloads 之间路径更短更简单，配置更少，在 host 上更容易进行 debug 调试。

4.更少的依赖

Calico 仅依赖三层路由可达。

5.可适配性

Calico 较少的依赖性使它能适配所有 VM、Container、白盒或者混合环境场景。

## 二、Calico 架构

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/1.png)

Calico网络模型主要工作组件：

1.Felix：运行在每一台 Host 的 agent 进程，主要负责网络接口管理和监听、路由、ARP 管理、ACL 管理和同步、状态上报等。

2.etcd：分布式键值存储，主要负责网络元数据一致性，确保Calico网络状态的准确性，可以与kubernetes共用；

3.BGP Client（BIRD）：Calico 为每一台 Host 部署一个 BGP Client，使用 BIRD 实现，BIRD 是一个单独的持续发展的项目，实现了众多动态路由协议比如 BGP、OSPF、RIP 等。在 Calico 的角色是监听 Host 上由 Felix 注入的路由信息，然后通过 BGP 协议广播告诉剩余 Host 节点，从而实现网络互通。

4.BGP Route Reflector：在大型网络规模中，如果仅仅使用 BGP client 形成 mesh 全网互联的方案就会导致规模限制，因为所有节点之间俩俩互联，需要 N^2 个连接，为了解决这个规模问题，可以采用 BGP 的 Router Reflector 的方法，使所有 BGP Client 仅与特定 RR 节点互联并做路由同步，从而大大减少连接数。

### 1. Felix

Felix会监听ECTD中心的存储，从它获取事件，比如说用户在这台机器上加了一个IP，或者是创建了一个容器等。用户创建pod后，Felix负责将其网卡、IP、MAC都设置好，然后在内核的路由表里面写一条，注明这个IP应该到这张网卡。同样如果用户制定了隔离策略，Felix同样会将该策略创建到ACL中，以实现隔离。

### 2. BIRD

BIRD是一个标准的路由程序，它会从内核里面获取哪一些IP的路由发生了变化，然后通过标准BGP的路由协议扩散到整个其他的宿主机上，让外界都知道这个IP在这里，你们路由的时候得到这里来。

### 3. 架构特点

由于Calico是一种纯三层的实现，因此可以避免与二层方案相关的数据包封装的操作，中间没有任何的NAT，没有任何的overlay，所以它的转发效率可能是所有方案中最高的，因为它的包直接走原生TCP/IP的协议栈，它的隔离也因为这个栈而变得好做。因为TCP/IP的协议栈提供了一整套的防火墙的规则，所以它可以通过IPTABLES的规则达到比较复杂的隔离逻辑。

## 三、Calico 与 Node 之间两种网络

### 1. IP IP

从字面来理解，就是把一个IP数据包又套在一个IP包里，即把 IP 层封装到 IP 层的一个 tunnel。它的作用其实基本上就相当于一个基于IP层的网桥！一般来说，普通的网桥是基于mac层的，根本不需 IP，而这个 ipip 则是通过两端的路由做一个 tunnel，把两个本来不通的网络通过点对点连接起来。

### 2. BGP

边界网关协议（Border Gateway Protocol, BGP）是互联网上一个核心的去中心化自治路由协议。它通过维护IP路由表或‘前缀’表来实现自治系统（AS）之间的可达性，属于矢量路由协议。BGP不使用传统的内部网关协议（IGP）的指标，而使用基于路径、网络策略或规则集来决定路由。因此，它更适合被称为矢量性协议，而不是路由协议。BGP，通俗的讲就是讲接入到机房的多条线路（如电信、联通、移动等）融合为一体，实现多线单IP，BGP 机房的优点：服务器只需要设置一个IP地址，最佳访问路由是由网络上的骨干路由器根据路由跳数与其它技术指标来确定的，不会占用服务器的任何系统。

## 四、IP IP 工作模式

### 1. 测试环境

一个msater节点，ip 172.171.5.95，一个node节点 ip 172.171.5.96

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/2.png)

创建一个daemonset的应用，pod1落在master节点上 ip地址为192.168.236.3，pod2落在node节点上 ip地址为192.168.190.203

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/3.png)

pod1 ping pod2

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/4.png)

### 2. ping 包

pod1上的路由信息

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/5.png)

根据路由信息，ping 192.168.190.203，会匹配到第一条。第一条路由的意思是：去往任何网段的数据包都发往网管169.254.1.1，然后从eth0网卡发送出去。

路由表中Flags标志的含义：

U up表示当前为启动状态

H host表示该路由为一个主机，多为达到数据包的路由

G Gateway 表示该路由是一个网关，如果没有说明目的地是直连的

D Dynamicaly 表示该路由是重定向报文修改

M 表示该路由已被重定向报文修改

master节点上的路由信息

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/6.png)

当ping包来到master节点上，会匹配到路由tunl0。该路由的意思是：去往192.169.190.192/26的网段的数据包都发往网关172.171.5.96。因为pod1在5.95，pod2在5.96。所以数据包就通过设备tunl0发往到node节点上。


 node节点上路由信息

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/7.png)

 当node节点网卡收到数据包之后，发现发往的目的ip为192.168.190.203，于是匹配到红线的路由。该路由的意思是：192.168.190.203是本机直连设备，去往设备的数据包发往caliadce112d250

 那么该设备是什么呢？如果到这里你能猜出来是什么，那说明你的网络功底是不错的。这个设备就是veth pair的一端。在创建pod2时calico会给pod2创建一个veth pair设备。一端是pod2的网卡，另一端就是我们看到的caliadce112d250。下面我们验证一下。在pod2中安装ethtool工具，然后使用ethtool -S eth0,查看veth pair另一端的设备号。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/8.png)

pod2 网卡另一端的设备好号是18，在node上查看编号为18的网络设备，可以发现该网络设备就是caliadce112d250。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/9.png)

所以，node上的路由，发送caliadce112d250的数据其实就是发送到pod2的网卡中。ping包的旅行到这里就到了目的地。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/10.png)

查看一下pod2中的路由信息，发现该路由信息和pod1中是一样的

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/11.png)

顾名思义，IPIP网络就是将IP网络封装在IP网络里。IPIP网络的特点是所有pod的数据流量都从隧道tunl0发送，并且在tunl0这增加了一层传输层的封包。

在master网卡上抓包分析该过程。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/12.png)

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/13.png)

打开ICMP 285，pod1 ping pod2的数据包，能够看到该数据包一共5层，其中IP所在的网络层有两个，分别是pod之间的网络和主机之间的网络封装。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/14.png)

根据数据包的封装顺序，应该是在pod1 ping pod2的ICMP包外面多封装了一层主机之间的数据包。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/15.png)

之所以要这样做是因为tunl0是一个隧道端点设备，在数据到达时要加上一层封装，便于发送到对端隧道设备中。

 两层IP封装的具体内容

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/16.png)

 IPIP的连接方式：

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/17.png)

## 五、BGP 工作模式

### 1. 修改配置

在安装calico网络时，默认安装是IPIP网络。calico.yaml文件中，将CALICO_IPV4POOL_IPIP的值修改成 "off"，就能够替换成BGP网络。

```yaml
4195             # Enable IPIP
4196             - name: CALICO_IPV4POOL_IPIP
4197               value: "Always"  ## 修改为off
```

### 2. 对比

BGP网络相比较IPIP网络，最大的不同之处就是没有了隧道设备 tunl0。 前面介绍过IPIP网络pod之间的流量发送tunl0，然后tunl0发送对端设备。BGP网络中，pod之间的流量直接从网卡发送目的地，减少了tunl0这个环节。

master节点上路由信息。从路由信息来看，没有tunl0设备。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/18.png)

同样创建一个daemonset，pod1在master节点上，pod2在node节点上。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/19.png)

### 3. ping 包

pod1 ping pod2

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/20.png)

根据pod1中的路由信息，ping包通过eth0网卡发送到master节点上。

master节点上路由信息。根据匹配到的 192.168.190.192 路由，该路由的意思是：去往网段192.168.190.192/26 的数据包，发送网段172.171.5.96。而5.96就是node节点。所以，该数据包直接发送了5.96节点。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/21.png)

node节点上的路由信息。根据匹配到的192.168.190.192的路由，数据将发送给 cali6fcd7d1702e设备，该设备和上面分析的是一样，为pod2的veth pair 的一端。数据就直接发送给pod2的网卡。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/22.png)

当pod2对ping包做出回应之后，数据到达node节点上，匹配到192.168.236.0的路由，该路由说的是：去往网段192.168.236.0/26 的数据，发送给网关 172.171.5.95。数据包就直接通过网卡ens160，发送到master节点上。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/23.png)

通过在master节点上抓包，查看经过的流量，筛选出ICMP，找到pod1 ping pod2的数据包

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/24.png)

可以看到BGP网络下，没有使用IPIP模式，数据包是正常的封装。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/25.png)

值得注意的是mac地址的封装。192.168.236.0是pod1的ip，192.168.190.198是pod2的ip。而源mac地址是 master节点网卡的mac，目的mac是node节点的网卡的mac。这说明，在 master节点的路由接收到数据，重新构建数据包时，使用arp请求，将node节点的mac拿到，然后封装到数据链路层。

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/26.png)

BGP的连接方式：

![](/images/posts/Linux-Kubernetes-深入了解/Linux-Kubernetes-深入了解-04-Calico网络/27.png)

## 六、两种网络对比

### 1. IPIP网络：

流量：tunlo设备封装数据，形成隧道，承载流量。

适用网络类型：适用于互相访问的pod不在同一个网段中，跨网段访问的场景。外层封装的ip能够解决跨网段的路由问题。

效率：流量需要tunl0设备封装，效率略低

### 2. BGP网络：

流量：使用路由信息导向流量

适用网络类型：适用于互相访问的pod在同一个网段，适用于大型网络。

效率：原生hostGW，效率高

## 七、存在问题

(1) 缺点租户隔离问题

Calico 的三层方案是直接在 host 上进行路由寻址，那么对于多租户如果使用同一个 CIDR 网络就面临着地址冲突的问题。

(2) 路由规模问题

通过路由规则可以看出，路由规模和 pod 分布有关，如果 pod离散分布在 host 集群中，势必会产生较多的路由项。

(3) iptables 规则规模问题

1台 Host 上可能虚拟化十几或几十个容器实例，过多的 iptables 规则造成复杂性和不可调试性，同时也存在性能损耗。

(4) 跨子网时的网关路由问题

当对端网络不为二层可达时，需要通过三层路由机时，需要网关支持自定义路由配置，即 pod 的目的地址为本网段的网关地址，再由网关进行跨三层转发。

转自：https://www.cnblogs.com/goldsunshine/p/10701242.html
