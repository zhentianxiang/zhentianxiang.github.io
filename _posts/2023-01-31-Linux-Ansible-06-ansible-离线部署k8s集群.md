---
layout: post
title: Linux-Ansible-06-ansible-离线部署k8s集群
date: 2023-01-31
tags: Linux-Ansible
music-id: 2010653119
---

# 文档教程

## 一、软件版本功能介绍

本文章教程中所涉及到的服务版本如下

```sh
[root@master01 ansible-k8s-kubeadm-off-line]# yum list kubeadm --showduplicates | sort -r
已加载插件：fastestmirror
可安装的软件包
Loading mirror speeds from cached hostfile
kubeadm.x86_64                        1.20.1-0                        k8s-1.20.1
[root@master01 ansible-k8s-kubeadm-off-line]# yum list docker-ce --showduplicates | sort -r
已加载插件：fastestmirror
可安装的软件包
Loading mirror speeds from cached hostfile
docker-ce.x86_64             3:20.10.9-3.el7             docker-ce-20.10.9-3.el7
```

所有软件安装均为 yum install 安装，脚本会自动配置本地repo源仓库，所有的repo源仓库均在以下目录

```sh
[root@master01 files]# pwd
/home/kubernetes-install/roles/init/files
[root@master01 files]# ls
ansible  docker-ce-19.03.15-3.el7  docker-ce-20.10.9-3.el7  k8s-1.20.1  k8s-1.23.0  k8s-1.25.1  mirrors.tar.gz  my-default.conf  nginx-1.20.1  nginx-all-modules  other
```
如果想要更换版本之类的，只需要提前准备好 rpm 包然后创建好索引文件，放到 files 目录中就行，最后 tar -zcvf mirrors.tar.gz . 打包好即可，注意：别把 mirrors.tar.gz 自身也打进去了，没必要占用无用空间

下载rpm包使用以下命令

```sh
[root@master01 package-all]# yum -y install --downloadonly docker-ce-19.03.15 docker-ce-cli-19.03.15 containerd.io --downloaddir=指定rpm包存放路径
[root@master01 package-all]# yum -y install --downloadonly kubelet-21.1 kubeadm-1.21.1 kubectl-1.21.1 --downloaddir=指定rpm包存放路径
```


也可以使用 `repotrack` 命令



repotrack 命令通常用于从软件包仓库中下载软件包及其依赖项，而不安装它们。这对于在没有互联网连接的系统上获取软件包及其依赖项的离线安装非常有用。

repotrack 命令通常与 yum 包管理器一起使用，用于下载 RPM 软件包及其依赖项。以下是 repotrack 命令的一般用法：

repotrack [选项] 软件包名

其中：

[选项] 是一些可选的命令选项，用于指定下载的目标目录等。
软件包名 是要下载的软件包的名称。
例如，要使用 repotrack 下载名为 example-package 的软件包及其依赖项到当前目录，可以运行以下命令：

```sh
[root@master01 package-all]# repotrack example-package
```
repotrack 将会查找 example-package 及其依赖项，并将它们下载到当前目录。您可以使用不同的选项来指定下载的目标目录等。

请注意，repotrack 的可用性和具体选项可能因不同的 Linux 发行版而有所不同，因此请查看您的系统文档以获取详细信息。在某些系统上，可能需要安装额外的软件包（如 yum-utils）才能使用 repotrack 命令。

随后在使用 createrepo --update 命令为rpm包创建索引文件

```sh
[root@master01 package-all]# createrepo --update docker-ce-19.03.15-3.el7
[root@master01 package-all]# createrepo --update k8s-1.21.1
```

当然也可以放进同一rpm包目录中，分开仅仅是为了好区分，最后在配置以下repo源文件

```sh
[root@master01 package-all]# vim ../../templates/CentOS-local.repo.j2

[docker-ce-19.03.15-3.el7]
name=ansible
baseurl=file://{{ package_dir }}/docker-ce-19.03.15-3.el7
gpgcheck=0
enabled=1

[k8s-1.21.1]
name=ansible
baseurl=file://{{ package_dir }}/k8s-1.21.1
gpgcheck=0
enabled=1
```

### 1. 目录详情

链接: https://pan.baidu.com/s/1X4pkTn98i6W_Ax39LwC0tA?pwd=qmwu 提取码: qmwu

