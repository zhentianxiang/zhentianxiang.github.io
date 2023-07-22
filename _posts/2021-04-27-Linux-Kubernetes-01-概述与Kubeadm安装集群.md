---
layout: post
title: Linux-Kubernetes-01-概述与Kubeadm安装集群
date: 2021-04-27
tags: 实战-Kubernetes
---

## 一、Kubernetes概述

### 1.1 Kubernetes是什么

> 1. Kubernetes是Google在2014年开源的一个容器集群管理系统
> 2. Kubernetes简称K8S
> 3. K8S用于容器化应用程序的部署，扩展和管理
> 4. K8S提供了容器编排，资源调度，弹性伸缩，部署管理，服务发现等一系列功能
> 5. K8S目标是让部署容器化应用简单高效
> 6. K8S本质上就是一组服务器集群，k8s可以在集群的各个节点上运行特定的docker容器
> 7. 官方网站：http://www.kubernetes.io

### 1.2 Kubernetes的特性

> 1. 自我修复
> 2. 弹性伸缩：实时根据服务器的并发情况，增加或缩减容器数量
> 3. 自动部署：借助yml文件
> 4. 回滚：遇到版本不支持可以自动恢复到版本支持的状态
> 5. 服务发现和负载均衡：可以对访问请求进行轮询调度
> 6. 机密和配置共享管理：搭建一个服务配置会自动共享到其他节点

### 1.3 Kubernetes集群架构与组件

> 1. Kubelet：是Master在Node节点上的Agent，管理本机运行容器的生命周期，比如创建容器、Pod挂载数据卷、下载secret、获取容器和节点状态等工作，Kubelet将每个Pod转换成一组容器
> 2. Kube-proxy：Node节点上实现Podcast网络代理，维护网络规则和四层负载均衡工作
> 3. Docker或rocket：容器引擎，运行容器
> 4. etcd：K8S的数据库，用来注册节点、服务、记录账户

### 1.4 Kubernetes功能基本概念

> Pod
>
> - 容器的组合，可以理解为docker-compose，但是不具备控制管理。
> - Pod是最小部署单元而不是容器
> - 一组容器或者多个的集合，又称为容器组
> - 一个Pod中的容器共享网络命名空间，Pod是短暂的
> - Pod会被分配一个单独的地址，但这个地址会随Pod的销毁而消失

------

> Controllers：
>
> - 控制器，控制Pod的启动、停止、删除
> - ReplicaSet：确保预期的Pod副本数量
> - Deployment：无状态应用部署
> - StatefulSet：有状态应用部署
> - DaemonSet：确保所有Node运行同一个Pod
> - Job：一次性任务
> - Cronjob：定时任务

------

> Label
>
> - 标签，附加到某个资源上，用于关联对象、查询和筛选
> - 一个标签可以对应多个资源，一个资源也可以有多个标签，它们是多对多的关系。
> - 一个资源拥有多个标签，可以实现不同维度的管理。
> - 标签的组成：key=value
> - 与标签类似的，还有一种 “注解”（annotaions）

------

> Label选择器
>
> - 给资源打上标签后，可以使用标签选择器过滤指定的标签
> - 标签选择器目前有两种：基于等值关系（等于、不等于）和基于集合关系（属于、不属于、存在）
> - 许多资源支持内嵌标签选择器字段
>   - matchLabels
>   - matchExpressions

------

> Service
>
> - 随然Pod会被分配一个单独的地址，但这个地址会随Pod的销毁而消失
> - Service就是用来解决这个问题的核心概念
> - 将一组Pod关联起来，提供一个统一的入口，即使Pod地址发生改变，这个统一的入口也不会发生变化，从而保证用户访问不受影响
> - Service作用于那些Pod是通过标签选择器来定义的

------

> Ingerss
>
> - Ingerss是K8s集群里工作在OSI网络参考模型下，第7层的应用，对外暴露的接口
> - Service知识进行L4流量调度，表现形式是ip+port
> - Ingerss可以调度不同业务域、不同URL访问路径的业务流量

### 1.5 Kubernetes核心组件

