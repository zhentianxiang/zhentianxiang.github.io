---
layout: post
title: Linux虚拟化-2-KVM直通GPU
date: 2021-11-22
tags: Linux虚拟化
---

## 一、简介

> 在生产环境中我们通常会使用docker、VMware等其他虚拟化技术，这两种技术分别在不同的环境下发挥不同的作用，有些特殊的情况下我们会用到GPU资源，但是GPU资源通常为宿主机可用的，如果说对于docker来使用的话还算比较简单，安装一个nvidia-docker2即可容器直通GPU资源，但是对于虚拟机来说就不太方便了，因此接下来的讲解以及操作就是针对于KVM虚拟来直通GPU
>
> 注意：虽然虚拟机直通GPU了，但是这种操作会导致宿主机上失去一块GPU卡。

### 1. 硬件条件

首先要确定主板和CPU都支持VT-d技术，即Virtualization Technology for Direct I/O（英特尔虚拟技术）。近年的产品应该都支持此技术。 在BIOS里将
还要确定要直通的显卡支持PCI Pass-through。似乎A卡对于直通的支持比N卡好，但N卡性能比A卡好，这个大家都知道。目前市面上的显卡一般都支持直通。我用过的NVIDIA 的M60和GeForce系统960，970，1080系列都支持的。注意做显卡直通需要两块显卡，一块主机用，另一块虚拟机用，主板有集成显卡的可以采用将集成显卡给宿主机，PCI的独立显卡给虚拟机用。

### 2. 准备工作

在BIOS将VT-d设置成enable（主板BIOS设置项名称不一样，类似于虚拟化技术的项目打开即可）。

> 如下是我的当前实验环境

```sh
# 查看机器系统版本
root@ubuntu:~# cat /proc/version
Linux version 5.4.0-90-generic (buildd@lgw01-amd64-054) (gcc version 9.3.0 (Ubuntu 9.3.0-17ubuntu1~20.04)) #101-Ubuntu SMP Fri Oct 15 20:00:55 UTC 2021
# 验证CPU是否支持虚拟化
root@ubuntu:~# cat /proc/cpuinfo | egrep 'vmx|svm'sh
# 查看是否加载kvm
root@ubuntu:~# lsmod | grep kvm
kvm_intel             170086  0
kvm                   566340  1 kvm_intel
irqbypass              13503  1 kvm
# 当前显卡信息
root@ubuntu955:~# nvidia-smi
Tue Nov 23 03:21:02 2021       
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 460.91.03    Driver Version: 460.91.03    CUDA Version: 11.2     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  GeForce GTX 108...  Off  | 00000000:02:00.0 Off |                  N/A |
| 28%   48C    P0    61W / 250W |      0MiB / 11178MiB |      0%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+
|   1  GeForce GTX 108...  Off  | 00000000:81:00.0 Off |                  N/A |
| 26%   44C    P8     9W / 250W |    607MiB / 11178MiB |      0%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
|    1   N/A  N/A     12188      C   python                            605MiB |
+-----------------------------------------------------------------------------+
```



### 3. 安装KVM

```sh
root@ubuntu:~# apt-get install qemu-kvm libvirt-bin bridge-utils ubuntu-vm-builder virt-manager virtinst
# 启动服务
root@ubuntu:~# systemctl enable libvirtd && systemctl start libvirtd
```

## 二、KVM直通GPU

### 4. 确认内核是否支持iommu

```sh
root@ubuntu:~# cat /proc/cmdline | grep iommu
```

如果没有输出结果，添加intel_iommu=on到grub的启动参数,需要重启

