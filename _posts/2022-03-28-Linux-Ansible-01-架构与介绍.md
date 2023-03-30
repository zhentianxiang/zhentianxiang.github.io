---
layout: post
title: Linux-Ansible-01-架构与介绍
date: 2022-03-28
tags: Linux-Ansible
---

## 一、Ansible 介绍与架构

### 1. Ansible 特性

 - 模块化：调用特定的模块，完成特定任务

 - Paramiko （python对ssh的实现）、PyYaml、Jinja2（模块语言）三个关键模块

 - 支持自定义模块，可使用任何编程语言写模块

 - 基础Python语言实现

 - 部署简单，基于 python 和 ssh（默认安装），agentless，无需代理不依赖 pki（无需ssl）

 - 安全，基于 openssh

 - 幂等性，一个任务执行1遍和执行N遍效果是一样的，不因重复执行带来意外情况

 - 支持 playbook 编排任务，YAML 格式，编排任务，支持丰富的数据结构

 - 较强大的多层解决方案 role

### 2. Ansible 架构

> 组合 INVENTORY、API、MODULES、PIUGINS 的绿框，可以理解为是ansible命令工具，其为核心执行工具

 - INVENTORY：ANSI 不了管理主机的清单 `/etc/ansible/hosts`

 - MODULES：Ansible 执行命令的功能模块，多为内置核心模块，也可自定义

 - PLUGINS：模块功能的补充，如连接类型插件、循环插件、变量插件、过滤插件等，该功能不常用

 - API：供第三方程序调用的应用程序编程接口

### 3. Ansible 安装和入门

修改主机名

```sh
[root@localhost ~]# hostnamectl set-hostname ansible && bash
```

查看ansible信息

```sh
[root@ansible ~]# yum info ansible
已加载插件：fastestmirror
Loading mirror speeds from cached hostfile
可安装的软件包
名称    ：ansible
架构    ：noarch
版本    ：2.9.27
发布    ：1.el7
大小    ：17 M
源    ：epel
简介    ： SSH-based configuration management, deployment, and task execution system
网址    ：http://ansible.com
协议    ： GPLv3+
描述    ： Ansible is a radically simple model-driven configuration management,
         : multi-node deployment, and remote task execution system. Ansible works
         : over SSH and does not require any software or daemons to be installed
         : on remote nodes. Extension modules can be written in any language and
         : are transferred to managed machines automatically.
```

基于centos7 yum 安装ansible

```sh
[root@ansible ~]# yum -y install ansible
.........................................

作为依赖被安装:
  PyYAML.x86_64 0:3.10-11.el7              libyaml.x86_64 0:0.1.4-11.el7_0         python-babel.noarch 0:0.9.6-8.el7         python-backports.x86_64 0:1.0-8.el7    python-backports-ssl_match_hostname.noarch 0:3.5.0.1-1.el7    python-cffi.x86_64 0:1.6.0-5.el7         
  python-enum34.noarch 0:1.0.4-1.el7       python-idna.noarch 0:2.4-1.el7          python-ipaddress.noarch 0:1.0.16-2.el7    python-jinja2.noarch 0:2.7.2-4.el7     python-markupsafe.x86_64 0:0.11-10.el7                        python-paramiko.noarch 0:2.1.1-9.el7     
  python-ply.noarch 0:3.4-11.el7           python-pycparser.noarch 0:2.14-1.el7    python-setuptools.noarch 0:0.9.8-7.el7    python-six.noarch 0:1.9.0-2.el7        python2-cryptography.x86_64 0:1.7.2-2.el7                     python2-httplib2.noarch 0:0.18.1-3.el7   
  python2-jmespath.noarch 0:0.9.4-2.el7    python2-pyasn1.noarch 0:0.1.9-7.el7     sshpass.x86_64 0:1.06-2.el7              

完毕！
[root@ansible ~]# ansible --version
ansible 2.9.27
  config file = /etc/ansible/ansible.cfg
  configured module search path = [u'/root/.ansible/plugins/modules', u'/usr/share/ansible/plugins/modules']
  ansible python module location = /usr/lib/python2.7/site-packages/ansible
  executable location = /usr/bin/ansible
  python version = 2.7.5 (default, Oct 14 2020, 14:45:30) [GCC 4.8.5 20150623 (Red Hat 4.8.5-44)]
```

#### 3.1 Ansible相关文件

**配置文件**

 - `/etc/ansible/ansible.cfg` 主配置文件，配置ansible工作特性（基本不需要修改）

 - `/etc/ansible/hosts` 主机清单（管理的目标主机地址写入到文件中，否则 ansible 无法连接被管理主机）

 - `/etc/ansible/roles` 存放角色的目录

Ansible 的配置文件

```sh
[defaults]

# some basic default values...

#inventory      = /etc/ansible/hosts   # 主机列表配置文件
#library        = /usr/share/my_modules/   # 库未见存放目录
#module_utils   = /usr/share/my_module_utils/   ###
#remote_tmp     = ~/.ansible/tmp   # 临时py命令文件存放在远程主机目录
#local_tmp      = ~/.ansible/tmp    # 本机的临时命令执行目录
#plugin_filters_cfg = /etc/ansible/plugin_filters.yml
#forks          = 5    # 默认并发数
#poll_interval  = 15
#sudo_user      = root   # 默认 sudo 用户
#ask_sudo_pass = True   # 每次执行 ansible 命令是否询问ssh密码
#host_key_checking = False      # 每次远程连接的时候提示yes/no，开启之后默认就是yes了，建议取消注释
#ask_pass      = True
#transport      = smart
#log_path = /var/log/ansible.log    # 日志文件，建议启用
#remote_port    = 22       # 默认远程端口
#module_lang    = C
#module_set_locale = False
#module_name = command   # 默认模块，可以修改为shell模块
```

Ansible hosts 配置文件

```sh
[root@ansible ~]# vim /etc/ansible/hosts
[webserver]
192.168.20.108
# 192.168.20.[120:130]   也可以用这个来表示同网段内的一组地址

[dbserver]
192.168.20.111

[appserver]
192.168.20.113

```

#### 3.2 Ansible 相关工具

 - ansible           主程序，临时命令执行工具

 - ansible-doc       查看配置文档。模块功能查看工具

 - ansible-galaxy    下载上传代码或 Roles 模块的官网平台

 - ansible-playbook   定制化自动任务，编排剧本工具

 - ansible-vault      文件加密工具

 - ansible-console    基于 console 界面与用户交互的执行工具


**举例：**

```sh
# 列出所有模块
[root@ansible ~]# ansible-doc -l
# 查看指定模块帮助用法
[root@ansible ~]# ansible-doc ping
# 查看指定模块帮助用法（简化版）
[root@ansible ~]# ansible-doc -s ping
```

在使用 ansible 命令操作 node 节点之前，需要配置好主节点与 node 节点之间的免密登陆

```sh
[root@ansible ~]# cat /etc/hosts
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.20.108 node01
192.168.20.111 node02
192.168.20.113 node03
[root@ansible ~]# ssh-keygen  //一路回车
# 如果提示找不到 `scp: /root/.ssh/: Is a director` 那么登陆到那台机器上去执行一下 `ssh localhost`
[root@ansible ~]# scp ~/.ssh/id_rsa.pub node01:~/.ssh/
[root@ansible ~]# scp ~/.ssh/id_rsa.pub node02:~/.ssh/
[root@ansible ~]# scp ~/.ssh/id_rsa.pub node03:~/.ssh/
# 切换到 node 机器
[root@node01 ~]# cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
```

如果机器比较多的话，且同网段，可以用这个脚本来完成

```sh
[root@ansible ~]# vim ssh-keygen
#!/bin/bash
ssh-keygen -f /root/.ssh/id_rsa -P ''

NET=192.168.20

export SSHPASS=123123

for IP in {105..120};do

    sshpass -e ssh-copy-id $NET.$IP

done
```

**格式：**

```sh
# 指定分组分类名称，指定模块，指定参数
[root@ansible ~]# ansible <host-pattern> [-m module_name] [-a args]
```

**选项说明：**

```sh
-- version               # 显示版本

-m                       # 指定模块，默认为command

-v                       # 详细过程，-vv -vvv 更详细

-- list-host             # 显示主机列表，可简写 --list

-k，--ask-pass           # 提示输入ssh连接密码，默认key验证

-c，--check              # 检查，并不执行

-T，--timeout=TIMEOUT    # 执行命令的超市时间，默认10s

-U，--user=REMOTE_USER   # 执行远程执行的用户

-b，--become             # 代替旧版的sudo切换

--become-user=USERNAME   # 指定sudo的runas用户，默认为root

-k，--ask-become-pass    # 提示输入sudo时的口令
```

**示例演示**

```sh
# all 表示所有的主机，不区分哪个分组分类
[root@ansible ~]# ansible all -m ping
192.168.20.113 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.20.111 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.20.108 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
```

#### 3.3 Ansible 多元匹配方式

**通配符**

```sh
[root@ansible ~]# ansible "*" --list
  hosts (3):
    192.168.20.113
    192.168.20.108
    192.168.20.111
```

**或关系**

```sh
[root@ansible ~]# ansible "webserver:appserver" -m ping
192.168.20.113 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.20.108 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
```

**逻辑与**

```sh
# 在webserver中并且在dbserver组中的主机
[root@ansible ~]# ansible "webserver;&dbserver" -m ping
[WARNING]: Could not match supplied host pattern, ignoring: webserver;&dbserver
[WARNING]: No hosts matched, nothing to do
提示这个是正常的，因为我没并没有这样条件的主机，即在webserver中又在dbsever中
```

**逻辑非**

```sh
# 在webserver中，但不在dbsever组中的主机
# 注意，此时为单引号
[root@ansible ~]# ansible 'webserver:!appserver' -m ping
192.168.20.108 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
```

**正则表达式**

```sh
# 以web或db开头，的server
[root@ansible ~]# ansible "~(web|db)server" -m ping
192.168.20.108 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}
192.168.20.111 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": false,
    "ping": "pong"
}

```

#### 3.4 Ansible-galaxy

此工具会连接 https://galaxy.ansible.com 下载相应的 roles

**举例示范：**