> 核心组件
>
> - 配置存储中心→etcd（服务非关系型数据库）
> - 主控（master）节点
>   - kube-apiserver服务（大脑）
>   - kube-controller-manger服务（管理控制器的控制器）
>     - Node Controller
>     - Deployment Controller
>     - Service Controller
>     - Volume Controller
>     - Endpoint Controller
>     - Namespace Controller
>     - Job Controller
>     - Resource quta Controller
>     - ……….
>   - kube-scheduler服务（主要功能是要接受调度Pod到核是的运算节点上）
>     - 预算策略（predict）
>     - 优选策略（priorities）
> - 运算（node）节点
>   - kube-kubelet服务
>     - 定时从某个地方获取节点上Pod的期望状态（运行什么容器、运行的副本数量、网络或者存储如何配置等），并调用对应容器平台接口到达这个状态
>     - 蒂尼故事汇报当前节点的状态给apiserver，以供调度的时候使用
>     - 镜像和容器的清理工作，保证节点上镜像不会沾满磁盘空间，退出容器不会占用太多资源
>   - kube-proxy服务
>     - 建立了Pod网络和集群网络的关系（clusterip→podip）
>     - 常用的三种流量调度模式
>       - Userpace（废弃）
>       - Iptables（濒临废弃）
>       - IPvs（推荐）
>     - 负责建立和删除包括更新调度规则、通知apiserver自己的更新，或者从apiserver那里获取其他kube-proxy的调度规则变化来更新自己的
> - CLI客户端
>   - kubectl

------

> 核心附件
>
> - CNI网络插件→Flannel/calico
> - 服务发现插件→Coredns
> - 服务暴露插件→Traefik
> - GUI管理插件→Dashhoard

## 二、kubeadm 快速部署K8S集群

### 2.1 环境需求

> 系统：centos7.4+
>
> 硬件需求：CPU≥2C，内存大于等于2G

### 2.2 环境角色

| IP        | 角色       | 安装软件                                                     | 配置  |
| --------- | ---------- | ------------------------------------------------------------ | ----- |
| 10.0.0.11 | k8s-master | kube-apiserver  kube-schduler  kube-controller-manager  docker  flannel  kubelet | 2核2G |
| 10.0.0.12 | k8s-node01 | kubelet  kube-proxy  docker  flannel                         | 2核2G |
| 10.0.0.13 | k8s-node01 | kubelet  kube-proxy  docker  flannel                         | 2核2G |

### 2.3 环境初始化

> PS : 以下所有操作，在三台节点全部执行

**1. 关闭防火墙及selinux**

```sh
[root@k8s-master ~]# systemctl stop firewalld && systemctl disable firewalld
[root@k8s-master ~]# sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config  && setenforce 0
```

**2. 关闭swap分区**

```sh
[root@k8s-master ~]# swapoff -a  # 临时
[root@k8s-master ~]# sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab #永久
```
或者
```sh
[root@k8s-master ~]#  touch /usr/local/stop-swap.sh
[root@k8s-master ~]#  cat > /usr/local/stop-swap.sh << EOF
#!/bin/bash
swapoff -a
EOF

[root@k8s-master ~]#  chmod +x /usr/local/stop-swap.sh
[root@k8s-master ~]#  cat > /etc/systemd/system/stop-swap.service << EOF
[Unit]
Description=stop-swap
After=network.target

[Service]
User=root
Group=root
Type=forking
ExecStart=/usr/local/stop-swap.sh
TimeoutSec=0
Restart=on-failure
StandardOutput=journal
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
[root@k8s-master ~]#  systemctl start stop-swap.service
[root@k8s-master ~]#  systemctl enable stop-swap.service

```

**3. 修改主机名称**

node节点修改为node专用的

```sh
[root@k8s-master ~]# hostnamectl set-hostname k8s-master
```

**4. 配置hosts解析**

```sh
[root@k8s-master ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
10.0.0.11 k8s-master
10.0.0.12 k8s-node01
10.0.0.13 k8s-node02
```

**5. 内核调整,将桥接的IPv4流量传递到iptables的链**

```sh
[root@k8s-master ~]# lsmod | grep br_netfilter #确认是否有加载此模块
[root@k8s-master ~]# sudo modprobe br_netfilter  #没有的话可以先加载

[root@k8s-master ~]# cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
[root@k8s-master ~]# sudo sysctl --system
```

**6. 设置系统时间同步Windows服务器**

```sh
[root@k8s-master ~]# yum install -y ntpdate
[root@k8s-master ~]# ntpdate time.windows.com
```

### 2.4 docker环境安装

> ps：三台节点都安装

