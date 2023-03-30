---
layout: post
title: Linux-Kubernetes-15-Apollo分环境管理dubbo
date: 2021-04-30
tags: 实战-Kubernetes
---
### 添加解析

```sh
[root@host0-200 ~]# vim /etc/rc.local 
[root@host0-200 ~]# vim /var/named/od.com.zone 
[root@host0-200 ~]# systemctl restart named
[root@host0-200 ~]# cat /var/named/od.com.zone 
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2020010516 ; serial
                10800      ; refresh (3 hours)
                900        ; retry (15 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
                )
                NS   dns.od.com.
$TTL 60 ; 1 minute
dns                A    10.0.0.200
harbor             A    10.0.0.200
k8s-yaml           A    10.0.0.200
traefik            A    10.0.0.10
dashboard          A    10.0.0.10
zk1                A    10.0.0.11
zk2                A    10.0.0.12
zk3                A    10.0.0.21
mirrors            A    10.0.0.200
jenkins            A    10.0.0.10
dubbo-monitor      A    10.0.0.10
demo               A    10.0.0.10
config             A    10.0.0.10
mysql              A    10.0.0.11
portal             A    10.0.0.10
zk-test            A    10.0.0.11
zk-prod            A    10.0.0.12
```

### 修改一下容器启动

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/58.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/59.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/60.png)

### 创建命名空间

先关停这三个服务

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/61.png)

```sh
[root@host0-21 ~]# kubectl create ns test
namespace/test created
[root@host0-21 ~]# kubectl create secret docker-registry harbor --docker-server=harbor.od.com --docker-username=admin --docker-password=Harbor12345 -n test
secret/harbor created
[root@host0-21 ~]# kubectl create ns prod
namespace/prod created
[root@host0-21 ~]# kubectl create secret docker-registry harbor --docker-server=harbor.od.com --docker-username=admin --docker-password=Harbor12345 -n prod
secret/harbor created
```

### 修改数据库信息

配置测试环境的库

```sh
[root@host0-11 apollo1.5.1-DB]# vim apolloconfig.sql 

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

# Create Database
# ------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS ApolloConfigTestDB DEFAULT CHARACTER SET = utf8mb4;

Use ApolloConfigTestDB;
```

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/62.png)

```sh
[root@host0-11 apollo1.5.1-DB]# mysql -uroot -p < apolloconfig.sql 
Enter password: 
[root@host0-11 apollo1.5.1-DB]# mysql -uroot -p123123
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 1081
Server version: 10.1.48-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| ApolloConfigDB     |
| ApolloConfigTestDB |
| ApolloPortalDB     |
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
6 rows in set (0.00 sec)

MariaDB [(none)]> use ApolloConfigTestDB
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
MariaDB [ApolloConfigTestDB]> show tables;
+------------------------------+
| Tables_in_ApolloConfigTestDB |
+------------------------------+
| AccessKey                    |
| App                          |
| AppNamespace                 |
| Audit                        |
| Cluster                      |
| Commit                       |
| GrayReleaseRule              |
| Instance                     |
| InstanceConfig               |
| Item                         |
| Namespace                    |
| NamespaceLock                |
| Release                      |
| ReleaseHistory               |
| ReleaseMessage               |
| ServerConfig                 |
+------------------------------+
16 rows in set (0.00 sec)

MariaDB [ApolloConfigTestDB]> update ApolloConfigTestDB.ServerConfig set ServerConfig.Value="http://config-test.od.com/eureka" where ServerConfig.Key="eureka.service.url";
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

MariaDB [ApolloConfigTestDB]> select * from ServerConfig\G
*************************** 1. row ***************************
                       Id: 1
                      Key: eureka.service.url
                  Cluster: default
                    Value: http://config-test.od.com/eureka
                  Comment: Eureka服务Url，多个service以英文逗号分隔
MariaDB [ApolloConfigProdDB]> grant INSERT,DELETE,UPDATE,SELECT on ApolloConfigTestDB.* to 'apolloconfig'@'10.0.0.%'  identified by "123123";
Query OK, 0 rows affected (0.00 sec)
```