```sh
# 查看
[root@ansible ~]# ansible-galaxy list
# /usr/share/ansible/roles
# /etc/ansible/roles
[WARNING]: - the configured path /root/.ansible/roles does not exist.
# 安装
[root@ansible ~]# ansible-galaxy install geerlingguy.redis
- downloading role 'redis', owned by geerlingguy
- downloading role from https://github.com/geerlingguy/ansible-role-redis/archive/1.7.0.tar.gz
- extracting geerlingguy.redis to /root/.ansible/roles/geerlingguy.redis
- geerlingguy.redis (1.7.0) was installed successfully
[root@ansible ~]# ansible-galaxy list
# /root/.ansible/roles
- geerlingguy.redis, 1.7.0
# /usr/share/ansible/roles
# /etc/ansible/roles
# 删除
[root@ansible ~]# ansible-galaxy remove geerlingguy.redis
- successfully removed geerlingguy.redis
```

#### 3.5 Ansible-pull

此工具会推送ansible的命令至远程，效率无限提升，对运维要求较高

#### 3.6 Ansible-playbook

此工具用于执行编写好的playbook任务

**示例：**

```YAML
[root@ansible data]# cat hello.yml
---
# hello world yml file

- hosts: webserver    #指定所执行的主机
  remote_user: root
  tasks:
    - name: hello world
      command: /usr/bin/wall hello world

```
执行playbook
```sh
[root@ansible data]# ansible-playbook hello.yml

PLAY [webserver] *************************************************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] *******************************************************************************************************************************************************************************************************************************************************
ok: [192.168.20.108]

TASK [hello world] ***********************************************************************************************************************************************************************************************************************************************************
changed: [192.168.20.108]

PLAY RECAP *******************************************************************************************************************************************************************************************************************************************************************
192.168.20.108             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

#### 3.7 Ansible-vault

此工具可以用于加密解密yml文件

```sh
[root@ansible data]# ansible-vault encrypt hello.yml
New Vault password: 123123
Confirm New Vault password: 123123
Encryption successful
[root@ansible data]# ll
总用量 4
-rw------- 1 root root 873 3月  29 14:18 hello.yml
[root@ansible data]# cat hello.yml
$ANSIBLE_VAULT;1.1;AES256
66626334623461363939346264646639323433313363613334633661336363386238643365316163
6431646164396235313936356238623133646363323234340a373537623063316237343432316332
61633666633564373738376561303534303762376664663138666136383431313263636631313136
6330343336613433360a373931303062393962623135653133633230346338653335386561653466
33353336636132383537343761376631373735383934326632353037653338636334333937616238
65386238353564623236323066613030323135643333383966363261643263373635633032376536
37653234333033383338393838613637303861643961306134386635623539323736393437383530
32616336663665373035666438336132313534323938356532376462666131383236366435346333
34613863373835623839373136623264643537383064643965636231613731613434636233366164
33386330333833313732373932346263666466363330366261346463346439353936643336616238
626337623435643438646535346463613636
```

再次执行

```sh
# 提示错误，需要解密
[root@ansible data]# ansible-playbook hello.yml
ERROR! Attempting to decrypt but no vault secrets found
[root@ansible data]# ansible-vault decrypt hello.yml
Vault password:
Decryption successful
[root@ansible data]# ansible-playbook hello.yml

PLAY [webserver] *************************************************************************************************************************************************************************************************************************************************************

TASK [Gathering Facts] *******************************************************************************************************************************************************************************************************************************************************
ok: [192.168.20.108]

TASK [hello world] ***********************************************************************************************************************************************************************************************************************************************************
changed: [192.168.20.108]

PLAY RECAP *******************************************************************************************************************************************************************************************************************************************************************
192.168.20.108             : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

#### 3.8 Ansible-console

此工具可以交互执行命令，支持tab，ansible2.0+ 新增

就好像是进入到hosts主机列表里面去了

> 常用子命令
- 设置并发数： forks n 例如：forks 10
- 切换到组：cd 例如：cd webserver
- 列出当前组的主机列表：list
- 列出所有的内置命令：? 或者 help

**示例：**

```sh
root@all (3)[f:5]$ list
192.168.20.113
192.168.20.108
192.168.20.111
root@all (3)[f:5]$ cd appserver
root@appserver (1)[f:5]$ list
192.168.20.113
root@appserver (1)[f:5]$ yum name=httpd state=present
root@appserver (1)[f:5]$ service name=httpd state=stated
```

### 4. Ansible 常用模块

常用模块帮助文档：https://docs.ansible.com/ansible/latest/modules/modules_by_categort.html

#### 1. command 模块

功能：在远程主机上执行命令，默认模块为此模块，可忽略-m选项

注意：此模块不支持$VARNAME <> | ; & 等，用shell模块实现

**示例：**

```sh
[root@ansible data]# ansible-doc -s command
- name: Execute commands on targets
  command:
      argv:                  # Passes the command as a list rather than a string. Use `argv' to avoid quoting values that would otherwise be interpreted incorrectly (for example "user name"). Only the string or the list form can be provided, not both.  One or the other
                               must be provided.
      chdir:                 # Change into this directory before running the command.
      cmd:                   # The command to run.
      creates:               # A filename or (since 2.0) glob pattern. If it already exists, this step *won't* be run.
      free_form:             # The command module takes a free form command to run. There is no actual parameter named 'free form'.
      removes:               # A filename or (since 2.0) glob pattern. If it already exists, this step *will* be run.
      stdin:                 # Set the stdin of the command directly to the specified value.
      stdin_add_newline:     # If set to `yes', append a newline to stdin data.
      strip_empty_ends:      # Strip empty lines from the end of stdout/stderr in result.
      warn:                  # Enable or disable task warnings.
```

```sh
# 针对 webserver 下的主机进行 ping 网关地址
[root@ansible data]# ansible webserver -m command -a 'ping -c 4 192.168.20.1'
192.168.20.108 | CHANGED | rc=0 >>
PING 192.168.20.1 (192.168.20.1) 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=64 time=32.5 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=64 time=0.291 ms
64 bytes from 192.168.20.1: icmp_seq=3 ttl=64 time=0.248 ms
64 bytes from 192.168.20.1: icmp_seq=4 ttl=64 time=0.313 ms

--- 192.168.20.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3002ms
rtt min/avg/max/mdev = 0.248/8.355/32.568/13.979 ms

# 针对所有的主机进行 ping 网关地址
[root@ansible data]# ansible all -m command -a 'ping -c 4 192.168.20.1'
192.168.20.108 | CHANGED | rc=0 >>
PING 192.168.20.1 (192.168.20.1) 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=64 time=0.367 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=64 time=0.300 ms
64 bytes from 192.168.20.1: icmp_seq=3 ttl=64 time=0.307 ms
64 bytes from 192.168.20.1: icmp_seq=4 ttl=64 time=0.429 ms

--- 192.168.20.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3002ms
rtt min/avg/max/mdev = 0.300/0.350/0.429/0.056 ms
192.168.20.113 | CHANGED | rc=0 >>
PING 192.168.20.1 (192.168.20.1) 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=64 time=0.273 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=64 time=0.330 ms
64 bytes from 192.168.20.1: icmp_seq=3 ttl=64 time=0.363 ms
64 bytes from 192.168.20.1: icmp_seq=4 ttl=64 time=0.362 ms

--- 192.168.20.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3000ms
rtt min/avg/max/mdev = 0.273/0.332/0.363/0.036 ms
192.168.20.111 | CHANGED | rc=0 >>
PING 192.168.20.1 (192.168.20.1) 56(84) bytes of data.
64 bytes from 192.168.20.1: icmp_seq=1 ttl=64 time=0.261 ms
64 bytes from 192.168.20.1: icmp_seq=2 ttl=64 time=0.295 ms
64 bytes from 192.168.20.1: icmp_seq=3 ttl=64 time=0.230 ms
64 bytes from 192.168.20.1: icmp_seq=4 ttl=64 time=6.51 ms

--- 192.168.20.1 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3000ms
rtt min/avg/max/mdev = 0.230/1.826/6.518/2.709 ms

# 查看系统版本
[root@ansible data]# ansible webserver -m command -a 'cat /etc/centos-release'
192.168.20.108 | CHANGED | rc=0 >>
CentOS Linux release 7.9.2009 (Core)
# 跟上指定参数，进入到特定目录下
[root@ansible data]# ansible webserver -m command -a 'chdir=/etc cat centos-release'
192.168.20.108 | CHANGED | rc=0 >>
CentOS Linux release 7.9.2009 (Core)
```

但是有些字符或名利用默认的command模块就行不通了

```sh
[root@ansible data]# ansible appserver -m command  -a 'mkdir /data'
[WARNING]: Consider using the file module with state=directory rather than running 'mkdir'.  If you need to use command because file is insufficient you can add 'warn: false' to this command task or set 'command_warnings=False' in ansible.cfg to get rid of this
message.
192.168.20.113 | CHANGED | rc=0 >>
[root@ansible data]# ansible appserver -m command -a 'ls /data'
192.168.20.113 | CHANGED | rc=0 >>
[root@ansible data]# ansible appserver -m command -a 'echo hello > /data/hello.log'
192.168.20.113 | CHANGED | rc=0 >>
hello > /data/hello.log

# 看似成功的echo了一些内容，但是查看根本没有
[root@ansible data]# ansible appserver -m command -a 'cat /data/hello.log'
192.168.20.113 | FAILED | rc=1 >>
cat: /data/hello.log: 没有那个文件或目录non-zero return code
[root@ansible data]# ansible appserver -m command -a 'ls /data/'
192.168.20.113 | CHANGED | rc=0 >>

