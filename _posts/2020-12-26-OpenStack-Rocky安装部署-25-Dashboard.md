---
layout: post
title: OpenStack-Rocky安装部署-25-Dashboard
date: 2020-12-26
tags: 云计算
---

Dashboard(horizon)是一个web接口，使得云平台管理员以及用户可以管理不同的Openstack资源以及服务。

这个部署示例使用的是 Apache Web 服务器。

⚠：本部分假定使用Apache HTTP服务器和Memcached服务正确安装，配置和操作Identity服务。

### 1.安装和配置的部件

安装软件包

```
[root@controller ~]#  yum install openstack-dashboard
```

编辑 `/etc/openstack-dashboard/local_settings` 文件

```
[root@controller ~]# vim  /etc/openstack-dashboard/local_settings

配置仪表板以在controller节点上使用OpenStack服务
OPENSTACK_HOST = "controller"

允许主机访问仪表板
ALLOWED_HOSTS = ['*']

⚠：ALLOWED_HOSTS也可以是['*']以接受所有主机。这对于开发工作可能有用，但可能不安全，因此不应在生产中使用。有关 更多信息，请参见 https://docs.djangoproject.com/en/dev/ref/settings/#allowed-hosts。

配置memcached会话存储服务
SESSION_ENGINE = 'django.contrib.sessions.backends.cache'

CACHES = {
    'default': {
         'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
         'LOCATION': 'controller:11211',
    }
}

⚠：注释掉任何其他会话存储配置

启用身份API版本3
OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST

启用对域的支持
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True

配置API版本
OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 2,
}

配置Default为通过仪表板创建的用户的默认域
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"

配置user为通过仪表板创建的用户的默认角色
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"

如果选择网络选项1，请禁用对第3层网络服务的支持
OPENSTACK_NEUTRON_NETWORK = {
    ...
    'enable_router': False,
    'enable_quotas': False,
    'enable_distributed_router': False,
    'enable_ha_router': False,
    'enable_lb': False,
    'enable_firewall': False,
    'enable_vpn': False,
    'enable_fip_topology_check': False,
}

（可选）配置时区
TIME_ZONE = "Asia/Shanghai"
```

替换`TIME_ZONE`为适当的时区标识符。有关更多信息，请参见[时区列表](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)。

### 2.配置httpd文件

```
[root@controller ~]# vim  /etc/httpd/conf.d/openstack-dashboard.conf

WSGIApplicationGroup %{GLOBAL}
```

### 3.最终确定安装

重新启动Web服务器和会话存储服务

```
[root@controller ~]#  systemctl restart httpd.service memcached.service
```

#### 4.验证操作

验证仪表板的操作。

使用Web浏览器访问仪表板，网址为 `http://controller/dashboard`。