```sh
[root@master01 ansible-k8s-kubeadm-off-line]# ll
总用量 40
-rw-r--r--  1 root root  511 9月  29 2020 add-node.yml
drwxr-xr-x  2 root root   21 1月  31 13:03 group_vars
-rw-r--r--  1 root root  701 1月  29 17:21 hosts.ini
-rw-r--r--  1 root root  966 1月  29 17:18 hosts.ini-bak
-rw-r--r--  1 root root 7816 9月  29 2020 LICENSE
-rw-r--r--  1 root root  924 1月  31 09:59 multi-master-ha-deploy.yml
-rw-r--r--  1 root root  832 9月  29 2020 multi-master-lvs-deploy.yml
-rw-r--r--  1 root root 1277 1月  30 15:50 README.md
-rw-r--r--  1 root root 1288 9月  29 2020 remove-k8s.yml
drwxr-xr-x 14 root root  171 1月  31 09:54 roles
-rw-r--r--  1 root root  591 9月  29 2020 single-master-deploy.yml
```

### 2. 修改主机文件

| 主机     | IP              |
| -------- | --------------- |
| master01 | 192.168.229.135 |
| master02 | 192.168.229.136 |
| master03 | 192.168.229.137 |
| node01   | 192.168.229.138 |

我这里演示的三台机器都为master节点1台为node节点

注意：ansible机器必须和master01为同一台机器，否则没办法正常使用

```sh
[root@master01 ansible-k8s-kubeadm-off-line]# vim hosts.ini

[all]
master01 ansible_host=192.168.229.136  ip=192.168.229.135
master02 ansible_host=192.168.229.136 ip=192.168.229.136
node01 ansible_host=192.168.229.138 ip=192.168.229.138

# 对应更改all.yml 定义的master ip变量
[master]
master01
master02
master03

[node]
node01

# 多master高可用, 单master忽略该项
[ha]
master01 ha_name=ha-master
master02 ha_name=ha-backup
master03 ha_name=ha-backup

# 高可用+负载均衡, 需多计划2台机器做lvs, 无需lvs可忽略该项
[lvs]
#lvs01 lvs_name=lvs-master
#lvs02 lvs_name=lvs-backup
#lvs03 lvs_name=lvs-backup

# 24小时token过期后添加node节点
[newnode]

[k8s:children]
master
node
newnode
```

### 3. 配置免密登录

```sh
[root@master01 ansible-k8s-kubeadm-off-line]# ssh-keygen -t rsa
[root@master01 ansible-k8s-kubeadm-off-line]# ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.229.135
[root@master01 ansible-k8s-kubeadm-off-line]# ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.229.136
[root@master01 ansible-k8s-kubeadm-off-line]# ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.229.137
[root@master01 ansible-k8s-kubeadm-off-line]# ssh-copy-id -i ~/.ssh/id_rsa.pub root@192.168.229.138
```

### 4. 一键部署

```sh
# 首先安装ansible工具
[root@master01 ansible-k8s-kubeadm-off-line]# yum -y localinstall roles/init/files/package-all/ansible/*.rpm
```

```sh
# 测试ansible是否能连接服务器, 显示root权限即可
[root@master01 ansible-k8s-kubeadm-off-line]# ansible -i hosts.ini all -m shell -a "whoami"

# 单Master版：
[root@master01 ansible-k8s-kubeadm-off-line]# ansible-playbook -i hosts.ini single-master-deploy.yml

# Master-HA 版：
[root@master01 ansible-k8s-kubeadm-off-line]# ansible-playbook -i hosts.ini multi-master-ha-deploy.yml  # 我是用的这个

# 多Master-LVS 版：
[root@master01 ansible-k8s-kubeadm-off-line]# ansible-playbook -i hosts.ini multi-master-lvs-deploy.yml
```

### 5. 部署控制

如果安装某个阶段失败，可针对性测试

```sh
# 例如：只运行部署插件
[root@master01 ansible-k8s-kubeadm-off-line]# ansible-playbook -i hosts.ini single-master-deploy.yml -t master,node
```

### 6. 节点扩容

修改hosts，添加新节点ip到[newnode]标签

```sh
# vim hosts.ini
[all]
node02 ansible_host=192.168.229.138 ip=192.168.229.138

[node]
node02

#24小时token过期后添加node节点
[newnode]
node02
...
```

执行部署

```sh
[root@master01 ansible-k8s-kubeadm-off-line]# ansible-playbook -i hosts.ini add-node.yml
```

### 7. 移除k8s集群

```sh
[root@master01 ansible-k8s-kubeadm-off-line]# ansible-playbook -i hosts.ini remove-k8s.yml
```

### 8. 视频演示

<video width="1200" height="600" controls>
    <source src="https://blog.linuxtian.top/data/9-ansible/ansible%E8%87%AA%E5%8A%A8%E9%83%A8%E7%BD%B2k8s.mp4" type="video/mp4">
</video>