# 而且应用变量根本不行
[root@ansible data]# ansible appserver -m command -a 'echo $HOSTNAME'
192.168.20.113 | CHANGED | rc=0 >>
$HOSTNAME
# 用单引号还不行，必须得用双引号，而且显示的主机名还是ansible节点的，根本不是appserver组中的主机
[root@ansible data]# ansible appserver -m command -a "echo $HOSTNAME"
192.168.20.113 | CHANGED | rc=0 >>
ansible
```

#### 2. Shell模块

功能：和command相似，用shell去执行命令，它可以执行特殊的符号，比command要强大一些

**示例：**

```sh
[root@ansible data]# ansible appserver -m shell -a "echo $HOSTNAME"
192.168.20.113 | CHANGED | rc=0 >>
ansible
# 这次要用单引号
[root@ansible data]# ansible appserver -m shell -a 'echo $HOSTNAME'
192.168.20.113 | CHANGED | rc=0 >>
node03
[root@ansible data]# ansible appserver -m shell -a 'echo hello > /data/hello.log'
192.168.20.113 | CHANGED | rc=0 >>
[root@ansible data]# ansible appserver -m shell -a 'cat /data/hello.log'
192.168.20.113 | CHANGED | rc=0 >>
hello
# 创建一些用户
[root@ansible data]# ansible all -m shell -a 'useradd abc'
192.168.20.108 | CHANGED | rc=0 >>

192.168.20.113 | CHANGED | rc=0 >>

192.168.20.111 | CHANGED | rc=0 >>
# 修改用户密码
[root@ansible data]# ansible all -m shell -a 'echo 123123 | passwd --stdin abc'
192.168.20.108 | CHANGED | rc=0 >>
更改用户 abc 的密码 。
passwd：所有的身份验证令牌已经成功更新。
192.168.20.113 | CHANGED | rc=0 >>
更改用户 abc 的密码 。
passwd：所有的身份验证令牌已经成功更新。
192.168.20.111 | CHANGED | rc=0 >>
更改用户 abc 的密码 。
passwd：所有的身份验证令牌已经成功更新。
```

以上测试由此发现，像管道符和大于小于号都能用shell模块来完成了

然后为此我们还可以修改shell模块为默认的模块

```sh
[root@ansible data]# vim /etc/ansible/ansible.cfg
module_name = shell
```

#### 3. Script 模块

功能：在远程主机上执行ansible主机上的脚本

**示例：**

```sh
# 本机测试创建一个脚本并执行
[root@ansible data]# cat hostname.sh
#!/bin/bash
echo "My hostname is $HOSTNAME"
[root@ansible data]# ./hostname.sh
My hostname is ansible
# ansible 执行 脚本
[root@ansible data]# ansible webserver -m script -a 'hostname.sh'
192.168.20.108 | CHANGED => {
    "changed": true,
    "rc": 0,
    "stderr": "Shared connection to 192.168.20.108 closed.\r\n",
    "stderr_lines": [
        "Shared connection to 192.168.20.108 closed."
    ],
    "stdout": "My hostname is node01\r\n",
    "stdout_lines": [
        "My hostname is node01"
    ]
}
```

#### 4. Copy 模块

功能：从ansible机器像node节点拷贝传输文件

**示例：**

```sh
[root@ansible data]# ansible webserver -m copy -a "src=/root/data/hello.yml dest=/root/hello.yml owner=root mode=600"
192.168.20.108 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": true,
    "checksum": "c35e2cf4bb90f1b29f1bc883ab65989e98e17dce",
    "dest": "/root/hello.yml",
    "gid": 0,
    "group": "root",
    "md5sum": "d883625d94cd6d986d118ac1ca366bfa",
    "mode": "0600",
    "owner": "root",
    "size": 141,
    "src": "/root/.ansible/tmp/ansible-tmp-1648541223.18-2998-63223546833824/source",
    "state": "file",
    "uid": 0
}
[root@ansible data]# ansible webserver -a 'ls -l /root'
192.168.20.108 | CHANGED | rc=0 >>
总用量 8
-rw-------. 1 root root 1530 2月  24 11:18 anaconda-ks.cfg
-rw-------  1 root root  141 3月  29 16:07 hello.yml
```

#### 5. Fetach 模块

功能：从远程主机提取文件至ansible的节点，目前不支持抓取远端主机上的目录文件

```sh
[root@ansible data]# ansible webserver -m fetch -a 'src=/root/anaconda-ks.cfg dest=/root/data/test'
192.168.20.108 | CHANGED => {
    "changed": true,
    "checksum": "92c20d50f07895c9256a391bccc63bc4c4e876cd",
    "dest": "/root/data/test/192.168.20.108/root/anaconda-ks.cfg",
    "md5sum": "e35148f8e4f9c9a6e3e4057df66aaf51",
    "remote_checksum": "92c20d50f07895c9256a391bccc63bc4c4e876cd",
    "remote_md5sum": null
}
[root@ansible data]# ls
hello.yml  hostname.sh  test
[root@ansible data]# tree test/
test/
└── 192.168.20.108
    └── root
        └── anaconda-ks.cfg
```

#### 6. File 模块

功能：设置文件属性

```sh
# 创建一个文件
[root@hadoop01 ~]# ansible appserver -m file -a 'path=/root/first-01.txt state=touch'
hadoop03 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": true,
    "dest": "/root/first-01.txt",
    "gid": 0,
    "group": "root",
    "mode": "0644",
    "owner": "root",
    "size": 0,
    "state": "file",
    "uid": 0
}
[root@hadoop01 ~]# ansible appserver -a 'ls -l /root'
hadoop03 | CHANGED | rc=0 >>
总用量 52
-rw-------. 1 root root  1529 6月   6 09:53 anaconda-ks.cfg
-rw-r--r--  1 root root     0 7月   5 15:56 first-01.txt
-rw-r--r--  1 root root 47105 7月   5 13:48 zookeeper.out
```
```sh
# 更改文件的属组
[root@hadoop01 ~]# ansible appserver -m file -a 'path=/root/first-01.txt owner=bin group=bin mode=755'
hadoop03 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": true,
    "gid": 0,
    "group": "root",
    "mode": "0755",
    "owner": "bin",
    "group": "bin"
    "path": "/root/first-01.txt",
    "size": 0,
    "state": "file",
    "uid": 1
}
[root@hadoop01 ~]# ansible appserver -a 'ls -l /root'
hadoop03 | CHANGED | rc=0 >>
总用量 52
-rw-------. 1 root root  1529 6月   6 09:53 anaconda-ks.cfg
-rwxr-xr-x  1 bin  bin      0 7月   5 15:56 first-01.txt
-rw-r--r--  1 root root 47105 7月   5 13:48 zookeeper.out
```

```sh
# 删除一个文件
[root@hadoop01 ~]# ansible appserver -m file -a 'path=/root/first-01.txt state=absent'
```

#### 7. unarchive 模块

功能：解压缩包文件

实现有两种方法：
- 将asnible主机伤的压缩包传输到远程主机上然后解压制特定目录，类似 tar -C ，设置copy=yes
- 将远程主机上的某个压缩包解压至特定目录下，设置copy=no

常见参数：
- copy：默认为yes，当copy=yes，拷贝ansbile主机上的文件到远程主机上，为no时，是在远程主机上寻找src源文件
- remote_src: 和copy功能一样且互斥，yes表示在远程主机上，no表示在ansible主机上
- src：源路径，可以是ansible主机也可以是远程主机，如果要指定远程主机的话，那么copy=no
- dest：远程主机上的目标路径
- mode：设置解压后的文件权限

范例：

```sh
[root@hadoop01 ~]# tar zvcf rpm.tar.gz /var/lib/rpm
tar: 从成员名中删除开头的“/”
/var/lib/rpm/
/var/lib/rpm/.dbenv.lock
/var/lib/rpm/Packages
/var/lib/rpm/Name
/var/lib/rpm/Basenames
/var/lib/rpm/Group
/var/lib/rpm/Requirename
/var/lib/rpm/Providename
/var/lib/rpm/Conflictname
/var/lib/rpm/Obsoletename
/var/lib/rpm/Triggername
/var/lib/rpm/Dirnames
/var/lib/rpm/Installtid
/var/lib/rpm/Sigmd5
/var/lib/rpm/Sha1header
/var/lib/rpm/.rpm.lock
/var/lib/rpm/__db.001
/var/lib/rpm/__db.002
/var/lib/rpm/__db.003
[root@hadoop01 ~]# ls
anaconda-ks.cfg  rpm.tar.gz  zookeeper.out
[root@hadoop01 ~]# ansible appserver -m unarchive -a 'src=/root/rpm.tar.gz dest=/data/'
hadoop03 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": true,
    "dest": "/data/",
    "extract_results": {
        "cmd": [
            "/usr/bin/gtar",
            "--extract",
            "-C",
            "/data/",
            "-z",
            "-f",
            "/root/.ansible/tmp/ansible-tmp-1657009864.6-7296-219305127996044/source"
        ],
        "err": "",
        "out": "",
        "rc": 0
    },
    "gid": 0,
    "group": "root",
    "handler": "TgzArchive",
    "mode": "0755",
    "owner": "root",
    "size": 17,
    "src": "/root/.ansible/tmp/ansible-tmp-1657009864.6-7296-219305127996044/source",
    "state": "directory",
    "uid": 0
}
[root@hadoop01 ~]# ansible appserver -a 'tree /data'
hadoop03 | CHANGED | rc=0 >>
/data
└── var
    └── lib
        └── rpm
            ├── Basenames
            ├── Conflictname
            ├── __db.001
            ├── __db.002
            ├── __db.003
            ├── Dirnames
            ├── Group
            ├── Installtid
            ├── Name
            ├── Obsoletename
            ├── Packages
            ├── Providename
            ├── Requirename
            ├── Sha1header
            ├── Sigmd5
            └── Triggername

