---
layout: post
title: Linux-Ansible-02-离线部署 kubernetes 集群
date: 2025-03-2
tags: Linux-Ansible
---

**通过网盘分享的文件：kubernetes-install.tar.gz**
**链接: https://pan.baidu.com/s/1ZFIKcvqqx6xxj76wlWj-AA?pwd=pmft 提取码: pmft**

### 1. 基础环境配置

```sh
[root@k8s-master1 ~]# yum -y localinstall roles/init/files/ansible/*.rpm
[root@k8s-master1 ~]# ssh-keygen -t rsa
[root@k8s-master1 ~]# vim iplist.txt
10.0.0.11
10.0.0.12
10.0.0.13
10.0.0.14
[root@k8s-master1 ~]# for host in $(cat iplist.txt); do sshpass -p '123123' ssh-copy-id -o StrictHostKeyChecking=no 'root'@$host; done
[root@k8s-master1 ~]# ansible -i hosts.ini all -m shell -a "whoami"
```

### 2. 升级内核

不是必须的，根据实际情况来判断自己是否要升级内核

```sh
[root@k8s-master1 ~]# ansible-playbook -i hosts.ini install_kernel.yml
```

### 3. 准备修改关键配置文件

- 单 master 部署如下修改

```sh
[root@k8s-master1 ~]# cp roles/init/templates/no-etcd-hosts.j2 roles/init/templates/hosts.j2
[root@k8s-master1 ~]# sed -i '/^etcd/s/^/#/' hosts.ini
```

```sh
[root@k8s-master1 ~]# vim hosts.ini 
[all]
k8s-master1 ansible_connection=local  ip=10.0.0.11
k8s-node1 ansible_host=10.0.0.12 ip=10.0.0.12 ansible_port=22 ansible_user=root
k8s-node2 ansible_host=10.0.0.13 ip=10.0.0.13 ansible_port=22 ansible_user=root
k8s-node3 ansible_host=10.0.0.14 ip=10.0.0.14 ansible_port=22 ansible_user=root
#etcd1 ansible_host=10.0.0.141 ip=10.0.0.141 ansible_port=22 ansible_user=root
#etcd2 ansible_host=10.0.0.142 ip=10.0.0.142 ansible_port=22 ansible_user=root
#etcd3 ansible_host=10.0.0.143 ip=10.0.0.143 ansible_port=22 ansible_user=root
# 对应更改all.yml 定义的master ip变量
[k8s]
k8s-master1
k8s-node1
k8s-node2
k8s-node3

[master]
k8s-master1

[node]
k8s-node1
k8s-node2
k8s-node3

[etcd]
#etcd1
#etcd2
#etcd3

# keepalived 高可用集群 + Nginx 负载均衡

# 如果不部署单 master ha 里面的可以注释掉了,避免产生警告信息
[ha]
#k8s-master1 ha_name=ha-master
#k8s-master2 ha_name=ha-backup
#k8s-master3 ha_name=ha-backup

#24小时token过期后添加node节点
[newnode]
[k8s:children]
master
node
newnode
```

重点修改的如下：

> registry_address: registry 私有仓库地址
>
> registry_port: registry 私有仓库端口号
>
> k8s_image_url: kubenetes 初始化拉取的镜像前缀
>
> k8s_extra_ips:  kubrenetes master 节点信息(预留)，目的为了后期方便扩容 master 节点
>
> nic:  keepalived 调用的本地网卡的设备
>
> vip: keepalived 的虚拟 IP，如果部署单节点 master 把这个值写为 master 的 IP 地址即可
>
> lb_port: nginx 的负载均衡监听的端口，如果部署单节点 master 把这个值写为 6443 即可
>
> extra_ips:  etcd 集群的节点信息(预留)，目的为了后期方便扩容 etcd 节点
>
> calico_network: calico 调用本地网卡的设备

