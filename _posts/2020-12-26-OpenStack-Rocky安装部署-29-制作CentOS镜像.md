---
layout: post
title: OpenStack-Rocky安装部署-29-制作CentOS镜像
date: 2020-12-26
tags: 云计算
---

## 前提：开启CPU支持虚拟化服务，内存4G

本文以制作CentOS7.2镜像为例，详细介绍手动制作OpenStack镜像详细步骤，解释每一步这么做的原因。镜像上传到OpenStack glance，支持以下几个功能：

- 支持密码注入功能(nova boot时通过--admin-pass参数指定设置初始密码）
- 支持根分区自动调整(根分区自动调整为flavor disk大小，而不是原始镜像分区大小)
- 支持动态修改密码(使用nova set-password命令可以修改管理员密码)

手动制作镜像非常麻烦和耗时，本文后面会介绍一个专门用于自动化构建镜像的项目DIB，通过DIB只需要在命令行上指定elements即可制作镜像，省去了重复下载镜像、启动虚拟机配置镜像的繁杂步骤。

镜像的宿主机操作系统为CentOS7.6，开启了VT功能(使用kvm-ok命令验证)并安装了libvirt系列工具，包括virsh。

> 注意：当前实验操作我在controller节点上做的，你完全可以另起一台主机，之后把qcow2文件拷贝过去即可

### 1.安装部署libvirt

```
[root@controller ~]# yum install virt-install.noarch libguestfs-tools

[root@controller ~]# groupadd libvirtd

[root@controller ~]# usermod -a -G libvirtd $USER

[root@controller ~]# vi /etc/libvirt/libvirtd.conf
找到第85行的unix_sock_group，把注释去掉，把libvirt，修改为libvirtd
85 unix_sock_group = "libvirtd"

[root@controller ~]# vi /etc/polkit-1/localauthority/50-local.d/50-org.libvirtd-group-access.pkla
[libvirtd group Management Access]
Identity=unix-group:libvirtd
Action=org.libvirt.unix.manage
ResultAny=yes
ResultInactive=yes
ResultActive=yes


[root@controller ~]# systemctl restart libvirtd.service
```

### 2.给虚拟机创建一个网络

```
手动创建镜像需要确保libvirt运行有default网络，这个网络可以给虚拟机提供上网服务。

查看当前是否启用default网络
[root@compute ~]# virsh net-list
 Name                 State      Autostart     Persistent
----------------------------------------------------------
 default active yes yes


 注：如果没有启用，使用以下命令启用default
 virsh net-start default

[root@controller ~]# virsh net-start default
错误：获得网络 'default' 失败
错误：未找到网络: 没有网络与名称 'default' 映射

这是因为libvirt没有创建default网络， 手动创建即可
[root@compute ~]# vim /etc/libvirt/qemu/networks/default.xml
<network>
  <name>default</name>
  <bridge name="virbr0" />
  <forward/>
  <ip address="192.168.122.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.122.2" end="192.168.122.254" />
    </dhcp>
  </ip>
</network>

定义指定的虚拟网络文件：
[root@compute ~]# virsh net-define /etc/libvirt/qemu/networks/default.xml

[root@compute ~]# systemctl  restart  libvirtd

标记自动启动：
 [root@cloud networks]# virsh net-autostart default


启动网络：
[root@cloud networks]# virsh net-start default

[root@controller ~]# brctl show
bridge name	bridge id		STP enabled	interfaces
brq76b5c1c6-79		8000.000c299fc959	no		ens33
							tap98c255ed-6d
virbr0		8000.5254006f8d7c	yes		virbr0-nic

[root@controller ~]# ifconfig

virbr0: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        inet 192.168.122.1  netmask 255.255.255.0  broadcast 192.168.122.255
        ether 52:54:00:6f:8d:7c  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

virbr0-nic: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        ether 52:54:00:6f:8d:7c  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

### 3.创建虚拟机

```
(1)创建一个目录上传iso镜像到/data目录

[root@controller ~]# mkdir -p /data
[root@controller ~]# wget http://220.195.2.232:8080/iso/centos/CentOS-7.6-x86_64-bin-DVD.iso

(2)创建一个10G的磁盘文件给虚拟机使用
[root@controller ~]# qemu-img create -f qcow2 /data/CentOS-7.6_1810_x86.qcow2 10G

(3)安装
[root@controller ~]# virt-install --virt-type kvm --name centos7.6_x86_64 --ram 1024 \
 --disk /data/CentOS-7.6_1810_x86.qcow2,format=qcow2 \
 --network network=default \
 --graphics vnc,listen=0.0.0.0 --noautoconsole \
 --os-type=linux \
 --location=/iso/CentOS-7.6-x86_64-bin-DVD.iso
```

![](/images/posts/云计算/Train版本部署/自定义镜像/1.png)

![1](/images/posts/云计算/Train版本部署/自定义镜像/2.png)

![1](/images/posts/云计算/Train版本部署/自定义镜像/3.png)

这个网络就是你在上面配置的网络

![](/images/posts/云计算/Train版本部署/自定义镜像/4.png)

如果安装过程中发现自己的选错了可以结束重新安装

```
[root@controller ~]# virsh list --all
 Id    名称                         状态
----------------------------------------------------
 -     centos7.4_x86_64               关闭

[root@controller ~]# virsh destroy centos7.4_x86_64
域 centos7.4_x86_64 被删除

[root@controller ~]# virt-install --virt-type kvm --name centos7.6_x86_64 --ram 1024 \
 --disk /data/centos.qcow2,format=qcow2 \
 --network network=default \
 --graphics vnc,listen=0.0.0.0 --noautoconsole \
 --os-type=linux \
 --location=/iso/CentOS-7.6-x86_64-bin-DVD.iso
```

![](/images/posts/云计算/Train版本部署/自定义镜像/5.png)

```
vnc点击重启不会生效，需要在宿主机进行重启

[root@controller ~]# virsh list --all
 Id    名称                         状态
----------------------------------------------------
 -     centos7.4_x86_64               关闭

[root@controller ~]# virsh start centos7.4_x86_64
域 centos7.4_x86_64 已开始
```

### 4.接下来可以自定义您的镜像了

![](/images/posts/云计算/Train版本部署/自定义镜像/6.png)

### 5.把制作好的qcow2镜像上传到glance中

```
[root@controller data]# ls
CentOS-7.6-x86_64-bin-DVD.iso  centos.qcow2
[root@controller data]# du -sh centos.qcow2
1.8G	centos.qcow2
[root@controller data]# mv centos.qcow2 /var/lib/glance/images/
[root@controller data]# ls /var/lib/glance/images/
CentOS-7-x86_64-GenericCloud-1801-01.qcow2c
[root@controller ~]# glance image-create "CentOS_7.6_x86_64_1801" \
  --file /var/lib/glance/images/centos.qcow2
  --disk-format qcow2 --container-format bare \
  --public
[root@controller ~]# openstack image list
+--------------------------------------+------------------------+--------+
| ID                                   | Name                   | Status |
+--------------------------------------+------------------------+--------+
| 1f68d230-8401-426b-a91f-358a31448446 | CentOS_7.6_x86_64_1801 | active |
+--------------------------------------+------------------------+--------+
```