```sh
[root@k8s-master ~]# wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
[root@k8s-master ~]# yum -y install docker-ce
修改docker运行环境
[root@k8s-master ~]# vim /etc/docker/daemon.json
{
    "graph": "/var/lib/docker",
    "registry-mirrors": [
        "https://registry.docker-cn.com",
        "https://docker.mirrors.ustc.edu.cn"
    ],
    "insecure-registries": [
        "harbor.hyper.com"
    ],
    "live-restore": true,
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "10"
    }
}
---
# 安装 nvidia-docker 的用以下
{
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
        }
    },
    "graph": "/var/lib/docker",
    "default-runtime": "nvidia",
    "registry-mirrors": [
        "https://registry.docker-cn.com",
        "https://docker.mirrors.ustc.edu.cn"
    ],
    "insecure-registries": [
        "harbor.hyper.com"
    ],
    "live-restore": true,
    "exec-opts": ["native.cgroupdriver=systemd"],
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "100m",
        "max-file": "10"
    }
}

[root@k8s-master ~]# mkdir /data/docker  #docker数据存储目录，尽量找一个大的空间
[root@k8s-master ~]# systemctl enable docker && systemctl start docker
[root@k8s-master ~]# docker --version
```

### 2.5 kubernetes安装源

```sh
[root@k8s-master ~]# cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```
ubuntu 1804系统
```sh
root@hyper:~# apt-get update && apt-get install -y apt-transport-https
root@hyper:~# curl https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | apt-key add -
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  2537  100  2537    0     0  21319      0 --:--:-- --:--:-- --:--:-- 21319
OK
root@hyper:~# vim /etc/apt/sources.list
# k8s mirrors
deb https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main
root@hyper:~# apt-get update && apt-cache madison kubeadm
```

### 2.6 安装kubeadm,kubelet和kubectl

> ps：所有主机都需要操作，由于版本更新频繁，这里指定版本号部署

```sh
[root@k8s-master ~]# yum install -y kubelet-1.18.19 kubeadm-1.18.19 kubectl-1.18.19
[root@k8s-master ~]# systemctl enable kubelet
```

### 2.7 修改kubelet的cgroups也为systemd
在最后面添加这个参数--cgroup-driver=systemd
```sh
[root@k8s-master ~]# vim /usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml --cgroup-driver=systemd"
[root@k8s-master ~]# systemctl daemon-reload
[root@k8s-master ~]# systemctl restart kubelet
```

### 2.8 部署Kubernetes Master

> ps：只需要在Master 节点执行，这里的apiserve需要修改成自己的master地址

```sh
[root@k8s-master ~]# kubeadm init \
--apiserver-advertise-address=10.0.0.11 \
--apiserver-bind-port=6443 \
--kubernetes-version=v1.18.19 \
--pod-network-cidr=10.100.0.0/16 \
--image-repository=registry.cn-hangzhou.aliyuncs.com/google_containers \
--ignore-preflight-errors=swap
```

**输出结果:**

```sh
[preflight] Pulling images required for setting up a Kubernetes cluster
[preflight] This might take a minute or two, depending on the speed of your internet connection
[preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Activating the kubelet service
[certs] Using certificateDir folder "/etc/kubernetes/pki"
[certs] Generating "ca" certificate and key
[certs] Generating "apiserver-kubelet-client" certificate and key
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [k8s-master kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.1.0.1 192.168.4.34]
[certs] Generating "front-proxy-ca" certificate and key
[certs] Generating "front-proxy-client" certificate and key
[certs] Generating "etcd/ca" certificate and key
[certs] Generating "apiserver-etcd-client" certificate and key
[certs] Generating "etcd/healthcheck-client" certificate and key
[certs] Generating "etcd/server" certificate and key
[certs] etcd/server serving cert is signed for DNS names [k8s-master localhost] and IPs [192.168.4.34 127.0.0.1 ::1]
[certs] Generating "etcd/peer" certificate and key
[certs] etcd/peer serving cert is signed for DNS names [k8s-master localhost] and IPs [192.168.4.34 127.0.0.1 ::1]
[certs] Generating "sa" key and public key
[kubeconfig] Using kubeconfig folder "/etc/kubernetes"
......(省略)
[bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 10.0.0.11:6443 --token 2nm5l9.jtp4zwnvce4yt4oj \
    --discovery-token-ca-cert-hash sha256:12f628a21e8d4a7262f57d4f21bc85f8802bb717d
```

