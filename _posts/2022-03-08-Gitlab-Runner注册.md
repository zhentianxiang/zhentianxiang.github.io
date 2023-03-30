---
layout: post
title: Gitlab-Runner注册
date: 2022-3-08
tags: Gitlab
---

本文接上一篇的runner配置

## 一. 了解各种类型的token

- 注册步骤：
  - 获取runner token ------->进行注册

- GitlanRunner类型
  - shared：运行整个平台项目的作业（gitlab）
  - group：运行特定group下面所有项目的作业（group）
  - specific：运行指定的项目作业（project）
  - locked：无法运行项目作业
  - paused：不会运行该项目作业


### 1. shared类型token

![](/images/posts/gitlab-runner注册/1.png)

### 2. group类型token

![](/images/posts/gitlab-runner注册/2.png)

![](/images/posts/gitlab-runner注册/3.png)

### 3. specific类型token

![](/images/posts/gitlab-runner注册/5.png)

![](/images/posts/gitlab-runner注册/6.png)

## 二、注册共享类型runner

### 1. 交互式注册

```sh
[root@k8s-master02 ~]# gitlab-runner register  ////输入命令
Runtime platform                                    arch=amd64 os=linux pid=56235 revision=4c96e5ad version=12.9.0
Running in system-mode.                            

Please enter the gitlab-ci coordinator URL (e.g. https://gitlab.com/):     ////gitlab地址
http://gitlab.k8s.com/
Please enter the gitlab-ci token for this runner:           ////runner token
SMigs1yWqVCCWCShs3c5
Please enter the gitlab-ci description for this runner:           ////描述信息
[k8s-master02]: buildtest
Please enter the gitlab-ci tags for this runner (comma separated):          ////标签
build
Registering runner... succeeded                     runner=SMigs1yW
Please enter the executor: docker+machine, docker-ssh+machine, kubernetes, custom, docker-ssh, shell, ssh, docker, parallels, virtualbox:            ////选择哪种类型的执行器
shell
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
```

![](/images/posts/gitlab-runner注册/7.png)

### 2. 非交互式注册（docker）

> - –non-interactive 非交互操作
> - executor shell类型的执行器
> - url gitlab地址
> - registration-token gitlab 的 token
> - tag-list 设置的tag
> - run-untagged 选择无标记的作业
> - locked 关闭锁定

```sh
[root@localhost runner]# mkdir /home/gitlab-runner/config -pv
mkdir: created directory '/home/gitlab-runner'
mkdir: created directory '/home/gitlab-runner/config'
[root@localhost runner]# docker run -itd --name gitlab-runner -v /home/gitlab-runner/config/:/etc/gitlab-runner --restart always gitlab/gitlab-runner:v12.1.0
f580eed6201562d554e55fecadfa264df28cc96b22bf3f704df19cec420d1b99
[root@localhost runner]# docker exec -it gitlab-runner bash
root@f580eed62015:/# gitlab-runner register \
 --non-interactive \
 --executor "shell" \
 --url "http://gitlab.k8s.com/" \
 --registration-token "SMigs1yWqVCCWCShs3c5" \
 --description "devops-runner" \
 --tag-list "build,deploy" \
 --run-untagged="true" \
 --locked="false" \
 --access-level="not_protected"

Runtime platform                                    arch=amd64 os=linux pid=42 revision=de7731dd version=12.1.0
Running in system-mode.                            

Registering runner... succeeded                     runner=a6nZcbyu
Runner registered successfully. Feel free to start it, but if it's running already the config should be automatically reloaded!
################ 检查
root@433660ac5eb9:/# gitlab-runner verify
Runtime platform                                    arch=amd64 os=linux pid=53 revision=de7731dd version=12.1.0
Running in system-mode.                            

Verifying runner... is alive                        runner=GwQ4keHT
root@433660ac5eb9:/# gitlab-runner list
Runtime platform                                    arch=amd64 os=linux pid=71 revision=de7731dd version=12.1.0
Listing configured runners                          ConfigFile=/etc/gitlab-runner/config.toml
devops-runner                                       Executor=shell Token=GwQ4keHTimdQ5_xKyQwF URL=http://gitlab.k8s.com/
```

查看runner已添加好，并且点击进去已经勾选好可以运行未标记的作业

![](/images/posts/gitlab-runner注册/8.png)

![](/images/posts/gitlab-runner注册/9.png)
