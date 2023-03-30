---
layout: post
title: OpenStack-Rocky安装部署-12-Keystone认证服务
date: 2020-12-26
tags: 云计算
---

OpenStack:term:[`](https://docs.openstack.org/mitaka/zh_CN/install-guide-rdo/common/get_started_identity.html#id1)Identity service`为认证管理，授权管理和服务目录服务管理提供单点整合。其它OpenStack服务将身份认证服务当做通用统一API来使用。此外，提供用户信息但是不在OpenStack项目中的服务（如LDAP服务）可被整合进先前存在的基础设施中。

为了从identity服务中获益，其他的OpenStack服务需要与它合作。当某个OpenStack服务收到来自用户的请求时，该服务询问Identity服务，验证该用户是否有权限进行此次请求

身份服务包含这些组件：

- 服务器

  一个中心化的服务器使用RESTful 接口来提供认证和授权服务。

- 驱动

  驱动或服务后端被整合进集中式服务器中。它们被用来访问OpenStack外部仓库的身份信息, 并且它们可能已经存在于OpenStack被部署在的基础设施（例如，SQL数据库或LDAP服务器）中。

- 模块

  中间件模块运行于使用身份认证服务的OpenStack组件的地址空间中。这些模块拦截服务请求，取出用户凭据，并将它们送入中央是服务器寻求授权。中间件模块和OpenStack组件间的整合使用Python Web服务器网关接口。

当安装OpenStack身份服务，用户必须将之注册到其OpenStack安装环境的每个服务。身份服务才可以追踪那些OpenStack服务已经安装，以及在网络中定位它们。

### 1.先决条件

```
[root@controller ~]# mysql -u root -p
创建 keystone 数据库
CREATE DATABASE keystone;

对keystone数据库授予恰当的权限
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' \
  IDENTIFIED BY 'KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' \
  IDENTIFIED BY 'KEYSTONE_DBPASS';

```

### 2.安装配置组件

```
[root@controller ~]# yum install openstack-keystone httpd mod_wsgi
```

### 3.编辑配置文件

```
[root@controller ~]# vim /etc/keystone/keystone.conf
配置数据库访问
[database]
...
connection = mysql+pymysql://keystone:KEYSTONE_DBPASS@controller/keystone

配置Fernet UUID令牌的提供者
[token]
...
provider = fernet
```

### 4.初始化身份认证服务的数据库

```
[root@controller ~]# su -s /bin/sh -c "keystone-manage db_sync" keystone
```

> 注意：忽略输出信息

### 5.初始化Fernet keys

```
[root@controller ~]# keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone

[root@controller ~]# keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
```

### 6.引导身份服务

```
[root@controller ~]# keystone-manage bootstrap --bootstrap-password ADMIN_PASS \
  --bootstrap-admin-url http://controller:5000/v3/ \
  --bootstrap-internal-url http://controller:5000/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne
```

### 7.配置 Apache HTTP 服务器

```
[root@controller ~]# vim /etc/httpd/conf/httpd.conf
ServerName controller
[root@controller ~]# ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
```

### 7.完成安装

```
[root@controller ~]# systemctl enable httpd.service
[root@controller ~]# systemctl start httpd.service
```

### 8.设置环境变量来配置管理员用户

```
[root@controller ~]# export OS_USERNAME=admin
[root@controller ~]# export OS_PASSWORD=ADMIN_PASS
[root@controller ~]# export OS_PROJECT_NAME=admin
[root@controller ~]# export OS_USER_DOMAIN_NAME=Default
[root@controller ~]# export OS_PROJECT_DOMAIN_NAME=Default
[root@controller ~]# export OS_AUTH_URL=http://controller:5000/v3
[root@controller ~]# export OS_IDENTITY_API_VERSION=3
```