**根据输出提示操作：**

```sh
[root@k8s-master ~]# mkdir -p $HOME/.kube
[root@k8s-master ~]# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
[root@k8s-master ~]# sudo chown $(id -u):$(id -g) $HOME/.kube/config
#添加命令补齐
[root@k8s-master ~]# source /usr/share/bash-completion/bash_completion
[root@k8s-master ~]# source <(kubectl completion bash)
[root@k8s-master ~]# echo "source <(kubectl completion bash)" >> ~/.bashrc
```

> 默认token的有效期为24小时，当过期之后，该token就不可用了
>
> 如果后续有nodes节点加入，解决方法如下：

**重新生成新的token**

```sh
[root@k8s-master ~]# kubeadm token create
0w3a92.ijgba9ia0e3scicg
[root@k8s-master ~]# kubeadm token list
TOKEN                     TTL       EXPIRES                     USAGES                   DESCRIPTION                                                EXTRA GROUPS
0w3a92.ijgba9ia0e3scicg   23h       2019-09-08T22:02:40+08:00   authentication,signing   <none>                                                     system:bootstrappers:kubeadm:default-node-token
t0ehj8.k4ef3gq0icr3etl0   22h       2019-09-08T20:58:34+08:00   authentication,signing   The default bootstrap token generated by 'kubeadm init'.   system:bootstrappers:kubeadm:default-node-token
```

**获取ca证书sha256编码hash值**

```sh
[root@k8s-master ~]# openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
ce07a7f5b259961884c55e3ff8784b1eda6f8b5931e6fa2ab0b30b6a4234c09a
```

**节点加入集群**

```sh
[root@k8s-node01 ~]# kubeadm join 10.0.0.11:6443 --token 0w3a92.ijgba9ia0e3scicg \
    --discovery-token-ca-cert-hash sha256:ce07a7f5b259961884c55e3ff8784b1eda6f8b5931e6fa2ab0b30b6a4234c09a
```

### 2.8 加入Kubernetes Node

> ps：在两个 Node 节点执行

使用kubeadm join 注册Node节点到Matser

kubeadm join 的内容，在上面kubeadm init 已经生成好了

```sh
[root@k8s-node01 ~]# kubeadm join 10.0.0.11:6443 --token 2nm5l9.jtp4zwnvce4yt4oj \
    --discovery-token-ca-cert-hash sha256:12f628a21e8d4a7262f57d4f21bc85f8802bb717dd6f513bf9d33f254fea3e89
```

**输出内容：**

```sh
[preflight] Running pre-flight checks
    [WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -oyaml'
[kubelet-start] Downloading configuration for the kubelet from the "kubelet-config-1.15" ConfigMap in the kube-system namespace
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
[kubelet-start] Activating the kubelet service
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
```

如果遇到以下报错

```sh
[root@k8s-node01 ~]# kubeadm join 10.0.0.11:6443 --token 2xbgzg.l7oxqe7vpmua470u \
>     --discovery-token-ca-cert-hash sha256:7f0d5b506164f6f162ffda6590ad1fde01739ba688591521a94b984185428ad3
[preflight] Running pre-flight checks
	[WARNING IsDockerSystemdCheck]: detected "cgroupfs" as the Docker cgroup driver. The recommended driver is "systemd". Please follow the guide at https://kubernetes.io/docs/setup/cri/
	[WARNING SystemVerification]: this Docker version is not on the list of validated versions: 20.10.7. Latest validated version: 18.09
error execution phase preflight: [preflight] Some fatal errors occurred:
	[ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]: /proc/sys/net/bridge/bridge-nf-call-iptables contents are not set to 1
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
```

在命令行执行如下

```sh
[root@k8s-node01 ~]# echo "1" >/proc/sys/net/bridge/bridge-nf-call-iptables
```

### 2.9 安装网络插件

> ps：只在master执行

```sh
[root@k8s-master ~]# wget https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml
```

如果下载不下来，可以访问我网盘的资源

> 链接：https://pan.baidu.com/s/1JtE6dCHFYWxCvd0Fpcdnww
> 提取码：an69

修改yaml配置文件中的镜像源地址

```sh
[root@k8s-master ~]# vim kube-flannel.yml
```

修改106和120行的镜像源地址

