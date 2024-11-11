---
layout: post
title: Linux-Ansible-03-ansible部署harbor高可用集群
date: 2023-03-30
tags: Linux-Ansible
music-id: 27731176
---

## ansible部署harbor高可用集群

| IP        | 服务端口    | 角色             |
| --------- | ----------- | ---------------- |
| 11.0.1.5  | 22          | ansible控制端    |
| 11.0.1.10 | 6379、26379 | redis-master     |
| 11.0.1.11 | 6379、26379 | redis-slave      |
| 11.0.1.12 | 6379、26379 | redis-slave      |
| 11.0.1.13 | 5432        | psql-master      |
| 11.0.1.14 | 5432        | pgsql-slave      |
| 11.0.1.15 | 5432        | pgsql-slave      |
| 11.0.1.16 | 1443        | harbor           |
| 11.0.1.17 | 1443        | harbor           |
| 11.0.1.18 | 1443        | harbor           |
| 11.0.1.19 | 443         | nginx+keepalived |
| 11.0.1.20 | 443         | nginx+keepalived |

### 1. 查看目录结构

```shell
[root@redis-master01 ~]# cd ansible-harbor/
[root@redis-master01 ansible-harbor]# ls
group_vars  hosts.ini  install-deploy.yml  remove_cluster.yml   roles  tips
[root@redis-master01 ansible-harbor]# ls roles/
docker  harbor  harbor-nfs  init  keepalived  nginx  pgsql-master  pgsql-slave  redis-master  redis-sentinel  redis-slave  yum-repo
```

### 2. 查看主机文件

配置文件中主机数量可以变化的有以下：

> pgsql-slave、redis-slave、redis-sentinel

```sh
[root@ansible ansible-harbor]# cat hosts.ini
[all]
yum-repo ansible_connection=local ip=11.0.1.5
redis-master01 ansible_host=11.0.1.10 ip=11.0.1.10
redis-slave01 ansible_host=11.0.1.11 ip=11.0.1.11
redis-slave02 ansible_host=11.0.1.12 ip=11.0.1.12
pgsql-master01 ansible_host=11.0.1.13 ip=11.0.1.13
pgsql-slave01 ansible_host=11.0.1.14 ip=11.0.1.14
pgsql-slave02 ansible_host=11.0.1.15 ip=11.0.1.15
harbor01 ansible_host=11.0.1.16 ip=11.0.1.16
harbor02 ansible_host=11.0.1.17 ip=11.0.1.17
harbor03 ansible_host=11.0.1.18 ip=11.0.1.18
harbor-ha01 ansible_host=11.0.1.19 ip=11.0.1.19
harbor-ha02 ansible_host=11.0.1.20 ip=11.0.1.20
harbor-nfs ansible_host=11.0.1.20 ip=11.0.1.20

[yum_repo]
yum-repo

[redis]
redis-master01
redis-slave01
redis-slave02

[redis_master]
redis-master01

[redis_slave]
redis-slave01
redis-slave02

[redis_sentinel]
redis-master01
redis-slave01
redis-slave02

[postgresql]
pgsql-master01
pgsql-slave01
pgsql-slave02

[pgsql_master]
pgsql-master01

[pgsql_slave]
pgsql-slave01
pgsql-slave02

[harbor]
harbor01 harbor_name=harbor-01
harbor02 harbor_name=harbor-02
harbor03 harbor_name=harbor-03

[harbor_nfs]
harbor-nfs

[keepalived_nginx]
harbor-ha01 harbor_ha_name=harbor-ha-master
harbor-ha02 harbor_ha_name=harbor-ha-backup01
```

### 3. 查看全局变量文件