配置生产环境的库

```sh
[root@host0-11 apollo1.5.1-DB]# vim apolloconfig.sql 

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

# Create Database
# ------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS ApolloConfigProdDB DEFAULT CHARACTER SET = utf8mb4;

Use ApolloConfigProdDB;
```

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/63.png)

```sh
[root@host0-11 apollo1.5.1-DB]# mysql -uroot -p < apolloconfig.sql 
Enter password: 
[root@host0-200 apollo1.5.1-DB]# mysql -uroot -p123123
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 1088
Server version: 10.1.48-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> show databases;
+--------------------+
| Database           |
+--------------------+
| ApolloConfigDB     |
| ApolloConfigProdDB |
| ApolloConfigTestDB |
| ApolloPortalDB     |
| information_schema |
| mysql              |
| performance_schema |
+--------------------+
7 rows in set (0.00 sec)

MariaDB [(none)]> use ApolloConfigProdDB
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
MariaDB [ApolloConfigProdDB]> show tables;
+------------------------------+
| Tables_in_ApolloConfigProdDB |
+------------------------------+
| App                          |
| AppNamespace                 |
| Audit                        |
| Cluster                      |
| Commit                       |
| GrayReleaseRule              |
| Instance                     |
| InstanceConfig               |
| Item                         |
| Namespace                    |
| NamespaceLock                |
| Release                      |
| ReleaseHistory               |
| ReleaseMessage               |
| ServerConfig                 |
+------------------------------+
15 rows in set (0.00 sec)

MariaDB [ApolloConfigProdDB]> update ApolloConfigProdDB.ServerConfig set ServerConfig.Value="http://config-prod.od.com/eureka" where ServerConfig.Key="eureka.service.url";
Query OK, 1 row affected (0.00 sec)
Rows matched: 1  Changed: 1  Warnings: 0

MariaDB [ApolloConfigProdDB]> select * from ServerConfig\G
ERROR 1146 (42S02): Table 'ApolloConfigProdDB.ServiceConfig' doesn't exist
MariaDB [ApolloConfigProdDB]> select * from ServerConfig\G
*************************** 1. row ***************************
                       Id: 1
                      Key: eureka.service.url
                  Cluster: default
                    Value: http://config-test.od.com/eureka
MariaDB [ApolloConfigProdDB]> grant INSERT,DELETE,UPDATE,SELECT on ApolloConfigProdDB.* to 'apolloconfig'@'10.0.0.%'  identified by "123123";
Query OK, 0 rows affected (0.00 sec)
```

修改portal的可支持环境列表

```sh
MariaDB [ApolloConfigProdDB]> use ApolloPortalDB;

Database changed
MariaDB [ApolloPortalDB]> update ServerConfig set Value='fat,pro' where Id=1;
Query OK, 1 row affected (0.02 sec)
Rows matched: 1  Changed: 1  Warnings: 0

MariaDB [ApolloPortalDB]> select * from ServerConfig\G
*************************** 1. row ***************************
                       Id: 1
                      Key: apollo.portal.envs
                    Value: fat,pro
                  Comment: 可支持的环境列表
```

### 修改protal的configmap资源

```sh
[root@host0-200 dubbo-demo-consumer]# cd /data/k8s-yaml/apollo-portal/
[root@host0-200 apollo-portal]# ls
cm.yaml  dp.yaml  ingress.yaml  svc.yaml
[root@host0-200 apollo-portal]# vim cm.yaml 

apiVersion: v1
kind: ConfigMap
metadata:
  name: apollo-portal-cm
  namespace: infra
data:
  application-github.properties: |
    # DataSource
    spring.datasource.url = jdbc:mysql://mysql.od.com:3306/ApolloPortalDB?characterEncoding=utf8
    spring.datasource.username = apolloportal
    spring.datasource.password = 123123
  app.properties: |
    appId=100003173
  apollo-env.properties: |
    fat.meta=http://config-test.od.com
    pro.meta=http://config-prod.od.com
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/apollo-portal/cm.yaml
configmap/apollo-portal-cm configured
```

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/64.png)

