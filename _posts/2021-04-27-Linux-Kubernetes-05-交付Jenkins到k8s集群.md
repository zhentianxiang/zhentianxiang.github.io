---
layout: post
title: Linux-Kubernetes-05-交付Jenkins到k8s集群
date: 2021-04-27
tags: 实战-Kubernetes
---



## 部署Jenkins

准备镜像

- [Jenkins官网](https://www.jenkins.io/download/)
- [Jenkins镜像](https://hub.docker.com/r/jenkins/jenkins/tags?page=1&ordering=last_updated)

host0-200运维主机pull镜像

### 拉镜像打标签上传镜像

```sh
[root@host0-200 ~]#  docker pull jenkins/jenkins:2.277.3
2.190.3: Pulling from jenkins/jenkins
9a0b0ce99936: Downloading [=========>                                         ]  8.776MB/45.38MB
db3b6004c61a: Download complete
f8f075920295: Downloading [==============================>                    ]  2.653MB/4.34MB
9a0b0ce99936: Extracting [======>                                            ]  5.505MB/45.38MB
9a0b0ce99936: Pull complete
db3b6004c61a: Pull complete
f8f075920295: Pull complete
6ef14aff1139: Pull complete
962785d3b7f9: Pull complete
631589572f9b: Pull complete
c55a0c6f4c7b: Pull complete
4e96cf3bdc20: Pull complete
e0b44ce6ec69: Pull complete
d961082c76f4: Pull complete
5a229d171c71: Pull complete
64514e4513d4: Pull complete
6797bb506402: Pull complete
b8d0a307156c: Pull complete
b17b306b4a0a: Pull complete
e47bd954be8f: Pull complete
b2d9d6b1cd91: Pull complete
fa537a81cda1: Pull complete
Digest: sha256:64576b8bd0a7f5c8ca275f4926224c29e7aa3f3167923644ec1243cd23d611f3
Status: Downloaded newer image for jenkins/jenkins:2.277.3
docker.io/jenkins/jenkins:2.277.3
[root@host0-200 ~]# docker images |grep jenkins
jenkins/jenkins                                                      2.277.3                         22b8b9a84dbe   16 months ago   568MB
[root@host0-200 ~]# docker tag jenkins/jenkins:2.277.3 harbor.od.com/public/jenkins:v2.277.3
[root@host0-200 ~]# ls
anaconda-ks.cfg
[root@host0-200 ~]# docker push harbor.od.com/public/jenkins:v2.277.3
The push refers to repository [harbor.od.com/public/jenkins]
e0485b038afa: Pushed
2950fdd45d03: Pushed
cfc53f61da25: Pushed
29c489ae7aae: Pushed
473b7de94ea9: Pushed
6ce697717948: Pushed
0fb3a3c5199f: Pushed
23257f20fce5: Pushed
b48320151ebb: Pushed
911119b5424d: Pushed
5051dc7ca502: Pushed
a8902d6047fe: Pushed
99557920a7c5: Pushed
7e3c900343d0: Pushed
b8f8aeff56a8: Pushed
687890749166: Pushed
2f77733e9824: Pushed
97041f29baff: Pushed
v2.277.3: digest: sha256:64576b8bd0a7f5c8ca275f4926224c29e7aa3f3167923644ec1243cd23d611f3 size: 4087
```

### 制作SSL密钥

注意：别用我邮箱，因为dubbo服务有两个服务，一个提供者一个消费者，消费者使用gitssh去拉取的，所以要用加密的方式去拉区代码。

把私钥封装到Jenkins镜像里，把公钥拷贝到gitee仓库

```sh
[root@host0-200 ~]# ssh-keygen -t rsa -b 2048 -C "2099637909@qq.com" -N "" -f /root/.ssh/id_rsa
Generating public/private rsa key pair.
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
SHA256:ALJTjNQPbSIcS8t2WmlB64du+SMvWMyJInywID0HwKw 2099637909@qq.com
The key's randomart image is:
+---[RSA 2048]----+
|++=*=.           |
| ==*==o          |
|..Bo*=.          |
|EooB....         |
|+ +*o.. S        |
|oo.o=o           |
|...o+            |
|  ..o..          |
|     +o.         |
+----[SHA256]-----+
[root@host0-200 ~]# cat /root/.ssh/id_rsa.pub
AAAAB3NzaC1yc2EAAAADAQABAAABAQCsG72I6gn0fQ6458Mm6VWRIUJ6eCxnS5TfYivKANYVN283dbuV1Ofd3bTAo51u5G3flQV8E5lmIISZ+YdwHtd2TLYXoPn45k6RidKSBQqPMCjFULw1jaTdbCW+9xMVGRkeghagvkjmX8Fx8DKl33sHFUrf6ulQt1RbhrHR8kRzHiMqMPzNvx/GUebk8WCXGwvkkHqZeBWiGJ/Q0Pz8CnaxqoG05Vuv99SRdrOLsWl8UdD+G/1UdNYKSV+xZwmIl4WWuvief7ucVg7SmV9IH5zWppJNs/M8a6dMYEgJ+78vgAWVA3b33C2MaaXYUJGNUvV/VyF+q7fwDrlNhsD0FnnB 2099637909@qq.com
```

![image-20210427183819968](/images/posts/Linux-Kubernetes/交付dubbo/1.png)

### 拷贝私钥到和docker.json以及下载docker安装脚本

```sh
[root@host0-200 ]# mkdir /data/dockerfile && cd /data/dockerfile
[root@host0-200 dockerfile]# cp /root/.ssh/id_rsa .
[root@host0-200 dockerfile]# cp /root/.docker/config.json .
[root@host0-200 dockerfile]# curl -fsSL get.daocloud.io/docker -o get-docker.sh && ls
[root@host0-200 dockerfile]# chmod o+x get-docker.sh
```

### 自定义dockerfile

```sh
[root@host0-200 dockerfile]# vim /data/dockerfile/Dockerfile
FROM jenkins/jenkins:2.277.3
USER root
RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&\
    echo "Asia/Shanghai" >/etc/timezone
ADD id_rsa /root/.ssh/id_rsa
ADD config.json /root/.docker/config.json
ADD get-docker.sh /get-docker.sh
RUN echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config &&\
/get-docker.sh
```

### 制作上传镜像

```sh
[root@host0-200 dockerfile]# docker build . -t harbor.od.com/infra/jenkins:v2.277.3
Sending build context to Docker daemon  20.99kB
Step 1/8 : FROM jenkins/jenkins:2.277.3
 ---> de181f8c70e8
Step 2/8 : USER root
 ---> Running in b8e4e187ff30
Removing intermediate container b8e4e187ff30
 ---> a9009587a667
Step 3/8 : RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&    echo "Asia/Shanghai" >/etc/timezone
 ---> Running in 1bee0b59921e
Removing intermediate container 1bee0b59921e
 ---> de681989a533
Step 4/8 : ADD id_rsa /root/.ssh/id_rsa
 ---> 78790cbe16ad
Step 5/8 : ADD config.json /root/.docker/config.json
 ---> e427823d4092
Step 6/8 : ADD get-docker.sh /get-docker.sh
 ---> 4dae17a998a1
Step 7/8 : RUN echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config
 ---> Running in 58eda3dabb3a
Removing intermediate container 58eda3dabb3a
 ---> f099e7bc81c4
Step 8/8 : RUN /get-docker.sh
 ---> Running in e205acd308c5
# Executing docker install script, commit: 7cae5f8b0decc17d6571f9f52eb840fbc13b2737
+ sh -c apt-get update -qq >/dev/null
+ sh -c DEBIAN_FRONTEND=noninteractive apt-get install -y -qq apt-transport-https ca-certificates curl >/dev/null
+ sh -c curl -fsSL "https://download.docker.com/linux/debian/gpg" | apt-key add -qq - >/dev/null
Warning: apt-key output should not be parsed (stdout is not a terminal)
+ sh -c echo "deb [arch=amd64] https://download.docker.com/linux/debian buster stable" > /etc/apt/sources.list.d/docker.list
+ sh -c apt-get update -qq >/dev/null
+ [ -n  ]
+ sh -c apt-get install -y -qq --no-install-recommends docker-ce >/dev/null
debconf: delaying package configuration, since apt-utils is not installed
+ [ -n 1 ]
+ sh -c DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce-rootless-extras >/dev/null
debconf: delaying package configuration, since apt-utils is not installed

================================================================================

To run Docker as a non-privileged user, consider setting up the
Docker daemon in rootless mode for your user:

    dockerd-rootless-setuptool.sh install

Visit https://docs.docker.com/go/rootless/ to learn about rootless mode.


To run the Docker daemon as a fully privileged service, but granting non-root
users access, refer to https://docs.docker.com/go/daemon-access/

WARNING: Access to the remote API on a privileged Docker daemon is equivalent
         to root access on the host. Refer to the 'Docker daemon attack surface'
         documentation for details: https://docs.docker.com/go/attack-surface/

================================================================================

Removing intermediate container e205acd308c5
 ---> 7d72c233ef5d
Successfully built 7d72c233ef5d
Successfully tagged harbor.od.com/infra/jenkins:v2.277.3
如果build镜像报错，可以尝试换个其他版本的Jenkins，或者把Dockerfile文件中的最后面的/get-docker.sh去掉，然后手动进入容器去执行这个脚本安装docker，然后commit生成新的镜像
```

### 创建私有infra仓库，以及上传自定义镜像

![image-20210427183858538](/images/posts/Linux-Kubernetes/交付dubbo/2.png)
```sh
[root@host0-200 dockerfile]# docker push harbor.od.com/infra/jenkins:v2.277.3
```
### 测试Jenkins容器是否可以连接到gitee仓库

```sh
[root@host0-200 ~]# docker run --rm harbor.od.com/infra/jenkins:v2.277.3 ssh -i /root/.ssh/id_rsa -T git@gitee.com
ssh: connect to host gitee.com port 22: Connection refused
# 出现以上情况，可以把本地网络切换一下试试。
[root@host0-200 ~]# ping www.baidu.com
PING www.a.shifen.com (220.181.38.149) 56(84) bytes of data.
64 bytes from 220.181.38.149 (220.181.38.149): icmp_seq=1 ttl=128 time=35.8 ms
^C
--- www.a.shifen.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 35.872/35.872/35.872/0.000 ms
[root@host0-200 ~]# docker run --rm harbor.od.com/infra/jenkins:v2.277.3 ssh -i /root/.ssh/id_rsa -T git@gitee.com
Warning: Permanently added 'gitee.com,180.97.125.228' (ECDSA) to the list of known hosts.
Hi 甄天祥! You've successfully authenticated, but GITEE.COM does not provide shell access.
```

## 准备交付Jenkins到k8s

```sh
# 创建命名空间
[root@host0-21 ~]# kubectl create ns infra
namespace/infra created
[root@host0-21 ~]# kubectl get ns
NAME              STATUS   AGE
default           Active   19d
infra             Active   6s
kube-node-lease   Active   19d
kube-public       Active   19d
kube-system       Active   19d
# 创建拉取Jenkins镜像专属的secret资源
以下命令就是在infra命名空间里面创建一个名为harbor的secret资源，资源里面包括harbor仓库的用户名和密码
[root@host0-21 ~]# kubectl create secret docker-registry harbor --docker-server=harbor.od.com --docker-username=admin --docker-password=Harbor12345 -n infra
secret/harbor created
[root@host0-21 ~]# kubectl get secret -n infra
NAME                  TYPE                                  DATA   AGE
default-token-7dfjr   kubernetes.io/service-account-token   3      15h
harbor                kubernetes.io/dockerconfigjson        1      34s
```

### 准备共享存储

我们现在有两个个运算节点，Jenkins有一些需要持久化的数据（/var/lib/jenkins_home），需要挂载到指定的节点，无论Jenkins是否存活还是是否来回飘逸node节点，数据永远不会丢失。

需要在host0-21、host0-22、host0-200安装，但是仅需要在200主机进行配置

```sh
[root@host0-200 docker]# yum -y install nfs-utils
[root@host0-200 docker]# echo '/data/nfs-volume 10.0.0.0/24(rw,no_root_squash)' >>/etc/exports
[root@host0-200 docker]# mkdir -pv /data/nfs-volume/jenkins_home
[root@host0-200 docker]# systemctl start nfs && systemctl enable nfs
Created symlink from /etc/systemd/system/multi-user.target.wants/nfs-server.service to /usr/lib/systemd/system/nfs-server.service.
```

### 准备资源配置清单

```sh
# deployment资源
[root@host0-200 jenkins]# mkdir /data/k8s-yaml/jenkins/ && cd /data/k8s-yaml/jenkins/
[root@host0-200 jenkins]# vim dp.yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: jenkins
  namespace: infra
  labels:
    name: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      name: jenkins
  template:
    metadata:
      labels:
        app: jenkins
        name: jenkins
    spec:
      volumes:
      - name: data
        nfs:
          server: host0-200
          path: /data/nfs-volume/jenkins_home
      - name: docker
        hostPath:
          path: /run/docker.sock
          type: ''
      containers:
      - name: jenkins
        image: harbor.od.com/infra/jenkins:v2.277.3
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          protocol: TCP
        env:
        - name: JAVA_OPTS
          value: -Xmx512m -Xms512m -Dhudson.security.csrf.GlobalCrumbIssuerConfiguration.DISABLE_CSRF_PROTECTION=true
        volumeMounts:
        - name: data
          mountPath: /var/jenkins_home
        - name: docker
          mountPath: /run/docker.sock
      imagePullSecrets:
      - name: harbor
      securityContext:
        runAsUser: 0
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  revisionHistoryLimit: 7
  progressDeadlineSeconds: 600
```
> 老版本Jenkins的CSRF保护功能只需要在 系统管理 > 全局安全配置 中便可进行打开或者关闭。让人头疼的是较高版本的Jenkins竟然在管理页面关闭不了CSRF，网上搜索到的资料有写通过 groovy代码 实现取消保护，但是笔者操作未成功，最后，Get到了一种成功的解决姿势。
> 在变量中添加-Dhudson.security.csrf.GlobalCrumbIssuerConfiguration.DISABLE_CSRF_PROTECTION=true

```sh
# service资源
[root@host0-200 jenkins]# vim svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: infra
spec:
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  selector:
    app: jenkins
```

```sh
# ingress资源
[root@host0-200 jenkins]# vim ingress.yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: jenkins
  namespace: infra
spec:
  rules:
  - host: jenkins.od.com
    http:
      paths:
      - path: /
        backend:
          serviceName: jenkins
          servicePort: 80
```

### 应用资源配置清单

```sh
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/jenkins/svc.yaml
deployment.apps/jenkins created
[root@host0-21 ~]# kubectl get pods -n infra
NAME                       READY   STATUS    RESTARTS   AGE
jenkins-5fccb8b87f-8jl85   1/1     Running   0          87s
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/jenkins/dp.yaml
service/jenkins created
[root@host0-21 ~]# kubectl apply -f http://k8s-yaml.od.com/jenkins/ingress.yaml
ingress.extensions/jenkins created
[root@host0-21 ~]# kubectl get svc -n infra
NAME      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
jenkins   ClusterIP   192.168.250.71   <none>        80/TCP    18s
[root@host0-21 ~]# kubectl get ingress -n infra
NAME      HOSTS            ADDRESS   PORTS   AGE
jenkins   jenkins.od.com             80      21s
```

查看挂载的数据已经有了

```
[root@host0-200 ~]# ls
anaconda-ks.cfg  dubbo-demo-monitor  dubbo-demo-service  dubbo-demo-web  jenkins2.277.3  jre8u112
[root@host0-200 ~]# ll /data/nfs-volume/jenkins_home/
总用量 84
drwxr-xr-x  3 root root   26 4月  27 12:46 caches
-rw-r--r--  1 root root 1667 4月  27 12:40 config.xml
-rw-r--r--  1 root root   50 4月  27 12:30 copy_reference_file.log
-rw-r--r--  1 root root  156 4月  27 12:40 hudson.model.UpdateCenter.xml
-rw-r--r--  1 root root  370 4月  27 12:39 hudson.plugins.git.GitTool.xml
-rw-------  1 root root 1712 4月  27 12:30 identity.key.enc
-rw-r--r--  1 root root    7 4月  27 12:40 jenkins.install.InstallUtil.lastExecVersion
-rw-r--r--  1 root root    7 4月  27 12:30 jenkins.install.UpgradeWizard.state
-rw-r--r--  1 root root  357 4月  27 12:34 jenkins.security.apitoken.ApiTokenPropertyConfiguration.xml
-rw-r--r--  1 root root  169 4月  27 12:34 jenkins.security.QueueItemAuthenticatorConfiguration.xml
-rw-r--r--  1 root root  162 4月  27 12:34 jenkins.security.UpdateSiteWarningsConfiguration.xml
-rw-r--r--  1 root root  171 4月  27 12:30 jenkins.telemetry.Correlator.xml
drwxr-xr-x  3 root root   24 4月  27 12:40 jobs
drwxr-xr-x  4 root root   37 4月  27 12:39 logs
drwxr-xr-x  6 root root   99 4月  27 00:25 maven-3.6.3-8u282
-rw-r--r--  1 root root  907 4月  27 12:40 nodeMonitors.xml
drwxr-xr-x  2 root root    6 4月  27 12:30 nodes
-rw-r--r--  1 root root   46 4月  27 17:15 org.jenkinsci.plugins.workflow.flow.FlowExecutionList.xml
drwxr-xr-x 89 root root 8192 4月  27 12:39 plugins
-rw-r--r--  1 root root  130 4月  27 17:15 queue.xml
-rw-r--r--  1 root root  129 4月  27 12:40 queue.xml.bak
-rw-r--r--  1 root root   64 4月  27 12:30 secret.key
-rw-r--r--  1 root root    0 4月  27 12:30 secret.key.not-so-secret
drwx------  4 root root 4096 4月  27 12:46 secrets
drwxr-xr-x  2 root root  100 4月  27 12:39 updates
drwxr-xr-x  2 root root   24 4月  27 12:30 userContent
drwxr-xr-x  3 root root   55 4月  27 12:30 users
drwxr-xr-x 11 root root 4096 4月  27 12:32 war
drwxr-xr-x  2 root root    6 4月  27 12:39 workflow-libs
drwxr-xr-x  4 root root   46 4月  27 12:46 workspace
```

并且查看容器日志已经成功启动了

![image-20210427184153690](/images/posts/Linux-Kubernetes/交付dubbo/3.png)

### 添加named解析

```
[root@host0-200 ~]# vim /var/named/od.com.zone
[root@host0-200 ~]# cat /var/named/od.com.zone 
$ORIGIN od.com.
$TTL 600    ; 10 minutes
@           IN SOA  dns.od.com. dnsadmin.od.com. (
                2021033105 ; serial
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
zk1                A    10.0.0.21
zk2                A    10.0.0.22
zk3                A    10.0.0.200
jenkins            A    10.0.0.10
[root@host0-15 ~]# systemctl restart named
[root@host0-15 ~]# nslookup jenkins.od.com
Server:         10.0.0.200
Address:        10.0.0.200#53

Name:   jenkins.od.com
Address: 10.0.0.10
```

## 准备jenkins配置

浏览器测试访问：jenkins.od.com

```sh
# 默认密码
[root@host0-200 secrets]# cat /data/nfs-volume/jenkins_home/secrets/initialAdminPassword 
9661aca84a3a481898523d5bfc35a11d
```



修改配置安全选项
![image-20210427184153690](/images/posts/Linux-Kubernetes/交付dubbo/补充1.png)
![image-20210427184153690](/images/posts/Linux-Kubernetes/交付dubbo/补充2.png)

安装blueocean插件（工作流）
![image-20210427184153690](/images/posts/Linux-Kubernetes/交付dubbo/补充3.png)
![image-20210427184153690](/images/posts/Linux-Kubernetes/交付dubbo/补充4.png)
![image-20210427184153690](/images/posts/Linux-Kubernetes/交付dubbo/补充5.png)

### 验证jenkins容器

```sh
[root@host0-21 ~]# kubectl get pods -n infra -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP           NODE                NOMINATED NODE   READINESS GATES
jenkins-5fccb8b87f-g94nf   1/1     Running   0          83m   172.7.11.5   host0-11.host.com   <none>           <none>
[root@host0-21 ~]# kubectl exec -it jenkins-5fccb8b87f-g94nf -n infra /bin/bash
root@jenkins-5fccb8b87f-g94nf:/# whoami
root
root@jenkins-5fccb8b87f-g94nf:/# date
Tue Apr 20 21:59:21 CST 2021
root@jenkins-5fccb8b87f-g94nf:/# docker ps 
CONTAINER ID        IMAGE                               COMMAND                  CREATED             STATUS              PORTS                NAMES
19e5c8fac9ba        73345ce88ada                        "/sbin/tini -- /usr/…"   About an hour ago   Up About an hour                         k8s_jenkins_jenkins-5fccb8b87f-g94nf_infra_21ce3c1a-12fc-46cd-9d05-dba1894898d2_0
3dc68e7777a8        harbor.od.com/public/pause:latest   "/pause"                 About an hour ago   Up About an hour                         k8s_POD_jenkins-5fccb8b87f-g94nf_infra_21ce3c1a-12fc-46cd-9d05-dba1894898d2_0
7103ff148eef        harbor.od.com/public/nginx          "/docker-entrypoint.…"   7 hours ago         Up 7 hours                               k8s_my-nginx_nginx-ds-qgjpz_default_306332e2-dcc5-45ff-858e-cdce47f918ec_3
f901e870a47b        add5fac61ae5                        "/entrypoint.sh --ap…"   7 hours ago         Up 7 hours                               k8s_traefik-ingress_traefik-ingress-z4nzg_kube-system_61f0bffa-bae1-41b0-aa47-3bf4f51b488d_3
b3f5fc3edfcd        c359b95ad38b                        "/opt/bitnami/heapst…"   7 hours ago         Up 7 hours                               k8s_heapster_heapster-5bb4cb85dd-dtnqs_kube-system_ec3b5f4d-5c71-44a2-981d-910f5ff27bcb_3
6e96acd9413a        harbor.od.com/public/pause:latest   "/pause"                 7 hours ago         Up 7 hours                               k8s_POD_nginx-ds-qgjpz_default_306332e2-dcc5-45ff-858e-cdce47f918ec_3
00926d208f78        harbor.od.com/public/pause:latest   "/pause"                 7 hours ago         Up 7 hours                               k8s_POD_heapster-5bb4cb85dd-dtnqs_kube-system_ec3b5f4d-5c71-44a2-981d-910f5ff27bcb_3
57307a2a5b2f        harbor.od.com/public/pause:latest   "/pause"                 7 hours ago         Up 7 hours          0.0.0.0:81->80/tcp   k8s_POD_traefik-ingress-z4nzg_kube-system_61f0bffa-bae1-41b0-aa47-3bf4f51b488d_3
root@jenkins-5fccb8b87f-g94nf:/# docker login harbor.od.com
Authenticating with existing credentials...
WARNING! Your password will be stored unencrypted in /root/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
root@jenkins-5fccb8b87f-g94nf:/# ssh -i /root/.ssh/id_rsa -T git@gitee.com
Warning: Permanently added 'gitee.com,180.97.125.228' (ECDSA) to the list of known hosts.
Hi 甄天祥! You've successfully authenticated, but GITEE.COM does not provide shell access.
```

### 安装部署maven

[官方安装包](https://archive.apache.org/dist/maven/maven-3/3.6.3/binaries/apache-maven-3.6.3-bin.tar.gz)

```sh
[root@host0-200 jenkins_home]# cd /opt/src/
[root@host0-200 src]# wget http://10.0.0.100:8080/jenkins/apache-maven-3.6.3-bin.tar.gz
--2021-04-20 22:09:00--  http://10.0.0.100:8080/jenkins/apache-maven-3.6.3-bin.tar.gz
正在连接 10.0.0.100:8080... 已连接。
已发出 HTTP 请求，正在等待回应... 200 OK
长度：9136463 (8.7M) [application/x-gzip]
正在保存至: “apache-maven-3.6.1-bin.tar.gz”

100%[=============================================================================================================================================================================================================>] 9,136,463   --.-K/s 用时 0.03s   

2021-04-20 22:09:00 (314 MB/s) - 已保存 “apache-maven-3.6.3-bin.tar.gz” [9136463/9136463])

[root@host0-200 src]# ls
apache-maven-3.6.1-bin.tar.gz  harbor-1.9.4.tar.gz
[root@host0-200 src]# ls
apache-maven-3.6.1-bin.tar.gz  harbor-1.9.4.tar.gz
# 查看jenkins Java环境
root@jenkins-5fccb8b87f-g94nf:/# java -version
openjdk version "1.8.0_282"
OpenJDK Runtime Environment (build 1.8.0_282-b09)
OpenJDK 64-Bit Server VM (build 25.232-b09, mixed mode)
# 因为jenkins的Java环境是1.8.0_282，所以创建个特殊的目录
[root@host0-200 src]# mkdir -pv /data/nfs-volume/jenkins_home/maven-3.6.3-8u282
[root@host0-200 src]# tar xf apache-maven-3.6.3-bin.tar.gz -C /data/nfs-volume/jenkins_home/maven-3.6.3-8u282/
[root@host0-200 src]# cd /data/nfs-volume/jenkins_home/maven-3.6.3-8u282/
[root@host0-200 maven-3.6.3-8u282]# ls
apache-maven-3.6.3
[root@host0-200 maven-3.6.3-8u282]# mv apache-maven-3.6.3/* .
[root@host0-200 maven-3.6.3-8u282]# ls
apache-maven-3.6.1  bin  boot  conf  lib  LICENSE  NOTICE  README.txt
[root@host0-200 maven-3.6.3-8u282]# rm -rf apache-maven-3.6.3/
[root@host0-200 maven-3.6.3-8u282]# ls
bin  boot  conf  lib  LICENSE  NOTICE  README.txt.
# 粘贴到此位置，添加镜像源，在第146行添加
[root@host0-200 maven-3.6.3-8u282]# vim conf/settings.xml
    <mirror>
      <id>nexus-aliyun</id>
      <mirrorOf>*</mirrorOf>
      <name>Nexus aliyun</name>
      <url>http://maven.aliyun.com/nexus/content/groups/public</url>
    </mirror>
```

![image-20210427185347120](/images/posts/Linux-Kubernetes/交付dubbo/6.png)

## 制作dubbo微服务的底包镜像

因为我们是一个Java程序，不管是dubbo的提供者还是消费者，他都是需要运行在Java环境下，所以我们直接from一个部署好的Java环境的镜像来制作dubbo微服务即可，不需要自己from一个centos镜像，然后再手动部署Java环境

```sh
[root@host0-200 maven-3.6.3-8u282]# docker pull docker.io/zhentianxiang/jre8:8u112
8u112: Pulling from zhentianxiang/jre8
cd9a7cbe58f4: Pull complete 
8372fab2fcdf: Pull complete 
54746b802c92: Pull complete 
969413759d76: Pull complete 
3a44edd3f51d: Pull complete 
Digest: sha256:921225313d0ae6ce26eac31fc36b5ba8a0a841ea4bd4c94e2a167a9a3eb74364
Status: Downloaded newer image for zhentianxiang/jre8:8u112
docker.io/zhentianxiang/jre8:8u112
[root@host0-200 maven-3.6.1-8u232]# docker images|grep jre
zhentianxiang/jre8                                                       8u112                           fa3a085d6ef1   3 years ago     363MB
[root@host0-200 maven-3.6.1-8u232]# docker tag zhentianxiang/jre8:8u112 harbor.od.com/public/jre:8u112
[root@host0-200 maven-3.6.1-8u232]# docker push harbor.od.com/public/jre:8u112
The push refers to repository [harbor.od.com/public/jre]
0690f10a63a5: Pushed 
c843b2cf4e12: Pushed 
fddd8887b725: Pushed 
42052a19230c: Pushed 
8d4d1ab5ff74: Pushed 
8u112: digest: sha256:733087bae1f15d492307fca1f668b3a5747045aad6af06821e3f64755268ed8e size: 1367
[root@host0-200 plugins]# mkdir -pv /data/dockerfile/jre8
[root@host0-200 plugins]# cd /data/dockerfile/jre8/
[root@host0-200 jre8]# vim Dockerfile
FROM harbor.od.com/public/jre:8u112
RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&\
    echo 'Asia/Shanghai' >/etc/timezone
ADD config.yml /opt/prom/config.yml
ADD jmx_javaagent-0.3.1.jar /opt/prom/
WORKDIR /opt/project_dir
ADD entrypoint.sh /entrypoint.sh
CMD ["/entrypoint.sh"]
[root@host0-200 jre8]# wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.3.1/jmx_prometheus_javaagent-0.3.1.jar
--2021-04-21 15:48:42--  https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.3.1/jmx_prometheus_javaagent-0.3.1.jar
正在解析主机 repo1.maven.org (repo1.maven.org)... 151.101.40.209
正在连接 repo1.maven.org (repo1.maven.org)|151.101.40.209|:443... 已连接。
已发出 HTTP 请求，正在等待回应... 200 OK
长度：367417 (359K) [application/java-archive]
正在保存至: “jmx_prometheus_javaagent-0.3.1.jar”

100%[=============================================================================================================================================================================================================>] 367,417      764KB/s 用时 0.5s   

2021-04-21 15:48:47 (764 KB/s) - 已保存 “jmx_prometheus_javaagent-0.3.1.jar” [367417/367417])

[root@host0-200 jre8]# ls
Dockerfile  jmx_prometheus_javaagent-0.3.1.jar
[root@host0-200 jre8]# mv jmx_prometheus_javaagent-0.3.1.jar jmx_javaagent-0.3.1.jar
[root@host0-200 jre8]# vim config.yml
---
rules:
  - pattern: '.*'
[root@host0-200 jre8]# vim entrypoint.sh
#!/bin/sh
M_OPTS="-Duser.timezone=Asia/Shanghai -javaagent:/opt/prom/jmx_javaagent-0.3.1.jar=$(hostname -i):${M_PORT:-"12346"}:/opt/prom/config.yml"
C_OPTS=${C_OPTS}
JAR_BALL=${JAR_BALL}
exec java -jar ${M_OPTS} ${C_OPTS} ${JAR_BALL}
[root@host0-200 jre8]# chmod u+x entrypoint.sh 
[root@host0-200 jre8]# ll
总用量 372
-rw-r--r-- 1 root root     29 4月  21 15:50 config.yml
-rw-r--r-- 1 root root    297 4月  21 15:47 Dockerfile
-rwxr-xr-x 1 root root    236 4月  21 16:09 entrypoint.sh
-rw-r--r-- 1 root root 367417 5月  10 2018 jmx_prometheus_javaagent-0.3.1.jar
```

> 注：entrypoint.sh文件中
> C_OPTS=${C_OPTS}表示将资源配置清单中的变量值赋值给它
> ${M_PORT:-"12346"}表示如果没有给它赋值，则默认值是12346
> 最后一行前面加exec是因为这个shell执行完，这个容器就死了，exec作用就是把这个shell 的pid交给 exec后面的命令继续使用，这样java不死，这个pod就能一直存活
> shell的内建命令exec将并不启动新的shell，而是用要被执行命令替换当前的shell进程，并且将老进程的环境清理掉，而且exec命令后的其它命令将不再执行。

```sh
[root@host0-200 jre8]# docker build . -t harbor.od.com/base/jre8:8u112
Sending build context to Docker daemon  372.2kB
Step 1/7 : FROM harbor.od.com/public/jre:8u112
 ---> fa3a085d6ef1
Step 2/7 : RUN /bin/cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime &&    echo 'Asia/Shanghai' >/etc/timezone
 ---> Using cache
 ---> 2ed9d117be34
Step 3/7 : ADD config.yml /opt/prom/config.yml
 ---> Using cache
 ---> b9744dcbd88a
Step 4/7 : ADD jmx_javaagent-0.3.1.jar /opt/prom/
 ---> 577bb0c44f2a
Step 5/7 : WORKDIR /opt/project_dir
 ---> Running in 0ea96ad4594e
Removing intermediate container 0ea96ad4594e
 ---> 9bb25e6013b7
Step 6/7 : ADD entrypoint.sh /entrypoint.sh
 ---> 241beacb416b
Step 7/7 : CMD ["/entrypoint.sh"]
 ---> Running in 4b62aaf3c166
Removing intermediate container 4b62aaf3c166
 ---> 0ef58475f2be
Successfully built 0ef58475f2be
Successfully tagged harbor.od.com/base/jre8:8u112
```
![image-20210427183819968](/images/posts/Linux-Kubernetes/交付dubbo/补充6.png)
```sh
[root@host0-200 jre8]# docker push harbor.od.com/base/jre8:8u112 
The push refers to repository [harbor.od.com/base/jre8]
954644fe62b7: Pushed 
b8ebbd8b2a86: Pushed 
ded72126ad60: Pushed 
b701b5a9e2b2: Pushed 
b9866c1e7dd1: Pushed 
0690f10a63a5: Mounted from public/jre 
c843b2cf4e12: Mounted from public/jre 
fddd8887b725: Mounted from public/jre 
42052a19230c: Mounted from public/jre 
8d4d1ab5ff74: Mounted from public/jre 
8u112: digest: sha256:1ac9db207eddd4d9b1d26d21a400f3bb290f1124f42414c438af0946def9471d size: 2405
```
