---
layout: post
title: Linux-Ansible-02-CKA模拟环境搭建
date: 2023-02-16
tags: Linux-Ansible
music-id: 28219175
---

### 1. 免密登录

```sh
[root@localhost data]# ssh-keygen
[root@localhost data]# ssh-copy-id -i ~/.ssh/id_rsa.pub root@11.0.1.111
[root@localhost data]# ssh-copy-id -i ~/.ssh/id_rsa.pub root@11.0.1.112
[root@localhost data]# ssh-copy-id -i ~/.ssh/id_rsa.pub root@11.0.1.113
```
### 2. 创建普通用户

三台机器都创建 candidate 用户，密码 123，后续用来模拟考试环境
```sh
[root@localhost data]# useradd candidate
[root@localhost data]# useradd candidate
[root@localhost data]# useradd candidate
```

### 4. 使用 ansible 部署集群

因为考试环境是一台 master 两台 node，所以我们也这样部署

```sh
[root@localhost k8s1.25.1-containerd-ansible]# ls
add-node.yml  group_vars  hosts.ini  hosts.ini-bak  LICENSE  multi-master-ha-deploy.yml  multi-master-lvs-deploy.yml  README.md  remove-k8s.yml  roles  single-master-deploy.yml
```

配置主机信息

```sh
[root@master01 k8s1.25.1-containerd-ansible]# cat hosts.ini
[all]
master01 ansible_connection=local ip=11.0.1.5
node01 ansible_host=11.0.1.6 ip=11.0.1.6
node02 ansible_host=11.0.1.7 ip=11.0.1.7

[k8s]
master01
node01
node02
# 对应更改all.yml 定义的master ip变量
[master]
master01


[node]
node01
node02

# 多master高可用, 单master忽略该项
#[ha]
#master01 ha_name=ha-master
#master02 ha_name=ha-backup
#master03 ha_name=ha-backup

# 高可用+负载均衡, 需多计划2台机器做lvs, 无需lvs可忽略该项
#[lvs]
#lvs01 lvs_name=lvs-master
#lvs02 lvs_name=lvs-backup

#24小时token过期后添加node节点
[newnode]

[k8s:children]
master
node
newnode
```

配置全局变量
```sh
[root@master01 k8s1.25.1-containerd-ansible]# cat group_vars/all.yml
# 临时文件存放目录
tmp_dir: '/opt/k8s/join'
addons_dir: '/opt/k8s/addons'
package_dir: '/opt/k8s/package'
image_dir: '/opt/k8s/images'

# 部署 containerd 安装信息
docker_ce_repo: 'http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo'
containerd: 'containerd.io-1.6.16'
containerd_data_dir: '/var/lib/containerd'
containerd_systemd: 'true'
sandbox_image: '11.0.1.5:5000/google_containers/pause:3.6'

# 部署 registry 私有仓库
docker_ce: 'docker-ce-19.03.15'
docker_ce_cli: 'docker-ce-cli-19.03.15'
docker_data_dir: '/var/lib/docker'
registry_data_dir: '/var/lib/registry'
registry_port: '5000'
registry_address: '11.0.1.5'  # master01 机器

# 部署 k8s 安装信息
kube_version: '1.25.1'
k8s_version: 'v1.25.1'
kubelet_data_dir: '/var/lib/kubelet'
k8s_api: 'kube-apiserver'
k8s_controller: 'kube-controller-manager'
k8s_scheduler: 'kube-scheduler'
k8s_proxy: 'kube-proxy'
k8s_etcd: 'etcd:3.5.4-0'
k8s_pause: 'pause:3.5'
k8s_coredns: 'coredns:v1.9.3'
GCR_URL: k8s.gcr.io
Other_URL: 11.0.1.5:5000/google_containers

# 安装部署 keepalived, 如果安装的是单节点 master,那么 VIP 位置填写 master IP 即可
vip: '11.0.1.5'
nic: 'ens33'  # 调用的物理网卡名称
api_vip_hosts: 'api.mastervip.com'
Virtual_Router_ID: '55'


# CIN 插件配置
service_cidr: '10.96.0.0/12'
cluster_dns: '10.96.0.1'   
pod_cidr: '10.244.0.0/16'
```

