---
layout: post
title: 2023-02-13-Docker-启动-OpenWRT-软路由
date: 2023-02-13
tags: 其他
music-id: 25639007
---

## 一、环境说明

- 宿主机 IP：192.168.229.135
- Docker 内 openWrt macvlan ip: 192.168.229.111
- 主路由网关：192.168.229.2
- 机器网段为: 192.168.229.0/24
- docker 使用容器: `raymondwong/openwrt_r9:21.2.1-x86_64`
- 操作系统: `centos7-x86_64`

VMware workstation 使用 centos 启动 openWRT 做为主路由的旁路由

以次文章作为教学参考，实际应该还需要物理设备来充当软路由，因为使用虚拟机启动的 openWRT 只能在本机能用，没办法使其他设备联网

主路由模式如下，然后 openWRT 页面中接口设置中的 WAN 口上网选择 PPOE 拨号上网

![0](/images/posts/other/openWRT/0.png)

### 1. 配置安装源和 Docker

```sh
# 安装 dokcer-compose,首先安装好epel源和docker源
[root@localhost openwrt]# wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
[root@localhost openwrt]# yum install -y epel-release
[root@localhost openwrt]# yum -y install docker-compose && yum -y install docker-ce-19.03.15 docker-ce-cli-19.03.15 containerd.io

# 启动docker
[root@localhost openwrt]# systemctl enable docker --now
[root@localhost openwrt]# cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2",
  "insecure-registries": ["registry.access.redhat.com","quay.io"],
  "registry-mirrors": ["https://q2gr04ke.mirror.aliyuncs.com"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "live-restore": true
}
EOF
[root@localhost openwrt]# systemctl restart docker
```

### 2. 启动 openWRT

```sh
# 开启网卡混淆模式
[root@localhost openwrt]# ip link set ens33 promisc on
[root@localhost openwrt]# cat > docker-compose.yaml <<EOF
version: '2'

services:
  openwrt:
    image: raymondwong/openwrt_r9:21.2.1-x86_64
    container_name: openwrt_r9
    privileged: true
    restart: always
    networks:
      openwrt_macnet:
        ipv4_address: 192.168.229.111

networks:
  openwrt_macnet:
    driver: macvlan
    driver_opts:
      parent: ens33 # 对应桥接的网卡
    ipam:
      config:
        - subnet: 192.168.229.0/24
          ip_range: 192.168.229.220/25  #这个不清楚是啥
          gateway: 192.168.229.2 #主路由网关
EOF

# 容器启动后，默认的 ip 地址使用的是 192.168.1.254，与我们局域网网段不在一个段，这里需要去更改一下 ip 地址 和 网关地址
[root@localhost openwrt]# docker exec -it openwrt_r9 bash -c "sed -i 's#192.168.1.254#192.168.229.111#g;s#192.168.1.1#192.168.229.2#g' /etc/config/network" \
&& docker restart openwrt_r9
```

### 3. 验证网络通信

```sh
[root@localhost openwrt]# docker exec -it openwrt_r9 bash -c "cat /etc/config/network"

config interface 'loopback'
	option ifname 'lo'
	option proto 'static'
	option ipaddr '127.0.0.1'
	option netmask '255.0.0.0'

config globals 'globals'
	option ula_prefix 'fdc4:0ac4:85d4::/48'
	option packet_steering '1'

config interface 'lan'
	option ifname 'eth0'
	option proto 'static'
	option ipaddr '192.168.229.111'
	option netmask '255.255.255.0'
	option gateway '192.168.229.2'
	option dns '192.168.229.2'
	option ip6assign '60'

config interface 'vpn0'
	option ifname 'tun0'
	option proto 'none'

[root@localhost openwrt]# docker exec -it openwrt_r9 bash -c "ping -c 3 baidu.com"
PING baidu.com (110.242.68.66): 56 data bytes
64 bytes from 110.242.68.66: seq=0 ttl=128 time=10.616 ms
64 bytes from 110.242.68.66: seq=1 ttl=128 time=10.479 ms
64 bytes from 110.242.68.66: seq=2 ttl=128 time=10.792 ms

# ping 容器网络不通信
[root@localhost openwrt]# ping 192.168.229.111
PING 192.168.229.111 (192.168.229.111) 56(84) bytes of data.
^C
--- 192.168.229.111 ping statistics ---
2 packets transmitted, 0 received, 100% packet loss, time 999ms

# 容器ping宿主机也不通信
[root@localhost openwrt]# docker exec -it openwrt_r9 bash -c "ping 192.168.229.135"
PING 192.168.229.135 (192.168.229.135): 56 data bytes
```

### 4. 网络通信问题解决

> 原因是部署 openWRT 系统时使用到了 `docker` 的 `macvlan` 模式，这个模式通俗一点讲就是在一张物理网卡上虚拟出两个虚拟网卡，具有不同的MAC地址，可以让宿主机和docker同时接入网络并且使用不同的ip，此时 docker 可以直接和同一网络下的其他设备直接通信，相当的方便，但是这种模式有一个问题，宿主机和容器是没办法直接进行网络通信的，如宿主机ping容器的ip，尽管他们属于同一网段，但是也是ping不通的，反过来也是。因为该模式在设计的时候，为了安全禁止了宿主机与容器的直接通信，不过解决的方法其实也很简单——宿主机虽然没办法直接和容器内的 `macvlan` 接口通信，但是只要在宿主机上再建立一个 `macvlan`，然后修改路由，使数据经由该 `macvlan` 传输到容器内的 `macvlan` 即可，`macvlan` 之间是可以互相通信的。

