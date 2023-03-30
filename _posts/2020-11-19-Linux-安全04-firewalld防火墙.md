---
layout: post
title:  Linux-安全04-firewalld防火墙
date: 2020-11-19
tags: Linux-安全
---

## 一、Firewalld概述

> Filewalld（动态防火墙）作为redhat7系统中变更对于netfilter内核模块的管理工具

- iptables service 管理防火墙规则的模式（静态）：

> 用户将新的防火墙规则添加进 /etc/sysconfig/iptables 配置文件当中，再执行命令 /etc/init.d/iptables reload 使变更的规则生效。在这整个过程的背后，iptables service 首先对旧的防火墙规则进行了清空，然后重新完整地加载所有新的防火墙规则，如果加载了防火墙的模块，需要在重新加载后进行手动加载防火墙的模块；

- firewalld 管理防火墙规则的模式（动态）:

> 任何规则的变更都不需要对整个防火墙规则列表进行重新加载，只需要将变更部分保存并更新到运行中的 iptables 即可。还有命令行和图形界面配置工具，它仅仅是替代了 iptables service 部分，其底层还是使用 iptables 作为防火墙规则管理入口。

## 二、Firewalld与iptables对比

- firewalld 是 iptables 的前端控制器
- iptables 静态防火墙 任一策略变更需要reload所有策略，丢失现有链接
- firewalld 动态防火墙 任一策略变更不需要reload所有策略 将变更部分保存到iptables,不丢失现有链接
- firewalld 提供一个daemon和service 底层使用iptables
- 基于内核的Netfilter

### 1.配置方式

- firewall-config 图形界面
- firewall-cmd 命令行工具

### 2.运行时配置和永久配置

- firewall-cmd - –zone=public - –add-service=smtp 运行时配置，重启后失效
- firewall-cmd - –permanent - –zone=public - –add-service=smtp 永久配置，不影响当前连接，重启后生效
- firewall-cmd - –runtime-to-permanent 将运行时配置保存为永久配置

## 三、ZONE

|   区域   |                         默认策略规则                         |
| :------: | :----------------------------------------------------------: |
| trusted  |                       允许所有的数据包                       |
|   home   | 拒绝流入的流量，除非与流出的流量相关；如果流量与ssh、mdns、ipp-client、amba-client、与dhcpv6-client服务相关，则允许流量 |
| internal |                        等同于home区域                        |
|   work   | 拒绝流入的流量，除非与流出的流量数相关；而如果流量与ssh、ipp-client与dhcpv6-client服务相关，则允许流量 |
|  public  | 拒绝流入的流量，除非与流出的流量相关；而如果流量与ssh、dhcpv6-client服务相关，则允许流量 |
| external | 拒绝流入的流量，除非与流出流量相关；而如果流量与ssh服务相关，则允许流量 |
|   dmz    |            拒绝流入的流量，除非与流出的流量相关；            |
|  block   |            拒绝流入的流量，除非与流出的流量相关；            |
|   drop   |            拒绝流入的流量，除非与流出的流量相关；            |

### 服务管理

```
[root@tianxiang~]# yum -y install firewalld firewall-config #安装firewalld

[root@tianxiang~]# systemctl enable|disable firewalld #开机启动

[root@tianxiang~]# systemctl start|stop|restart firewalld #启动、停止、重启firewalld
```

> 如果想使用iptables配置防火墙规则，要先安装iptables并禁用firewalld

```
[root@tianxiang~]# yum -y install iptables-services #安装iptables

[root@tianxiang~]# systemctl enable iptables #开机启动

[root@tianxiang~]# systemctl start|stop|restart iptables #启动、停止、重启iptables
```

## 四、终端管理工具

### 1.firewall-cmd

> firewall-cmd命令一般使用长格式选项，所以命令比较长，但是不用担心，在7系列系统当中firewall-cmd命令的选项可以利用tab补齐

