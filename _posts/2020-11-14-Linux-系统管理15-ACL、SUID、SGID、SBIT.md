---
layout: post
title: Linux-系统管理15-ACL、SUID、SGID、SBIT
date: 2020-11-14
tags: Linux-系统管理
---

## 一、ACL 权限控制

### 1.ACL 概述

> ACL(Access Control List)，主要作用可以提供除属主、属组、其他人的 rwx 权限之外的 细节权限设定。

### 2.ACL 的权限控制

> 使用者(user)
>
>  群组(group)
>
>  默认权限掩码(mask)

### 3.启动ACL

> Centos7系统中默认对ext4，xfs类型的文件系统启用ACL

### 4.ACL 的设置 setfacl 命令

#### (1)格式:

setfacl [选项] [acl 参数] 目标文件或目录

#### (2)常见选项:

> -m:设置后续的 acl 参数，不可与-x 一起使用
>
> -x:删除后续的 acl 参数，不可与-m 一起使用
>
> -b:删除所有的 acl 参数
>
> -k:删除默认的 acl 参数
>
> -R:递归设置 acl 参数
>
> -d:设置默认 acl 参数，只对目录有效

#### (3)ACL 参数格式:

> u:用户名:权限 【给某个用户设定权限，若不添加用户名，默认修改属主权限】
>
> g:组名:权限 【给某个组设定权限，若不添加组名，默认修改属组权限】
>
> m:权限 【更改权限掩码】

#### 示例：

增加用户 test1 与 gtest 组具有读写权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/1.png)

> 发现权限发生变化，并且结尾增加了一个“+”

### 5.ACL 的查询 getfacl 命令

#### (1)格式:

getfacl 文件或目录

#### (2)示例:

查看/aaa/123.txt 的 ACL 设置

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/2.png)

### 6.权限掩码

> 类似于 umask，需要注意的是使用者的 ACL 权限设置必须要在 mask 的权限范围内才会 生效。 修改示例:

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/3.png)

### 7.递归修改目录下现有文件的 ACL 设置

> 示例:递归修改/aaa/目录及其目录下的 ACL 设置，并新建文件查看是否具有相同 acl 权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/4.png)

> 递归式修改目录及目录下的 ACL 设置，仅对当前存在的文件生效，但新建文件并不具有 相同的 ACL 设置。

### 8.预设 ACL 权限

> 示例:设置/aaa/目录下，test1 用户一直具有读写执行权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/5.png)

> 测试之前设置:

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/6.png)

### 9.删除 ACL 设置

#### (1)删除某文件或目录单个用户或组的权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/7.png)

#### (2)删除某文件或目录全部 ACL 设置

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/8.png)

递归删除/aaa/目录及其目录下所有文件的 ACL 设置

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/9.png)

## 二、特殊权限 SUID、SGID、SBIT

### 1.SUID(Set UID)

#### SUID 概述

> 当 s 标志出现在文件属主权限的 X 权限上时，例如/usr/bin/passwd 这个文件，权限为 “-rwsr-x-r-x”，这个文件就具有 SUID 特殊权限，在执行此命令的时候，执行者在执行的瞬 间将拥有文件属主 root 的身份权限，即/etc/shadow 文件，普通用户并没有写入权限，但是普通用户可以执行 passwd 命令对自己的账号密码进行修改，同时写入/etc/shadow 文件，正是因为/usr/bin/passwd 这个文件具有 SUID 这种特殊权限。

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/10.png)

SUID 特殊权限的特点:

- SUID 权限仅对二进制程序(binary program)有效
- 执行者对于改程序需要具有可执行权限
- SUID 权限仅在执行该程序的过程中有效
- 执行者将具有该程序拥有者的权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/11.png)

### 2.SGID(Set GID)

#### SGID 概述

> 当 s 标志出现在文件属组权限的 x 权限上时，例如/usr/bin/write 文件的权限为“-rwxr-sr-x” 属组为 tty，当执行者执行 locate 命令时，将具有 tty 组成员的权限。

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/12.png)

> 与 SUID 不同的是，SGID 可以针对文件或目录来设定，对于文件来讲，SGID 对二进制程 序有用，若程序执行者对于该程序来说具备 x 的权限，则执行者在执行的过程中将会获得该 程序群组的支持。

> 除了与 SUID 相同的对二进制程序有效以外，SGID 还能够用在目录上，当一个目录设定 了 SGID 的权限后，用户若对此目录具有 r 与 x 权限，该用户能进入此目录后，在此目录下 的有效群组将变为目录的群组，即若该用户具有 w 权限，新建文件或目录后我们会发现， 该用户所建立的文件或目录的属组为上层(具有 SGID 设置)的目录的属组。

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/13.png)

实验发现，当以 root 用户身份建立/aaa/目录时并加以 SGID 权限设置，su 到普通用户 linuxli 身份后，在/aaa/目录下创建文件与目录其属组均为 root，且新建目录也具有 SGID 的 特殊权限。可见 SGID 权限对于目录而言，具有递归式的影响，但对新建文件并没有 SGID 权 限。且即使是以 linuxli 身份复制到/aaa/目录下一个二进制程序，该文件属组会变为 root， 但二进制程序仍不具有 SGID 权限。

### 3.SBIT(Sticky Bit)粘滞位

#### (1)SBIT 粘滞位概述

> 当目录权限 x 的位置变为 t 时，即该目录设有 SBIT 粘滞位权限，主要作用是该目录下的 文件即目录仅其属主与 root 用户具有删除该文件或目录的权限，增强安全性。

#### (2)示例:

> 创建/test/目录，权限 777，root 用户创建一测试文件，su 到普通用户 linuxli 身份尝试删除该文件。再将/test/增加 SBIT 粘滞位权限后，再以 linuxli 身份尝试删除该文件。

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/14.png)

> 实验发现，虽然普通用户 linuxli 对于 123.txt 文件并没有 w 权限，但因上层目录/test/ 具有 777 的权限，linuxli 可以删除修改该目录下的所以文件，这对于系统来讲是十分不安全 的。可以通过增加 SBIT 粘滞位权限进行控制。

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/15.png)

> 增加 SBIT 粘滞位后，/test/目录下的文件仅其属主和 root 可以删除修改，其他用户无法 修改，增加了系统的安全性。需要注意的是，SBIT 粘滞位仅对目录生效，对文件无效。

### 4.SUID、SGID、SBIT 权限的设定

#### (1)八进制数设置方法

> 方法:
>
> 在属主、属组、其他人的权限前增加特殊权限的八进制数字表示

- 4 为 SUID
- 2 为 SGID
- 1 为 SBIT

#### (2)示例:

设置 SUID 权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/16.png)

设置 SGID 权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/17.png)

设置 SBIT 权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/18.png)

#### (3)字母设置方法 示例:

设置 SUID 权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/19.png)

设置 SGID 权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/20.png)

设置 SBIT 权限

![](/images/posts/Linux-系统管理/Linux-系统管理14-ACL、SUID、SGID、SBIT/21.png)
