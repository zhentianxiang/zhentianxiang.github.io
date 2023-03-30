---
layout: post
title: Linux-Kubernetes-21-解释Prometheus配置文件
date: 2021-05-10
tags: 实战-Kubernetes
---

## 解释Prometheus配置文件

![](/images/posts/Linux-Kubernetes/Prometheus监控/11.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/12.png)

![](/images/posts/Linux-Kubernetes/Prometheus监控/13.png)

首先要说的就是，有多少个[targets]，配置文件中就有多少个[- job_name:]

而且在一段配置里只有ETCD用的是静态配置，其它全是自动发现，如果在生产上运用这个配置文件，只需要修改这个静态地址

```sh
- job_name: etcd
  honor_timestamps: true
  scrape_interval: 15s
  scrape_timeout: 10s
  metrics_path: /metrics
  scheme: https
  static_configs:
  - targets:
    - 10.0.0.200:2379
    - 10.0.0.21:2379
    - 10.0.0.22:2379
  tls_config:
    ca_file: /data/etc/ca.pem
    cert_file: /data/etc/client.pem
    key_file: /data/etc/client-key.pem
    insecure_skip_verify: false
```

![](/images/posts/Linux-Kubernetes/Prometheus监控/14.png)