```sh
root@ubuntu:~# vim /etc/default/grub

# If you change this file, run 'update-grub' afterwards to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n 'Simple configuration'

GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="maybe-ubiquity"sh
# 添加intel_iommu=on
GRUB_CMDLINE_LINUX="intel_iommu=on"

# 更新grub菜单文件
root@ubuntu:~# grub-mkconfig -o /boot/grub/grub.cfg
# 重启机器
root@ubuntu:~# reboot
# 开机后检查一下
root@ubuntu:~# dmesg | grep IOMMU
# 或
root@ubuntu:~# dmesg | grep -e DMAR -e IOMMU
检查VT-d（AMD芯片时是 IOV）是否工作。若没有相应输出，需要重新检查之前的步骤
```

### 5. 查看pci设备信息

```sh
root@ubuntu:~# lspci -nn | grep NVIDIA
02:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP102 [GeForce GTX 1080 Ti] [10de:1b06] (rev a1)
02:00.1 Audio device [0403]: NVIDIA Corporation GP102 HDMI Audio Controller [10de:10ef] (rev a1)
```

### 6. 查看驱动

```sh
# 02:00.0指的就是上面grep查看出来的设备信息的开头编号
root@ubuntu:~# lspci -vv -s 02:00.0 | grep driver
	Kernel driver in use: nouveau nouveau            （系统为显卡绑定的默认驱动）
root@ubuntu:~# lspci -vv -s 02:00.1 | grep driver
	Kernel driver in use: snd_hda_intel             (显卡上附带的集成声卡的默认驱动)
# 禁用显卡的默认驱动
root@ubuntu:~# modprobe -r nouveau
```

### 7. 将显卡从宿主机解绑定

echo的所有内容都能在上面的第5标题找到,并且标题7 8 的操作仅针对于Ubuntu系统，centos系统和Ubuntu不一样

```sh
root@ubuntu:~# modprobe vfio
root@ubuntu:~# vfio-pci
root@ubuntu:~# cd /sys/bus/pci/devices/0000\:02\:00.0
root@ubuntu:~# echo "10de 1b06" > /sys/bus/pci/drivers/vfio-pci/new_id
root@ubuntu:~# echo "0000:02:00.0" > /sys/bus/pci/devices/0000\:02\:00.0/driver/unbind
# 如下两句针对centos系统
# centos7是/sys/bus/pci/drivers/pci-stub/bind
#root@ubuntu:~# echo "0000:02:00.0" > /sys/bus/pci/drivers/pcieport/bind
```

### 8. 将显卡上附带的集成声卡的默认驱动接触绑定

```sh
root@ubuntu:~# cd /sys/bus/pci/devices/0000\:02\:00.1
root@ubuntu:~# echo "10de 10ef" > /sys/bus/pci/drivers/vfio-pci/new_id
root@ubuntu:~# echo "0000:02:00.1" > /sys/bus/pci/devices/0000\:02\:00.1/driver/unbind
# 如下两句针对centos系统
# centos7是/sys/bus/pci/drivers/pci-stub/bind
#root@ubuntu:~# echo "0000:02:00.1" > /sys/bus/pci/drivers/pcieport/bind
```

检查预留是否成功

```sh
root@ubuntu:~# lspci -nnv | grep -E "(^\S|Kernel driver in use)" | grep "02:00" -A 1
02:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP102 [GeForce GTX 1080 Ti] [10de:1b06] (rev a1) (prog-if 00 [VGA controller])
	Kernel driver in use: vfio-pci
02:00.1 Audio device [0403]: NVIDIA Corporation GP102 HDMI Audio Controller [10de:10ef] (rev a1)
	Kernel driver in use: vfio-pci
```

## 三、安装测试虚拟机

### 9. 新建虚拟机

基础过程略过，直接看硬件信息

```sh
注意：安装驱动之前首先禁用掉默认的nVidia驱动（nouveau）
root@ubuntu:~# touch /etc/modprobe.d/blacklist-nouveau.conf
root@ubuntu:~# cat > /etc/modprobe.d/blacklist-nouveau.conf <<EOF
blacklist nouveau
options nouveau modeset=0
EOF
# 重新生成 kernel initramfs
root@ubuntu:~# update-initramfs -u
root@ubuntu:~# reboot
# 开机后进入manager管理器
root@ubuntu:~# virt-manager
```

