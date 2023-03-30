---
layout: post
title:  集群服务03-LVS+keepalived高可用集群
date: 2020-11-20
tags: Linux-集群服务
---

## 一、Keepalived 工具介绍

> 专为 LVS 和 HA 设计的一款健康检查工具

- 支持故障自动切换(Failover)
- 支持节点健康状态检查(Health Checking)
- 官方网站:http://www.keepalived.org/

![img](/images/posts/集群服务/集群服务03-LVS+keepalived高可用集群/1.png)

## 二、Keepalived 实现原理剖析

> Keepalived 采用 VRRP 热备份协议实现 Linux 服务器的多机热备功能。
>
> VRRP，虚拟路由冗余协议，是针对路由器的一种备份解决方案。由多台路由器组成一 个热备组，通过共用的虚拟 IP 地址对外提供服务。每个热备组内同一时刻只有一台主路由 器提供服务，其他路由器处于冗余状态。若当前在线的路由器失败，则其他路由器会根据设 置的优先级自动接替虚拟 IP 地址，继续提供服务。

![img](/images/posts/集群服务/集群服务03-LVS+keepalived高可用集群/2.png)

## 三、Keepalived+LVS+DR+ NFS+Raid5+LVM 高可用负载均衡群集

### 实验环境:

|     名称      |        IP（网卡）         | 描述 |
| :-----------: | :-----------------------: | :--: |
| 主负载均衡器  | 192.168.100.10/24(vmnet1) | BLM  |
| 从负载均衡器  | 192.168.100.20/24(vmnet1) | BLS  |
|     Web1      | 192.168.100.30/24(vmnet1) | Web1 |
|     Web2      | 192.168.100.40/24(vmnet1) | Web2 |
| NFS+Raid5+LVM | 192.168.100.50/24(vmnet1) | NFS  |
|      VIP      |     192.168.100.66/32     |      |

![img](/images/posts/集群服务/集群服务03-LVS+keepalived高可用集群/3.png)

### 1.Web1配置

```
[root@web1 ~]# ip a|grep ens33

2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet 192.168.100.30/24 brd 192.168.100.255 scope global noprefixroute ens33

[root@web1 ~]# yum -y install httpd

[root@web1 ~]# sed -i "/#S/ s/#//" /etc/httpd/conf/httpd.conf

[root@web1 ~]# systemctl start httpd

[root@web1 ~]# systemctl enable httpd

[root@web1 ~]# echo "1111" >>/var/www/html/index.html

[root@web1 ~]# yum -y install net-tools

[root@web1 ~]# vim /opt/lvs-dr.sh

#!/bin/bash
# lvs-dr
VIP="192.168.100.66"
/sbin/ifconfig lo:0 $VIP broadcast $VIP netmask 255.255.255.255
/sbin/route add -host $VIP dev lo:0
echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore
echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce
echo 1 >/proc/sys/net/ipv4/conf/all/arp_ignore
echo 2 >/proc/sys/net/ipv4/conf/all/arp_announce

[root@web1 ~]# chmod +x /opt/lvs-dr.sh

[root@web1 ~]# /opt/lvs-dr.sh

[root@web1 ~]# ip a

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet 192.168.100.66/32 brd 192.168.100.66 scope global lo:0
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever

2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:25:68:3f brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.30/24 brd 192.168.100.255 scope global noprefixroute ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::eb19:a2af:11b5:a47a/64 scope link noprefixroute
       valid_lft forever preferred_lft forever

[root@web1 ~]# echo "/opt/lvs-dr.sh" >>/etc/rc.local
```

### 2.Web2配置

```
[root@web2 ~]# ip a|grep ens33

2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet 192.168.100.40/24 brd 192.168.100.255 scope global noprefixroute ens33

[root@web2 ~]# yum -y install httpd

[root@web2 ~]# sed -i "/#S/ s/#//" /etc/httpd/conf/httpd.conf

[root@web2 ~]# systemctl start httpd

[root@web2 ~]# systemctl enable httpd

[root@web2 ~]# echo "2222" >>/var/www/html/index.html

[root@web2 ~]# yum -y install net-tools

[root@web2 ~]# vim /opt/lvs-dr.sh

#!/bin/bash
# lvs-dr
VIP="192.168.100.66"
/sbin/ifconfig lo:0 $VIP broadcast $VIP netmask 255.255.255.255
/sbin/route add -host $VIP dev lo:0
echo 1 > /proc/sys/net/ipv4/conf/lo/arp_ignore
echo 2 > /proc/sys/net/ipv4/conf/lo/arp_announce
echo 1 >/proc/sys/net/ipv4/conf/all/arp_ignore
echo 2 >/proc/sys/net/ipv4/conf/all/arp_announce

[root@web1 ~]# chmod +x /opt/lvs-dr.sh

[root@web1 ~]# /opt/lvs-dr.sh

[root@web1 ~]# ip a

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet 192.168.100.66/32 brd 192.168.100.66 scope global lo:0
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever

2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:25:68:3f brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.40/24 brd 192.168.100.255 scope global noprefixroute ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::eb19:a2af:11b5:a47a/64 scope link noprefixroute
       valid_lft forever preferred_lft forever

[root@web1 ~]# echo "/opt/lvs-dr.sh" >>/etc/rc.local
```

