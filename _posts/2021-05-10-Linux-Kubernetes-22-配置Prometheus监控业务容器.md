---
layout: post
title: Linux-Kubernetes-22-配置Prometheus监控业务容器
date: 2021-05-10
tags: 实战-Kubernetes
---

## 配置Prometheus监控业务容器

### 1.监控traefik

> 修改traefik的yaml：
>
> 从dashboard里找到traefik的yaml，跟labels同级添加annotations
>
> 重启pod使其监控生效

```sh
"annotations": {
  "prometheus_io_scheme": "traefik",
  "prometheus_io_path": "/metrics",
  "prometheus_io_port": "8080"
}
```

![](/images/posts/Linux-Kubernetes/Prometheus监控/15.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/16.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/17.png)

如果重启遇到问题，那就把docker重启一下

### 2.查看Prometheus的traefik监控项

![](/images/posts/Linux-Kubernetes/Prometheus监控/18.png)

### 3.blackbox

> 这个是检测容器内服务存活性的，也就是端口健康状态检查，分为tcp和http
>
> 首先准备两个服务，将dubbo-demo-service和dubbo-demo-consumer都调整为使用master镜像，不依赖apollo的（节省资源）
>
> 等两个服务起来以后，首先在dubbo-demo-service资源中添加一个TCP的annotation：

```sh
"annotations": {
  "blackbox_port": "20880",
  "blackbox_scheme": "tcp"
}
```

![](/images/posts/Linux-Kubernetes/Prometheus监控/19.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/20.png)



![](/images/posts/Linux-Kubernetes/Prometheus监控/21.png)

### 4.查看Prometheus监控容器项信息

![](/images/posts/Linux-Kubernetes/Prometheus监控/23.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/24.png)

> 容器的存活是由BlackboxExporter来做的，Prometheus是定期的去抓BlackboxExporter，你只要去配置一个以tcp监控pod的存活性，
>
> 那么它就会生成一个Endpoint，Prometheus去请求自动发现的业务容器，帮你请求的是BlackboxExporter，他把你这个容器的地址
>
> 当作参数传给BlackboxExporter，然后BlackboxExporter再去curl业务容器，curl成功发送给Prometheus，然后记到数据库里。

### 5.接下来在dubbo-demo-consumer资源中添加一个HTTP的annotation

```sh
"annotations": {
  "blackbox_path": "/hello?name=health",
  "blackbox_port": "8080",
  "blackbox_scheme": "http"
}
```
![](/images/posts/Linux-Kubernetes/Prometheus监控/26.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/27.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/28.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/29.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/30.png)

### 6.接下来添加监控jvm信息的annotation：

```sh
"annotations": {
  "prometheus_io_path": "/",
  "prometheus_io_port": "12346",
  "prometheus_io_scrape": "true"
}
```

dubbo-demo-service和dubbo-demo-consumer都添加：

![](/images/posts/Linux-Kubernetes/Prometheus监控/54.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/55.png)