### 创建相关目录

```sh
[root@host0-200 apollo-portal]# mkdir -pv /data/k8s-yaml/test/{apollo-configservice,apollo-adminservice,dubbo-demo-service,dubbo-demo-consumer}
mkdir: 已创建目录 "test"
mkdir: 已创建目录 "test/apollo-configservice"
mkdir: 已创建目录 "test/apollo-adminservice"
mkdir: 已创建目录 "test/dubbo-demo-service"
mkdiar: 已创建目录 "test/dubbo-demo-consumer"
[root@host0-200 apollo-portal]# mkdir -pv /data/k8s-yaml/prod/{apollo-configservice,apollo-adminservice,dubbo-demo-service,dubbo-demo-consumer}
mkdir: 已创建目录 "prod"
mkdir: 已创建目录 "prod/apollo-configservice"
mkdir: 已创建目录 "prod/apollo-adminservice"
mkdir: 已创建目录 "prod/dubbo-demo-service"
mkdir: 已创建目录 "prod/dubbo-demo-consumer"
```

## apollo-configservice资源配置清单

### 准备Test的资源配置清单

```sh
[root@host0-200 apollo-portal]# cp -a /data/k8s-yaml/apollo-configservice/cm.yaml /data/k8s-yaml/test/apollo-configservice/
[root@host0-200 apollo-portal]# cp -a /data/k8s-yaml/apollo-configservice/dp.yaml /data/k8s-yaml/test/apollo-configservice/
[root@host0-200 apollo-portal]# cp -a /data/k8s-yaml/apollo-configservice/svc.yaml /data/k8s-yaml/test/apollo-configservice/
[root@host0-200 apollo-portal]# cp -a /data/k8s-yaml/apollo-configservice/ingress.yaml /data/k8s-yaml/test/apollo-configservice/
[root@host0-200 apollo-portal]# cd /data/k8s-yaml/test/apollo-configservice/
[root@host0-200 apollo-configservice]# ls
cm.yaml  dp.yaml  ingress.yaml  svc.yaml
[root@host0-200 apollo-configservice]# vim cm.yaml 

apiVersion: v1
kind: ConfigMap
metadata:
  name: apollo-configservice-cm
  namespace: test
data:
  application-github.properties: |
    # DataSource
    spring.datasource.url = jdbc:mysql://mysql.od.com:3306/ApolloConfigTestDB?characterEncoding=utf8
    spring.datasource.username = apolloconfig
    spring.datasource.password = 123123
    eureka.service.url = http://config-test.od.com/eureka
  app.properties: |
    appId=100003171
    
其他三个文件只是把infra空间修改为了test，和ingress的host主机修改了config-test.od.com
```

### 配置解析

```sh
[root@host0-200 ~]# vim /var/named/od.com.zone
config-test        A    10.0.0.10
config-prod        A    10.0.0.10
[root@host0-200 ~]# systemctl restart named
```

### 应用资源配置清单

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/test/apollo-configservice/cm.yaml
configmap/apollo-configservice-cm created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/test/apollo-configservice/svc.yaml
deployment.extensions/apollo-configservice created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/test/apollo-configservice/dp.yaml
service/apollo-configservice created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/test/apollo-configservice/ingress.yaml
ingress.extensions/apollo-configservice created
```

## 准备prod资源配置清单

```
[root@host0-200 apollo-configservice]# pwd
/data/k8s-yaml/prod/apollo-configservice
[root@host0-200 apollo-configservice]# cp ../../test/apollo-configservice/* .
修改内容同上，只是修改为prod
```

### 应用资源配置清单

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/prod/apollo-configservice/cm.yaml
configmap/apollo-configservice-cm created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/prod/apollo-configservice/svc.yaml
deployment.extensions/apollo-configservice created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/prod/apollo-configservice/dp.yaml
service/apollo-configservice created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/prod/apollo-configservice/ingress.yaml
ingress.extensions/apollo-configservice created
```

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/65.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/66.png)