```sh
[root@k8s-master1 ~]# vim group_vars/all.yml
tmp_dir: '/opt/k8s-install/join'                                                      # 初始化集群一些配置文件存放位置
package_dir: '/opt/k8s-install/package'                                               # yum 安装总包解压后的位置
image_dir: '/opt/k8s-install/image'                                                   # docker 镜像
docker_ce: 'docker-ce-20.10.9'                                                        # docker_ce 版本信息
docker_ce_cli: 'docker-ce-cli-20.10.9'                                                # docker_ce_cli 版本信息
containerd: 'containerd.io'                                                           # containerd 版本信息
docker_data_dir: '/var/lib/docker'                                                    # docker 数据存储路径
registry_address: '10.0.0.11'                                                         # registry 私有仓库地址
registry_port: 5000                                                                   # registry 私有仓库端口号
registry_data: '/var/lib/registry'                                                    # registry 私有仓库数据存放路径
repo_data: '/opt/k8s-install/mirrors'                                                 # yum 安装 rpm 总包存放路径
kube_version: '1.23.0'                                                                # kubenetes 版本信息(ansible中 main.yml 文件引用的)
k8s_version: 'v1.23.0'                                                                # kubenetes 初始化定义的版本信息
kubelet_data_dir: '/var/lib/kubelet'                                                  # kubelet (pod) 数据存储路径
k8s_image_url: '10.0.0.11:5000/google_containers'                                     # kubenetes 初始化拉取的镜像前缀
k8s_extra_ips:                                                                        # kubrenetes master 节点信息(预留),并不是当前 hosts.ini 文件定义的
  - "10.0.0.150"
  - "10.0.0.151"
  - "10.0.0.152"
  - "10.0.0.153"
nic: 'ens33'                                                                          # keepalived 调用本机网卡
Virtual_Router_ID: '52'                                                               # keepalived VRRP 组播协议号(每个局域网环境中唯一)
vip: '10.0.0.11'                                                                      # keepalived vip 地址
api_vip_hosts: apiserver.cluster.local                                                # keepalived vip 地址配置的域名
notification_emails:
  - acassen@firewall.loc                                                              # keepalived 邮箱
  - failover@firewall.loc                                                             # keepalived 邮箱
  - sysadmin@firewall.loc                                                             # keepalived 邮箱
smtp_server: '127.0.0.1'                                                              # keepalived 邮件服务器地址
smtp_connect_timeout: '30'                                                            # keepalived 邮件发送超时时间(模板而已,并没有启用)
auth_pass: 'kubernetes'                                                               # keepalived auth_pass
lb_port: '6443'                                                                       # nginx 负载均衡监听端口
etcd_version: 'v3.5.1'                                                                # ETCD 版本
etcd_conf: "/etc/etcd/"                                                               # ETCD 配置文件路径
etcd_ssl: '/etc/etcd/ssl'                                                             # ETCD 证书存储路径
etcd_data: '/var/lib/etcd'                                                            # ETCD 数据存储路径
extra_ips:                                                                            # ETCD 节点信息(预留),并不是当前 hosts.ini 文件定义的
  - "10.0.0.160"
  - "10.0.0.161"
  - "10.0.0.162"
  - "10.0.0.163"
custom_hosts:                                                                         # 自定义 hosts 解析,ansible 会帮我们自动添加
  registry.example.com: 127.0.0.1
  mirrors.local.com: 172.16.246.15
service_cidr: '10.96.0.0/12'                                                          # service ip 段
cluster_dns: '10.96.0.1'                                                              # kube-dns 服务器地址
pod_cidr: '192.18.0.0/16'                                                             # pod ip 段
calico_network: '"interface=ens33"'                                                   # 服务器宿主机网卡信息使用","分割可以选择多个网卡设备
k8s_app: '/opt/k8s-install/app'                                                       # 创建了一个存放 yaml 文件的主目录
ingress_app: '/opt/k8s-install/app/ingress'                                           # ingress yaml 存放位置
openebs_app: '/opt/k8s-install/app/openebs_app'                                       # openebs_app yaml 存放位置
calico_app: '/opt/k8s-install/app/calico'                                             # calico yaml 存放位置
```
```sh
[root@k8s-master1 ~]# ansible-playbook -i hosts.ini single-master-deploy.yml  # 单节点部署
```
- 多 master 集群方式部署

```sh
[root@k8s-master1 ~]# cp roles/init/templates/yes-etcd-hosts.j2 roles/init/templates/hosts.j2
[root@k8s-master1 ~]# sed -i 's/^#etcd/etcd/' hosts.ini
```