准备部署
```sh
# single-master-deploy.yml 单节点master部署
# multi-master-ha-deploy.yml 高可用master部署
# multi-master-lvs-deploy.yml 高可用lvs部署
[root@localhost k8s1.25.1-containerd-ansible]# ansible -i hosts.ini all -m shell -a "whoami"
master01 | CHANGED | rc=0 >>
root
node02 | CHANGED | rc=0 >>
root
node01 | CHANGED | rc=0 >>
root
[root@localhost k8s1.25.1-containerd-ansible]# ansible-playbook -i hosts.ini single-master-deploy.yml
TASK [addons : 提交 yaml 资源] ***************************************************************************************************************************************************************************************
changed: [master01] => (item=0-namesapce.yaml)
changed: [master01] => (item=components.yaml)
changed: [master01] => (item=foo-pod.yaml)
changed: [master01] => (item=front-end-deployment.yaml)
changed: [master01] => (item=nginx-host-deployment.yaml)
changed: [master01] => (item=nginx-ingress.yaml)
changed: [master01] => (item=hello-deployment.yaml)
changed: [master01] => (item=presentation-deployment.yaml)
changed: [master01] => (item=redis-test-deployment.yaml)
changed: [master01] => (item=test0-deployment.yaml)

PLAY RECAP *******************************************************************************************************************************************************************************************************
master01                   : ok=81   changed=55   unreachable=0    failed=0    skipped=1    rescued=0    ignored=1   
node01                     : ok=47   changed=27   unreachable=0    failed=0    skipped=1    rescued=0    ignored=0   
node02                     : ok=47   changed=27   unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

### 5. 检查环境

```sh
[root@localhost k8s1.25.1-containerd-ansible]# bash
[root@master01 k8s1.25.1-containerd-ansible]# kubectl get node
NAME       STATUS   ROLES           AGE   VERSION
master01   Ready    control-plane   82s   v1.25.1
node01     Ready    <none>          46s   v1.25.1
node02     Ready    <none>          46s   v1.25.1
[root@master01 k8s1.25.1-containerd-ansible]# kubectl get pods -A
NAMESPACE       NAME                                       READY   STATUS      RESTARTS   AGE
cpu-top         nginx-host-b95b79669-9vb2z                 1/1     Running     0          26s
cpu-top         redis-test-687c6c9d6d-s5sc8                1/1     Running     0          22s
cpu-top         test0-766448d48f-rlck4                     1/1     Running     0          22s
default         foo                                        1/1     Running     0          27s
default         front-end-84cc4fc8b7-n4pzd                 1/1     Running     0          27s
default         presentation-5b5fdc448b-xn2ss              1/1     Running     0          23s
ing-internal    hello-595d787cd-rw6qv                      1/1     Running     0          24s
ingress-nginx   ingress-nginx-admission-create-8smwv       0/1     Completed   0          24s
ingress-nginx   ingress-nginx-admission-patch-x7kvt        0/1     Completed   2          24s
ingress-nginx   ingress-nginx-controller-hqf87             0/1     Running     0          25s
ingress-nginx   ingress-nginx-controller-mr9wx             0/1     Running     0          25s
kube-system     calico-kube-controllers-69f758778b-flfcg   1/1     Running     0          74s
kube-system     calico-node-8mk5h                          1/1     Running     0          55s
kube-system     calico-node-j7ccb                          1/1     Running     0          74s
kube-system     calico-node-w2bcl                          1/1     Running     0          55s
kube-system     coredns-5d98f8f7c8-ksd4f                   1/1     Running     0          74s
kube-system     coredns-5d98f8f7c8-m8f75                   1/1     Running     0          74s
kube-system     etcd-master01                              1/1     Running     4          88s
kube-system     kube-apiserver-master01                    1/1     Running     4          90s
kube-system     kube-controller-manager-master01           1/1     Running     4          88s
kube-system     kube-proxy-cb56t                           1/1     Running     0          55s
kube-system     kube-proxy-dcck4                           1/1     Running     0          55s
kube-system     kube-proxy-fgfbj                           1/1     Running     0          74s
kube-system     kube-scheduler-master01                    1/1     Running     4          90s
kube-system     metrics-server-5f485688d9-dvhl9            1/1     Running     0          29s
```

### 6. 清除环境

```sh
[root@master01 k8s1.25.1-containerd-ansible]# ansible-playbook -i hosts.ini remove-k8s.yml
```

### 7. 部署录屏

<video width="1200" height="600" controls>
    <source src="https://blog.linuxtian.top/data/k8s1.25.1-containerd-ansible.mp4" type="video/mp4">
</video>
