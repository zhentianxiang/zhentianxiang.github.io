---
layout: post
title: Linux-Kubernetes-25-配置alert告警插件
date: 2021-05-10
tags: 实战-Kubernetes
---

## 配置alert告警插件

### 1.准备镜像

```sh
[root@host0-200 plugins]# docker pull docker.io/prom/alertmanager:v0.14.0
v0.14.0: Pulling from prom/alertmanager
Image docker.io/prom/alertmanager:v0.14.0 uses outdated schema1 manifest format. Please upgrade to a schema2 image for better future compatibility. More information at https://docs.docker.com/registry/spec/deprecated-schema-v1/
65fc92611f38: Pull complete 
439b527af350: Pull complete 
a3ed95caeb02: Pull complete 
f65042d2fee2: Pull complete 
282a28c3341d: Pull complete 
f36e0769f073: Pull complete 
Digest: sha256:2ff45fb2704a387347aa34f154f450d4ad86a8f47bcf72437761267ebdf45efb
Status: Downloaded newer image for prom/alertmanager:v0.14.0
[root@host0-200 plugins]# docker tag prom/alertmanager:v0.14.0 harbor.od.com/infra/alertmanager:v0.14.0
[root@host0-200 plugins]# docker push harbor.od.com/infra/alertmanager:v0.14.0
The push refers to repository [harbor.od.com/infra/alertmanager]
5f70bf18a086: Mounted from infra/dubbo-monitor 
b5abc4736d3f: Pushed 
6b961451fcb0: Pushed 
30d4e7b232e4: Pushed 
68d1a8b41cc0: Pushed 
4febd3792a1f: Pushed 
v0.14.0: digest: sha256:77a5439a03d76ba275b9a6e004113252ec4ce3336cf850a274a637090858a5ed size: 2603
```

### 2.准备资源配置清单

```sh
[root@host0-200 plugins]# mkdir -pv /data/k8s-yaml/alertmanager && cd /data/k8s-yaml/alertmanager
mkdir: 已创建目录 "/data/k8s-yaml/alertmanager"
```

- vim cm.yaml

```sh
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: infra
data:
  config.yml: |-
    global:
      # 在没有报警的情况下声明为已解决的时间
      resolve_timeout: 5m
      # 配置邮件发送信息
      smtp_smarthost: 'smtp.163.com:25'
      smtp_from: 'xiahediyijun@163.com'
      smtp_auth_username: 'xiahediyijun@163.com'
      smtp_auth_password: '18332825309'
      smtp_require_tls: false
    # 所有报警信息进入后的根路由，用来设置报警的分发策略
    route:
      # 这里的标签列表是接收到报警信息后的重新分组标签，例如，接收到的报警信息里面有许多具有 cluster=A 和 alertname=LatncyHigh 这样的标签的报警信息将会批量被聚合到一个分组里面
      group_by: ['alertname', 'cluster']
      # 当一个新的报警分组被创建后，需要等待至少group_wait时间来初始化通知，这种方式可以确保您能有足够的时间为同一分组来获取多个警报，然后一起触发这个报警信息。
      group_wait: 30s

      # 当第一个报警发送后，等待'group_interval'时间来发送新的一组报警信息。
      group_interval: 5m

      # 如果一个报警信息已经发送成功了，等待'repeat_interval'时间来重新发送他们
      repeat_interval: 5m

      # 默认的receiver：如果一个报警没有被一个route匹配，则发送给默认的接收器
      receiver: default

    receivers:
    - name: 'default'
      email_configs:
      - to: '2099637909@qq.com'
        send_resolved: true
```

- vim dp.yaml

```sh
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: alertmanager
  namespace: infra
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: harbor.od.com/infra/alertmanager:v0.14.0
        args:
          - "--config.file=/etc/alertmanager/config.yml"
          - "--storage.path=/alertmanager"
        ports:
        - name: alertmanager
          containerPort: 9093
        volumeMounts:
        - name: alertmanager-cm
          mountPath: /etc/alertmanager
      volumes:
      - name: alertmanager-cm
        configMap:
          name: alertmanager-config
      imagePullSecrets:
      - name: harbor
```

- vim svc.yaml

```sh
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: infra
spec:
  selector: 
    app: alertmanager
  ports:
    - port: 80
      targetPort: 9093
```

### 3.应用资源配置清单

```sh
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/alertmanager/cm.yaml
configmap/alertmanager-config created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/alertmanager/dp.yaml
deployment.extensions/alertmanager created
[root@host0-22 ~]# kubectl apply -f http://k8s-yaml.od.com/alertmanager/svc.yaml
service/alertmanager created
```

![](/images/posts/Linux-Kubernetes/Prometheus监控/56.png)

### 4.基础报警规则