```sh
[root@k8s-master1 ~]# vim hosts.ini
[all]
k8s-master1 ansible_connection=local  ip=10.0.0.11
k8s-master2 ansible_host=10.0.0.12 ip=10.0.0.12 ansible_port=22 ansible_user=root
k8s-master3 ansible_host=10.0.0.13 ip=10.0.0.13 ansible_port=22 ansible_user=root
k8s-node1 ansible_host=10.0.0.14 ip=10.0.0.14 ansible_port=22 ansible_user=root
etcd1 ansible_host=10.0.0.11 ip=10.0.0.11 ansible_port=22 ansible_user=root
etcd2 ansible_host=10.0.0.12 ip=10.0.0.12 ansible_port=22 ansible_user=root
etcd3 ansible_host=10.0.0.13 ip=10.0.0.13 ansible_port=22 ansible_user=root
# 对应更改all.yml 定义的master ip变量
[k8s]
k8s-master1
k8s-master2
k8s-master3
k8s-node1

[master]
k8s-master1
k8s-master2
k8s-master3

[node]
k8s-node1

[etcd]
etcd1
etcd2
etcd3

# keepalived 高可用集群 + Nginx 负载均衡

# 如果不部署单 master ha 里面的可以注释掉了,避免产生警告信息
[ha]
k8s-master1 ha_name=ha-master
k8s-master2 ha_name=ha-backup
k8s-master3 ha_name=ha-backup

#24小时token过期后添加node节点
[newnode]
[k8s:children]
master
node
newnode
```
重点修改的如下：

> registry_address: registry 私有仓库地址
>
> registry_port: registry 私有仓库端口号
>
> k8s_image_url: kubenetes 初始化拉取的镜像前缀
>
> k8s_extra_ips:  kubrenetes master 节点信息(预留)，目的为了后期方便扩容 master 节点
>
> nic:  keepalived 调用的本地网卡的设备
>
> vip: keepalived 的虚拟 IP，如果部署单节点 master 把这个值写为 master 的 IP 地址即可
>
> lb_port: nginx 的负载均衡监听的端口，如果部署单节点 master 把这个值写为 6443 即可
>
> extra_ips:  etcd 集群的节点信息(预留)，目的为了后期方便扩容 etcd 节点
>
> calico_network: calico 调用本地网卡的设备

