---
layout: post
title: 2024-04-13-VMware-workstation-显卡直通
date: 2024-04-13
tags: 其他
music-id: 2051548110
---

## VMware workstation 显卡直通

我这边直接记录一下显卡的驱动安装方法吧，其他的也没乱用

### 1. 安装工具

[下载地址](https://zhiyukj.lanzouy.com/b031o7jni)

![1](/images/posts/other/VMware-workstation-显卡直通/1.png)

![2](/images/posts/other/VMware-workstation-显卡直通/2.png)

可以随机序列号安装，也可以自己自定义选择信息，然后点击新硬件，即可！

显卡类型要根据宿主机显卡来设置，比如我这个是 [1C82]NVDIA GeForce GTX 1050Ti ，那么1C82在哪里查看呢，就在你的设备管理器中查看

![2.1](/images/posts/other/VMware-workstation-显卡直通/2.1.png)

![3](/images/posts/other/VMware-workstation-显卡直通/3.png)

接下来开始安装虚拟机

### 2. 安装虚拟机

注意，一定是要全新的虚拟机（不论系统是中文还是英文），如果有其他的虚拟机也没关系，只要没做过显卡直通就行

![4](/images/posts/other/VMware-workstation-显卡直通/4.png)

![5](/images/posts/other/VMware-workstation-显卡直通/5.png)

![6](/images/posts/other/VMware-workstation-显卡直通/6.png)

![7](/images/posts/other/VMware-workstation-显卡直通/7.png)

![8](/images/posts/other/VMware-workstation-显卡直通/8.png)

![9](/images/posts/other/VMware-workstation-显卡直通/9.png)

![10](/images/posts/other/VMware-workstation-显卡直通/10.png)

![11](/images/posts/other/VMware-workstation-显卡直通/11.png)

![12](/images/posts/other/VMware-workstation-显卡直通/12.png)

![13](/images/posts/other/VMware-workstation-显卡直通/13.png)

![14](/images/posts/other/VMware-workstation-显卡直通/14.png)

![15](/images/posts/other/VMware-workstation-显卡直通/15.png)

![16](/images/posts/other/VMware-workstation-显卡直通/16.png)

![17](/images/posts/other/VMware-workstation-显卡直通/17.png)

![18](/images/posts/other/VMware-workstation-显卡直通/18.png)

![19](/images/posts/other/VMware-workstation-显卡直通/19.png)

![20](/images/posts/other/VMware-workstation-显卡直通/20.png)

![21](/images/posts/other/VMware-workstation-显卡直通/21.png)

### 3. 开始安装显卡驱动

![](/images/posts/other/VMware-workstation-显卡直通/22.png)

![23](/images/posts/other/VMware-workstation-显卡直通/23.png)

![24](/images/posts/other/VMware-workstation-显卡直通/24.png)

![25](/images/posts/other/VMware-workstation-显卡直通/25.png)

![26](/images/posts/other/VMware-workstation-显卡直通/26.png)

![27](/images/posts/other/VMware-workstation-显卡直通/27.png)

![28](/images/posts/other/VMware-workstation-显卡直通/28.png)

![29](/images/posts/other/VMware-workstation-显卡直通/29.png)

![30](/images/posts/other/VMware-workstation-显卡直通/30.png)

![31](/images/posts/other/VMware-workstation-显卡直通/31.png)

![32](/images/posts/other/VMware-workstation-显卡直通/32.png)

![33](/images/posts/other/VMware-workstation-显卡直通/33.png)

![34](/images/posts/other/VMware-workstation-显卡直通/34.png)

![35](/images/posts/other/VMware-workstation-显卡直通/35.png)

![36](/images/posts/other/VMware-workstation-显卡直通/36.png)

![37](/images/posts/other/VMware-workstation-显卡直通/37.png)

![38](/images/posts/other/VMware-workstation-显卡直通/38.png)

![39](/images/posts/other/VMware-workstation-显卡直通/39.png)



![](/images/posts/other/VMware-workstation-显卡直通/40.png)

![41](/images/posts/other/VMware-workstation-显卡直通/41.png)

![42](/images/posts/other/VMware-workstation-显卡直通/42.png)

![43](/images/posts/other/VMware-workstation-显卡直通/43.png)

![44](/images/posts/other/VMware-workstation-显卡直通/44.png)

![45](/images/posts/other/VMware-workstation-显卡直通/45.png)

![46](/images/posts/other/VMware-workstation-显卡直通/46.png)

![47](/images/posts/other/VMware-workstation-显卡直通/47.png)

![48](/images/posts/other/VMware-workstation-显卡直通/48.png)

![49](/images/posts/other/VMware-workstation-显卡直通/49.png)

![50](/images/posts/other/VMware-workstation-显卡直通/50.png)

![51](/images/posts/other/VMware-workstation-显卡直通/51.png)

![52](/images/posts/other/VMware-workstation-显卡直通/52.png)

![53](/images/posts/other/VMware-workstation-显卡直通/53.png)

![54](/images/posts/other/VMware-workstation-显卡直通/54.png)

![55](/images/posts/other/VMware-workstation-显卡直通/55.png)

![56](/images/posts/other/VMware-workstation-显卡直通/56.png)

![57](/images/posts/other/VMware-workstation-显卡直通/57.png)

![58](/images/posts/other/VMware-workstation-显卡直通/58.png)

![59](/images/posts/other/VMware-workstation-显卡直通/59.png)

![60](/images/posts/other/VMware-workstation-显卡直通/60.png)

`dism.exe /online /export-driver /destination:c:\1050Ti-driver`

![61](/images/posts/other/VMware-workstation-显卡直通/61.png)

![62](/images/posts/other/VMware-workstation-显卡直通/62.png)

![63](/images/posts/other/VMware-workstation-显卡直通/63.png)

![64](/images/posts/other/VMware-workstation-显卡直通/64.png)

![65](/images/posts/other/VMware-workstation-显卡直通/65.png)

![66](/images/posts/other/VMware-workstation-显卡直通/66.png)

![67](/images/posts/other/VMware-workstation-显卡直通/67.png)

![68](/images/posts/other/VMware-workstation-显卡直通/68.png)

`NVDIA GeForce GTX 1050Ti`

![69](/images/posts/other/VMware-workstation-显卡直通/69.png)

[FreeRename5.3.exe](http://xz.winwin7xz.com/Small/FreeRename5.3.rar)

![70](/images/posts/other/VMware-workstation-显卡直通/70.png)

![71](/images/posts/other/VMware-workstation-显卡直通/71.png)

![72](/images/posts/other/VMware-workstation-显卡直通/72.png)

![73](/images/posts/other/VMware-workstation-显卡直通/73.png)

![74](/images/posts/other/VMware-workstation-显卡直通/74.png)

![75](/images/posts/other/VMware-workstation-显卡直通/75.png)

![76](/images/posts/other/VMware-workstation-显卡直通/76.png)

![77](/images/posts/other/VMware-workstation-显卡直通/77.png)

![78](/images/posts/other/VMware-workstation-显卡直通/78.png)

![79](/images/posts/other/VMware-workstation-显卡直通/79.png)

![80](/images/posts/other/VMware-workstation-显卡直通/80.png)

![81](/images/posts/other/VMware-workstation-显卡直通/81.png)

![82](/images/posts/other/VMware-workstation-显卡直通/82.png)

重启机器，验证功能

### 4. 检查

`dxdiag`

![93](/images/posts/other/VMware-workstation-显卡直通/83.png)

![84](/images/posts/other/VMware-workstation-显卡直通/84.png)

### 5. 视频演示

<video width="1200" height="600" controls>
    <source src="https://fileserver.tianxiang.love/api/view?file=%E8%A7%86%E9%A2%91%E6%95%99%E5%AD%A6%E7%9B%AE%E5%BD%95%2FVMware-workstation-%E6%98%BE%E5%8D%A1%E7%9B%B4%E9%80%9A.mp4" type="video/mp4">
</video>