3 directories, 16 files
```

```sh
# 将ansible主机上的包拷贝到远程主机
[root@hadoop01 ~]# ansible appserver -m copy -a 'src=/root/rpm.tar.gz dest=/data'
hadoop03 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": true,
    "checksum": "939f9f007cdfe77168509c48fe599c7b77a67163",
    "dest": "/data/rpm.tar.gz",
    "gid": 0,
    "group": "root",
    "md5sum": "e348fd2d6ac86561dcebbbe32e1c8a7f",
    "mode": "0644",
    "owner": "root",
    "size": 16560334,
    "src": "/root/.ansible/tmp/ansible-tmp-1657010195.67-7405-92000960644205/source",
    "state": "file",
    "uid": 0
}
[root@hadoop01 ~]# ansible appserver -a 'ls -l /data'
hadoop03 | CHANGED | rc=0 >>
总用量 16176
-rw-r--r-- 1 root root 16560334 7月   5 16:36 rpm.tar.gz
drwxr-xr-x 3 root root       17 7月   5 16:31 var
# 将远程主机上的包解压到指定目录下
[root@hadoop01 ~]# ansible appserver -m unarchive -a 'src=/data/rpm.tar.gz dest=/opt/ copy=no'
hadoop03 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": true,
    "dest": "/opt/",
    "extract_results": {
        "cmd": [
            "/usr/bin/gtar",
            "--extract",
            "-C",
            "/opt/",
            "-z",
            "-f",
            "/data/rpm.tar.gz"
        ],
        "err": "",
        "out": "",
        "rc": 0
    },
    "gid": 0,
    "group": "root",
    "handler": "TgzArchive",
    "mode": "0755",
    "owner": "root",
    "size": 47,
    "src": "/data/rpm.tar.gz",
    "state": "directory",
    "uid": 0
}
[root@hadoop01 ~]# ansible appserver -a 'ls -l /opt'
hadoop03 | CHANGED | rc=0 >>
总用量 0
drwxr-xr-x 5 root root 47 7月   4 16:18 module
drwxr-xr-x 2 root root 99 7月   4 16:11 software
drwxr-xr-x 3 root root 17 7月   5 16:37 var
```

#### 8. Archive 模块

功能：打包压缩

```sh
[root@hadoop01 ~]# ansible appserver -m archive -a 'path=/opt/var dest=/opt/var.tar.gz format=gz'
hadoop03 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "archived": [
        "/opt/var/lib/rpm/.dbenv.lock",
        "/opt/var/lib/rpm/Packages",
        "/opt/var/lib/rpm/Name",
        "/opt/var/lib/rpm/Basenames",
        "/opt/var/lib/rpm/Group",
        "/opt/var/lib/rpm/Requirename",
        "/opt/var/lib/rpm/Providename",
        "/opt/var/lib/rpm/Conflictname",
        "/opt/var/lib/rpm/Obsoletename",
        "/opt/var/lib/rpm/Triggername",
        "/opt/var/lib/rpm/Dirnames",
        "/opt/var/lib/rpm/Installtid",
        "/opt/var/lib/rpm/Sigmd5",
        "/opt/var/lib/rpm/Sha1header",
        "/opt/var/lib/rpm/.rpm.lock",
        "/opt/var/lib/rpm/__db.001",
        "/opt/var/lib/rpm/__db.002",
        "/opt/var/lib/rpm/__db.003"
    ],
    "arcroot": "/opt/",
    "changed": true,
    "dest": "/opt/var.tar.gz",
    "expanded_exclude_paths": [],
    "expanded_paths": [
        "/opt/var"
    ],
    "gid": 0,
    "group": "root",
    "missing": [],
    "mode": "0644",
    "owner": "root",
    "size": 16456997,
    "state": "file",
    "uid": 0
}
[root@hadoop01 ~]# ansible appserver -a 'ls -l /opt'
hadoop03 | CHANGED | rc=0 >>
总用量 16072
drwxr-xr-x 5 root root       47 7月   4 16:18 module
drwxr-xr-x 2 root root       99 7月   4 16:11 software
drwxr-xr-x 3 root root       17 7月   5 16:37 var
-rw-r--r-- 1 root root 16456997 7月   5 16:44 var.tar.gz
```

#### 9. Yum 模块

功能：管理软件包，针对centos、RHEL等

```sh
# 安装一个软件
[root@hadoop01 ~]# ansible appserver -m yum -a 'name=httpd'
hadoop03 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": true,
    "changes": {
        "installed": [
            "httpd"
        ]
    },
    "msg": "",
    "rc": 0,
    "results": [
        "Loaded plugins: fastestmirror\nLoading mirror speeds from cached hostfile\nResolving Dependencies\n--> Running transaction check\n---> Package httpd.x86_64 0:2.4.6-97.el7.centos.5 will be installed\n--> Processing Dependency: httpd-tools = 2.4.6-97.el7.centos.5 for package: httpd-2.4.6-97.el7.centos.5.x86_64\n--> Processing Dependency: /etc/mime.types for package: httpd-2.4.6-97.el7.centos.5.x86_64\n--> Processing Dependency: libaprutil-1.so.0()(64bit) for package: httpd-2.4.6-97.el7.centos.5.x86_64\n--> Processing Dependency: libapr-1.so.0()(64bit) for package: httpd-2.4.6-97.el7.centos.5.x86_64\n--> Running transaction check\n---> Package apr.x86_64 0:1.4.8-7.el7 will be installed\n---> Package apr-util.x86_64 0:1.5.2-6.el7 will be installed\n---> Package httpd-tools.x86_64 0:2.4.6-97.el7.centos.5 will be installed\n---> Package mailcap.noarch 0:2.1.41-2.el7 will be installed\n--> Finished Dependency Resolution\n\nDependencies Resolved\n\n================================================================================\n Package         Arch       Version                   Repository           Size\n================================================================================\nInstalling:\n httpd           x86_64     2.4.6-97.el7.centos.5     centos7_updates     2.7 M\nInstalling for dependencies:\n apr             x86_64     1.4.8-7.el7               centos7_base        104 k\n apr-util        x86_64     1.5.2-6.el7               centos7_base         92 k\n httpd-tools     x86_64     2.4.6-97.el7.centos.5     centos7_updates      94 k\n mailcap         noarch     2.1.41-2.el7              centos7_base         31 k\n\nTransaction Summary\n================================================================================\nInstall  1 Package (+4 Dependent packages)\n\nTotal download size: 3.0 M\nInstalled size: 10 M\nDownloading packages:\n--------------------------------------------------------------------------------\nTotal                                               13 MB/s | 3.0 MB  00:00     \nRunning transaction check\nRunning transaction test\nTransaction test succeeded\nRunning transaction\n  Installing : apr-1.4.8-7.el7.x86_64                                       1/5 \n  Installing : apr-util-1.5.2-6.el7.x86_64                                  2/5 \n  Installing : httpd-tools-2.4.6-97.el7.centos.5.x86_64                     3/5 \n  Installing : mailcap-2.1.41-2.el7.noarch                                  4/5 \n  Installing : httpd-2.4.6-97.el7.centos.5.x86_64                           5/5 \n  Verifying  : apr-1.4.8-7.el7.x86_64                                       1/5 \n  Verifying  : mailcap-2.1.41-2.el7.noarch                                  2/5 \n  Verifying  : httpd-tools-2.4.6-97.el7.centos.5.x86_64                     3/5 \n  Verifying  : apr-util-1.5.2-6.el7.x86_64                                  4/5 \n  Verifying  : httpd-2.4.6-97.el7.centos.5.x86_64                           5/5 \n\nInstalled:\n  httpd.x86_64 0:2.4.6-97.el7.centos.5                                          \n\nDependency Installed:\n  apr.x86_64 0:1.4.8-7.el7                      apr-util.x86_64 0:1.5.2-6.el7   \n  httpd-tools.x86_64 0:2.4.6-97.el7.centos.5    mailcap.noarch 0:2.1.41-2.el7   \n\nComplete!\n"
    ]
}
[root@hadoop01 ~]# ansible appserver -a 'rpm -qi httpd'
[WARNING]: Consider using the yum, dnf or zypper module rather than running 'rpm'.  If you need to use command because yum, dnf or zypper is insufficient you can add 'warn: false' to this command task or set 'command_warnings=False' in ansible.cfg to get rid of this
message.
hadoop03 | CHANGED | rc=0 >>
Name        : httpd
Version     : 2.4.6
Release     : 97.el7.centos.5
Architecture: x86_64
Install Date: 2022年07月05日 星期二 17时06分52秒
Group       : System Environment/Daemons
Size        : 9821136
License     : ASL 2.0
Signature   : RSA/SHA256, 2022年03月25日 星期五 02时21分56秒, Key ID 24c6a8a7f4a80eb5
Source RPM  : httpd-2.4.6-97.el7.centos.5.src.rpm
Build Date  : 2022年03月24日 星期四 22时59分42秒
Build Host  : x86-02.bsys.centos.org
Relocations : (not relocatable)
Packager    : CentOS BuildSystem <http://bugs.centos.org>
Vendor      : CentOS
URL         : http://httpd.apache.org/
Summary     : Apache HTTP Server
Description :
The Apache HTTP Server is a powerful, efficient, and extensible
web server.
```

```sh
# 卸载一个软件
[root@hadoop01 ~]# ansible appserver -m yum -a 'name=httpd state=absent'
hadoop03 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "changed": true,
    "changes": {
        "removed": [
            "httpd"
        ]
    },
    "msg": "",
    "rc": 0,
    "results": [
        "已加载插件：fastestmirror\n正在解决依赖关系\n--> 正在检查事务\n---> 软件包 httpd.x86_64.0.2.4.6-97.el7.centos.5 将被 删除\n--> 解决依赖关系完成\n\n依赖关系解决\n\n================================================================================\n Package    架构        版本                        源                     大小\n================================================================================\n正在删除:\n httpd      x86_64      2.4.6-97.el7.centos.5       @centos7_updates      9.4 M\n\n事务概要\n================================================================================\n移除  1 软件包\n\n安装大小：9.4 M\nDownloading packages:\nRunning transaction check\nRunning transaction test\nTransaction test succeeded\nRunning transaction\n  正在删除    : httpd-2.4.6-97.el7.centos.5.x86_64                          1/1 \n  验证中      : httpd-2.4.6-97.el7.centos.5.x86_64                          1/1 \n\n删除:\n  httpd.x86_64 0:2.4.6-97.el7.centos.5                                          \n\n完毕！\n"
    ]
}
```

#### 10. service 模块

功能：启动一个systemd管理的服务

```sh
# 启动httpd服务并设置为开机自启
[root@hadoop01 ~]# ansible appserver -m service -a 'name=httpd state=started enable=yes'
```

```sh
# 查看监听端口
[root@hadoop01 ~]# ansible appserver -a 'ss -lntp'
hadoop03 | CHANGED | rc=0 >>
State      Recv-Q Send-Q Local Address:Port               Peer Address:Port              
LISTEN     0      128          *:22                       *:*                   users:(("sshd",pid=914,fd=3))
LISTEN     0      100    127.0.0.1:25                       *:*                   users:(("master",pid=1062,fd=13))
LISTEN     0      128       [::]:80                    [::]:*                   users:(("httpd",pid=3668,fd=4),("httpd",pid=3667,fd=4),("httpd",pid=3666,fd=4),("httpd",pid=3665,fd=4),("httpd",pid=3664,fd=4),("httpd",pid=3663,fd=4))
LISTEN     0      128       [::]:22                    [::]:*                   users:(("sshd",pid=914,fd=4))
LISTEN     0      100      [::1]:25                    [::]:*                   users:(("master",pid=1062,fd=14))
```

```sh
# 停止服务
[root@hadoop01 ~]# ansible appserver -m service -a 'name=httpd state=stoped'
# 重启服务
[root@hadoop01 ~]# ansible appserver -m service -a 'name=httpd state=restarted'
```

### 5. Playbook 功能

#### 1. 简介

playbook是ansible用于配置，部署，和管理被节点的剧本
通过playbook的详细描述，执行其中的一些列tasks，可以让远端的主机达到预期的状态。playbook就像ansible控制器给被控节点列出的一系列to-do-list，而且被控节点必须要完成
playbook顾名思义，即剧本，现实生活中演员按照剧本表演，在ansible中，这次由被控计算机表演，进行安装，部署应用，提供对外的服务等，以及组织计算机处理各种各样的事情。

#### 2. 使用场景

执行一些简单的任务，使用ad-hoc命令可以方便的解决问题，但是有时一个设施过于复杂，需要大量的操作的时候，执行的ad-hoc命令是不合适的，这时候最好使用playbook。
就像执行shell命令与写shell脚本一样，也可以理解为批处理任务，不过playbook有自己的语法格式
使用playbook可以方便的重复使用这些代码，可以移植到不同的机器上面，像函数一样，最大化的利用代码。在你使用Ansible的过程中，你也会发现，你所处理的大部分操作都是编写playbook。可以把常见的应用都编写playbook，之后管理服务器会变得很简单。

#### 3. 格式

playbook由YAML语言编写。
YAML( /ˈjæməl/ )参考了其他多种语言，包括：XML、C语言、Python、Perl以及电子邮件格式RFC2822，Clark Evans在2001年5月在首次发表了这种语言，另外Ingy döt Net与OrenBen-Kiki也是这语言的共同设计者。
YAML格式是类似JSON的文件格式。YAML用于文件的配置编写，JSON多用于开发设计。
YAML的格式如下：

> 1.文件的第一行应该以“—”（三个连字符）开始，表明YAML文件的开始。
>
> 2.在同一行中，#之后的内容表示注释，类似于shell，python和ruby。
>
> 3.YAML中的列表元素以“-”开头并且跟着一个空格。后面为元素内容。
>
> 4.同一个列表之中的元素应该保持相同的缩进，否则会被当做错误处理。
>
> 5.play中hosts、variables、roles、tasks等对象的表示方法都是以键值中间以“：”分隔表示，并且“：”之后要加一个空格。

**(1) List 列表**

列表由多个元素组成，且所有元素前均用 - 打头

```YAML
# A list of tasty fruits