### 3.主负载均衡器(BLM)配置

```
[root@blm ~]# ip a|grep ens33

2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet 192.168.100.10/24 brd 192.168.100.255 scope global noprefixroute ens33

[root@blm ~]# modprobe ip_vs

[root@blm ~]# yum -y install ipvsadm keepalived

[root@blm ~]# cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak

[root@blm ~]# vim /etc/keepalived/keepalived.conf    

! Configuration File for keepalived

global_defs {			//全局配置
   notification_email {
     xiahediyijun@163.com			//报警邮件地址，每行一个
   }
   notification_email_from root@blm.zhentianxiang.com			//设置邮件的发送地址
   smtp_server 127.0.0.1			//设置smtp server地址
   smtp_connect_timeout 30			//设置连接smtp服务器超时时间，30秒
   router_id LVS_DEVEL_BLM			//运行Keepalived服务器标识，发邮件显示在邮件标题中的信息，Backup（Slave）服务器将此项改为LVS_DEVEL_BLS
}

vrrp_instance VI_1 {			//VRRP实例定义部分
    state MASTER			//指定Keepalived的角色，MASTER表示主服务器，BACKUP或SLAVE表示备用服务器
    interface ens33			//指定HA检测网络的接口
    virtual_router_id 51			//虚拟路由标识，这个标识是一个数字，并且同一个VRRP实例使用唯一的标识，即同一个VRRP_instance下，MASTER和BACKUP必须是一致的
    priority 100			//优先级1-254，数字越大优先级越高，主服务器一定要高过备份服务器，且俩者之间的数值差越小越好，如此MASTER优先级100，BACKUP可设为99
    advert_int 2			//设置MASTER与BACKUP负载均衡器之间同步检查的间隔时间2秒
    authentication {			//设定验证类型和密码
        auth_type PASS			//设置验证类型，主要有PASS和AH俩种
        auth_pass 1111			//设置验证密码，在一个VRRP_instance下，MASTER与BACKUP必须使用相同的密码才能正常通信
    }
    virtual_ipaddress {			//设置虚拟IP地址，可以设置多个虚拟IP地址，每行一个
        192.168.100.66
    }
}

virtual_server 192.168.100.66 80 {			//设置虚拟服务器，需要指定虚拟ip地址和服务端口，ip与端口之间用空格隔开
    delay_loop 2			//设置健康检查时间，2秒
    lb_algo rr			//设置负载调度算法，这里设置为rr，即轮询算法
    lb_kind DR			//设置LVS实现负载均衡的机制，可以有NAT、TUN和DR三个模式
!   nat_mask 255.255.255.0			//若非使用NAT模式，此行需要注释掉
!   persistence_timeout 300			//存留超时时间，300秒，即客户机连接成功后，300秒后才会切换服务器。
    protocol TCP			//指定转发协议，TCP或UDP

    real_server 192.168.100.30 80 {			//设置真实服务器，需要指定真实IP地址和服务端口，ip与端口之间用空格隔开
        weight 1			//设置服务器节点的权值，权值大小用数字表示，数字越大，权值越高，设置权值的大小可以为不同性能的服务器分配不同的负载，可以对性能高的服务器设置较高的权值，而对性能较低的服务器设置相对较低的权值，这样就合理的利用和分配了系统资源
        TCP_CHECK{			//realserver的状态监测设置部分，单位是秒
            connect_timeout 10			//10秒无响应超时
            nb_get_retry 3			//重试次数
            delay_before_retry 3			//俩次重试的间隔为3秒
            connect_port 80			//测试连接的端口
        }
    }
    real_server 192.168.100.40 80 {
        weight 1
        TCP_CHECK{
            connect_timeout 10
            nb_get_retry 3
            delay_before_retry 3
            connect_port 80
        }
    }

}


[root@blm ~]# systemctl start keepalived.service

[root@blm ~]# ipvsadm -ln

IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.100.66:80 rr persistent 50
  -> 192.168.100.30:80            Route   1      0          0
  -> 192.168.100.40:80            Route   1      0          0

[root@blm ~]# ip a


1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:93:b0:e8 brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.10/24 brd 192.168.100.255 scope global noprefixroute ens33
       valid_lft forever preferred_lft forever
    inet 192.168.100.66/32 scope global ens33
       valid_lft forever preferred_lft forever
```