```sh
[root@ansible ansible-harbor]# cat group_vars/all.yml
# 部署内网 yum 源
repo_address: '11.0.1.5'
repo_port: '80'
repo_data: '/opt/mirrors'
repo_file: '/etc/yum.repos.d/*.repo*'

# 部署 pgsql
postgresql_version: 'postgresql-9.6.3.tar.gz'  # 包名
dir: '/usr/local/src'                   # 解压目录地址
postgresql_dir: 'postgresql-9.6.3'      # 解压目录名
data_dir: '/usr/local/pgsql'            # 二进制编译目录
datadir: '/usr/local/pgsql/data'        # 数据目录
archive_dir: '/data/postgres/pgsql/archive'  # 归档目录
postgres_password: '123123'   # 修改 postgres 数据库密码
sync_user: 'replica'          # 主从用户
sync_password: '123456'       # 主从用户密码
sync_db: 'replication'        # 主从连接数据库
network: '11.0.1.0/24'        # 允许连接访问的网段
#pgsql_addres: '11.0.1.7'      # pgsql 主节点 IP

# 部署 redis
redis_version : 'redis-6.2.4.tar.gz'       # 包名
redis_dir: 'redis-6.2.4'                # 解压出来的包名
make_dir: '/usr/local/src'                 # 编译目录/usr/local/src/redis-6.2.4
redis_data_dir: '/usr/local/redis'              # reids 工作目录
redis_port: '6379'                         # redis 端口
redis_bind: '0.0.0.0'                      # 所有地址都可访问
redis_passwd: 'redis123'                   # reids密码
redis_sentinel_port: '26379'               # 哨兵端口

# 部署 docker 私有仓库
docker_ce: 'docker-ce-19.03.15'
docker_ce_cli: 'docker-ce-cli-19.03.15'
containerd: 'containerd.io'
docker_data_dir: '/var/lib/docker'
registry_data_dir: '/var/lib/registry'

# 部署 harbor
harbor_nfs_data: '/data/nfs/harbor_storage'           # harbor 共享存储
harbor_version: 'harbor-offline-installer-v2.1.5.tgz' # 压缩包名
harbor_port: '1443'                                   # harbor 访问端口
unharbor_dir: "/usr/local/"                           # harbor 解压目录
harbor_dir: '/usr/local/harbor'                       # harbor 工作目录
harbor_password: 'Harbor12345'                        # harbor 访问密码
harbor_data: '/data/harbor'                           # harbor 数据目录
harbor_tls: '/data/harbor/tls'                        # harbor 证书存放目录,因为三台机器用同一套证书，所以干脆就把他放到共享目录即可

# 部署 keepalived
nic: 'ens33'  # 调用的物理网卡名称
harbor_vip: '11.0.1.50'
Virtual_Router_ID: '51'
```

### 4. 查看安装脚本

```sh
- name: 1.配置内网 yum 源
  gather_facts: false
  hosts: yum_repo
  roles:
    - yum-repo
  tags: yum-repo

- name: 2.系统初始化
  gather_facts: false
  hosts: all
  roles:
    - init
  tags: init

- name: 3.部署 postgresql master 服务
  gather_facts: false
  hosts: pgsql_master
  roles:
    - pgsql-master
  tags: pgsql-master

- name: 4.部署 postgresql slave 服务
  gather_facts: false
  hosts: pgsql_slave
  roles:
    - pgsql-slave
  tags: pgsql-slave

- name: 5.部署 redis-master 服务
  gather_facts: false
  hosts: redis_master
  roles:
    - redis-master
  tags: redis-master

- name: 6.部署 redis-slave 服务
  gather_facts: false
  hosts: redis_slave
  roles:
    - redis-slave
  tags: redis-slave

- name: 7.部署 redis-sentinel 服务
  gather_facts: false
  hosts: redis_sentinel
  roles:
    - redis-sentinel
  tags: redis-sentinel

- name: 8.部署 docker 服务
  gather_facts: false
  hosts: harbor
  roles:
    - docker
  tags: docker

- name: 9.部署 nfs 服务
  gather_facts: false
  hosts: harbor_nfs
  roles:
    - harbor-nfs
  tags: harbor-nfs

- name: 10.部署 harbor 服务
  gather_facts: false
  hosts: harbor
  roles:
    - harbor
  tags: harbor

- name: 11.部署 nginx 负载均衡
  gather_facts: false
  hosts: keepalived_nginx
  roles:
    - nginx
  tags: nginx

- name: 12.部署 keepalived 高可用
  gather_facts: false
  hosts: keepalived_nginx
  roles:
    - keepalived
  tags: keepalived
```