```sh
[root@k8s-master1 ~]# vim group_vars/all.yml
tmp_dir: '/opt/k8s-install/join'                                                      # 初始化集群一些配置文件存放位置
package_dir: '/opt/k8s-install/package'                                               # yum 安装总包解压后的位置
image_dir: '/opt/k8s-install/image'                                                   # docker 镜像
docker_ce: 'docker-ce-20.10.9'                                                        # docker_ce 版本信息
docker_ce_cli: 'docker-ce-cli-20.10.9'                                                # docker_ce_cli 版本信息
containerd: 'containerd.io'                                                           # containerd 版本信息
docker_data_dir: '/var/lib/docker'                                                    # docker 数据存储路径
registry_address: '10.0.0.11'                                                         # registry 私有仓库地址
registry_port: 5000                                                                   # registry 私有仓库端口号
registry_data: '/var/lib/registry'                                                    # registry 私有仓库数据存放路径
repo_data: '/opt/k8s-install/mirrors'                                                 # yum 安装 rpm 总包存放路径
kube_version: '1.23.0'                                                                # kubenetes 版本信息(ansible中 main.yml 文件引用的)
k8s_version: 'v1.23.0'                                                                # kubenetes 初始化定义的版本信息
kubelet_data_dir: '/var/lib/kubelet'                                                  # kubelet (pod) 数据存储路径
k8s_image_url: '10.0.0.11:5000/google_containers'                                     # kubenetes 初始化拉取的镜像前缀
k8s_extra_ips:                                                                        # kubrenetes master 节点信息(预留),并不是当前 hosts.ini 文件定义的
  - "10.0.0.150"
  - "10.0.0.151"
  - "10.0.0.152"
  - "10.0.0.153"
nic: 'ens33'                                                                          # keepalived 调用本机网卡
Virtual_Router_ID: '52'                                                               # keepalived VRRP 组播协议号(每个局域网环境中唯一)
vip: '10.0.0.100'                                                                     # keepalived vip 地址
api_vip_hosts: apiserver.cluster.local                                                # keepalived vip 地址配置的域名
notification_emails:
  - acassen@firewall.loc                                                              # keepalived 邮箱
  - failover@firewall.loc                                                             # keepalived 邮箱
  - sysadmin@firewall.loc                                                             # keepalived 邮箱
smtp_server: '127.0.0.1'                                                              # keepalived 邮件服务器地址
smtp_connect_timeout: '30'                                                            # keepalived 邮件发送超时时间(模板而已,并没有启用)
auth_pass: 'kubernetes'                                                               # keepalived auth_pass
lb_port: '16443'                                                                      # nginx 负载均衡监听端口
etcd_version: 'v3.5.1'                                                                # ETCD 版本
etcd_conf: "/etc/etcd/"                                                               # ETCD 配置文件路径
etcd_ssl: '/etc/etcd/ssl'                                                             # ETCD 证书存储路径
etcd_data: '/var/lib/etcd'                                                            # ETCD 数据存储路径
extra_ips:                                                                            # ETCD 节点信息(预留),并不是当前 hosts.ini 文件定义的
  - 
  - "10.0.0.160"
  - "10.0.0.161"
  - "10.0.0.162"
  - "10.0.0.163"
custom_hosts:                                                                         # 自定义 hosts 解析,ansible 会帮我们自动添加
  registry.example.com: 127.0.0.1
  mirrors.local.com: 172.16.246.15
service_cidr: '10.96.0.0/12'                                                          # service ip 段
cluster_dns: '10.96.0.1'                                                              # kube-dns 服务器地址
pod_cidr: '192.18.0.0/16'                                                             # pod ip 段
calico_network: '"interface=ens33"'                                                   # 服务器宿主机网卡信息使用","分割可以选择多个网卡设备
k8s_app: '/opt/k8s-install/app'                                                       # 创建了一个存放 yaml 文件的主目录
ingress_app: '/opt/k8s-install/app/ingress'                                           # ingress yaml 存放位置
openebs_app: '/opt/k8s-install/app/openebs_app'                                       # openebs_app yaml 存放位置
openebs_data: '"/data/openebs"'                                                       # openebs local pvc 数据存储目录
calico_app: '/opt/k8s-install/app/calico'                                             # calico yaml 存放位置
```

```sh
[root@k8s-master1 ~]# ansible-playbook -i hosts.ini multi-master-ha-deploy.yml   # 集群部署
```

### 4. 验证集群