```sh
[root@host0-200 plugins]# vim /data/nfs-volume/prometheus/etc/rules.yml
groups:
- name: hostStatsAlert
  rules:
  - alert: hostCpuUsageAlert
    expr: sum(avg without (cpu)(irate(node_cpu{mode!='idle'}[5m]))) by (instance) > 0.85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "{{ $labels.instance }} CPU usage above 85% (current value: {{ $value }}%)"
  - alert: hostMemUsageAlert
    expr: (node_memory_MemTotal - node_memory_MemAvailable)/node_memory_MemTotal > 0.85
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "{{ $labels.instance }} MEM usage above 85% (current value: {{ $value }}%)"
  - alert: OutOfInodes
    expr: node_filesystem_free{fstype="overlay",mountpoint ="/"} / node_filesystem_size{fstype="overlay",mountpoint ="/"} * 100 < 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Out of inodes (instance {{ $labels.instance }})"
      description: "Disk is almost running out of available inodes (< 10% left) (current value: {{ $value }})"
  - alert: OutOfDiskSpace
    expr: node_filesystem_free{fstype="overlay",mountpoint ="/rootfs"} / node_filesystem_size{fstype="overlay",mountpoint ="/rootfs"} * 100 < 10
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Out of disk space (instance {{ $labels.instance }})"
      description: "Disk is almost full (< 10% left) (current value: {{ $value }})"
  - alert: UnusualNetworkThroughputIn
    expr: sum by (instance) (irate(node_network_receive_bytes[2m])) / 1024 / 1024 > 100
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Unusual network throughput in (instance {{ $labels.instance }})"
      description: "Host network interfaces are probably receiving too much data (> 100 MB/s) (current value: {{ $value }})"
  - alert: UnusualNetworkThroughputOut
    expr: sum by (instance) (irate(node_network_transmit_bytes[2m])) / 1024 / 1024 > 100
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Unusual network throughput out (instance {{ $labels.instance }})"
      description: "Host network interfaces are probably sending too much data (> 100 MB/s) (current value: {{ $value }})"
  - alert: UnusualDiskReadRate
    expr: sum by (instance) (irate(node_disk_bytes_read[2m])) / 1024 / 1024 > 50
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Unusual disk read rate (instance {{ $labels.instance }})"
      description: "Disk is probably reading too much data (> 50 MB/s) (current value: {{ $value }})"
  - alert: UnusualDiskWriteRate
    expr: sum by (instance) (irate(node_disk_bytes_written[2m])) / 1024 / 1024 > 50
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Unusual disk write rate (instance {{ $labels.instance }})"
      description: "Disk is probably writing too much data (> 50 MB/s) (current value: {{ $value }})"
  - alert: UnusualDiskReadLatency
    expr: rate(node_disk_read_time_ms[1m]) / rate(node_disk_reads_completed[1m]) > 100
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Unusual disk read latency (instance {{ $labels.instance }})"
      description: "Disk latency is growing (read operations > 100ms) (current value: {{ $value }})"
  - alert: UnusualDiskWriteLatency
    expr: rate(node_disk_write_time_ms[1m]) / rate(node_disk_writes_completedl[1m]) > 100
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Unusual disk write latency (instance {{ $labels.instance }})"
      description: "Disk latency is growing (write operations > 100ms) (current value: {{ $value }})"
- name: http_status
  rules:
  - alert: ProbeFailed
    expr: probe_success == 0
    for: 1m
    labels:
      severity: error
    annotations:
      summary: "Probe failed (instance {{ $labels.instance }})"
      description: "Probe failed (current value: {{ $value }})"
  - alert: StatusCode
    expr: probe_http_status_code <= 199 OR probe_http_status_code >= 400
    for: 1m
    labels:
      severity: error
    annotations:
      summary: "Status Code (instance {{ $labels.instance }})"
      description: "HTTP status code is not 200-399 (current value: {{ $value }})"
  - alert: SslCertificateWillExpireSoon
    expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 30
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "SSL certificate will expire soon (instance {{ $labels.instance }})"
      description: "SSL certificate expires in 30 days (current value: {{ $value }})"
  - alert: SslCertificateHasExpired
    expr: probe_ssl_earliest_cert_expiry - time()  <= 0
    for: 5m
    labels:
      severity: error
    annotations:
      summary: "SSL certificate has expired (instance {{ $labels.instance }})"
      description: "SSL certificate has expired already (current value: {{ $value }})"
  - alert: BlackboxSlowPing
    expr: probe_icmp_duration_seconds > 2
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Blackbox slow ping (instance {{ $labels.instance }})"
      description: "Blackbox ping took more than 2s (current value: {{ $value }})"
  - alert: BlackboxSlowRequests
    expr: probe_http_duration_seconds > 2 
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Blackbox slow requests (instance {{ $labels.instance }})"
      description: "Blackbox request took more than 2s (current value: {{ $value }})"
  - alert: PodCpuUsagePercent
    expr: sum(sum(label_replace(irate(container_cpu_usage_seconds_total[1m]),"pod","$1","container_label_io_kubernetes_pod_name", "(.*)"))by(pod) / on(pod) group_right kube_pod_container_resource_limits_cpu_cores *100 )by(container,namespace,node,pod,severity) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Pod cpu usage percent has exceeded 80% (current value: {{ $value }}%)"
```

### 4.在prometheus.yml中添加配置

```sh
[root@host0-200 plugins]# vim /data/nfs-volume/prometheus/etc/prometheus.yml
alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager"]
rule_files:
 - "/data/etc/rules.yml"
```

![](/images/posts/Linux-Kubernetes/Prometheus监控/57.png)

### 5.重载服务

因为pod在21机器上面，所以

```sh
[root@host0-21 ~]# curl -X POST http://prometheus.od.com/-/reload
```

> 以上这些就是我们的告警规则

![](/images/posts/Linux-Kubernetes/Prometheus监控/58.png)

> 测试告警：
>
> 把app命名空间里的dubbo-demo-service给停掉

![](/images/posts/Linux-Kubernetes/Prometheus监控/59.png)

>  看下blackbox里的信息：

![](/images/posts/Linux-Kubernetes/Prometheus监控/60.png)

> 看下alert：

![](/images/posts/Linux-Kubernetes/Prometheus监控/61.png)

> 红色的时候就开会发邮件告警：

![](/images/posts/Linux-Kubernetes/Prometheus监控/62.png)

> 已经收到告警了，后续上生产，还会更新如何添加微信、钉钉、短信告警。
>
> 如果需要自己定制告警规则和告警内容，需要研究一下promql，自己修改配置文件。

![](/images/posts/Linux-Kubernetes/Prometheus监控/63.png)