![](/images/posts/Linux-虚拟化/GPU直通/1.png)

![](/images/posts/Linux-虚拟化/GPU直通/2.png)

![](/images/posts/Linux-虚拟化/GPU直通/3.png)

![](/images/posts/Linux-虚拟化/GPU直通/4.png)

### 10. NVIDIA 驱动的反虚拟机问题

> 转载：https://blog.csdn.net/jcq521045349/article/details/108910531

虚拟机直通GPU之后，安装好NVIDIA驱动之后，执行nvidia-smi会返回报错信息，提示`Unable to determine the device handle for GPU 0000:07:00.0: Unknown Error`，说是找不到设备信息，其实这是NVIDIA显卡会检查当前系统环境是虚拟机环境还是物理机环境，如果是虚拟机他会自动屏蔽掉，所以会提示这个报错

- Windows 下安装驱动报 43 错误
- Linux 安装驱动后，运行 nvidia-smi 无法找到显卡

![](/images/posts/Linux-虚拟化/GPU直通/5.png)

**解决办法如下：**

找到虚拟机的xml配置文件，然后对其进行修改
```sh
# 首先先关闭虚拟机
root@ubuntu:~# init 0
# 回到KVM宿主机修改配置文件其目的就是为了欺骗NVIDIA的检查
root@ubuntu:~# cd /etc/libvirt/qemu/
root@ubuntu955:/etc/libvirt/qemu# vim apt-mirrors.xml
# 填写如下配置信息，value任意写12位字符
```
格式有问题，注意和截图中的对应一致
```
<hyperv>
	<relaxed state="on"/>
	<vapic state="on"/>
	<spinlocks state="on" retries="8191"/>
	<vendor_id state="on" value="123456789123"/>
</hyperv>
<kvm>
	<hidden state="on"/>
</kvm>
```

![](/images/posts/Linux-虚拟化/GPU直通/6.png)

**Windows**

win10系统这里没做测试，win7系统安装显卡驱动的时候应该会有报错windows 7 needs to install SHA-2提示缺少补丁文件，这里安装补丁文件可下载一个360安全卫士，然后利用360下载一些补丁即可。

重启libvirtd服务

```sh
root@ubuntu:~# systemctl restart libvirtd
```

### 11. 验证虚拟机显卡以及驱动

![](/images/posts/Linux-虚拟化/GPU直通/7.png)

![](/images/posts/Linux-虚拟化/GPU直通/8.png)

![](/images/posts/Linux-虚拟化/GPU直通/9.png)

![](/images/posts/Linux-虚拟化/GPU直通/10.png)

![](/images/posts/Linux-虚拟化/GPU直通/11.png)

![](/images/posts/Linux-虚拟化/GPU直通/12.png)

### 12.系统重启后显卡挂掉问题

如果上面的禁止nouveau驱动方法不管用，可以是使用下面的这个systemd

```sh
# 脚本解决此问题
root@ubuntu:~# touch /opt/prohibit_nouveau.sh
root@ubuntu:~# cat > /opt/prohibit_nouveau.sh << EOF
#!/bin/bash
modprobe -r nouveau
EOF
root@ubuntu:~# chmod +x /opt/prohibit_nouveau.sh
root@ubuntu:~# cat > /etc/systemd/system/prohibit_nouveau.service << EOF
[Unit]
Description=prohibit_nouveau
After=network.target

[Service]
User=root
Group=root
Type=forking
ExecStart= /opt/prohibit_nouveau.sh
TimeoutSec=0
Restart=on-failure
StandardOutput=journal
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
# 设置为开机自启动
root@ubuntu:~# systemctl enable prohibit_nouveau.service
# 重启测试
root@ubuntu:~# reboot
```