### 2.firewall-cmd命令中使用的参数以及作用

```
# 查看默认的区域名称
[root@tianxiang~]# firewall-cmd --get-default-zone

#设置默认的区域，使其永久生效
[root@tianxiang~]# firewall-cmd --set-default-zone=<区域名称>

#显示可用的区域
[root@tianxiang~]# firewall-cmd --get-zones

#显示预先定义的服务
[root@tianxiang~]# firewall-cmd --get-services

#显示当前正在使用的区域与网卡名称
[root@tianxiang~]# firewall-cmd --get-active-zones

#将源自此IP或子网的流量导向指定的区域
[root@tianxiang~]# firewall-cmd --add-source=

#不再将源自此IP或子网的流量导向指定的区域
[root@tianxiang~]# firewall-cmd --remove-source=

#将源自该网卡的所有流量都导向某个指定区域
[root@tianxiang~]# firewall-cmd --add-interface=<网卡名称>

#将某个网卡与区域进行关联
[root@tianxiang~]# firewall-cmd --change-interface=<网卡名称>

#显示当前区域的网卡配置参数、资源、端口以及服务等信息
[root@tianxiang~]# firewall-cmd --list-all

#显示所有区域的网卡配置参数，资源、端口以及服务等信息
[root@tianxiang~]# firewall-cmd --list-all-zones

#设置默认区域允许该服务的流量
[root@tianxiang~]# firewall-cmd --add-service=<服务名>

#设置默认区域允许该端口的流量
[root@tianxiang~]# firewall-cmd --add-port=<端口号/协议>

#设置默认区域不再允许该服务的流量
[root@tianxiang~]# firewall-cmd --remove-service=<服务名>

#设置默认区域不再允许该端口的流量
[root@tianxiang~]# firewall-cmd --remove-port=<端口号/协议>

#让“永久生效”的配置规则立即生效，并覆盖当前的配置规则
[root@tianxiang~]# firewall-cmd --reload

#开启应急状况模式
[root@tianxiang~]# firewall-cmd --panic-on

#关闭应急状况模式
[root@tianxiang~]# firewall-cmd --panic-off
```

### 3.命令演示

> 流量转发规则演示

```
查询firewalld是否开启转发功能
[root@tianxiang~]# firewall-cmd --permanent --query-masquerade

开启转发/反之删除就是 --remove
[root@tianxiang~]# firewall-cmd --permanent --add-masquerade

添加80端口
[root@tianxiang~]# firewall-cmd --permanent --zone=public --add-port=80/tcp

把访问本地80的流量转发到192.168.100.1服务器80端口上面
[root@tianxiang~]# firewall-cmd --add-forward-port=port=80:proto=tcp:toport=80:toaddr=192.168.100.1 --permanent

查看当前网卡下面配置参数、资源、端口以及服务等信息
[root@tianxiang~]# firewall-cmd --list-all

开启本地的内核转发功能，再第7行添加此内容
[root@tianxiang~]# vim /etc/sysctl.conf
7 net.ipv4.ip_forward = 1

[root@tianxiang ~]# sysctl -p

最后测试访问本地IP，此时流量会转发到192.168.100.1上面。
```
> 查看firewall服务当前所使用的区域

```
[root@tianxiang~]# firewall-cmd --get-default-zone

public
```

> 查询ens33网卡在firewall服务中的区域

```
[root@tianxiang~]# firewall-cmd --get-zone-of-interface=ens33

public
```

> 把firewalld服务中ens33网卡的默认区域修改为external，并在系统重启后生效，分别查看当前与永久模式下的区域名称

```
[root@tianxiang~]# firewall-cmd --permanent --zone=external --change-interface=ens33

The interface is under control of NetworkManager, setting zone to 'external'.

success

[root@tianxiang~]# firewall-cmd --get-zone-of-interface=ens33

external
```

> 启动/关闭firewalld防火墙服务的应急状况模式，阻断一切网络连接（当远程控制服务器时请慎用！）