- Apple

- Orange

- Starwebrry

- Mango

[Apple,Orange,Starwebrry,Mango]

# 可以用 - 来表示，也可以用 [] 中括号来表示
```

**（2）Dictionary 字典**

字典通常由多个key和value组成

```YAML
name: zhangsan
age: 20
nationality: china

{name: "zhangsan", age: "20", nationality: "china"}

# 可以key value方式来写，也可以使用画括号来使用
```

json和yaml互相转换在线工具:https://www.json2yaml.com/

#### 4. Playbook 核心元素

- host 执行的专程主机列表

- tasks 任务集

- variables 内置变量或自定义变量在playbook中使用

- templates 模版，可替换模版文件中的变量并实现一些简单逻辑的文件

- handlers 和 notify 结合使用，由特定条件触发的操作，满足条件方才执行，否则不执行

- tags 标签，指定某条任务执行，用于选择运行playbook中的某条代码，ansible具有幂等性，因此会自动跳过没有变化的部分，即便如此，有些代码测试其确实没有发生变化的时间依然会非常长，此时如果确信其没有变化，就可通过tags跳过特定的代码

**（1）host 组件**

指定运行的任务主机，事先必须自定义到主机清单中

```sh
one.example.com
one.example.com:two.example.com
192.168.1.50
192.168.1.*
webserver:dbsever  # 或者，两个组的并集
webserver:&dbsever # 与，两个组的并集
webserver:!phoenix # 在webserver中但不在phoenix中
```

**（2）remote_user 组件**

可用于host和task中，也可以通过指定其通过sudo方式在远程主机上执行任务，其可用于play全局或某任务外；此外可以使用sudo时使用sudo_user指定sudo时切换用户

```YAML
---
- host: webserver
  remote_root: root

  tasks:
    - name: test connection
      ping:
      remote_user: magedu
      sudo: yes            # 默认sudo为root
      sudo_user: wang      # sudo为wang
```

**（3）task列表和action组件**

> play的部分主体是task list ，task list 中有一个或多个task，各个task按次序逐个在host中指定的所有主机上执行，即在所有主机上完成第一个task后，再开始第二个task。
>
> task的目的是使用指定的参数执行模块，而在模块参数中可以使用变量。模块执行是幂等的，这意味着多次执行是安全的，其结果均一致。
>
> 每个task都应该有其name，用于playbook执行结果输出，建议其内容能够清晰地描述任务执行步骤。如果未提供那么则action的结果用于输出。

- task 两种格式

（1）action: module arguments
（2）module: arguments 建议使用

> 注意：shell和command模块后面跟命令，而非key=value

```YAML
---
- host: webserver
  remote_user: root
  tasks:
    - name: install httpd
      yum: name=httpd
    - name: start httpd
      service: name=httpd state=started enabled=yes
```

**（4）其他组件**

某任务的状态在运行后为changed时，可通过notify通知给相应的handlers

任务可以通过tags打标签，可在ansible-playbook命令上使用 -t 指定进行时调用

**(5)ShellScripts vs Playbook 案例**

```sh
#!/bin/bash
# 安装httpd服务
yum install -y --quiet httpd

# 复制配置文件
cp /tmp/httpd.conf /etc/httpd/httpd.conf
cp /tmp/vhosts.conf /etc/httpd/conf.d

# 启动服务，并设置为开机自启

systemctl enable --now httpd
```

```YAML
---
- host: webserver
  remote_user: root
  tasks:
    - name: "安装httpd服务"
    yum: name=httpd
    - name: "复制配置文件"
    copy: src=/tmp/httpd.conf dest=/etc/httpd/httpd.conf
    - name: "复制配置文件"
    copy: src=/tmp/vhosts.conf dest=/etc/httpd/conf.d
    - name: "启动服务并开机自启"
    service: name=httpd state=started enabled=yes
```

#### 5. playbook 命令

格式

```sh
ansible-playbook <filename.yaml>
```

常见选项

> --check -C      # 只检测可能会发生的改变，但不会真正执行操作
>
> --list-hosts    # 列出运行任务的主机
>
> --list-tasks    # 列出task
>
> --list-tags     # 列出tag
>
> --limit         # 只针对主机列表中的主机执行
>
> -v -vv -vvv     # 显示过程

### 6. playbook 初步

#### 1. 利用 playbook 创建 mysql 用户

```YAML
---
- hosts: dbserver       # 针对dbserver主机列表
  remote_user: root     # 以root身份去执行远程主机

  tasks:                                           # 定义任务集
    - name: create group                          # 定义任务名称
      group: name=mysql system=yes gid=306        # 调用group模块来创建mysql组
    - name: create user                           # 定义任务名称
      user: name=mysql shell=/sbin/nologin system=yes group=mysql uid=306 home=/data/mysql create_home=no    # 调用user模块来创建mysql用户
```
检查一遍，去掉 -C 执行脚本
```sh
[root@hadoop01 ansible-playbook]# ansible-playbook -C mysql_user.yaml

PLAY [dbserver] *****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop02]

TASK [create group] *************************************************************************************************************************************************************************
changed: [hadoop02]

TASK [create user] **************************************************************************************************************************************************************************
changed: [hadoop02]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop02                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
检查是否创建出来
```sh
[root@hadoop01 ansible-playbook]# ansible dbserver -a 'getent passwd mysql'
hadoop02 | CHANGED | rc=0 >>
mysql:x:306:306::/data/mysql:/sbin/nologin
[root@hadoop01 ansible-playbook]# ansible dbserver -a 'id mysql'
hadoop02 | CHANGED | rc=0 >>
uid=306(mysql) gid=306(mysql) 组=306(mysql)
```

#### 2. 利用 playbook 安装并启动 nginx

```YAML
---
- hosts: appserver
  remote_user: root

  tasks:

# yum 安装会自动创建nginx用户和租，可以不用刻意创建
#    - name: create group nginx
#      user: name=nginx state=present
#    - name: create user nginx
#      user: name=nginx state=present group=nginx
    - name: install nginx
      yum: name=nginx state=present
    - name: html page
      copy: src=file/index.html dest=/usr/share/nginx/html/index.html
    - name: start nginx
      service: name=nginx state=started enabled=yes
```

