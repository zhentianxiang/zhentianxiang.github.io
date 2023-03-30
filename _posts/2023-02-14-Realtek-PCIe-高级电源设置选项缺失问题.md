---
layout: post
title: 2023-02-14-Realtek-PCIe-高级电源设置选项缺失问题
date: 2023-02-14
tags: Windows
music-id: 2022065276
---

### 1. 设备信息

版本	Windows 10 专业版
版本号	22H2
安装日期	‎2022/‎11/‎6
操作系统内部版本	19045.2486
体验	Windows Feature Experience Pack 120.2212.4190.0

### 2. 起因

由于最近在使用远程唤醒电脑功能，发现要把相关的设置给打开，于是乎查看网卡高级设置中没有电源设置选项

![](/images/posts/windows/Realtek-PCIe-高级电源设置选项缺失问题/1.png)

### 3. 解决办法

修改注册表

按下“Windows键”+“R键”，然后输入regedit，依次点击注册表左侧的：HKEY_LOCAL_MACHINE、SYSTEM、CurrentControlSet、Control、Power

```
HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Power
```

右侧可以看到CsEnabled选项，双击，将数值"1"改为"0"，然后点击确定，最后重启电脑

若找不到CsEnabled选项

以管理员身份打开控制台cmd.exe

运行：reg add HKLM\System\CurrentControlSet\Control\Power /v PlatformAoAcOverride /t REG_DWORD /d 0

重启电脑

![](/images/posts/windows/Realtek-PCIe-高级电源设置选项缺失问题/2.png)