![](/images/posts/Linux-Kubernetes/概述与Kubeadm安装集群/1.png)

```sh
[root@k8s-master ~]# kubectl apply -f kube-flannel.yml
[root@k8s-master ~]# ps -ef|grep flannel
root      2032  2013  0 21:00 ?        00:00:00 /opt/bin/flanneld --ip-masq --kube-subnet-mgr
```

**查看集群状态和pod状态**

```sh
[root@k8s-master ~]# kubectl get node
NAME         STATUS   ROLES    AGE    VERSION
k8s-master   Ready    master   126m   v1.15.0
k8s-node01   Ready    <none>   99m    v1.15.0
k8s-node02   Ready    <none>   99m    v1.15.0
[root@k8s-master ~]# kubectl get pods -n kube-system
NAME                                    READY   STATUS    RESTARTS   AGE
coredns-bccdc95cf-2xntr                 1/1     Running   1          126m
coredns-bccdc95cf-j7s2k                 1/1     Running   1          126m
etcd-k8s-master                         1/1     Running   1          125m
kube-apiserver-k8s-master               1/1     Running   1          125m
kube-controller-manager-k8s-master      1/1     Running   5          126m
kube-flannel-ds-amd64-5lvjq             1/1     Running   1          121m
kube-flannel-ds-amd64-c9mm9             1/1     Running   1          99m
kube-flannel-ds-amd64-pzxfh             1/1     Running   2          100m
kube-proxy-6sbnn                        1/1     Running   1          100m
kube-proxy-pwlxh                        1/1     Running   1          126m
kube-proxy-srk5m                        1/1     Running   1          99m
kube-scheduler-k8s-master               1/1     Running   4          126m
kubernetes-dashboard-5fc44c76fb-6sl78   1/1     Running   0          58m
```

查看ETCD集群状态如何

```#!/bin/sh
[root@k8s-node01 ~]# etcdctl --endpoints=https://127.0.0.1:2379 --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt --key=/etc/kubernetes/pki/etcd/peer.key member list -w table
```


修改k8s默认端口可取值范围
```sh
[root@k8s-master ~]# vim /etc/kubernetes/manifests/kube-apiserver.yaml
........
    - --tls-cert-file=/etc/kubernetes/pki/apiserver.crt
    - --tls-private-key-file=/etc/kubernetes/pki/apiserver.key
    - --service-node-port-range=1-65535
.......
```
重启组件
```sh
[root@k8s-master ~]# kubectl delete pod -n kube-system kube-apiserver-k8s-master
```

### 2.10 测试集群

在Kubernetes集群中创建一个pod，然后暴露端口，验证是否正常访问：

```yaml
[root@k8s-master dashboard]# vim nginx-ds.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    k8s-app: nginx
spec:
  type: NodePort
  selector:
    k8s-app: nginx
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
    nodePort: 30080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  labels:
    k8s-app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      k8s-app: nginx
  template:
    metadata:
      labels:
        k8s-app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
      restartPolicy: Always

[root@k8s-master dashboard]# kubectl apply -f nginx-ds.yaml
```

访问地址：http://NodeIP:Port ,此例就是：http://10.0.0.11:30080

![](/images/posts/Linux-Kubernetes/概述与Kubeadm安装集群/2.png)

### 3.1 部署 Dashboard

```sh
[root@k8s-master ~]# wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

[root@k8s-master ~]# vim kubernetes-dashboard.yaml
修改内容如下，首先把默认的鉴权全部删除，替换为本次提供的 dashboard rbac
# ------------------- Dashboard rbac ------------------- #
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
    addonmanager.kubernetes.io/mode: Reconcile
  name: kubernetes-dashboard-admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard-admin
  namespace: kube-system
  labels:
    k8s-app: kubernetes-dashboard
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard-admin
  namespace: kube-system
---
# ------------------- Dashboard Deployment ------------------- #
继续修改镜像源地址
109     spec:
110       containers:
111       - name: kubernetes-dashboard
112         image: zhentianxiang/kubernetes-dashboard-amd64:v1.10.1   # 修改此行，如果部署完发现dashboard没有权限，那么可以换成1.8.3版本的镜像。
继续修改pod所使用的集群用户
...............
      serviceAccountName: kubernetes-dashboard-admin
# ------------------- Dashboard Service ------------------- #
继续修改暴露端口类型为NodePort和要暴露的端口
................
157 spec:
158   type: NodePort     # 增加此行
159   ports:
160     - port: 443
161       targetPort: 8443
162       nodePort: 30001   # 增加此行
163   selector:
164     k8s-app: kubernetes-dashboard
```