```sh
[root@hadoop01 ansible-playbook]# cat file/index.html
<h1>hello world!<h2>
[root@hadoop01 ansible-playbook]# ansible-playbook  install_nginx.yaml

PLAY [appserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop03]

TASK [install nginx] ************************************************************************************************************************************************************************
changed: [hadoop03]

TASK [html page] ****************************************************************************************************************************************************************************
changed: [hadoop03]

TASK [start nginx] **************************************************************************************************************************************************************************
changed: [hadoop03]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop03                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

```sh
[root@hadoop01 ansible-playbook]#  ansible appserver -a 'netstat -lntp'
hadoop03 | CHANGED | rc=0 >>
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      3973/nginx: master  
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      920/sshd            
tcp        0      0 127.0.0.1:25            0.0.0.0:*               LISTEN      1070/master         
tcp6       0      0 :::80                   :::*                    LISTEN      3973/nginx: master  
tcp6       0      0 :::22                   :::*                    LISTEN      920/sshd            
tcp6       0      0 ::1:25                  :::*                    LISTEN      1070/master
```
![](/images/posts/ansible/1.png)

#### 3. 利用playbook二进制安装mysql

基本文件准备

```sh
[root@hadoop01 file]# pwd
/data/ansible-playbook/file
[root@hadoop01 file]#  wget https://cdn.mysql.com//Downloads/MySQL-5.7/mysql-5.6.46-linux-glibc2.12-x86_64.tar.gz
[root@hadoop01 file]# vim my.cnf
[mysqld]
socket=/tmp/mysql.sock
user=mysql
symbolic-links=0
datadir=/data/mysql
innodb_file_per_table=1
log-bin
pid-file=/data/mysql/mysqld.pid

[client]
port=3306
socket=/tmp/mysql.sock

[mysqld_safe]
log-error=/var/log/mysqld.log
[root@hadoop01 file]# vim secure_mysql.sh
#!/bin/bash

/usr/local/mysql/bin/mysql_secure_installation << EOF

y
123456
123456
y
y
y
y
EOF
```

编写playbook

```sh
[root@hadoop01 file]# vim install_mysql.yaml
---
- hosts: dbserver
  remote_user: root

  tasks:
    - name: remove mariadb
      yum: name=mariadb state=absent
    - name: install package
      yum: name=libaio,perl-Data-Dumper,perl-Getopt-Long,autoconf,cmake,ncurses-devel,ncurses,gcc,gcc-c++
    - name: create mysql group
      group: name=mysql gid=306
    - name: create mysql user
      user: name=mysql uid=306 group=mysql shell=/sbin/nologin system=yes create_home=no home=/data/mysql
    - name: copy tar to remote host and fime mode
      unarchive: src=/data/ansible-playbook/file/mysql-5.6.46-linux-glibc2.12-x86_64.tar.gz dest=/usr/local owner=root group=root
    - name: create linkfile /usr/local/mysql
      file: src=/usr/local/mysql-5.6.46-linux-glibc2.12-x86_64 dest=/usr/local/mysql state=link
    - name: data dir
      shell: chdir=/usr/local/mysql/ ./scripts/mysql_install_db --datadir=/data/mysql --user=mysql
      # tags标签，代表的是 data dir 这个 tasks任务集的标签。
      tags: data
    - name: config my.cnf
      copy: src=/data/ansible-playbook/file/my.cnf dest=/etc/my.cnf
    - name: service scripts
      shell: /bin/cp /usr/local/mysql/support-files/mysql.server /etc/init.d/mysqld
    - name: enable service
      shell: /etc/init.d/mysqld start;chkconfig --add mysqld;chkconfig mysqld on
      tags: service
    - name: PATH variable
      copy: content='PATH=/usr/local/mysql/bin:$PATH' dest=/etc/profile.d/mysql.sh
    - name: secure script
      script: /data/ansible-playbook/file/secure_mysql.sh
      tags: script
```

运行

```sh
[root@hadoop01 ansible-playbook]# ansible-playbook install_mysql.yaml

PLAY [webserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop02]

TASK [remove mariadb] ***********************************************************************************************************************************************************************
ok: [hadoop02]

TASK [install package] **********************************************************************************************************************************************************************
changed: [hadoop02]

TASK [create mysql group] *******************************************************************************************************************************************************************
changed: [hadoop02]

TASK [create mysql user] ********************************************************************************************************************************************************************
changed: [hadoop02]

TASK [copy tar to remote host and fime mode] ************************************************************************************************************************************************
changed: [hadoop02]

TASK [create linkfile /usr/local/mysql] *****************************************************************************************************************************************************
changed: [hadoop02]

TASK [data dir] *****************************************************************************************************************************************************************************
changed: [hadoop02]

TASK [config my.cnf] ************************************************************************************************************************************************************************
changed: [hadoop02]

TASK [service scripts] **********************************************************************************************************************************************************************
changed: [hadoop02]

TASK [enable service] ***********************************************************************************************************************************************************************
changed: [hadoop02]

TASK [PATH variable] ************************************************************************************************************************************************************************
changed: [hadoop02]

TASK [secure script] ************************************************************************************************************************************************************************
changed: [hadoop02]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop02                   : ok=13   changed=11   unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

登录验证

```sh
[root@hadoop02 mysql]# mysql -uroot -p123456
Enter password:
Welcome to the MySQL monitor.  Commands end with ; or \g.
Your MySQL connection id is 23
Server version: 5.6.46-log MySQL Community Server (GPL)

Copyright (c) 2000, 2019, Oracle and/or its affiliates. All rights reserved.

Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

mysql>
```

#### 4. playbook 中使用 handlers 和 notify

> handlers本质是task list，类似于mysql中触发器触发的行为，其中的task与前述的task本质上没有不同，主要用于当关注的资源发生变化时，才会采取一定的操作。而notify用于的action可用于在每个play的最后被触发，这样可避免多次有改变发生时每次都执行指定的操作，仅在所有的变化发生完成后一次性执行指定操作。而notify中列出的操作被称为handler，也即notify中调用handler中定义的操作

范例：

```YAML
---
- hosts: appserver
  remote_user: root

  tasks:
    - name: install httpd
      yum: name=httpd state=present
    - name: create config file
      copy: src=file/httpd.conf dest=/etc/httpd/conf/
      notify: restart httpd      # 监控copy是否发生新的变化，如果是则触发下面的handlers并重启httpd服务
    - name: ensure apache is running
      service: name=httpd state=started enabled=yes

  handlers:
    - name: restart httpd
      service: name=httpd state=restarted
```

演示：

```sh
[root@hadoop01 ansible-playbook]# ls
file  install_httpd.yaml  install_mysql.yaml  install_nginx.yaml  mysql_user.yaml
[root@hadoop01 ansible-playbook]# vim file/httpd.conf
[root@hadoop01 ansible-playbook]# ansible-playbook install_httpd.yaml

PLAY [appserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop03]

TASK [install httpd] ************************************************************************************************************************************************************************
ok: [hadoop03]

TASK [create config file] *******************************************************************************************************************************************************************
changed: [hadoop03]

TASK [ensure apache is running] *************************************************************************************************************************************************************
changed: [hadoop03]

RUNNING HANDLER [restart httpd] *************************************************************************************************************************************************************
changed: [hadoop03]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop03                   : ok=5    changed=3    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
检查启动情况

```sh
[root@hadoop01 ansible-playbook]# ansible appserver -a 'netstat -lntp'
hadoop03 | CHANGED | rc=0 >>
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      3973/nginx: master  
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      920/sshd            
tcp        0      0 127.0.0.1:25            0.0.0.0:*               LISTEN      1070/master         
tcp6       0      0 :::3306                 :::*                    LISTEN      6859/mysqld         
tcp6       0      0 :::8080                 :::*                    LISTEN      9474/httpd          
tcp6       0      0 :::80                   :::*                    LISTEN      3973/nginx: master  
tcp6       0      0 :::22                   :::*                    LISTEN      920/sshd            
tcp6       0      0 ::1:25                  :::*                    LISTEN      1070/master
```

不修改配置文件在跑一遍服务发现并没有发生新的变化，原因是没修改配置文件，所以不会触发handlers

```sh
[root@hadoop01 ansible-playbook]# ansible-playbook install_httpd.yaml

PLAY [appserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop03]

TASK [install httpd] ************************************************************************************************************************************************************************
ok: [hadoop03]

TASK [create config file] *******************************************************************************************************************************************************************
ok: [hadoop03]

TASK [ensure apache is running] *************************************************************************************************************************************************************
ok: [hadoop03]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop03                   : ok=4    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

修改httpd.conf验证handlers

```sh
[root@hadoop01 ansible-playbook]# sed -i 's/Listen 8080/Listen 8888/g' file/httpd.conf
[root@hadoop01 ansible-playbook]# cat file/httpd.conf |grep 8888
Listen 8888
[root@hadoop01 ansible-playbook]# ansible-playbook install_httpd.yaml

PLAY [appserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop03]

TASK [install httpd] ************************************************************************************************************************************************************************
ok: [hadoop03]

TASK [create config file] *******************************************************************************************************************************************************************
changed: [hadoop03]

TASK [ensure apache is running] *************************************************************************************************************************************************************
ok: [hadoop03]

RUNNING HANDLER [restart httpd] *************************************************************************************************************************************************************
changed: [hadoop03]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop03                   : ok=5    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
检查服务监听端口

```sh
[root@hadoop01 ansible-playbook]# ansible appserver -a 'netstat -lntp'
hadoop03 | CHANGED | rc=0 >>
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      3973/nginx: master  
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      920/sshd            
tcp        0      0 127.0.0.1:25            0.0.0.0:*               LISTEN      1070/master         
tcp6       0      0 :::3306                 :::*                    LISTEN      6859/mysqld         
tcp6       0      0 :::80                   :::*                    LISTEN      3973/nginx: master  
tcp6       0      0 :::22                   :::*                    LISTEN      920/sshd            
tcp6       0      0 :::8888                 :::*                    LISTEN      10205/httpd         
tcp6       0      0 ::1:25                  :::*                    LISTEN      1070/master
```

#### 5. playbook 中使用 tags 组件

在 playbook 文件中，可以使用 tags 组件，为特定 tasks 指定标签，当在执行 playbook 时，可以只执行特定的 tags 的 tasks ，而非整个 playbook 文件

范例：

```yaml
---
- hosts: appserver
  remote_user: root

  tasks:
    - name: install httpd
      yum: name=httpd state=present
    - name: create config file
      copy: src=file/httpd.conf dest=/etc/httpd/conf/
      notify: restart httpd
      tags: config
    - name: ensure apache is running
      service: name=httpd state=started enabled=yes

  handlers:
    - name: restart httpd
      service: name=httpd state=restarted
```

```sh
[root@hadoop01 ansible-playbook]# ansible-playbook --list-tags install_httpd.yaml

playbook: install_httpd.yaml

  play #1 (appserver): appserver	TAGS: []
      TASK TAGS: [config]
