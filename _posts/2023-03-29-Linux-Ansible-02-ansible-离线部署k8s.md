---
layout: post
title: Linux-Ansible-06-ansible-离线部署k8s
date: 2023-03-28
tags: Linux-Ansible
music-id: 2010653119
---

## 一、软件版本

首先我这个包里面的docker和k8s版本是，docker-ce-20.10.9、kubelet-21.0，如果你想更换版本你可以修改 group_vars 里面的变量文件，然后你在用 `yum -y install --downloadonly` 命令下载对应的 rpm 包，之后你在拷贝到 `roles/init/files` 目录中，但是要先把 files 目录中的 `mirrors.tgz` 文件解压，然后把旧的目录里面的 rpm 删掉，把你新下载的拷贝进去，然后重新打包

大概就是如下步骤：

- 下载 rpm

```sh
[root@master01 ~]# yum -y install --downloadonly docker-ce-20.10.9 docker-ce-cli-20.10.9 containerd.io --downloaddir=docker-ce-20.10.9-3.el7
[root@master01 ~]# yum -y install --downloadonly kubelet-1.23.0 kubeadm-1.23.0 kubectl-1.23.0 --downloaddir=kubernetes-1.23.0
```

- 生成 yum 的索引文件

```sh
[root@master01 ~]# createrepo --update docker-ce-20.10.9-3.el7
[root@master01 ~]# createrepo --update kubernetes-1.23.0
```

- 拷贝或移动文件

```sh
[root@master01 ~]# mv docker-ce-20.10.9-3.el7 roles/init/files/mirrors/
[root@master01 ~]# mv k8s-1.23.0 roles/init/files/mirrors/
```
- 重新打包

```sh
[root@master01 ~]# cd roles/init/files/mirrors/
[root@master01 ~]# tar -jcvf mirrors.tgz mirrors
```

- 修改 group_vars/all.yml 文件

```sh
docker_ce: 'docker-ce-20.10.9'   # 修改你新下载的版本
docker_ce_cli: 'docker-ce-cli-20.10.9'   # 修改你新下载的版本
containerd: 'containerd.io'   # 修改你新下载的版本
kube_version: '1.23.0'  # 修改你新下载的版本
k8s_version: 'v1.23.0'  # 修改你新下载的版本
```

- 修改 CentOS-local.repo.j2 文件

```sh
[root@master01 ~]# vim roles/init/templates/CentOS-local.repo.j2
[docker-ce-20.10.9]
name=docker-ce-20.10.9
baseurl=file://{{ repo_data }}/docker-ce-20.10.9   # 这个目录名字换成你新下载存放 rpm 包的目录
gpgcheck=0
enabled=1

[kubernetes-1.23.0]
name=kubernetes-1.23.0
baseurl=file://{{ repo_data }}/kubernetes-1.23.0   # 这个目录名字换成你新下载存放 rpm 包的目录
gpgcheck=0
enabled=1

[base]
name=base
baseurl=file://{{ repo_data }}/other
gpgcheck=0
enabled=1

[nginx-1.20.1]
name=nginx-1.20.1
baseurl=file://{{ repo_data }}/nginx-1.20.1
gpgcheck=0
enabled=1

[nginx-all-modules]
name=nginx-all-modules
baseurl=file://{{ repo_data }}/nginx-all-modules
gpgcheck=0
enabled=1
```

### 1. 目录详情

链接：https://pan.baidu.com/s/1pZQBVKzDrqIDeZLORTG3MQ?pwd=jwvu 
提取码：jwvu

点击下载：（kubernetes-install-CentOS-7.tgz)[[https://fileserver.tianxiang.love/api/download/%E7%A7%BB%E5%8A%A8%E7%A1%AC%E7%9B%98/3-Linux%E6%96%87%E4%BB%B6/2-%E9%83%A8%E7%BD%B2%E5%B7%A5%E5%85%B7/K8S%E8%87%AA%E5%8A%A8%E5%8C%96%E9%83%A8%E7%BD%B2/kubernetes-install-CentOS-7.tgz?as_attachment=true]

```sh
[root@master01 ansible-k8s-kubeadm-off-line]# ll
总用量 40
-rw-r--r--  1 root root  511 9月  29 2020 add-node.yml
drwxr-xr-x  2 root root   21 1月  31 13:03 group_vars
-rw-r--r--  1 root root  701 1月  29 17:21 hosts.ini
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

- 单master节点部署

<video width="1200" height="600" controls>
    <source src="https://fileserver.tianxiang.love/api/view?file=%E8%A7%86%E9%A2%91%E6%95%99%E5%AD%A6%E7%9B%AE%E5%BD%95%2Fk8s%E5%8D%95master%E8%8A%82%E7%82%B9%E8%87%AA%E5%8A%A8%E5%8C%96%E9%83%A8%E7%BD%B2.mp4" type="video/mp4">
</video>

- 3台master节点部署高可用

<video width="1200" height="600" controls>
    <source src="https://fileserver.tianxiang.love/api/view?file=%E8%A7%86%E9%A2%91%E6%95%99%E5%AD%A6%E7%9B%AE%E5%BD%95%2F3%E5%8F%B0master%E9%83%A8%E7%BD%B2k8s.mp4" type="video/mp4">
</video>

- 3台master节点部署高可用1台node为工作节点

<video width="1200" height="600" controls>
    <source src="https://fileserver.tianxiang.love/api/view?file=%E8%A7%86%E9%A2%91%E6%95%99%E5%AD%A6%E7%9B%AE%E5%BD%95%2F3%E5%8F%B0master1%E5%8F%B0node.mp4" type="video/mp4">
</video>