### 4.从负载均衡器(BLS)配置

```
[root@bls ~]# ip a |grep ens33

2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    inet 192.168.100.20/24 brd 192.168.100.255 scope global noprefixroute ens33

[root@bls ~]# modprobe ip_vs

[root@bls ~]# yum -y install ipvsadm keepalived

[root@bls ~]# mv /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf.bak

[root@bls ~]# scp root@192.168.100.10:/etc/keepalived/keepalived.conf /etc/keepalived/

The authenticity of host '192.168.100.10 (192.168.100.10)' can't be established.
ECDSA key fingerprint is SHA256:kyJL6c7K/v7dx8X+/ye5VEoJFVNQwaZSZJshODNWVu8.
ECDSA key fingerprint is MD5:ba:ce:ef:43:3b:99:98:77:6e:b8:60:0e:50:50:fb:15.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.100.10' (ECDSA) to the list of known hosts.

root@192.168.100.10's password:

keepalived.conf                                                    
100%  994     1.1MB/s   00:00


[root@bls ~]# vim /etc/keepalived/keepalived.conf

 14     state BACKUP
 15     interface ens33
 16     virtual_router_id 51
 17     priority 99

[root@bls ~]# systemctl start keepalived.service

[root@bls ~]# ip a

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:da:63:b3 brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.20/24 brd 192.168.100.255 scope global noprefixroute ens33			//并未出现IP就对了
       valid_lft forever preferred_lft forever
       
[root@bls ~]# ipvsadm -ln

IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.100.66:80 rr persistent 50
  -> 192.168.100.30:80            Route   1      0          0
  -> 192.168.100.40:80            Route   1      0          0
```

### 5.客户机测试:

![img](/images/posts/集群服务/集群服务03-LVS+keepalived高可用集群/4.png)

![img](/images/posts/集群服务/集群服务03-LVS+keepalived高可用集群/5.png)

> 多刷新几次 查看主负载均衡器记录:

```
[root@blm ~]# ipvsadm -lcn

IPVS connection entries
pro expire state       source             virtual            destination
TCP 00:56  FIN_WAIT    192.168.100.3:52192 192.168.100.66:80  192.168.100.40:80
TCP 00:10  FIN_WAIT    192.168.100.3:52179 192.168.100.66:80  192.168.100.40:80
TCP 00:10  FIN_WAIT    192.168.100.3:52180 192.168.100.66:80  192.168.100.30:80
TCP 00:56  FIN_WAIT    192.168.100.3:52193 192.168.100.66:80  192.168.100.30:80
TCP 11:35  ESTABLISHED 192.168.100.3:52163 192.168.100.66:80  192.168.100.40:80
```

> 查看从负载均衡器记录:

```
[root@bls ~]# ipvsadm -lnc

IPVS connection entries
pro expire state       source             virtual            destination
```

### 健康监测测试:

```
[root@blm ~]# ipvsadm -ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.100.66:80 rr
  -> 192.168.100.30:80            Route   1      0          0
  -> 192.168.100.40:80            Route   1      1          0
```

> 关闭 web2 的 httpd 服务

```
[root@web2 ~]# systemctl stop httpd

[root@blm ~]# ipvsadm -ln

IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.100.66:80 rr
  -> 192.168.100.30:80            Route   1      0          0
#发现web2的记录不见了
#再开启web2的httpd服务

[root@web2 ~]# systemctl start httpd

[root@blm ~]# ipvsadm -ln

IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.100.66:80 rr
  -> 192.168.100.30:80            Route   1      0          0
  -> 192.168.100.40:80            Route   1      1          0
#web2的记录又回来了
```

### 7.高可用测试