```

```sh
[root@hadoop01 ansible-playbook]# ansible-playbook -t config install_httpd.yaml  

PLAY [appserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop03]

TASK [create config file] *******************************************************************************************************************************************************************
changed: [hadoop03]

RUNNING HANDLER [restart httpd] *************************************************************************************************************************************************************
changed: [hadoop03]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop03                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

#### 6. playbook 中使用变量

**变量定义：**

```sh
variable=value
```

范例：

```sh
http_port=80
```

**变量调用方式：**

通过{{variable_name}}调用变量，且变量名前后建议加空格，有时用"{{variable_name}}"才生效

**变量来源：**

（1）ansible 的 setup facts 远程主机所有变量都可以直接调用
（2）通过命令行指定变量，优先级最高

```sh
ansible-playbook -e varname=value
```

（3）在playbook文件中定义

```sh
vars:
  - var1: value1
  - var2: value2
```

（4）在独立的变量yaml中定义

（5）在 playbook 文件中指定系统已有变量

```yaml
---
- hosts: appserver
  remote_user: root

  tasks:
    - name: create file
      # 调用 setup 模块中的变量
      file: name=/data/{{ansible_nodename}}.txt state=touch
```

```sh
[root@hadoop01 ansible-playbook]# ansible-playbook vars01.yaml

PLAY [appserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop03]

TASK [create file] **************************************************************************************************************************************************************************
changed: [hadoop03]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop03                   : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   

[root@hadoop01 ansible-playbook]# ansible appserver -a 'ls -l /data'
hadoop03 | CHANGED | rc=0 >>
总用量 16176
-rw-r--r-- 1 root  root         0 7月  13 10:48 hadoop03.txt
drwx------ 5 mysql mysql      243 7月  12 17:11 mysql
-rw-r--r-- 1 root  root  16560334 7月   5 16:36 rpm.tar.gz
drwxr-xr-x 3 root  root        17 7月   5 16:31 var
```

（6）在 playbook tasks模块中自定义变量，然后ansible命令行去调用

```yaml
[root@hadoop01 ansible-playbook]# cat vars02.yaml
---
- hosts: appserver
  remote_user: root

  tasks:
    - name: install package
      yum: name={{pkname}} state=present
```

```sh
[root@hadoop01 ansible-playbook]# ansible-playbook -e pkname=redis vars02.yaml

PLAY [appserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop03]

TASK [install package] **********************************************************************************************************************************************************************
changed: [hadoop03]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop03                   : ok=2    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

（7） 在 playbook 文件中定义变量，然后直接调用

```YAML
---
- hosts: appserver
  remote_user: root

  vars:
    - username: user1
    - groupname: group1

  tasks:
    - name: create group
      group: name={{groupname}} state=present
    - name: create user
      user: name={{username}} group={{groupname}} state=present
```

```sh
[root@hadoop01 ansible-playbook]# ansible-playbook vars03.yaml

PLAY [appserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop03]

TASK [create group] *************************************************************************************************************************************************************************
changed: [hadoop03]

TASK [create user] **************************************************************************************************************************************************************************
changed: [hadoop03]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop03                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

#### 7. 使用变量文件

可以在一个独立的 playbook 文件中定义变量，在另一个 playbook 文件中引用变量文件中的变量，比 playbook 中定义变量的优先级高

```YAML
---
package_name: vsftpd
service_name: vsftpd
```

```YAML
---
- hosts: dbserver
  remote_user: root
  vars_files:
    - varsall.yaml

  tasks:
    - name: install package
      yum: name={{package_name}}
      tags: install
    - name: start package
      service: name={{service_name}} state=started enabled=yes
```

```sh
[root@hadoop01 ansible-playbook]# ls -l
总用量 24
drwxr-xr-x 2 root root  129 7月  13 10:02 file
-rw-r--r-- 1 root root  417 7月  13 10:03 install_httpd.yaml
-rw-r--r-- 1 root root 1454 7月  12 17:19 install_mysql.yaml
-rw-r--r-- 1 root root  508 7月  12 10:23 install_nginx.yaml
-rw-r--r-- 1 root root  255 7月  13 13:59 install_package.yaml
-rw-r--r-- 1 root root  564 7月  12 09:59 mysql_user.yaml
-rw-r--r-- 1 root root   46 7月  13 13:49 varsall.yaml        # 包含的变量
```

```sh
[root@hadoop01 ansible-playbook]# ansible-playbook install_package.yaml

PLAY [dbserver] *****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop02]

TASK [install package] **********************************************************************************************************************************************************************
changed: [hadoop02]

TASK [start package] ************************************************************************************************************************************************************************
changed: [hadoop02]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop02                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
[root@hadoop01 ansible-playbook]# ansible dbserver -a 'netstat -lntp'
hadoop02 | CHANGED | rc=0 >>
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      909/sshd            
tcp6       0      0 :::3306                 :::*                    LISTEN      2537/mysqld         
tcp6       0      0 :::21                   :::*                    LISTEN      5209/vsftpd         
tcp6       0      0 :::22                   :::*                    LISTEN      909/sshd
```

#### 8. 主机清单文件中定义变量

（1）针对单个主机变量


在 inventory 清单文件中为指定主机定义变量以便在 playbook 中使用

范例：

```sh
[webserver]
10.211.55.6 http_port=80 maxRequestsPerChild=801
10.211.55.7 http_port=81 maxRequestsPerChild=802
10.211.55.8 http_port=82 maxRequestsPerChild=803
```

（2）针对一组内主机的变量

范例：

```sh
[dbserver]
10.211.55.6
10.211.55.7
10.211.55.8
```

### 7. Template 模版

模板是一个文本文件，可以做为生成文件的模版，并且模板文件中还可嵌套jinja2语法

Jinja2 是一个现代的，设计者友好的，仿照 Django 模板的 Python 模板语言。 它速度快，被广泛使用，并且提供了可选的沙箱模板执行环境保证安全:

#### 1. 字面量

表达式最简单的形式就是字面量。字面量表示诸如字符串和数值的 Python 对象。如"Hello World" 双引号或单引号中间的一切都是字符串。无论何时你需要在模板中使用一个字符串（比如函数调用、过滤器或只是包含或继承一个模板的参数），如42，42.23数值可以为整数和浮点数。如果有小数点，则为浮点数，否则为整数。在 Python 里， 42 和 42.0 是不


#### 2. 特性

> 沙箱中执行
>
> 强大的 HTML 自动转义系统保护系统免受 XSS
>
> 模板继承
>
> 及时编译最优的 python 代码
>
> 可选提前编译模板的时间
>
> 易于调试。异常的行数直接指向模板中的对应行。
>
>可配置的语法

#### 3. jinja2 语言支持多种数据类型和操作

> 字面量，如: 字符串：使用单引号或双引号,数字：整数，浮点数
>
> 列表：[item1, item2, ...]
>
> 元组：(item1, item2, ...)
>
> 字典：{key1:value1, key2:value2, ...}
>
> 布尔型：true/false
>
> 算术运算：+, -, *, /, //, %, **
>
> 比较操作：==, !=, >, >=, <, <=
>
> 逻辑运算：and，or，not
>
> 流表达式：For，If，When

#### 4. 算术运算

Jinja 允许用计算值。支持下面的运算符

> +：把两个对象加到一起。通常对象是素质，但是如果两者是字符串或列表，你可以用这 种方式来衔接 它们。无论如何这不是首选的连接字符串的方式！连接字符串见 ~ 运算符。 {{ 1 + 1 }} 等于 2
>
> -：用第一个数减去第二个数。 {{ 3 - 2 }} 等于 1
>
> /：对两个数做除法。返回值会是一个浮点数。 {{ 1 / 2 }} 等于 0.5
>
> //：对两个数做除法，返回整数商。 {{ 20 // 7 }} 等于 2
>
> %：计算整数除法的余数。 {{ 11 % 7 }} 等于 4
>
> *：用右边的数乘左边的操作数。 {{ 2 * 2 }} 会返回 4 。也可以用于重 复一个字符串多次。 {{ '=' * 80 }}
会打印 80 个等号的横条\
>
> **：取左操作数的右操作数次幂。 {{ 2**3 }} 会返回 8

#### 5. 比较运算符

> == 比较两个对象是否相等
>
> != 比较两个对象是否不等
>
> > 如果左边大于右边，返回 true
>
> >= 如果左边大于等于右边，返回 true
>
> < 如果左边小于右边，返回 true
>
> <= 如果左边小于等于右边，返回 true

#### 6. 逻辑运算符

> 对于 if 语句，在 for 过滤或 if 表达式中，它可以用于联合多个表达式
>
> and 如果左操作数和右操作数同为真，返回 true
>
> or 如果左操作数和右操作数有一个为真，返回 true
>
> not 对一个表达式取反
>
> (expr)表达式组
>
> true / false true 永远是 true ，而 false 始终是 false

#### 7. template

功能可以参考模版文件，动态生成相类似的配置文件

template文件必须存放于template目录下面，且文件后缀需为<.j2>结尾

yaml文件需和template目录平级

范例：template同步ningx配置文件

```YAML
---
- hosts: appserver
  remote_user: root


  tasks:
    - name: install nginx
      yum: name=nginx state=present
      notify: restart nginx
    - name: template config to remote hosts
      template: src=nginx.conf.j2 dest=/etc/nginx/nginx.conf
      notify: restart nginx
      tags: nginx.conf.j2
    - name:  start nginx
      service: name=nginx state=started enabled=yes

  handlers:
    - name: restart nginx
      service: name=nginx state=restarted
```

```sh
[root@hadoop01 ansible-playbook]# vim templates/nginx.conf.j2

# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes 1;  # 修改为1
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;
........................
........................
........................
........................
........................
```

