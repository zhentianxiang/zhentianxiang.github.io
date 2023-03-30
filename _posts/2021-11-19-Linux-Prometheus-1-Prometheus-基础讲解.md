---
layout: post
title: Linux-Prometheus-1-Prometheus-基础讲解
date: 2021-11-19
tags: Linux-Prometheus
---

## Prometheus

### 1. Prome配置文件讲解

```shell
# 全局配置
global:
  scrape_interval:   15s  # 多久收集一次数据
  evaluation_interval: 30s  # 对于监控规格评估的时间定义，如：我们设置当内存使用量>70%时，发出报警rule规则，那么在这个30秒的配置情况下就是以30秒进行判断是不是达到了要报警的阈值
  scrape_timeout:   10s  # 每次收集数据的超时时间

alerting:    # Alertmanager相关的配置
  alertmanagers:
  - scheme: https
    static_configs:
    - targets:
      - "1.2.3.4:9093"
      - "1.2.3.5:9093"
      - "1.2.3.6:9093"
rule_files:  #报警规则
  - "first_rules.yml"
  - "second_rules.yml"
scrape_configs:  #抓取数据的配置
  - job_name: 'prometheus'  #定义一个监控项的名称
    static_configs:    #定义服务静态发现
      - targets: [ 'prometheus.server:9090','prometheus.server:9100' ]      #定义被监控的监控项
```



### 2. PromQL语句

示例一

```sh
(1-((sum(increase(node_cpu{mode="idle"}[1m]))by(instance)) /(sum(increase(node_cpu[1m]))by(instance))))* 100
```

示例二

Linux系统开机后，CPU开始进入工作状态，每一个不同状态的CPU使用时间都从零开开始，而我们在被监控客户端安装的node_exporter会抓取并返回给我们常用的八种CPU状态的累计时间数值

用户态CPU通常是占用整个CPU状态最多的类型，当然也有个别的情况，内核态或者IO等待占用的更多

12:00开机后—到12:30截止

这30分钟的过程中(忽略CPU核数，当作为1核)

- CPU被使⽤在⽤户态 的时间⼀共是8分钟

- CPU被使⽤在内核态的时间 ⼀共是1.5分钟

- CPU被使⽤在IO等待状态 的时间⼀共是0.5分钟

- CPU被使⽤在Idle（空闲状态） 的时间 ⼀共是20分钟

- (idle空闲状态的CPU时间 其实就是CPU处于没事⼉⼲的时间 )

- CPU被使⽤在其他⼏个状态的时间是0

 上⾯的这些数据 为了我们计算CPU在这段30mins 时间的使⽤率提供了单位数据基础CPU的使⽤率 = （所有⾮空闲状态的CPU使⽤时间总和 ）/  （所有状态CPU时间的总和）有了这个公式后咱们就可以很⾃然的 得出如下的计算公式

```sh
(user(8mins) + sys(1.5mins) + iowa(0.5min) + 0 + 0 + 0 + 0 ) / (30mins) = 10分钟 / 30分钟= 30%
#或者
idle(20mins)/(30mins)   # 空闲20分钟/30分钟
# 最后
100%-70%=30%  #得30%cpu使用率
```

所以针对于30分钟内，CPU使用率就为30%

### 3 函数

- increase() 函数

increase 函数在Prometheus中，是用来针对Counter这种持续增长的数值，截取其中一段时间的增量

```sh
#这样就获取了CPU总使用时间在1分钟内的使用时间
increase(node_cpu[1m])
```
实际工作中的CPU大多都是多核的，所以查看的时候监控曲线图非常混乱

- sum() 函数

sum 就如字面意思一样，起到对value加合的作用

```sh
#求所有cpu核数一分钟内的使用时间
sum(increase(node_cpu[1m]))
```

**拆分公式**

然后就可以拆分上面的那个复杂公式了

1. node_cpu 等于全部CPU使用时间

2. node_cpu{mode="idle"} 过滤空闲CPU使用时间

3. increase(node_cpu{mode="idle"}[1m]) 取1分钟内空闲CPU的使用时间

4. sum(increase(node_cpu{mode="idle"}[1m])) 把所有核数的空闲CPU使用时间加到一起

那么现在问题又来了，如果从监控图标上看，现在的情况是一条曲线图，我们并不知道哪台是那台机器的监控数据

其实这就是由于sum()这个函数导致的，默认情况下会把所有的数据全部加合到一起了

那么现在就再引出一个函数by(instance)

- by(instance) 函数

这个函数可以把sum加合到一起的数值按照指定的一个方式进行一层的拆分

instance代表的是机器名