```
暂停主负载均衡的keepalived

[root@blm ~]# systemctl stop keepalived

[root@bls ~]# ip a

1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:da:63:b3 brd ff:ff:ff:ff:ff:ff
    inet 192.168.100.20/24 brd 192.168.100.255 scope global noprefixroute ens33
       valid_lft forever preferred_lft forever
    inet 192.168.100.66/32 scope global ens33
       valid_lft forever preferred_lft forever

[root@bls ~]# ipvsadm -ln

IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  192.168.100.66:80 rr
  -> 192.168.100.30:80            Route   1      0          0
  -> 192.168.100.40:80            Route   1      0          0
```

![img](/images/posts/集群服务/集群服务03-LVS+keepalived高可用集群/4.png)

![img](/images/posts/集群服务/集群服务03-LVS+keepalived高可用集群/5.png)

> 客户机可以正常访问 恢复主负载均衡器的服务，VIP 将会回到 BLM 上

### 8.NFS+Raid5+LVM 配置

> (1)软 Raid5

```
[root@nfs ~]# fdisk -l |grep /dev

磁盘 /dev/sda：64.4 GB, 64424509440 字节，125829120 个扇区
/dev/sda1   *        2048     2099199     1048576   83  Linux
/dev/sda2         2099200   125829119    61864960   8e  Linux LVM
磁盘 /dev/sdb：2147 MB, 2147483648 字节，4194304 个扇区
磁盘 /dev/sdc：2147 MB, 2147483648 字节，4194304 个扇区
磁盘 /dev/sdd：2147 MB, 2147483648 字节，4194304 个扇区
磁盘 /dev/sde：2147 MB, 2147483648 字节，4194304 个扇区
磁盘 /dev/mapper/centos-root：41.1 GB, 41120956416 字节，80314368 个扇区
磁盘 /dev/mapper/centos-swap：2147 MB, 2147483648 字节，4194304 个扇区
磁盘 /dev/mapper/centos-home：20.1 GB, 20073938944 字节，39206912 个扇区

[root@nfs ~]# parted /dev/sdb

GNU Parted 3.1
使用 /dev/sdb
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) p
错误: /dev/sdb: unrecognised disk label
Model: VMware, VMware Virtual S (scsi)
Disk /dev/sdb: 2147MB
Sector size (logical/physical): 512B/512B
Partition Table: unknown
Disk Flags:
(parted) mklabel
新的磁盘标签类型？ gpt
(parted) p
Model: VMware, VMware Virtual S (scsi)
Disk /dev/sdb: 2147MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start  End  Size  File system  Name  标志

(parted) mkpart
分区名称？  []? part1
文件系统类型？  [ext2]?
起始点？ 1
结束点？ -1
(parted) p
Model: VMware, VMware Virtual S (scsi)
Disk /dev/sdb: 2147MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt
Disk Flags:

Number  Start   End     Size    File system  Name   标志
 1      1049kB  2146MB  2145MB               part1

(parted) q
#同样的方法对/dev/sd[c-e]进行分区(略)

[root@nfs ~]# ls /dev/sdb*

/dev/sdb  /dev/sdb1

[root@nfs ~]# ls /dev/sdc*

/dev/sdc  /dev/sdc1

[root@nfs ~]# ls /dev/sdd*

/dev/sdd  /dev/sdd1

[root@nfs ~]# ls /dev/sde*

/dev/sde  /dev/sde1

[root@nfs ~]# yum -y install mdadm

[root@nfs ~]# mdadm -Cv /dev/md5 -a yes -n3 -x1 -l5 /dev/sd[b-e]1

mdadm: layout defaults to left-symmetric
mdadm: layout defaults to left-symmetric
mdadm: chunk size defaults to 512K
mdadm: size set to 2093056K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md5 started.

[root@nfs ~]# mkfs.xfs /dev/md5

meta-data=/dev/md5               isize=512    agcount=8, agsize=130688 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=1045504, imaxpct=25
         =                       sunit=128    swidth=256 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

[root@nfs ~]# mdadm -D -s

ARRAY /dev/md5 metadata=1.2 spares=1 name=nfs:5 UUID=3c682f46:ea36f472:1f7e8cf3:b08377b9

[root@nfs ~]# sed -i '1 s/$/ auto=yes/' /etc/mdadm.conf
```

> (2)LVM