如果下载不下来，也可以用我提供的

> 链接：https://pan.baidu.com/s/12jj1AUUuI96c-Q5Estxhrw
> 提取码：8ne8

**生成资源**

```sh
[root@k8s-master ~]# kubectl apply -f kubernetes-dashboard.yaml
```

**查看资源状态**

```sh
[root@k8s-master ~]# kubectl get pods -n kube-system kubernetes-dashboard-5fc44c76fb-6sl78
NAME                                    READY   STATUS    RESTARTS   AGE
kubernetes-dashboard-5fc44c76fb-6sl78   1/1     Running   0          63m
[root@k8s-master ~]# kubectl get svc -n kube-system
NAME                   TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)                  AGE
kube-dns               ClusterIP   192.168.0.10      <none>        53/UDP,53/TCP,9153/TCP   132m
kubernetes-dashboard   NodePort    192.168.242.176   <none>        443:30001/TCP            75m
```

在火狐浏览器访问(google受信任问题不能访问)地址： https://NodeIP:30001

![](/images/posts/Linux-Kubernetes/概述与Kubeadm安装集群/3.png)

获取token进行登录
```sh
[root@k8s-master dashboard]# kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')
Name:         kubernetes-dashboard-admin-token-vhpsk
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: kubernetes-dashboard-admin
              kubernetes.io/service-account.uid: 123f9513-7d75-4637-88fd-5d7939cb5800

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1025 bytes
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZC1hZG1pbi10b2tlbi12aHBzayIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZC1hZG1pbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjEyM2Y5NTEzLTdkNzUtNDYzNy04OGZkLTVkNzkzOWNiNTgwMCIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTprdWJlcm5ldGVzLWRhc2hib2FyZC1hZG1pbiJ9.cjIosMEKaeOVAGNP4Qlmd6PXFooPPAP3b0u6kXeS4A5QGU1ca76qrx0bJJi76_rKujKa_CO8hDNliomAbkxalab8dq75FRsw-eJoFgefrnGaXUD9t7KdSDnkwdfXExjHqKbEuQfQ2c5l9VFC2IwIMWlEaODkEFG_P-lAAeh-FfR7N0OR_BQmlay_6wth2i1UJXleM42BVKm89vzpulgbmzH8I0S64pZwLQTxZNhncPZP_faagliBfdr6zj3h1WE4l341jYded7wJ9d_FsyaV_jmZvJVC3W_a3iREAgPMu-PGX8Gx22ShxaoELpCquocwtYF93gNPlHcvX_9RFmFApA
```
![](/images/posts/Linux-Kubernetes/概述与Kubeadm安装集群/4.png)

![](/images/posts/Linux-Kubernetes/概述与Kubeadm安装集群/5.png)

**解决其他浏览器不能访问的问题**

