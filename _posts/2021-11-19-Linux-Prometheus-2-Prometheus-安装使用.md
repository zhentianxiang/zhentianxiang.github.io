---
layout: post
title: Linux-Prometheus-2-Prometheus-安装使用
date: 2021-11-20
tags: Linux-Prometheus
---

## Prometheus

### 1. 服务端的安装

[GitHub官网地址](https://github.com/prometheus/prometheus/releases)

```sh
[root@tianxiang src]# ls
prometheus-2.2.0.linux-amd64.tar.gz
[root@tianxiang src]# tar xvf prometheus-2.2.0.linux-amd64.tar.gz
[root@tianxiang src]# cd prometheus-2.2.0.linux-amd64/
[root@tianxiang prometheus-2.2.0.linux-amd64]# ls
console_libraries  consoles  LICENSE  NOTICE  prometheus  prometheus.yml  promtool
[root@tianxiang prometheus-2.2.0.linux-amd64]# yum -y install screen
[root@tianxiang prometheus-2.2.0.linux-amd64]# screen #回车
[root@tianxiang prometheus-2.2.0.linux-amd64]# ./prometheus  #然后CTRL+AD切到后端
[root@tianxiang prometheus-2.2.0.linux-amd64]# netstat -lntp |grep 9090
tcp6       0      0 :::9090                 :::*                    LISTEN      27574/./prometheus
[root@tianxiang prometheus-2.2.0.linux-amd64]# screen -ls
[root@tianxiang prometheus-2.2.0.linux-amd64]# screen -r 27454 #切到前端
```

当然也可以配置systemd启动服务
```sh
[root@tianxiang prometheus-2.2.0.linux-amd64]# cat > /etc/systemd/system/prometheus.service <<EOF
[Unit]
Description=Prometheus Monitoring system
Documentation=Prometheus Monitoring system

[service]
ExecStart=/usr/local/src/prometheus-2.2.0.linux-amd64/prometheus \
  --config.file /usr/local/src/prometheus-2.2.0.linux-amd64/prometheus.yml \
  --web.listen-address=:9090

[Install]
WantedBy=multi-user.target
EOF
```
### 2. 服务端配置文件写法

```sh

[root@tianxiang prometheus-2.2.0.linux-amd64]# cat prometheus.yml

# my global config
global:
  scrape_interval:     15s # 多久收集一次数据
  evaluation_interval: 15s #  对于监控规格评估的时间定义，如：我们设置当内存使用量>70%时，发出报警rule规则，那么在这个30秒的配置情况下就是以30秒进行判断是不是达到了要报警的阈值
  scrape_timeout: 10s  # 每次收集数据的超时时间
# Alertmanager相关的配置
alerting:
  alertmanagers:
  - static_configs:
    - targets:
      # - alertmanager:9093

rule_files:      #报警规则相关配置文件
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:   #抓取数据的配置
  - job_name: 'prometheus'     #定义一个监控项的名称
    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.
    static_configs:   #定义监控项为静态发现服务
      - targets: ['localhost:9090']     #被定义的监控项

  - job_name: 'node_exporter'

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    static_configs:
      - targets: ['localhost:9100']
```

[GitHub官网地址](https://github.com/prometheus/node_exporter/releases)

### 3. exportter安装

```sh
[root@tianxiang src]# tar xvf node_exporter-1.3.0.linux-amd64.tar.gz && cd node_exporter-1.3.0.linux-amd64
[root@tianxiang node_exporter-1.3.0.linux-amd64]# screen #回车
[root@tianxiang node_exporter-1.3.0.linux-amd64]# ./node_exporter  #然后CTRL+AD切到钱前端
[root@tianxiang node_exporter-1.3.0.linux-amd64]# netstat -lntp |grep 9100
tcp6       0      0 :::9100                 :::*                    LISTEN      29249/./node_export
[root@tianxiang node_exporter-1.3.0.linux-amd64]# curl 127.0.0.1:9100/metrics
# HELP go_gc_duration_seconds A summary of the pause duration of garbage collection cycles.
# TYPE go_gc_duration_seconds summary
go_gc_duration_seconds{quantile="0"} 2.4744e-05
go_gc_duration_seconds{quantile="0.25"} 6.5975e-05
go_gc_duration_seconds{quantile="0.5"} 7.1639e-05
go_gc_duration_seconds{quantile="0.75"} 8.4686e-05
go_gc_duration_seconds{quantile="1"} 0.000631765
go_gc_duration_seconds_sum 0.020127063
go_gc_duration_seconds_count 254
...........................
```

### 4. pushgateway安装

[GitHub官网地址](https://github.com/prometheus/pushgateway/releases/)

同样也是直接运行服务即可

```sh
[root@tianxiang src]# wget https://github.com/prometheus/pushgateway/releases/download/v1.4.2/pushgateway-1.4.2.linux-amd64.tar.gz
[root@tianxiang src]# tar xf pushgateway-1.4.2.linux-amd64.tar.gz
[root@tianxiang src]# cd pushgateway-1.4.2.linux-amd64/
[root@tianxiang pushgateway-1.4.2.linux-amd64]# screen
[root@tianxiang pushgateway-1.4.2.linux-amd64]# ./pushgateway  #然后CTRL+AD切到前端
[root@tianxiang pushgateway-1.4.2.linux-amd64]# netstat -lntp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      1366/nginx: master  
tcp        0      0 0.0.0.0:8080            0.0.0.0:*               LISTEN      1366/nginx: master  
tcp        0      0 127.0.0.1:25            0.0.0.0:*               LISTEN      1268/master         
tcp        0      0 0.0.0.0:443             0.0.0.0:*               LISTEN      1366/nginx: master  
tcp        0      0 0.0.0.0:4000            0.0.0.0:*               LISTEN      21248/ruby /usr/loc
tcp        0      0 0.0.0.0:8522            0.0.0.0:*               LISTEN      1297/sshd           
tcp6       0      0 ::1:25                  :::*                    LISTEN      1268/master         
tcp6       0      0 :::9090                 :::*                    LISTEN      17761/./prometheus  
tcp6       0      0 :::9091                 :::*                    LISTEN      17375/./pushgateway
tcp6       0      0 :::8522                 :::*                    LISTEN      1297/sshd           
tcp6       0      0 :::9100                 :::*                    LISTEN      17617/./node_export
tcp6       0      0 :::781                  :::*                    LISTEN      1347/./bcm-agent
```

配置prometheus配置文件

```sh
[root@tianxiang pushgateway-1.4.2.linux-amd64]# cd ../prometheus-2.2.0.linux-amd64/
[root@tianxiang prometheus-2.2.0.linux-amd64]# vim prometheus.yml
- job_name: 'pushgateway'

  static_configs:
    - targets: ['localhost:9091']
```
