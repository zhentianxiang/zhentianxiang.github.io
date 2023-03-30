---
layout: post
title: OpenStack-Rocky安装部署-30-制作Windows镜像
date: 2020-12-26
tags: 云计算
---

## 制作Windows镜像

准备材料：Windows镜像，[virtio-win-0.1.171.iso驱动](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.171-1/virtio-win-0.1.171.iso)，本地虚拟机开启支持CPU虚拟化

### 1.开启centos7的图形化界面

```
[root@localhost ~]# yum groupinstall -y "X Window System"
[root@localhost ~]# yum groupinstall -y "GNOME Desktop"
[root@localhost ~]# init 5   //开启图形界面
[root@localhost ~]# systemctl set-default graphical.target    //开机进入桌面
[root@localhost ~]# systemctl set-default multi-user.target   //开机进入字符
```

### 2.安装kvm

```
[root@localhost ~]# yum install qemu-kvm virt-manager libvirt libvirt-install libguestfs-tools libvirt-python -y
```

### 3.启动kvm虚拟化服务and图形化管理界面

```
启动虚拟化服务命令
[root@localhost ~]# systemctl start libvirtd
设置开机自启命令
[root@localhost ~]# systemctl enable libvirtd
查看是否为开机自启
[root@localhost ~]# systemctl is-enabled libvirtd
启动图形化管理工具
[root@localhost ~]# virt-manager
```

### 4.创建Windows虚拟机

![image-20210115190111545](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115190111545.png)

![image-20210115190127211](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115190127211.png)

![image-20210115190144743](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115190144743.png)

![image-20210115190224756](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115190224756.png)

![image-20210115190250639](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115190250639.png)

![image-20210115190339438](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115190339438.png)

![image-20210115190418964](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115190418964.png)

![image-20210115190544176](/images/posts/云计算/Train版本部署/自定义镜像/微信截图_20210117034726.png)

![image-20210115190634360](/images/posts/云计算/Train版本部署/自定义镜像/微信截图_20210117034850.png)

![image-20210115190702892](/images/posts/云计算/Train版本部署/自定义镜像/微信截图_20210117034922.png)

![image-20210115190809962](/images/posts/云计算/Train版本部署/自定义镜像/微信截图_20210117035047.png)

![image-20210115190929766](/images/posts/云计算/Train版本部署/自定义镜像/微信截图_20210117035326.png)

![image-20210115191541352](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115191541352.png)

![image-20210115191626881](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115191626881.png)

![image-20210115191933798](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115191933798.png)

![image-20210115191948955](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115191948955.png)

![image-20210115192053487](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115192053487.png)

![image-20210115192116641](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115192116641.png)

![image-20210115192138394](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115192138394.png)

![image-20210115192855961](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115192855961.png)

![image-20210115193138556](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115193138556.png)

![image-20210115193205889](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115193205889.png)

![image-20210115193246915](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115193246915.png)

![image-20210115193321135](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115193321135.png)

剩下其他两个也是同样方法更新程序

![image-20210115193334699](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115193334699.png)

![image-20210115193648708](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115193648708.png)

### 5.压缩镜像

![image-20210115193832539](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115193832539.png)

```
[root@localhost ~]# qemu-img convert -c -O qcow2 Windows7.qcow2 Windows7_x64.qcow2
```

![image-20210115194103215](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115194103215.png)

![image-20210115195108102](/images/posts/云计算/Train版本部署/自定义镜像/image-20210115195108102.png)

最后，把镜像拷贝到controller服务器上就行了。