### 5. 查看卸载脚本

```sh
---
#- hosts: 127.0.0.1
#  gather_facts: false
#  tasks:
#    - name: 删除内网 yum 源文件
#      file:
#        path: "{{ repo_data }}"
#        state: absent

- hosts: redis
  ignore_errors: yes
  gather_facts: False
  tasks:
    - name: 停止 redis 服务
      systemd:
        name: redis
        state: stopped

- hosts: redis
  ignore_errors: yes
  gather_facts: False
  tasks:
    - name: 停止 redis-sentinel 服务
      systemd:
        name: redis-sentinel
        state: stopped

- hosts: redis
  ignore_errors: yes
  gather_facts: false
  tasks:
    - name: 删除 redis 数据
      file:
        path: "{{ redis_dir }}"
        state: absent

- hosts: redis
  ignore_errors: yes
  gather_facts: false
  tasks:
    - name: 删除 redis-cli 命令
      file:
        path: /usr/bin/redis-cli
        state: absent
    - name: 删除关于内存的内核参数
      shell: sed -i -e 's/vm.overcommit_memory.*//g' -e '/./!d' /etc/sysctl.conf

- hosts: pgsql_master
  gather_facts: false
  ignore_errors: yes
  tasks:
    - name: pgsql 主节点停止服务
      systemd:
        name: postgresql
        state: stopped

    - name: pgsql 主节点删除数据
      file:
        path:
          - "{{ data_dir }}"
          - "{{archive_dir}}"
        state: absent

    - name: 删除 postgresq 用户
      user:
        name: postgres
        state: absent
        remove: yes

- hosts: pgsql_slave
  gather_facts: false
  ignore_errors: yes
  tasks:
    - name: pgsql 从节点停止服务
      systemd:
        name: postgresql
        state: stopped

    - name: pgsql 从节点删除数据
      file:
        path: "{{ data_dir }}"
        state: absent

    - name: 删除 postgresq 用户
      user:
        name: postgres
        state: absent
        remove: yes

- hosts: harbor
  ignore_errors: yes
  gather_facts: false
  tasks:
    - name: 停止 habror
      systemd:
        name: harbor
        state: stopped

    - name: 停止 docker
      systemd:
        name: docker
        state: stopped

    - name: 卸载 docker
      package:
        name:
          - "{{ docker_ce }}"
          - "{{ docker_ce_cli }}"
          - "{{ containerd }}"
        state: absent

    - name: 删除 docker 数据
      file:
        path: "{{ docker_data_dir }}"
        state: absent

    - name: umount 卸载共享存储
      shell: umount "{{ harbor_data }}"

    - name: 删除 harbor 数据
      file:
        path: "{{ harbor_dir }}"
        state: absent

    - name: 删除 harbor 证书
      file:
        path: "{{ harbor_tls }}"
        state: absent

    - name: 删除 ipv4 forword 转发
      shell: sed -i -e 's/net.ipv4.ip_forward.*//g' -e '/./!d' /etc/sysctl.conf

    - name: 删除开机自动挂载
      shell: sed -i -e 's/{{hostvars['harbor-nfs'].ip}}.*//g' -e '/./!d' /etc/fstab


- hosts: keepalived_nginx
  ignore_errors: yes
  gather_facts: false
  tasks:
    - name: 停止 keepalived
      systemd:
        name: keepalived
        state: stopped

    - name: 停止 nginx
      systemd:
        name: nginx
        state: stopped

    - name: 卸载 nginx keepalived
      package:
        name:
          - keepalived
          - nginx
        state: absent
```