```sh
[root@hadoop01 ansible-playbook]# ansible-playbook tempnginx.yaml

PLAY [appserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop03]

TASK [install nginx] ************************************************************************************************************************************************************************
ok: [hadoop03]

TASK [template config to remote hosts] ******************************************************************************************************************************************************
changed: [hadoop03]

TASK [start nginx] **************************************************************************************************************************************************************************
ok: [hadoop03]

RUNNING HANDLER [restart nginx] *************************************************************************************************************************************************************
changed: [hadoop03]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop03                   : ok=5    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

可以看到只有一个进程

```sh
[root@hadoop01 ansible-playbook]# ansible appserver -a 'ps -ef |grep nginx'
hadoop03 | CHANGED | rc=0 >>
root     13566     1  0 16:41 ?        00:00:00 nginx: master process /usr/sbin/nginx
nginx    13567 13566  0 16:41 ?        00:00:00 nginx: worker process
root     13645 13644  0 16:45 pts/2    00:00:00 /bin/sh -c ps -ef |grep nginx
root     13647 13645  0 16:45 pts/2    00:00:00 grep nginx
```

（1）template 算数运算

范例：

```sh
[root@hadoop01 ansible-playbook]# vim templates/nginx.conf.j2

# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes {{ansible_processor_vcpus**2}};  # 指数运算也就是2的2次方，或者worker_processes {{ansible_processes_vcpus+2}}; 数量加2
```

再次运行ansible-playbook

```sh
[root@hadoop01 ansible-playbook]# ansible-playbook -t nginx.conf.j2 tempnginx.yaml

PLAY [appserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop03]

TASK [template config to remote hosts] ******************************************************************************************************************************************************
changed: [hadoop03]

RUNNING HANDLER [restart nginx] *************************************************************************************************************************************************************
changed: [hadoop03]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop03                   : ok=3    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

检查启动进程发现有4个进程

```sh
[root@hadoop01 ansible-playbook]# ansible appserver -a 'ps -ef |grep nginx'
hadoop03 | CHANGED | rc=0 >>
root     14047     1  0 16:57 ?        00:00:00 nginx: master process /usr/sbin/nginx
nginx    14048 14047  0 16:57 ?        00:00:00 nginx: worker process
nginx    14049 14047  0 16:57 ?        00:00:00 nginx: worker process
nginx    14050 14047  0 16:57 ?        00:00:00 nginx: worker process
nginx    14051 14047  0 16:57 ?        00:00:00 nginx: worker process
root     14118 14117  0 16:58 pts/2    00:00:00 /bin/sh -c ps -ef |grep nginx
root     14120 14118  0 16:58 pts/2    00:00:00 grep nginx
```
#### 7.1 template 中使用流程控制 for 循环和 if 条件判断，实现动态生成文件功能

范例：

```yaml

```

### 8. playbook 中使用 when

when 语句可以实现条件测试，如果需要根据变量、facts 或此前任务的执行结果来作为某 tasks 执行与否的前提时要用到条件测试，通过 tasks 后添加 when 子句即可实现条件测试，jinja2的语法格式

范例：判断是否等于 RedHat 如果是则关机，调用的是setup模块

```yaml
---
- hosts: appserver
  remote_user: root

  tasks:
    - name: "shutdown RedHat flavored systems"
      command: /sbin/shutdown -h now
      when: ansible_os_family == "RedHat"
```

范例：依据操作系统版本来判断是否要往哪台主机上进行相应的操作，调用setup模块

```yaml
---
- hosts: appserver
  remote_user: root

  tasks:
    - name: install mysql
      yum: name=mysql-server
      when: ansible_distribution_major_version == "6"
    - name: install mariadb
      yum: name=mariadb
      when: ansible_distribution_major_version == "7"
```

### 9. playbook 中使用with_items

迭代：当需要重复性执行的任务时，可以使用迭代极致，对迭代项的引用，固定变量名为“item”，要在 tasks 中使用 with_items 给要迭代的元素列表

**列表格式：**

- 字符串

- 字典

范例：

```yaml
---
- hosts: appserver
  remote_user: root

  tasks:
    - name: add serveral users
      user: name={{item}} state=present groups=wheel
      with_items:
        - testuser1
        - testuser2
# 上面语句功能等同于下面的

#    - name: add user testuser1
#      user: name=testuser1 state=present groups=wheel
#    - name: add user testuser2
#      user: name=testuser2 state=present groups=wheel
```

```YAML
---
- hosts: appserver
  remote_user: root

  tasks:
    - name: add some groups
      group: name={{item}} state=present
      with_items:
        - nginx
        - mysql
        - apache

    - name: add some users
      user: name={{item.name}} group={{item.group}} state=present
      with_items:
        - {name: 'nginx', group: 'nginx'}
        - {name: 'mysql', group: 'mysql'}
        - {name: 'apache', group: 'apache'}
```

### 10. Roles 角色

> 角色是 ansible 自1.2版本引入的新特性、结构化的组织 playbook 。roles 能根据层次型结构自动装载变量文件、tasks 以及 handles 等。要使用 roles 只需要在 playbook 中使用 include 指令即可。简单来讲，roles 就是通过分别将变量、文件、任务、模版以及处理器放置于单独的目录中，便可以便捷的 include 它们的一种机制。角色一般用于基于主机构建服务的场景中，但也可以是用于构建守护进程等场景中。
>
> 运维复杂的场景：建议使用 roles，代码复用程度高
>
> roles 多个角色的集合，可以将多个的 role，分别防止 roles目录下独立的目录中

**Roles各个目录的作用**

> - file：存放 copy 或 script 调用的文件
>
> - templates：templates 模块查找所需要模版文件的目录
>
> - tasks：定义 tasks、roles 的基本元素，至少应该包含一个名为 main.yaml 的文件；其他的文件需要在此文件中通过 include 进行包含
>
> - handlers：至少包含一个名为 main.yaml 的文件；其他的文件需要在此文件中通过 include 进行包含
>
> - vars：定义变量的目录，存放相关变量的文件；至少包含一个名为 main.yaml 的文件；其他的文件需要在此文件中通过 include 进行包含
>
> - meta：定义当前角色的特殊设定及其依赖关系，至少包含一个名为 main.yaml 的文件；其他的文件需要在此文件中通过 include 进行包含
>
> - default：设定默认变量时，用词目录中的 main.yaml 文件，比 vars 的优先级低。

#### 1. 创建 roles

创建 roles 的步骤

（1）创建 roles 命名的目录
（2）在 roles 目录中分别创建以各角色名称空间的目录，如 webserver 等
（3）每个角色命名的目录分别创建 files、templates、tasks、handlers、vars、meta、default，用不到的目录可以创建为空目录也可以不用创建
（4）在 playbook 文件中调用各角色

范例：nginx的roles目录

```sh
roles/
└── nginx
    ├── files
    │   └── main.yaml
    ├── tasks
    │   ├── adduser.yaml
    │   ├── groupadd.yaml
    │   ├── install.yaml
    │   ├── main.yaml
    │   └── restart.yaml
    └── vars
        └── main.yaml
```

#### 2. playbook 调用 roles

调用角色方法1:

```YAML
---
- hosts: webserver
  remote_user: root

  roles:
    - mysql
    - memcache
    - nginx
```

调用角色方法2:

键 roles 指定角色名称，后续的 k/v 用于传递变量给角色

```yaml
---
- hosts:
  remote_user: root

  roles:
    - mysql
    - {role: nginx, username: nginx}
```

调用角色方法3：

```yaml
---
- hosts: webserver
  remote_user: root

  roles:
    - {role: nginx, username: nginx, when: ansible_distribution_major_version == "7"}
```

#### 3. roles 中 tags 的使用

```yaml
---
- hosts: webserver
  remote_ user: root

  roles:
    - {role: nginx ,tags: [ 'nginx', 'web' ] ,when: ansible_ _distribution_ _major _version == "6"}
    - {role: httpd , tags: [ 'httpd', 'web' ]}
    - {role: mysql , tags: [ 'mysql', 'db' ]}
    - {role: mariadb , tags: [ 'mariadb', 'db' ]}
```

#### 4. roles 实战演示

```sh
[root@hadoop01 roles]# pwd
/data/ansible-playbook/roles
[root@hadoop01 roles]# mkdir httpd/{files,tasks,handlers} -pv
mkdir: 已创建目录 "httpd"
mkdir: 已创建目录 "httpd/files"
mkdir: 已创建目录 "httpd/tasks"
mkdir: 已创建目录 "httpd/handlers"
[root@hadoop01 roles]# tree httpd/
httpd/
├── files
│   ├── httpd.conf
│   └── index.html
├── handlers
│   └── main.yaml
└── tasks
    ├── config.yaml
    ├── index.yaml
    ├── install.yaml
    ├── main.yaml
    └── service.yaml
3 directories, 8 files
```

```sh
[root@hadoop01 roles]# cat httpd/tasks/install.yaml
- name: install httpd package
  yum: name=httpd state=present
[root@hadoop01 roles]# cat httpd/tasks/config.yaml
- name: config file
  copy: src=httpd.conf dest=/etc/httpd/conf/ backup=yes
  notify: restart
[root@hadoop01 roles]# cat httpd/tasks/service.yaml
- name: start server
  service: name=httpd state=started enabled=yes
[root@hadoop01 roles]# cat httpd/tasks/main.yaml
- include: install.yaml
- include: config.yaml
- include: index.yaml
- include: service.yaml
[root@hadoop01 roles]# cat httpd/handlers/main.yaml
- name: restart
  service: name=httpd state=restarted
[root@hadoop01 roles]# ls httpd/file/
httpd.conf  index.html
```

```sh
[root@hadoop01 ansible-playbook]# pwd
/data/ansible-playbook
[root@hadoop01 ansible-playbook]# cat roles_httpd.yaml
---
- hosts: webserver
  remote_user: root

  roles:
   - httpd

# 启动服务
[root@hadoop01 ansible-playbook]# ansible-playbook roles_httpd.yaml

PLAY [webserver] ****************************************************************************************************************************************************************************

TASK [Gathering Facts] **********************************************************************************************************************************************************************
ok: [hadoop01]

TASK [install httpd package] ****************************************************************************************************************************************************************
ok: [hadoop01]

TASK [httpd : config file] ******************************************************************************************************************************************************************
ok: [hadoop01]

TASK [httpd : index.html] *******************************************************************************************************************************************************************
ok: [hadoop01]

TASK [httpd : start server] *****************************************************************************************************************************************************************
changed: [hadoop01]

PLAY RECAP **********************************************************************************************************************************************************************************
hadoop01                   : ok=5    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```
