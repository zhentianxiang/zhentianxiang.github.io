---
layout: post
title: Linux-Kubernetes-30-使用spinnaker部署dubbo服务
date: 2021-05-20
tags: 实战-Kubernetes
---

## 1. 清除无用的容器

首先把与本实验无关紧要的容器停掉，因为我们接下来要利用spinnaker构建dubbo环境，所以就不要用之前的dubbo环境了

![1](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/1.png)

### 1.1 关停prod环境下的dubbo服务

![2](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/2.png)

### 1.2 关停测试环境下的dubbo服务

![3](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/3.png)

再次查看没有了dubbo项目应用

![4](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/4.png)

### 1.3 创建一个项目的应用程序

![5](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/5.png)

### 1.4 填写基本信息，保存退出

![6](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/6.png)

### 1.5 查看发现出现了一个新的项目应用

![7](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/7.png)

### 1.6 查看front存储是否进入相关数据

![8](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/8.png)

## 2. 制作dubbo提供者的流水线任务

![9](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/9.png)

### 2.1 填写流水线的名字

![10](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/10.png)

### 2.2 添加相关参数

配置4个参数选项，保存退出

![11](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/11.png)

![12](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/12.png)

### 2.3 继续添加阶段

![13](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/13.png)

### 2.4 选择Jenkins作为CI工具

![14](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/14.png)

![15](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/15.png)

### 2.5 添加Jenkins相关参数，使用变量调用前面流水线的参数配置

![16](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/16.png)

![17](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/17.png)

### 2.6 测试调用Jenkins能否成功使用

![18](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/18.png)

### 2.7 添加一个代码的分支和镜像的版本号即可

![19](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/19.png)

![20](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/20.png)

![22](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/22.png)

![23](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/23.png)

## 3. 配置dubbo提供者的容器

![24](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/24.png)

![25](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/25.png)

### 3.1 deploy类型的资源，所以选择deploy

![27](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/26.png)

### 3.2 添加服务组

![27](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/27.png)

### 3.3 定义用户角色、管理的空间、项目的名称、以及该容器所用的镜像

![28](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/28.png)

### 3.4 配置副本数量

![29](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/29.png)

### 3.5 定义容器的环境变量，然后保存退出

![31](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/31.png)

> 注意：做到这里请看如下标题：5.6 修改资源清单，dubbo提供者的资源也可以同样使用相关变量进行替换

## 4. 启动dubbo提供者

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/32.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/33.png)

### 4.1 查看容器启动状态，以及日志反馈

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/34.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/35.png)

## 5. 制作dubbo消费者的流水线任务

### 5.1 创建一个消费者的流水线

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/36.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/37.png)

### 5.2 添加相关参数

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/38.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/39.png)

### 5.3 继续添加下一阶段

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/40.png)

### 5.4 添加Jenkins流水线参数，使用变量调用前面流水线的参数配置

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/41.png)

### 5.5 回到流水线主页启动流水线

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/42.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/43.png)

### 5.6 尝试拉取利用jenkins成功拉取镜像

这一步仅是测试Jenkins是否可以正常使用，如果很有自信的话，可以一并配置好yaml清单的流水线任务，直接一步到位交付到k8s集群里面

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/44.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/45.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/46.png)

### 5.7 配置service集群资源

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/47.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/48.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/49.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/50.png)

### 5.8 查看控制台是否已经出现svc资源

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/51.png)

### 5.9 配置ingress资源

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/52.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/53.png)

### 5.9.1 控制台验证ingress资源

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/54.png)

## 6. 配置dubbo消费者的容器

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/55.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/56.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/57.png)

### 6.1 定义用户角色、管理的空间、项目的名称、以及该容器所用的镜像

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/58.png)

### 6.2 配置副本数量

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/59.png)

### 6.3 关联service集群

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/60.png)

### 6.4 定义容器所用的镜像

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/61.png)

### 6.5 定义容器的环境变量，然后保存退出

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/62.png)

### 6.6 修改资源清单

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/63.png)

```sh
            "imageId": "harbor.od.com/${ parameters.image_name }:${ parameters.git_ver }_${ parameters.add_tag }",
            "registry": "harbor.od.com",
            "repository": "${ parameters.image_name }",
            "tag": "${ parameters.git_ver }_${ parameters.add_tag }"
```

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/64.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/65.png)

## 7. 启动dubbo消费者

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/66.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/67.png)

![](/images/posts/Linux-Kubernetes/spinnaker/使用spinnaker部署dubbo服务/68.png)