### 6. 部署集群

检查集群免密登录

```sh
[root@redis-master01 ansible-harbor]# for i in {10..20}; do sshpass -p '123123' ssh-copy-id -o stricthostkeychecking=no root@11.0.1.$i ; done
[root@redis-master01 ansible-harbor]# ansible -i hosts.ini all -m shell -a "whoami"
pgsql-master01 | CHANGED | rc=0 >>
root
redis-master01 | CHANGED | rc=0 >>
root
pgsql-slave02 | CHANGED | rc=0 >>
root
pgsql-slave01 | CHANGED | rc=0 >>
root
redis-slave01 | CHANGED | rc=0 >>
root
redis-slave02 | CHANGED | rc=0 >>
root
harbor01 | CHANGED | rc=0 >>
root
harbor02 | CHANGED | rc=0 >>
root
harbor-ha01 | CHANGED | rc=0 >>
root
harbor03 | CHANGED | rc=0 >>
root
harbor-ha02 | CHANGED | rc=0 >>
root
harbor-nfs | CHANGED | rc=0 >>
root
127.0.0.1 | CHANGED | rc=0 >>
root
```

清理集群环境

```sh
[root@redis-master01 ansible-harbor]# ansible-playbook -i hosts.ini remove_cluster.yml
```

部署

```
[root@redis-master01 ansible-harbor]# ansible-playbook -i hosts.ini install-deploy.yml
```

### 7. 检查

检查 harbor 容器和日志

```sh
[root@harbor01 ~]# docker ps
CONTAINER ID        IMAGE                                COMMAND                  CREATED             STATUS                    PORTS                                          NAMES
7cd0a3585c2a        goharbor/harbor-jobservice:v2.1.5    "/harbor/entrypoint.…"   36 minutes ago      Up 36 minutes (healthy)                                                  harbor-jobservice
7736b855ee98        goharbor/nginx-photon:v2.1.5         "nginx -g 'daemon of…"   36 minutes ago      Up 36 minutes (healthy)   0.0.0.0:80->8080/tcp, 0.0.0.0:1443->8443/tcp   nginx
494a435c2f71        goharbor/harbor-core:v2.1.5          "/harbor/entrypoint.…"   36 minutes ago      Up 36 minutes (healthy)                                                  harbor-core
9033413fc62f        goharbor/harbor-registryctl:v2.1.5   "/home/harbor/start.…"   36 minutes ago      Up 36 minutes (healthy)                                                  registryctl
fa1ce8539d13        goharbor/registry-photon:v2.1.5      "/home/harbor/entryp…"   36 minutes ago      Up 36 minutes (healthy)                                                  registry
78645ca0bb09        goharbor/harbor-portal:v2.1.5        "nginx -g 'daemon of…"   36 minutes ago      Up 36 minutes (healthy)                                                  harbor-portal
7d0d620b32e9        goharbor/harbor-log:v2.1.5           "/bin/sh -c /usr/loc…"   36 minutes ago      Up 36 minutes (healthy)   127.0.0.1:1514->10514/tcp                      harbor-log
[root@harbor01 ~]# tail -f /var/log/harbor/core.log
Mar  3 17:15:00 localhost core[52022]: 2023-03-03T09:15:00Z [INFO] [/core/main.go:244]: Removing Trivy scanner
Mar  3 17:15:00 localhost core[52022]: 2023-03-03T09:15:00Z [INFO] [/core/main.go:258]: Removing Clair scanner
Mar  3 17:15:00 localhost core[52022]: 2023-03-03T09:15:00Z [INFO] [/core/main.go:202]: initializing notification...
Mar  3 17:15:00 localhost core[52022]: 2023-03-03T09:15:00Z [INFO] [/pkg/notification/notification.go:47]: notification initialization completed
Mar  3 17:15:00 localhost core[52022]: 2023-03-03T09:15:00Z [INFO] [/core/main.go:221]: Version: v2.1.5, Git commit: 919c9fd2
Mar  3 17:15:00 localhost core[52022]: redis: 2023/03/03 09:15:00 sentinel.go:329: sentinel: discovered new sentinel="854c4ca44debe8a9a24fb28ef0fbb869640279d5" for master="mymaster"
Mar  3 17:15:00 localhost core[52022]: redis: 2023/03/03 09:15:00 sentinel.go:329: sentinel: discovered new sentinel="3e1468fd0b967fc250101ca5298785b87dac0606" for master="mymaster"
Mar  3 17:15:00 localhost core[52022]: redis: 2023/03/03 09:15:00 sentinel.go:296: sentinel: new master="mymaster" addr="11.0.1.7:6379"
Mar  3 17:15:00 localhost core[52022]: 2023/03/03 09:15:00.903 #033[1;34m[I]#033[0m [asm_amd64.s:1373]  http server Running on http://:8080
Mar  3 17:17:15 localhost core[52022]: 2023-03-03T09:17:15Z [INFO] [/replication/registry/healthcheck.go:60]: Start regular health check for registries with interval 5m0s
```