```sh
[root@localhost openwrt]# ip link add mynet link ens33 type macvlan mode bridge
[root@localhost openwrt]# ip link set mynet up
[root@localhost openwrt]# ip addr add 192.168.229.10 dev mynet
[root@localhost openwrt]# ip route add 192.168.299.11 dev mynet

# 可以看到源地址为任何地址都可以通过mynet设备访问192.168.229.111
[root@localhost openwrt]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         192.168.229.2   0.0.0.0         UG    100    0        0 ens33
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0
192.168.229.0   0.0.0.0         255.255.255.0   U     100    0        0 ens33
192.168.229.111 0.0.0.0         255.255.255.255 UH    0      0        0 mynet
[root@localhost openwrt]# docker exec -it openwrt_r9 bash -c "ping -c 3 192.168.229.135"
PING 192.168.229.135 (192.168.229.135): 56 data bytes
64 bytes from 192.168.229.135: seq=0 ttl=64 time=0.086 ms
64 bytes from 192.168.229.135: seq=1 ttl=64 time=0.100 ms
64 bytes from 192.168.229.135: seq=2 ttl=64 time=0.097 ms
[root@localhost openwrt]# ping 192.168.229.111
PING 192.168.229.111 (192.168.229.111) 56(84) bytes of data.
64 bytes from 192.168.229.111: icmp_seq=1 ttl=64 time=0.083 ms
64 bytes from 192.168.229.111: icmp_seq=2 ttl=64 time=0.068 ms
64 bytes from 192.168.229.111: icmp_seq=3 ttl=64 time=0.074 ms

# 写入开机自启
[root@localhost openwrt]# cat >> /etc/rc.local << EOF
ip link add mynet link ens33 type macvlan mode bridge
ip addr add 192.168.229.10 dev mynet
ip link set mynet up
ip route add 192.168.229.111 dev mynet
EOF

[root@localhost openwrt]# chmod a+x /etc/rc.local
```

## 二、openWRT 配置

### 1. 页面配置

![1](/images/posts/other/openWRT/1.png)

![2](/images/posts/other/openWRT/2.png)

![3](/images/posts/other/openWRT/3.png)

![4](/images/posts/other/openWRT/4.png)

![5](/images/posts/other/openWRT/5.png)

![6](/images/posts/other/openWRT/6.png)

![7](/images/posts/other/openWRT/7.png)

### 2. 验证

![8](/images/posts/other/openWRT/8.png)

![9](/images/posts/other/openWRT/9.png)

## 三、openWRT 命令行操作

### 1. ssh 远程

![10](/images/posts/other/openWRT/10.png)

### 2. 安装 wakeonlan

该命令可以发送魔幻数据包（远程对主机进行开机）

```sh
root@OpenWrt:~# opkg update
root@OpenWrt:~# opkg install wakeonlan
Installing wakeonlan (0.41-1) to root...
```

### 3. 文件传输

![11](/images/posts/other/openWRT/11.png)

### 4. 配置 frpc 客户端

```sh
root@OpenWrt:~# cd /tmp/upload/
root@OpenWrt:/tmp/upload# ls
frp_0.46.1_linux_amd64.tar.gz
root@OpenWrt:/tmp/upload# ls
frp_0.46.1_linux_amd64         frp_0.46.1_linux_amd64.tar.gz
root@OpenWrt:/tmp/upload# cd frp_0.46.1_linux_amd64
root@OpenWrt:/tmp/upload/frp_0.46.1_linux_amd64# rm -rf frps*
root@OpenWrt:/tmp/upload/frp_0.46.1_linux_amd64# cat frpc.ini
[common]
server_addr = xxxxxxxx # 公网IP地址
server_port = 7000
token = xxxxxxxxx

[ssh]
type = tcp
local_ip = 192.168.20.250
local_port = 22
remote_port = 7022
root@OpenWrt:/tmp/upload/frp_0.46.1_linux_amd64# ./frpc -c frpc.ini &
root@OpenWrt:/tmp/upload/frp_0.46.1_linux_amd64# 2023/02/13 13:31:07 [I] [service.go:298] [565e8f517411303c] login to server success, get run id [565e8f517411303c], server udp port [0]
2023/02/13 13:31:07 [I] [proxy_manager.go:142] [565e8f517411303c] proxy added: [ssh]
2023/02/13 13:31:07 [I] [control.go:172] [565e8f517411303c] [ssh] start proxy success
```

验证登陆

```sh
[root@localhost ~]# ssh -p 7022 root@x.x.x.x
root@blog.linuxtian.tops password:


BusyBox v1.31.1 () built-in shell (ash)

  _______                     ________        __
 |       |.-----.-----.-----.|  |  |  |.----.|  |_
 |   -   ||  _  |  -__|     ||  |  |  ||   _||   _|
 |_______||   __|_____|__|__||________||__|  |____|
          |__| W I R E L E S S   F R E E D O M
 -----------------------------------------------------
 OpenWrt SNAPSHOT, r3092-a38300a09
 -----------------------------------------------------

 # 然后就可以使用 wakeonlan 来激活内网主机设备了
 root@OpenWrt:~# wakeonlan mac地址
```