```
[root@nfs ~]# pvcreate /dev/md5

WARNING: xfs signature detected on /dev/md5 at offset 0. Wipe it? [y/n]: y
  Wiping xfs signature on /dev/md5.
  Physical volume "/dev/md5" successfully created.

[root@nfs ~]# vgcreate vg0 /dev/md5

  Volume group "vg0" successfully created

[root@nfs ~]# lvcreate -L 1G -n web vg0

  Logical volume "web" created.

[root@nfs ~]# mkfs.xfs /dev/vg0/web

meta-data=/dev/vg0/web           isize=512    agcount=8, agsize=32640 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=261120, imaxpct=25
         =                       sunit=128    swidth=256 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=624, version=2
         =                       sectsz=512   sunit=8 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

[root@nfs ~]# mkdir /web

[root@nfs ~]# mount /dev/vg0/web /web/

[root@nfs ~]# echo "<h1>www.linuxli.com</h1>" >/web/index.html

[root@nfs ~]# cp -p /etc/fstab /etc/fstab.bak

[root@nfs ~]# vim /etc/fstab

....
/dev/mapper/vg0-web     /web                    xfs     defaults        0 0

[root@nfs ~]# umount -a

umount: /：目标忙。
        (有些情况下通过 lsof(8) 或 fuser(1) 可以
         找到有关使用该设备的进程的有用信息)
umount: /sys/fs/cgroup/systemd：目标忙。
        (有些情况下通过 lsof(8) 或 fuser(1) 可以
         找到有关使用该设备的进程的有用信息)
umount: /sys/fs/cgroup：目标忙。
        (有些情况下通过 lsof(8) 或 fuser(1) 可以
         找到有关使用该设备的进程的有用信息)
umount: /run：目标忙。
        (有些情况下通过 lsof(8) 或 fuser(1) 可以
         找到有关使用该设备的进程的有用信息)
umount: /dev：目标忙。
        (有些情况下通过 lsof(8) 或 fuser(1) 可以
         找到有关使用该设备的进程的有用信息)

[root@nfs ~]# mount -a

[root@nfs ~]# df -hT
文件系统                类型      容量  已用  可用 已用% 挂载点
/dev/mapper/centos-root xfs        39G  1.7G   37G    5% /
devtmpfs                devtmpfs  476M     0  476M    0% /dev
tmpfs                   tmpfs     488M  7.7M  480M    2% /run
tmpfs                   tmpfs     488M     0  488M    0% /sys/fs/cgroup
/dev/sda1               xfs      1014M  159M  856M   16% /boot
/dev/mapper/centos-home xfs        19G   33M   19G    1% /home
/dev/mapper/vg0-web     xfs      1018M   33M  986M    4% /web
```

> (3)NFS

```
[root@nfs ~]# yum -y install nfs-utils rpcbind

[root@nfs ~]# vim /etc/exports

/web    192.168.100.0/24(rw,sync,no_root_squash)

[root@nfs ~]# systemctl start rpcbind

[root@nfs ~]# systemctl start nfs

[root@nfs ~]# showmount -e 192.168.100.50

Export list for 192.168.100.50:
/web 192.168.100.0/24
```

> web1、web2 挂载

```
[root@web1 ~]# cp -p /etc/fstab /etc/fstab.bak

[root@web1 ~]# vim /etc/fstab

......
192.168.100.50:/web     /var/www/html           nfs     defaults,_netdev        0 0

[root@web1 ~]# yum -y install nfs-utils

[root@web1 ~]# mount -a

[root@web1 ~]# df -hT

......
192.168.100.50:/web     nfs4     1018M   33M  986M    4% /var/www/html


[root@web2 ~]# cp /etc/fstab /etc/fstab.bak

[root@web2 ~]# vim /etc/fstab

......
192.168.100.50:/web     /var/www/html           nfs     defaults,_netdev        0 0

[root@web2 ~]# yum -y install nfs-utils

[root@web2 ~]# mount -a

[root@web2 ~]# df -hT

......
192.168.100.50:/web     nfs4     1018M   33M  986M    4% /var/www/html
```

### 客户机测试:

![img](/images/posts/集群服务/集群服务03-LVS+keepalived高可用集群/6.png)

```
[root@blm ~]# ipvsadm -lnc

IPVS connection entries
pro expire state       source             virtual            destination
TCP 01:30  FIN_WAIT    192.168.100.3:52349 192.168.100.66:80  192.168.100.40:80
TCP 01:46  FIN_WAIT    192.168.100.3:52351 192.168.100.66:80  192.168.100.40:80
TCP 01:36  FIN_WAIT    192.168.100.3:52350 192.168.100.66:80  192.168.100.30:80
TCP 14:58  ESTABLISHED 192.168.100.3:52354 192.168.100.66:80  192.168.100.30:80
```