检查登录仓库

```sh
# 测试直接登录 harbor 是否正常
[root@harbor01 ~]# docker login 11.0.1.10:1443 -u admin -p Harbor12345
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
[root@harbor01 ~]# docker login 11.0.1.11:1443 -u admin -p Harbor12345
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
[root@harbor01 ~]# docker login 11.0.1.12:1443 -u admin -p Harbor12345
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded

# 测试使用 VIP 通过 nginx 代理登录
[root@harbor01 ~]# docker login 11.0.1.30 -u admin -p Harbor12345
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
```

检查镜像推送仓库

```sh
[root@harbor01 ~]# docker pull hello-world
Using default tag: latest
latest: Pulling from library/hello-world
2db29710123e: Pull complete
Digest: sha256:2498fce14358aa50ead0cc6c19990fc6ff866ce72aeb5546e1d59caac3d0d60f
Status: Downloaded newer image for hello-world:latest
docker.io/library/hello-world:latest
[root@harbor01 ~]# docker tag hello-world:latest 11.0.1.30/library/hello-world:latest
[root@harbor01 ~]# docker push 11.0.1.30/library/hello-world:latest
The push refers to repository [11.0.1.30/library/hello-world]
e07ee1baac5f: Pushed
latest: digest: sha256:f54a58bc1aac5ea1a25d796ae155dc228b3f0e11d046ae276b39c4bf2f13d8c4 size: 525
```

检查 nginx 负载均衡日志

```sh
[root@localhost ~]# tail -f /var/log/nginx/harbor-access.log
[03/Mar/2023:17:55:36 +0800] 200 - 源IP - 11.0.1.10 目的IP - 11.0.1.10:1443 200 1882
[03/Mar/2023:17:55:36 +0800] 200 - 源IP - 11.0.1.10 目的IP - 11.0.1.11:1443 200 4691
[03/Mar/2023:17:55:36 +0800] 200 - 源IP - 11.0.1.10 目的IP - 11.0.1.12:1443 200 2206
[03/Mar/2023:17:55:36 +0800] 200 - 源IP - 11.0.1.10 目的IP - 11.0.1.10:1443 200 1887
[03/Mar/2023:17:55:36 +0800] 200 - 源IP - 11.0.1.10 目的IP - 11.0.1.11:1443 200 1887
[03/Mar/2023:17:55:36 +0800] 200 - 源IP - 11.0.1.10 目的IP - 11.0.1.12:1443 200 1882
[03/Mar/2023:17:55:36 +0800] 200 - 源IP - 11.0.1.10 目的IP - 11.0.1.10:1443 200 3681
[03/Mar/2023:17:55:36 +0800] 200 - 源IP - 11.0.1.10 目的IP - 11.0.1.11:1443 200 2206
[03/Mar/2023:17:55:36 +0800] 200 - 源IP - 11.0.1.10 目的IP - 11.0.1.12:1443 200 1887
[03/Mar/2023:17:55:36 +0800] 200 - 源IP - 11.0.1.10 目的IP - 11.0.1.10:1443 200 2462
```