意思就是把sum函数中服务器加合的这个动作强行拆分出来

```sh
#最终就是每台机器1分钟内的空闲CPU使用时间
sum(increase(node_cpu{mode="idle"}[1m])) by(instance)
```

如何算出每台机器CPU1分钟内的使用率呢？

```sh
#每台机器1分钟内的空闲CPU使用时间除以每台机器1分钟内的全部CPU使用时间
sum(increase(node_cpu{mode="idle"}[1m])) by(instance) / sum(instance(node_cpu[1m])) by(instance)
```
至此，每台机器1分钟内的空闲CPU使用率就得出来了

但是！我们要的应该是非空闲CPU的使用率，也就是CPU的1分钟内的使用率是多少

```sh
# 最后使用1- X 100 得出CPU的使用率的百分比
(1-((sum(increase(node_cpu{mode="idle"}[1m])) by(instance)) / (sum(instance(node_cpu[1m])) by(instance)))) *100
```
关于公式中括号的意思可以自己揣摩，这里文字不容易描述

**举一反三**

```sh
# 每台机器所有用户态1分钟的空闲CPU使用时间除以没每台机器全部CPU1分钟内的使用时间就等于每台机器空闲用户态的1分钟内CPU的使用时间的使用率
sum(increase(node_cpu{mode="user"[1m]})) by (instance) / sum(increase(node_cpu[1m])) by (instance)
# 求百分比
(1-((sum(increase(node_cpu{mode="user"[1m]})) by (instance)) / (sum(increase(node_cpu[1m])) by (instance)))) *100
```

 **标签**

> 标签也是来自于采集数据，可以自定义也可以直接使用，默认的exporter提供的标签项。命令行的查询在原始输入的基础上先使用{}进行第一步过滤`count_netstat_wait_connections{exported_instance="log"}`，其作用就是先过滤个大致范围，过滤除了精准匹配还有模糊匹配`count_netstat_wait_connections{exported_instance=~"log"}`，除了精准和模糊匹配还有按要求匹配，比如`count_netstat_wait_connections{exported_instance=~"log"} > 100`，过滤大于100的坐标值

 - rate 函数

> 这个函数可以说是Prometheus提供的最重要的函数，rate()函数是专门配合counter类型数据使用的函数，他的功能是按照设置一个时间段，取counter在这个时间段中的平均**每秒**的增量
>
>当然还有一个函数和rate特别相似，那就是iate
>
> irate和rate都会用于计算某个指标在一定时间间隔内的变化速率。但是它们的计算方法有所不同：irate取的是在指定时间范围内的最近两个数据点来算速率，而rate会取指定时间范围内所有数据点，算出一组速率，然后取平均值作为结果。

 ```sh
 # 示例：1分钟内每秒的数据量
 rate(node_network_receive_bytes[1m])
 ```
 > 强调：以后再使用任何counter数据类型的时候，永远记得别的先不做，先给他加上一个rate()或者increase()

 比如从23:45开始到23:50，比如累积量从40000->40100，1分钟增加了100bytes(假设)

 加入rate(*[1m])之后，这个函数会把100bytes除以1分钟=60秒，就是100bytes➗60秒≈1.6666bytes，rate就是这样计算的每秒的数据

 > increase函数和rate的概念及其使用方法非常相似，rate(*[1m])是取一段时间增量的平均每秒数量，而increase(*[1m])取的是一段时间内增量的总量，说白了就是rate用的是除以，increase用的是加合

 - topk()

定义：取前几位最高的key值

gauge类型使用如下
```sh
# 取前三位的值，如果key值是4562233，那么取出的结果就是456
topk(3,count_netstat_wait_connections)
```

counter类型如下
```sh
# 同样下面的这个就是20分钟内的
topk(3,rate(count_netstat_wait_connections[20m]))
```

> topk因为对于每一个时间点都只是去前三高的数值，那么必然会造成单个机器的采集数据不连贯
>
> 因为：比如server01在这1分钟的wait_connection数量排在所有机器的前三，到了下一分钟可能就排到点滴了，自然曲线就会终端，实际使用的时候一般用topk()函数进行瞬时报警，而不是为了观察曲线图

- count()

定义：把数值符合条件的输出数目进行加合

举例：找出当前或者历史的当TCP等待数值大于200的机器数量

```sh
count(count_netstat_wait_connections > 200)
```

> 一般用它count进行一些模糊的监控判断，比如说企业中有100台机器，那么只有10台机器CPU高于80%的时候，这个时候不需要报警，但是当符合80%CPU的机器数量，超过30台的时候那么就会触发报警count()