```
[root@tianxiang~]# firewall-cmd --panic-on

success

[root@tianxiang~]# firewall-cmd --panic-off

success
```

> 查询区域是否允许请求SSH和HTTPS协议的流量：

```
[root@tianxiang~]# firewall-cmd --zone=public --query-service=ssh

yes

[root@tianxiang~]# firewall-cmd --zone=public --query-service=https

no
```

> 把firewalld服务中请求HTTPS协议的流量设置为永久允许，并立即生效：

```
[root@tianxiang~]# firewall-cmd --zone=public --add-service=https

success

[root@tianxiang~]# firewall-cmd --permanent --zone=public --add-service=https

success

[root@tianxiang~]# firewall-cmd --reload

success
```

> 把firewalld服务中请求HTTP协议的流量设置为永久拒绝，并立即生效：

```
[root@tianxiang~]# firewall-cmd --permanent --zone=public --remove-service=http

success

[root@tianxiang~]# firewall-cmd --reload

success
```

> 把在firewalld服务中访问8080和8081的端口流量策略设置为允许，但仅限当前生效：

```
[root@tianxiang~]# firewall-cmd --zone=public --add-port=8080-8081/tcp

success

[root@tianxiang~]# firewall-cmd --zone=public --list-ports

8080-8081/tcp
```

> 把原本访问本机888端口的流量转发到22端口，且要求当前和长期均有效

```
注:流量转发命令格式为firewall-cmd --permanent --zone=<区域> --add-forward-port=port=<源端口号>:porto=<协议>:toport=<目标端口号>:toaddr=<目标IP地址>

[root@tianxiang~]# firewall-cmd --permanent --zone=public --add-forward-port=port=888:proto=tcp:toport=22:toaddr=192.168.100.1

success

[root@tianxiang~]# firewall-cmd --reload

success
```

### 富规则

> firewalld中的富规则表示更细致，它可以针对系统服务、端口号、源地址和目标地址等诸多信息的策略配置。

```
firewall-cmd –list-rich-rules 列出所有规则

firewall-cmd [–zone=zone] –query-rich-rule=’rule’ 检查一项规则是否存在

firewall-cmd [–zone=zone] –remove-rich-rule=’rule’ 移除一项规则

firewall-cmd [–zone=zone] –add -rich-rule=’rule’ 新增一项规则
```

> 复杂规则配置案例

```
firewall-cmd --zone=public --add-rich-rule 'rule family="ipv4" source address=192.168.0.14 accept' 允许来自主机 192.168.0.14 的所有 IPv4 流量

firewall-cmd --zone=public --add-rich-rule 'rule family="ipv4" source address="192.168.1.10" port port=22 protocol=tcp reject' 拒绝来自主机 192.168.1.10 到 22 端口的 IPv4 的 TCP 流量

firewall-cmd --zone=public --add-rich-rule 'rule family=ipv4 source address=10.1.0.3 forward-port port=80 protocol=tcp to-port=6532' 许来自主机 10.1.0.3 到 80 端口的 IPv4 的 TCP 流量，并将流量转发到 6532 端口上

firewall-cmd --zone=public --add-rich-rule 'rule family=ipv4 forward-port port=80 protocol=tcp to-port=8080 to-addr=172.31.4.2' 将主机 172.31.4.2 上 80 端口的 IPv4 流量转发到 8080 端口（需要在区域上激活 masquerade）

firewall-cmd --add-rich-rule='rule family="ipv4" source address="192.168.122.0" accept' 允许192.168.122.0/24主机所有连接

firewall-cmd --add-rich-rule='rule service name=ftp limit value=2/m accept' 每分钟允许2个新连接访问ftp服务

firewall-cmd --add-rich-rule='rule service name=ftp log limit value="1/m" audit accept' 同意新的IPv4和IPv6连接FTP ,并使用审核每分钟登录一次

firewall-cmd --add-rich-rule='rule family="ipv4" source address="192.168.122.0/24" service name=ssh log prefix="ssh" level="notice" limit value="3/m" accept' 允许来自1192.168.122.0/24地址的新IPv4连接连接TFTP服务,并且每分钟记录一次

firewall-cmd --permanent --add-rich-rule='rule protocol value=icmp drop' 丢弃所有icmp包

firewall-cmd --add-rich-rule='rule family=ipv4 source address=192.168.122.0/24 reject' --timeout=10 当使用source和destination指定地址时,必须有family参数指定ipv4或ipv6。如果指定超时,规则将在指定的秒数内被激活,并在之后被自动移除

firewall-cmd --add-rich-rule='rule family=ipv6 source address="2001:db8::/64" service name="dns" audit limit value="1/h" reject' --timeout=300 拒绝所有来自2001:db8::/64子网的主机访问dns服务,并且每小时只审核记录1次日志

firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.122.0/24 service name=ftp accept' 允许192.168.122.0/24网段中的主机访问ftp服务

firewall-cmd --add-rich-rule='rule family="ipv6" source address="1:2:3:4:6::" forward-portto-addr="1::2:3:4:7" to-port="4012" protocol="tcp" port="4011"' 转发来自ipv6地址1:2:3:4:6::TCP端口4011,到1:2:3:4:7的TCP端口4012
```