检查 VIP 是否可以切换

```sh
[root@localhost ~]# systemctl stop nginx
[root@localhost ~]# 登出
Connection to 11.0.1.13 closed.
[root@redis-master01 ~]# ssh 11.0.1.14
Last login: Fri Mar  3 17:15:10 2023 from 11.0.1.7
[root@localhost ~]# systemctl status keepalived
● keepalived.service - LVS and VRRP High Availability Monitor
   Loaded: loaded (/usr/lib/systemd/system/keepalived.service; enabled; vendor preset: disabled)
   Active: active (running) since 五 2023-03-03 17:15:10 CST; 42min ago
  Process: 66999 ExecStart=/usr/sbin/keepalived $KEEPALIVED_OPTIONS (code=exited, status=0/SUCCESS)
 Main PID: 67000 (keepalived)
   CGroup: /system.slice/keepalived.service
           ├─67000 /usr/sbin/keepalived -D
           ├─67001 /usr/sbin/keepalived -D
           └─67002 /usr/sbin/keepalived -D

3月 03 17:57:53 localhost.localdomain Keepalived_vrrp[67002]: VRRP_Instance(VI_redis) forcing a new MASTER election
3月 03 17:57:56 localhost.localdomain Keepalived_vrrp[67002]: VRRP_Instance(VI_redis) Transition to MASTER STATE
3月 03 17:57:59 localhost.localdomain Keepalived_vrrp[67002]: VRRP_Instance(VI_redis) Entering MASTER STATE
3月 03 17:57:59 localhost.localdomain Keepalived_vrrp[67002]: VRRP_Instance(VI_redis) setting protocol VIPs.
3月 03 17:57:59 localhost.localdomain Keepalived_vrrp[67002]: Sending gratuitous ARP on ens33 for 11.0.1.30
3月 03 17:57:59 localhost.localdomain Keepalived_vrrp[67002]: VRRP_Instance(VI_redis) Sending/queueing gratuitous ARPs on ens33 for 11.0.1.30
3月 03 17:57:59 localhost.localdomain Keepalived_vrrp[67002]: Sending gratuitous ARP on ens33 for 11.0.1.30
3月 03 17:57:59 localhost.localdomain Keepalived_vrrp[67002]: Sending gratuitous ARP on ens33 for 11.0.1.30
3月 03 17:57:59 localhost.localdomain Keepalived_vrrp[67002]: Sending gratuitous ARP on ens33 for 11.0.1.30
3月 03 17:57:59 localhost.localdomain Keepalived_vrrp[67002]: Sending gratuitous ARP on ens33 for 11.0.1.30
[root@localhost ~]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: ens33: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 00:0c:29:c8:3a:b2 brd ff:ff:ff:ff:ff:ff
    inet 11.0.1.14/24 brd 11.0.1.255 scope global noprefixroute dynamic ens33
       valid_lft 1429sec preferred_lft 1429sec
    inet 11.0.1.30/32 scope global ens33
       valid_lft forever preferred_lft forever
    inet6 fe80::bc68:3b95:11e5:ab8f/64 scope link tentative noprefixroute dadfailed
       valid_lft forever preferred_lft forever
    inet6 fe80::1399:924d:dc58:cdc7/64 scope link tentative noprefixroute dadfailed
       valid_lft forever preferred_lft forever
    inet6 fe80::c798:ca5d:a500:db2e/64 scope link tentative noprefixroute dadfailed
       valid_lft forever preferred_lft forever
```

### 8. 录屏演示

<video width="1200" height="600" controls>
    <source src="http://blog.tianxiang.love/data/harbor%E9%AB%98%E5%8F%AF%E7%94%A8.mp4">
</video>