```sh
[root@k8s-master ~]# cd /etc/kubernetes/pki/
[root@k8s-master pki]# mkdir ui
[root@k8s-master pki]# cp apiserver.crt  ui/
[root@k8s-master pki]# cp apiserver.key  ui/
[root@k8s-master pki]# cd ui/
[root@k8s-master ui]# mv apiserver.crt dashboard.pem
[root@k8s-master ui]# mv  apiserver.key   dashboard-key.pem
[root@k8s-master ui]# kubectl delete secret kubernetes-dashboard-certs -n kube-system
[root@k8s-master ui]# kubectl create secret generic kubernetes-dashboard-certs --from-file=./ -n kube-system
[root@k8s-master]# vim kubernetes-dashboard.yaml #回到这个yaml的路径下修改
修改 dashboard-controller.yaml 文件，在args下面增加证书两行
          - --tls-key-file=dashboard-key.pem
          - --tls-cert-file=dashboard.pem
[root@k8s-master ~]kubectl apply -f kubernetes-dashboard.yaml
[root@k8s-master ~]# kubectl create serviceaccount dashboard-admin -n kube-system
serviceaccount/dashboard-admin created
[root@k8s-master ~]# kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin
--serviceaccount=kube-system:dashboard-admin
[root@k8s-master ~]# kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')
Name:         dashboard-admin-token-zbn9f
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name: dashboard-admin
              kubernetes.io/service-account.uid: 40259d83-3b4f-4acc-a4fb-43018de7fc19

Type:  kubernetes.io/service-account-token

Data
====
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJkYXNoYm9hcmQtYWRtaW4tdG9rZW4temJuOWYiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoiZGFzaGJvYXJkLWFkbWluIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQudWlkIjoiNDAyNTlkODMtM2I0Zi00YWNjLWE0ZmItNDMwMThkZTdmYzE5Iiwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50Omt1YmUtc3lzdGVtOmRhc2hib2FyZC1hZG1pbiJ9.E0hGAkeQxd6K-YpPgJmNTv7Sn_P_nzhgCnYXGc9AeXd9k9qAcO97vBeOV-pH518YbjrOAx_D6CKIyP07aCi_3NoPlbbyHtcpRKFl-lWDPdg8wpcIefcpbtS6uCOrpaJdCJjWFcAEHdvcfmiFpdVVT7tUZ2-eHpRTUQ5MDPF-c2IOa9_FC9V3bf6XW6MSCZ_7-fOF4MnfYRa8ucltEIhIhCAeDyxlopSaA5oEbopjaNiVeJUGrKBll8Edatc7-wauUIJXAN-dZRD0xTULPNJ1BsBthGQLyFe8OpL5n_oiHM40tISJYU_uQRlMP83SfkOpbiOpzuDT59BBJB57OQtl3w
ca.crt:     1025 bytes
```
### 3.2 部署harbor私有仓库

上传部署harbor
```sh
[root@k8s-master]# mkdir -pv /home/k8s-data && cd /home/k8s-data
[root@k8s-master]# tar xvf harbor-offline-installer-v2.1.5.tgz &&  cd harbor
[root@k8s-master]# cp harbor.yml.tmpl harbor.yml && vim harbor.ym
# Configuration file of Harbor

# The IP address or hostname to access admin UI and registry service.
# DO NOT use localhost or 127.0.0.1, because Harbor needs to be accessed by external clients.
hostname: 10.0.0.11   #需要修改位置

# http related config
http:
  # port for http, default is 80. If https enabled, this port will redirect to https port
  port: 180   #需要修改位置

# https related config
#https: #注释掉https
  # https port for harbor, default is 443
  #port: 443  #注释掉443
  # The path of cert and key files for nginx
  certificate: /your/certificate/path
  private_key: /your/private/key/path
.....................................
data_volume: /data  #修改数据存储路径，自定义
# 安装docker-compose,以方便启动harbor
[root@k8s-master ~]# wget https://github.com/docker/compose/releases/download/1.28.6/docker-compose-Linux-x86_64
[root@k8s-master ~]# chmod +x docker-compose-Linux-x86_64
[root@k8s-master ~]# mv docker-compose-Linux-x86_64 /usr/bin/docker-compose
[root@k8s-master ~]# ./install.sh
[root@k8s-master ~]# docker-compose ps
      Name                     Command                  State                 Ports          
---------------------------------------------------------------------------------------------
harbor-core         /harbor/entrypoint.sh            Up (healthy)                            
harbor-db           /docker-entrypoint.sh            Up (healthy)                            
harbor-jobservice   /harbor/entrypoint.sh            Up (healthy)                            
harbor-log          /bin/sh -c /usr/local/bin/ ...   Up (healthy)   127.0.0.1:1514->10514/tcp
harbor-portal       nginx -g daemon off;             Up (healthy)                            
nginx               nginx -g daemon off;             Up (healthy)   0.0.0.0:180->8080/tcp    
redis               redis-server /etc/redis.conf     Up (healthy)                            
registry            /home/harbor/entrypoint.sh       Up (healthy)                            
registryctl         /home/harbor/start.sh            Up (healthy)
# 为了下面的systemd启动harbor，现在可以先停掉harbor
[root@k8s-master ~]# docker-compose down
```
**编写systemd启动harbor服务**