```
# 也可使用 https://etc1:2379 域名
[root@k8s-master1 ~]# etcdctl --cacert=/etc/etcd/ssl/ca.pem --cert=/etc/etcd/ssl/server.pem --key=/etc/etcd/ssl/server-key.pem --endpoints="https://10.0.0.11:2379,https://10.0.0.12:2379,https://10.0.0.13:2379" member list -w table
+------------------+---------+-------+---------------------------+---------------------------+------------+
|        ID        | STATUS  | NAME  |        PEER ADDRS         |       CLIENT ADDRS        | IS LEARNER |
+------------------+---------+-------+---------------------------+---------------------------+------------+
| ac050d32d6a110ec | started | etcd3 | https://10.0.0.13:2380 | https://10.0.0.13:2379 |      false |
| ea122616f14b31db | started | etcd2 | https://10.0.0.12:2380 | https://10.0.0.12:2379 |      false |
| f17683dfe42353c0 | started | etcd1 | https://10.0.0.11:2380 | https://10.0.0.11:2379 |      false |
+------------------+---------+-------+---------------------------+---------------------------+------------+
[root@k8s-master1 ~]# etcdctl --cacert=/etc/etcd/ssl/ca.pem --cert=/etc/etcd/ssl/server.pem --key=/etc/etcd/ssl/server-key.pem --endpoints="https://10.0.0.11:2379,https://10.0.0.12:2379,https://10.0.0.13:2379" endpoint status -w table
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
|         ENDPOINT          |        ID        | VERSION | DB SIZE | IS LEADER | IS LEARNER | RAFT TERM | RAFT INDEX | RAFT APPLIED INDEX | ERRORS |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
| https://10.0.0.11:2379 | f17683dfe42353c0 |   3.5.1 |  6.8 MB |     false |      false |         7 |      23532 |              23532 |        |
| https://10.0.0.12:2379 | ea122616f14b31db |   3.5.1 |  6.8 MB |     false |      false |         7 |      23532 |              23532 |        |
| https://10.0.0.13:2379 | ac050d32d6a110ec |   3.5.1 |  6.8 MB |      true |      false |         7 |      23532 |              23532 |        |
+---------------------------+------------------+---------+---------+-----------+------------+-----------+------------+--------------------+--------+
[root@k8s-master1 ~]# etcdctl --cacert=/etc/etcd/ssl/ca.pem --cert=/etc/etcd/ssl/server.pem --key=/etc/etcd/ssl/server-key.pem --endpoints="https://10.0.0.11:2379,https://10.0.0.12:2379,https://10.0.0.13:2379" endpoint health --write-out=table
+---------------------------+--------+-------------+-------+
|         ENDPOINT          | HEALTH |    TOOK     | ERROR |
+---------------------------+--------+-------------+-------+
| https://10.0.0.12:2379 |   true | 21.748801ms |       |
| https://10.0.0.11:2379 |   true | 21.666785ms |       |
| https://10.0.0.13:2379 |   true | 24.024215ms |       |
+---------------------------+--------+-------------+-------+

[root@k8s-master1 ~]# kubectl get cs

[root@k8s-master1 ~]# kubectl get node

[root@k8s-master1 ~]# kubectl get pods -A

[root@k8s-master1 ~]# kubectl create deployment nginx --image=harbor.meta42.indc.vnet.com/library/nginx:latest --replicas=4

[root@k8s-master1 ~]# kubectl expose deployment nginx --port=80 --target-port=80 --type=NodePort
```

### 5. 调整 kube 启动参数

```sh
# 请手动执行以下命令来修改 kube 自定义配置：
[root@k8s-master1 ~]# sed -i "/image:/i\    - --feature-gates=RemoveSelfLink=false" /etc/kubernetes/manifests/kube-apiserver.yaml # 每台 master 都执行
[root@k8s-master1 ~]# sed -i "s/bind-address=127.0.0.1/bind-address=0.0.0.0/g" /etc/kubernetes/manifests/kube-controller-manager.yaml # 每台 master 都执行
[root@k8s-master1 ~]# kubectl get cm -n kube-system kube-proxy -o yaml | sed "s/metricsBindAddress: \"\"/metricsBindAddress: \"0.0.0.0\"/g" | kubectl replace -f -
[root@k8s-master1 ~]# kubectl rollout restart daemonset -n kube-system kube-proxy
```

### 6. 解决 node 节点报错

```sh
Sep 14 00:59:22 k8s-node1 kubelet[1611]: E0914 00:59:22.040084    1611 file_linux.go:61] "Unable to read config path" err="path does not exist, ignoring" path="/etc/kubernetes/manifests"
[root@k8s-node1 ~]# ansible -i hosts.ini node -m shell -a "mkdir -pv /etc/kubernetes/manifests"
[root@k8s-node1 ~]# ansible -i hosts.ini node -m shell -a "systemctl restart kubelet"
```

### 7. 卸载删除集群

```sh
[root@k8s-master1 ~]# ansible-playbook -i hosts.ini remove-k8s.yml
```

### 8. 实验录屏

<video width="1200" height="600" controls>
    <source src="https://fileserver.tianxiang.love/api/view?file=%2Fdata%2Fzhentianxiang%2F%E7%A7%BB%E5%8A%A8%E7%A1%AC%E7%9B%98%2F3-Linux%E6%96%87%E4%BB%B6%2F%E9%83%A8%E7%BD%B2%E5%B7%A5%E5%85%B7%2FK8S%E8%87%AA%E5%8A%A8%E5%8C%96%E9%83%A8%E7%BD%B2%2Fkubernetes-install-centos-%E7%A6%BB%E7%BA%BF%E9%83%A8%E7%BD%B2%E9%AB%98%E5%8F%AF%E7%94%A8%E9%9B%86%E7%BE%A4%E5%AE%9E%E9%AA%8C%E8%A7%86%E9%A2%91.mp4" type="video/mp4">
</video