## 五、图形管理工具

### 1.firewalld界面如图所示，其功能具体如下：

①:选择”立即生效“或”重启后依然生效“配置。

②:区域列表。

③:服务列表。

④:当前选中的区域。

⑤:被选中区域的服务。

⑥:被选中区域的端口。

⑦:被选中区域的伪装。

⑧:被选中区域的端口转发。

⑨:被选中区域的ICMP包。

⑩:被选中区域的富规则。

⑪:被选中区域的网卡设备。

⑫:被选中区域的服务，前面有√的表示允许。

⑬:firewalld防火墙的状态

![img](/images/posts/Linux-安全/Linux-安全04-firewalld防火墙/1.png)

> firewall-config图形化管理工具中没有保存/完成按钮，只要修改就会生效。

> 允许其他主机访问http服务，仅当前生效：

![img](/images/posts/Linux-安全/Linux-安全04-firewalld防火墙/2.png)

> 允许其他主机访问8080-8088端口且重启后依然生效:

![img](/images/posts/Linux-安全/Linux-安全04-firewalld防火墙/3.png)

![img](/images/posts/Linux-安全/Linux-安全04-firewalld防火墙/4.png)

> 开启伪装功能，重启后依然生效：

> firewalld防火墙的伪装功能实际就是SNAT技术，即让内网用户不必在公网中暴露自己的真实IP地址。

![img](/images/posts/Linux-安全/Linux-安全04-firewalld防火墙/5.png)

> 将向本机888端口的请求转发至本机的22端口且重启后依然生效：

![img](/images/posts/Linux-安全/Linux-安全04-firewalld防火墙/6.png)

> 过滤所有”echo-reply”的ICMP协议报文数据包，仅当前生效：

> ICMP即互联网控制报文协议”Internet Control Message Protocol“，归属于TCP/IP协议族，主要用于检测网络间是否可通信、主机是否可达、路由是否可用等网络状态，并不用于传输用户数据。

![img](/images/posts/Linux-安全/Linux-安全04-firewalld防火墙/7.png)

> 仅允许192.168.10.20主机访问本机的1234端口，仅当前生效：

> 富规则代表着更细致、更详细的规则策略，针对某个服务、主机地址、端口号等选项的规则策略，优先级最高。

![img](/images/posts/Linux-安全/Linux-安全04-firewalld防火墙/8.png)

> 查看网卡设备信息：

![img](/images/posts/Linux-安全/Linux-安全04-firewalld防火墙/9.png)
