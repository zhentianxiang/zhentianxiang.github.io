---
layout: post
title: OpenStack-Rocky安装部署-13-创建域，项目，用户和角色
date: 2020-12-26
tags: 云计算
---

身份服务为每个OpenStack服务提供身份验证服务。身份验证服务使用域，项目，用户和角色的组合。

### 1.创建新域

```
[root@controller ~]#  openstack domain create --description "An Example Domain" example

+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | An Example Domain                |
| enabled     | True                             |
| id          | 2f4f80574fd84fe6ba9067228ae0a50c |
| name        | example                          |
| tags        | []                               |
+-------------+----------------------------------+
```

### 2.创建service项目

```
[root@controller ~]#  openstack project create --domain default \
  --description "Service Project" service

+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | Service Project                  |
| domain_id   | default                          |
| enabled     | True                             |
| id          | 24ac7f19cd944f4cba1d77469b2a73ed |
| is_domain   | False                            |
| name        | service                          |
| parent_id   | default                          |
| tags        | []                               |
+-------------+----------------------------------+
```

### 3.创建`myproject`项目和`myuser` 用户

创建`myproject`项目

```
[root@controller ~]# openstack project create --domain default \
  --description "Demo Project" myproject

+-------------+----------------------------------+
| Field       | Value                            |
+-------------+----------------------------------+
| description | Demo Project                     |
| domain_id   | default                          |
| enabled     | True                             |
| id          | 231ad6e7ebba47d6a1e57e1cc07ae446 |
| is_domain   | False                            |
| name        | myproject                        |
| parent_id   | default                          |
| tags        | []                               |
+-------------+----------------------------------+
```

创建`myuser`用户

```
[root@controller ~]# openstack user create --domain default \
  --password-prompt myuser

User Password:MYUSER_PASS
Repeat User Password:MYUSER_PASS
+---------------------+----------------------------------+
| Field               | Value                            |
+---------------------+----------------------------------+
| domain_id           | default                          |
| enabled             | True                             |
| id                  | aeda23aa78f44e859900e22c24817832 |
| name                | myuser                           |
| options             | {}                               |
| password_expires_at | None                             |
+---------------------+----------------------------------+
```

创建`myrole`角色

```
[root@controller ~]# openstack role create myrole

+-----------+----------------------------------+
| Field     | Value                            |
+-----------+----------------------------------+
| domain_id | None                             |
| id        | 997ce8d05fc143ac97d83fdfb5998552 |
| name      | myrole                           |
+-----------+----------------------------------+
```

将`myrole`角色添加到`myproject`项目和`myuser`用户

```
[root@controller ~]# openstack role add --project myproject --user myuser myrole
```