## apollo-adminservice资源配置清单

### 准备Test的资源配置清单

```sh
[root@host0-200 apollo-configservice]# cd ../../test/apollo-adminservice/
[root@host0-200 apollo-adminservice]# cp /data/k8s-yaml/apollo-adminservice/* .
[root@host0-200 apollo-adminservice]# ls
cm.yaml  dp.yaml
[root@host0-200 apollo-adminservice]# vim cm.yaml 

apiVersion: v1
kind: ConfigMap
metadata:
  name: apollo-adminservice-cm
  namespace: test
data:
  application-github.properties: |
    # DataSource
    spring.datasource.url = jdbc:mysql://mysql.od.com:3306/ApolloConfigTestDB?characterEncoding=utf8
    spring.datasource.username = apolloconfig
    spring.datasource.password = 123123
    eureka.service.url = http://config-test.od.com/eureka
  app.properties: |
    appId=100003172
    

# dp只改一个命名空间
```

### 准备Prod资源配置清单

```
[root@host0-200 apollo-adminservice]# cd ../../prod/apollo-adminservice/
[root@host0-200 apollo-adminservice]# cp ../../test/apollo-adminservice/* .
[root@host0-200 apollo-adminservice]# ls
cm.yaml  dp.yaml
[root@host0-200 apollo-adminservice]# vim cm.yaml 
[root@host0-200 apollo-adminservice]# vim dp.yaml
同上修改，只是把test修改为prod
```

### 应用资源配置清单

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/test/apollo-adminservice/cm.yaml
configmap/apollo-adminservice-cm created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/test/apollo-adminservice/dp.yaml
deployment.extensions/apollo-adminservice created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/prod/apollo-adminservice/cm.yaml
configmap/apollo-adminservice-cm created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/prod/apollo-adminservice/dp.yaml
deployment.extensions/apollo-adminservice created
```

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/67.png)

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/68.png)

### 整理修改portal

清空的意思就是为了把infra演示的dev运行环境清空

```
[root@host0-11 apollo1.5.1-DB]# mysql -uroot -p123123
Welcome to the MariaDB monitor.  Commands end with ; or \g.
Your MariaDB connection id is 1129
Server version: 10.1.48-MariaDB MariaDB Server

Copyright (c) 2000, 2018, Oracle, MariaDB Corporation Ab and others.

Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.

MariaDB [(none)]> use ApolloPortalDB
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
MariaDB [ApolloPortalDB]> show tables;
+--------------------------+
| Tables_in_ApolloPortalDB |
+--------------------------+
| App                      |
| AppNamespace             |
| Authorities              |
| Consumer                 |
| ConsumerAudit            |
| ConsumerRole             |
| ConsumerToken            |
| Favorite                 |
| Permission               |
| Role                     |
| RolePermission           |
| ServerConfig             |
| UserRole                 |
| Users                    |
+--------------------------+
14 rows in set (0.00 sec)

MariaDB [ApolloPortalDB]> truncate table AppNamespace;
Query OK, 0 rows affected (0.00 sec)

MariaDB [ApolloPortalDB]> truncate table App;
Query OK, 0 rows affected (0.01 sec)
```

### 测试登陆Apollo

![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/69.png)
![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/70.png)
![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/71.png)
![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/72.png)
![](/images/posts/Linux-Kubernetes/在k8s中集成Apollo配置中心/73.png)