创建相关目录以及编写启停脚本
```sh
[root@k8s-master ~]# mkdir -pv /var/log/harbor/{start,stop,fail}

####
[root@k8s-master ~]# vim /home/k8s-data/harbor/start-harbor.sh

#!/bin/bash
cd /home/k8s-data/harbor && /usr/bin/docker-compose down && sleep 10;/usr/bin/docker-compose up -d

if [ $? -eq 0 ]

        then

echo "harbor仓库启动成功!" > /var/log/harbor/start/log.$(date +%Y%m%d%H%M)

        else

echo "docker未启动!" > /var/log/harbor/fail/log.$(date +%Y%m%d%H%M)

fi

####
[root@k8s-master ~]# vim /home/k8s-data/harbor/stop-harbor.sh

#!/bin/bash
cd /home/k8s-data/harbor && /usr/bin/docker-compose down
echo "harbor仓库已停止!" > /var/log/harbor/stop/log.$(date +%Y%m%d%H%M)

####
[root@k8s-master ~]# chmod +x /home/k8s-data/harbor/start-harbor.sh
[root@k8s-master ~]# chmod +x /home/k8s-data/harbor/stop-harbor.sh
```

编写systemd脚本程序
```sh
[root@k8s-master ~]# vim /etc/systemd/system/harbor.service

[Unit]
# 介绍信息
Description=harbor
# 依赖服务，该字样会检测网络服务是否启动
After=network.target
# 依赖服务，依赖docker的启停，如果没启动，该字样会协助启动docker之后再启动harbor服务
Requires=docker.socket

[Service]
User=root
Group=root
# 后台允许
Type=forking
# 启动命令
ExecStart=/home/k8s-data/harbor/start-harbor.sh
# 停止命令
ExecStop=/home/k8s-data/harbor/stop-harbor.sh
TimeoutSec=0
Restart=on-failure
# 日志输出模式
StandardOutput=journal
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

测试服务是否正常
```sh
[root@k8s-master ~]# systemctl enable harbor.service
[root@k8s-master ~]# systemctl start harbor.service
[root@k8s-master ~]# systemctl stop harbor.service
[root@k8s-master ~]# systemctl restart harbor.service
[root@k8s-master ~]# systemctl status harbor.service
● harbor.service - harbor
   Loaded: loaded (/etc/systemd/system/harbor.service; enabled; vendor preset: enabled)
   Active: active (exited) since Thu 2021-09-09 11:24:56 CST; 12s ago
  Process: 26309 ExecStart=/home/k8s-data/harbor/start-harbor.sh (code=exited, status=0/SUCCESS)

Sep 09 11:24:52 tianxiang start-harbor.sh[26309]: Creating redis         ... done
Sep 09 11:24:53 tianxiang start-harbor.sh[26309]: Creating harbor-db     ... done
Sep 09 11:24:53 tianxiang start-harbor.sh[26309]: Creating harbor-core   ...
Sep 09 11:24:54 tianxiang start-harbor.sh[26309]: Creating harbor-core   ... done
Sep 09 11:24:54 tianxiang start-harbor.sh[26309]: Creating harbor-jobservice ...
Sep 09 11:24:54 tianxiang start-harbor.sh[26309]: Creating nginx             ...
Sep 09 11:24:54 tianxiang start-harbor.sh[26309]: Creating registryctl       ... done
Sep 09 11:24:55 tianxiang start-harbor.sh[26309]: Creating harbor-jobservice ... done
Sep 09 11:24:56 tianxiang start-harbor.sh[26309]: Creating nginx             ... done
Sep 09 11:24:56 tianxiang systemd[1]: Started harbor.
[root@k8s-master ~]# docker-compose ps
      Name                     Command                       State                     Ports          
------------------------------------------------------------------------------------------------------
harbor-core         /harbor/entrypoint.sh            Up (health: starting)                            
harbor-db           /docker-entrypoint.sh            Up (health: starting)                            
harbor-jobservice   /harbor/entrypoint.sh            Up (health: starting)                            
harbor-log          /bin/sh -c /usr/local/bin/ ...   Up (health: starting)   127.0.0.1:1514->10514/tcp
harbor-portal       nginx -g daemon off;             Up (health: starting)                            
nginx               nginx -g daemon off;             Up (health: starting)   0.0.0.0:180->8080/tcp    
redis               redis-server /etc/redis.conf     Up (health: starting)                            
registry            /home/harbor/entrypoint.sh       Up (health: starting)                            
registryctl         /home/harbor/start.sh            Up (health: starting)
```
登录harbor仓库测试
```sh
[root@k8s-master ~]# docker login 10.0.0.11:180
Username: admin
Password: Harbor12345 默认
Authenticating with existing credentials...
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```
