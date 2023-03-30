---
layout: post
title: 缓存与加速07-Redis主从sentinel集群
date: 2020-12-09
tags: Linux-缓存与加速
music-id: 5257205
---

## 一、redis之主从、哨兵、集群介绍

 Redis高可用性，因为redis的存储方式是存储于内存中，所以redis在进行数据查询操作时，效率非常的快；因为是存储于内存，为了使数据不丢失，通过RDB或是AOF的方式进行持久化存储

> 但是这边还有一个问题如果说这个主机突然间出现故障，数据全部丢失，那这个时候，可能存储于数据库、redis中的数据就都完全都丢；为了说解决这个问题，所以我们可能衍生出以下的一些解决方式；

### 1. 主从架构

redis多机器部署时，这些机器节点会被分成两类，一类是主节点（master节点），一类是从节点（slave节点）。一般主节点可以进行读、写操作，而从节点只能进行读操作。同时由于主节点可以写，数据会发生变化，当主节点的数据发生变化时，会将变化的数据同步给从节点，这样从节点的数据就可以和主节点的数据保持一致了。一个主节点可以有多个从节点，但是一个从节点会只会有一个主节点，也就是所谓的一主多从结构。

Redis 的 主从复制 模式下，一旦 主节点 由于故障不能提供服务，需要手动将 从节点 晋升为 主节点，同时还要通知 客户端 更新 主节点地址，这种故障处理方式从一定程度上是无法接受的。

例如我们有两台服务器去存储我们的数据，一台为主节点，一台是从节点；主节点是有读写的功能，可以对数据进行操作，但是从的那台只有读取的功能，没有对数据操作的功能；并且两台机子上面的数据都是一致的
如果我们的主的这台机子突然间故障无法使用了，那这个时候，我们的从节点对数据是无法进行操作的，这个时候就需要我们人为的将这台从的机子设置为主机子

![](/images/posts/缓存与加速/缓存与加速-07-Redis主从sentinel集群/1.png)

该图只是最简单的一种主从结构方式，所有的 Slave 节点都挂在 Master 节点上

- 优点： Slave 节点与 Master 节点的数据延迟较小；
- 缺点：如果 Slave 节点数量很多，Master 同步一次数据的耗时就很长。

还有一种主从结构就是 Master 下面只挂一个 Slave 节点，其他的 Slave 节点挂在这个 Slave 节点下面，这样，Master 节点每次只需要把数据同步给它下面的那一个 Slave 节点即可，后续 Slave 节点的数据同步由这个 Slave 节点完成。

- 优点：降低了 Master 节点做数据同步的压力
- 缺点：导致 Slave 节点与 Master 节点数据不一致的延迟更高。



### 2. 主从架构原理

主从模式的核心就是 Master 节点与 Slave 节点之间的数据同步。需要注意的是，Redis 和大部分中间件的主从模式中的数据同步都是由 Slave 节点主动发起的，原因是主从模式中只有一个 Master 节点，剩余的全是 Slave 节点，如果由 Master 节点主动推送数据到各个 Slave 节点

- 首先，维护成本太大，Master 节点上要维护所有 Slave 的地址信息，而且在增加 Slave 节点的时候，也要同步维护到 Master 上，这样 Master 才能将数据同步到所有的 Slave 上面；
- 其次，Master 性能受影响，节点之间同步数据肯定要通过网络传输数据，由 Master 节点建立所有 Slave 节点的连接会对 Master 的性能产生较大影响。
  而由 Slave 发起数据同步则避免了上述问题，只需在每个 Slave 中维护一个 Master 的地址即可。

> 1. Slave 发送 sync 命令到 Master
> 2. Master 收到 sync 之后，执行bgsave，生成 RDB 全量文件
> 3. Master 把 Slave 的写命令记录到缓存
> 4. bgsave 执行完毕之后，发送 RDB 文件到 Slave，Slave 执行
> 5. Master 发送缓存中的写命令到 Slave，Slave 执行

![](/images/posts/缓存与加速/缓存与加速-07-Redis主从sentinel集群/2.png)

### 3. 哨兵模式

​        主从模式下，当主服务器宕机后，需要手动把一台从服务器切换为主服务器，这就需要人工干预，费事费力，还会造成一段时间内服务不可用。这种方式并不推荐，实际生产中，我们优先考虑哨兵模式。这种模式下，master宕机，哨兵会自动选举master并将其他的slave指向新的master。

首先 Redis 提供了哨兵的命令，哨兵是一个独立的进程，作为进程，它独立运行。其原理是哨兵通过发送命令，等待 Redis 服务器响应，从而监控运行的多个 Redis 实例。因此哨兵模式具备了自动故障转移、集群监控、消息通知等功能。

![](/images/posts/缓存与加速/缓存与加速-07-Redis主从sentinel集群/3.png)

### 4. Redis 哨兵模式工作过程

哨兵可以同时监视多个主从服务器，并且在被监视的 Master 下线时，自动将某个 Slave 提升为 Master，然后由新的 Master 继续接收命令。整个过程如下：

初始化 sentinel，将普通的 redis 代码替换成 sentinel 专用代码
初始化 Masters 字典和服务器信息，服务器信息主要保存 ip:port，并记录实例的地址和 ID
创建和 Master 的两个连接，命令连接和订阅连接，并且订阅 sentinel:hello 频道
每隔 10 秒向 Master 发送 info 命令，获取 Master 和它下面所有 Slave 的当前信息
当发现 Master 有新的 Slave 之后，sentinel 和新的 Slave同样建立两个连接，同时每个10秒发送 info 命令，更新 Master 信息
sentinel 每隔1秒向所有服务器发送 ping 命令，如果某台服务器在配置的响应时间内连续返回无效回复，将会被标记为下线状态
选举出领头 sentinel，领头 sentinel 需要半数以上的 sentinel 同意
领 头sentinel 从已下线的的 Master 所有 Slave 中挑选一个，将其转换为 Master
让所有的 Slave 改为从新的 Master 复制数据
将原来的 Master 设置为新的 Master 的从服务器，当原来 Master 重新回复连接时，就变成了新 Master 的从服务器
其中，sentinel 会每隔 1 秒向所有实例（包括主从服务器和其他sentinel）发送 ping 命令，并且根据回复判断是否已经下线，这种方式叫做主观下线。当判断为主观下线时，就会向其他监视的 sentinel 询问，如果超过半数的投票认为已经是下线状态，则会标记为客观下线状态，同时触发故障转移。



### 3. 集群模式

Redis 的哨兵模式基本已经可以实现高可用，读写分离 ，但是在这种模式下每台 Redis 服务器都存储相同的数据，很浪费内存，所以在redis3.0上加入了集群模式，实现了 Redis 的分布式存储，对数据进行分片，也就是说每台 Redis 节点上存储不同的内容；

**故障转移**

如果节点 A 向节点 B 发送 ping 消息，节点 B 没有在规定的时间内响应 pong，那么节点 A 会标记节点 B 为 pfail 疑似下线状态，同时把 B 的状态通过消息的形式发送给其他节点，如果超过半数以上的节点都标记 B 为 pfail 状态，B 就会被标记为 fail 下线状态，此时将会发生故障转移，优先从复制数据较多的从节点选择一个成为主节点，并且接管下线节点的 slot，整个过程和哨兵非常类似，都是基于 Raft 协议做选举。





## 二、一主多从+哨兵

### 1. 主从集群

![](/images/posts/缓存与加速/缓存与加速-07-Redis主从sentinel集群/4.png)

| IP地址   | 端口号 | 角色   |
| -------- | ------ | ------ |
| 11.0.1.3 | 6379   | master |
| 11.0.1.4 | 6379   | salve  |
| 11.0.1.5 | 6379   | slave  |

### 2. 编译安装 redis

```sh
[root@master src]# yum -y install make gcc
[root@master src]# wget http://download.redis.io/releases/redis-6.2.4.tar.gz
[root@master src]# tar xvf redis-6.2.4.tar.gz
[root@master src]# ls
redis-6.2.4  redis-6.2.4.tar.gz
[root@master src]# cd redis-6.2.4/
[root@master redis-6.2.4]# make -j4
    LINK redis-server
    INSTALL redis-sentinel
    INSTALL redis-check-rdb
    INSTALL redis-check-aof
    LINK redis-benchmark
    LINK redis-cli

Hint: It's a good idea to run 'make test' ;)

make[1]: 离开目录“/usr/local/src/redis-6.2.4/src”
[root@master redis-6.2.4]# cd src/
[root@master src]# make install
    CC Makefile.dep

Hint: It's a good idea to run 'make test' ;)

    INSTALL redis-server
    INSTALL redis-benchmark
    INSTALL redis-cli
```

由于有很多文件不需要，因此我们为了方便管理可以拷贝出一部分有用的文件

```sh
[root@master src]# mkdir -pv /usr/local/redis/{bin,db,etc,logs,tmp}
mkdir: 已创建目录 "/usr/local/redis"
mkdir: 已创建目录 "/usr/local/redis/bin"
mkdir: 已创建目录 "/usr/local/redis/db"
mkdir: 已创建目录 "/usr/local/redis/etc"
mkdir: 已创建目录 "/usr/local/redis/logs"
[root@master src]# cp redis-server redis-cli redis-sentinel redis-check-aof redis-check-rdb redis-benchmark /usr/local/redis/bin/
[root@master src]# cp ../redis.conf /usr/local/redis/etc/
[root@master src]# cp ../sentinel.onf /usr/local/redis/etc/
```

首先看一下redis.conf 配置文件中的各个参数，详解如下

```sh
# redis进程是否以守护进程的方式运行，yes为是，no为否(不以守护进程的方式运行会占用一个终端)。
daemonize no
# 指定redis进程的PID文件存放位置
pidfile /var/run/redis.pid
# redis进程的端口号
port 6379
#是否开启保护模式，默认开启。要是配置里没有指定bind和密码。开启该参数后，redis只会本地进行访问，拒绝外部访问。要是开启了密码和bind，可以开启。否则最好关闭设置为no。
protected-mode yes
# 绑定的主机地址
bind 127.0.0.1
# 客户端闲置多长时间后关闭连接，默认此参数为0即关闭此功能
timeout 300
# redis日志级别，可用的级别有debug.verbose.notice.warning
loglevel verbose
# log文件输出位置，如果进程以守护进程的方式运行，此处又将输出文件设置为stdout的话，就会将日志信息输出到/dev/null里面去了
logfile stdout
# 设置数据库的数量，默认为0可以使用select <dbid>命令在连接上指定数据库id
databases 16
# 指定在多少时间内刷新次数达到多少的时候会将数据同步到数据文件
save <seconds> <changes>
# 指定存储至本地数据库时是否压缩文件，默认为yes即启用存储
rdbcompression yes
# 指定本地数据库文件名
dbfilename dump.db
# 指定本地数据问就按存放位置
dir ./
# 指定当本机为slave服务时，设置master服务的IP地址及端口，在redis启动的时候他会自动跟master进行数据同步
replicaof <masterip> <masterport>
# 当master设置了密码保护时，slave服务连接master的密码
masterauth <master-password>
# 设置redis连接密码，如果配置了连接密码，客户端在连接redis是需要通过AUTH<password>命令提供密码，默认关闭
requirepass footbared
# 设置同一时间最大客户连接数，默认无限制。redis可以同时连接的客户端数为redis程序可以打开的最大文件描述符，如果设置 maxclients 0，表示不作限制。当客户端连接数到达限制时，Redis会关闭新的连接并向客户端返回 max number of clients reached 错误信息
maxclients 128
# 指定Redis最大内存限制，Redis在启动时会把数据加载到内存中，达到最大内存后，Redis会先尝试清除已到期或即将到期的Key。当此方法处理后，仍然到达最大内存设置，将无法再进行写入操作，但仍然可以进行读取操作。Redis新的vm机制，会把Key存放内存，Value会存放在swap区
maxmemory<bytes>
# 指定是否在每次更新操作后进行日志记录，Redis在默认情况下是异步的把数据写入磁盘，如果不开启，可能会在断电时导致一段时间内的数据丢失。因为redis本身同步数据文件是按上面save条件来同步的，所以有的数据会在一段时间内只存在于内存中。默认为no。
appendonly no
# 指定跟新日志文件名默认为appendonly.aof
appendfilename appendonly.aof
# 指定更新日志的条件，有三个可选参数 - no：表示等操作系统进行数据缓存同步到磁盘(快)，always：表示每次更新操作后手动调用fsync()将数据写到磁盘(慢，安全)， everysec：表示每秒同步一次(折衷，默认值)；
appendfsync everysec
```

### 3. master 配置

```sh
[root@master src]# cd /usr/local/redis/etc/
[root@master etc]# vim redis.conf
bind 0.0.0.0
port 6379
protected-mode no
daemonize yes
dir /usr/local/redis/db
logfile /usr/local/redis/logs/redis.log
requirepass redis123
masterauth redis123
```

> - bind：0.0.0.0
>   Redis 默认只允许本机访问，把 bind 修改为 0.0.0.0 表示允许所有远程访问。如果想指定限制访问，可设置对应的 ip。
>
> - port：6379
>   监听端口默认为6379，想改其他也行。
>
> - protected-mode：no
>   关闭保护模式，可以外部访问。
>
> - daemonize：yes
>   设置为后台启动。
>
> - pidfile：/var/run/redis_6379.pid
>
>   pid 守护进程
>
> - dir：/usr/local/redis/db
>
>   数据存放目录
>
> - logfile：/usr/local/redis/logs/redis.log
>   redis 日志文件
> - requirepass：redis123
>   设置 redis 连接密码。
> - masterauth：redis123
>   slave 服务连接 master 的密码。

启动服务

```sh
[root@master etc]# vim /usr/lib/systemd/system/redis.service

[Unit]
Description=redis-server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/redis/bin/redis-server /usr/local/redis/etc/redis.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target

[root@master etc]# systemctl enable redis --now
[root@master bin]# ./redis-cli -h 127.0.0.1 -p 6379
127.0.0.1:6379> info
NOAUTH Authentication required.
127.0.0.1:6379> AUTH redis123
OK
```

### 4. slave 配置

从机的配置和主机相似，相同的地方我就不再详解，不同的地方是需要使用`replicaof`指定主机（master）的IP地址和端口，需要注意的是老版本使用的是 slaveof，目前我使用的6.24版本要使用 replicaof ，如下

```sh
[root@slave01 etc]# vim redis.conf
bind 0.0.0.0
port 6379
protected-mode no
daemonize yes
pidfile /var/run/redis_6379.pid
dir /usr/local/redis/db
logfile /usr/local/redis/logs/redis.log
requirepass redis123
masterauth redis123
replicaof 11.0.1.3 6379

```

```sh
[root@salve02 etc]# vim redis.conf

bind 0.0.0.0
port 6379
protected-mode no
daemonize yes
pidfile /var/run/redis_6379.pid
dir /usr/local/redis/db
logfile /usr/local/redis/logs/redis.log
requirepass redis123
masterauth redis123
replicaof 11.0.1.3 6379
```

> - replicaof 192.168.231.130 6379
>   指定当本机为 slave 服务时，设置 master 服务的IP地址及端口，在 redis 启动的时候会自动跟 master 进行数据同步，所以两台从机都这样配置即可。
> - 注：由于我们搭建的集群需要自动容灾切换，主数据库可能会变成从数据库，所以三台机器上都需要同时设置 requirepass 和 masterauth 配置项。

启动服务

```sh
# slave01
[root@slave01 etc]# vim /usr/lib/systemd/system/redis.service

[Unit]
Description=redis-server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/redis/bin/redis-server /usr/local/redis/etc/redis.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target

# slave02
[root@slave02 etc]# vim /usr/lib/systemd/system/redis.service

[Unit]
Description=redis-server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/redis/bin/redis-server /usr/local/redis/etc/redis.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

### 5. 检查集群状态

```sh
[root@master bin]# tail -f ../logs/redis.log
18394:M 23 Feb 2023 13:53:37.895 * Background saving terminated with success
18394:M 23 Feb 2023 13:53:37.896 * Synchronization with replica 11.0.1.4:6379 succeeded
18394:M 23 Feb 2023 13:58:22.596 * Replica 11.0.1.5:6379 asks for synchronization
18394:M 23 Feb 2023 13:58:22.596 * Full resync requested by replica 11.0.1.5:6379
18394:M 23 Feb 2023 13:58:22.596 * Starting BGSAVE for SYNC with target: disk
18394:M 23 Feb 2023 13:58:22.621 * Background saving started by pid 18457
18457:C 23 Feb 2023 13:58:22.622 * DB saved on disk
18457:C 23 Feb 2023 13:58:22.623 * RDB: 4 MB of memory used by copy-on-write
18394:M 23 Feb 2023 13:58:22.722 * Background saving terminated with success
18394:M 23 Feb 2023 13:58:22.722 * Synchronization with replica 11.0.1.5:6379 succeeded
[root@master bin]# ./redis-cli -h 127.0.0.1 -p 6379
127.0.0.1:6379> AUTH redis123
OK
127.0.0.1:6379> info Replication
# Replication
role:master
connected_slaves:2
slave0:ip=11.0.1.4,port=6379,state=online,offset=630,lag=0
slave1:ip=11.0.1.5,port=6379,state=online,offset=630,lag=0
master_failover_state:no-failover
master_replid:bee8ff240f87d36f886c8661aa7394de00e0b94f
master_replid2:0000000000000000000000000000000000000000
master_repl_offset:630
second_repl_offset:-1
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:630
```

测试数据是否进行同步

```sh
# master 节点写入数据
127.0.0.1:6379> set name tianxiang
OK
# 从节点查看
[root@slave01 bin]# ./redis-cli -h 127.0.0.1 -p 6379
127.0.0.1:6379> AUTH redis123
OK
127.0.0.1:6379> get name
"tianxiang"

[root@salve02 bin]# ./redis-cli -h 127.0.0.1 -p 6379
127.0.0.1:6379> AUTH redis123
OK
127.0.0.1:6379> get name
"tianxiang"
```

### 6. sentinel 集群

哨兵的配置主要就是修改`sentinel.conf`配置文件中的参数，在`Redis`安装目录即可看到此配置文件，各参数详解如下:

```sh
# 哨兵sentinel实例运行的端口，默认26379  
port 26379
# 哨兵sentinel的工作目录
dir ./
# 是否开启保护模式，默认开启。
protected-mode:no
# 是否设置为后台启动。
daemonize:yes

# 哨兵sentinel的日志文件
logfile:./sentinel.log

# 哨兵sentinel监控的redis主节点的
## ip：主机ip地址
## port：哨兵端口号
## master-name：可以自己命名的主节点名字（只能由字母A-z、数字0-9 、这三个字符".-_"组成。）
## quorum：当这些quorum个数sentinel哨兵认为master主节点失联 那么这时 客观上认为主节点失联了  
# sentinel monitor <master-name> <ip> <redis-port> <quorum>  
sentinel monitor mymaster 127.0.0.1 6379 2

# 当在Redis实例中开启了requirepass，所有连接Redis实例的客户端都要提供密码。
# sentinel auth-pass <master-name> <password>  
sentinel auth-pass mymaster 123456  

# 指定主节点应答哨兵sentinel的最大时间间隔，超过这个时间，哨兵主观上认为主节点下线，默认30秒  
# sentinel down-after-milliseconds <master-name> <milliseconds>
sentinel down-after-milliseconds mymaster 30000  

# 指定了在发生failover主备切换时，最多可以有多少个slave同时对新的master进行同步。这个数字越小，完成failover所需的时间就越长；反之，但是如果这个数字越大，就意味着越多的slave因为replication而不可用。可以通过将这个值设为1，来保证每次只有一个slave，处于不能处理命令请求的状态。
# sentinel parallel-syncs <master-name> <numslaves>
sentinel parallel-syncs mymaster 1  

# 故障转移的超时时间failover-timeout，默认三分钟，可以用在以下这些方面：
## 1. 同一个sentinel对同一个master两次failover之间的间隔时间。  
## 2. 当一个slave从一个错误的master那里同步数据时开始，直到slave被纠正为从正确的master那里同步数据时结束。  
## 3. 当想要取消一个正在进行的failover时所需要的时间。
## 4.当进行failover时，配置所有slaves指向新的master所需的最大时间。不过，即使过了这个超时，slaves依然会被正确配置为指向master，但是就不按parallel-syncs所配置的规则来同步数据了
# sentinel failover-timeout <master-name> <milliseconds>  
sentinel failover-timeout mymaster 180000

# 当sentinel有任何警告级别的事件发生时（比如说redis实例的主观失效和客观失效等等），将会去调用这个脚本。一个脚本的最大执行时间为60s，如果超过这个时间，脚本将会被一个SIGKILL信号终止，之后重新执行。
# 对于脚本的运行结果有以下规则：  
## 1. 若脚本执行后返回1，那么该脚本稍后将会被再次执行，重复次数目前默认为10。
## 2. 若脚本执行后返回2，或者比2更高的一个返回值，脚本将不会重复执行。  
## 3. 如果脚本在执行过程中由于收到系统中断信号被终止了，则同返回值为1时的行为相同。
# sentinel notification-script <master-name> <script-path>  
sentinel notification-script mymaster /var/redis/notify.sh

# 这个脚本应该是通用的，能被多次调用，不是针对性的。
# sentinel client-reconfig-script <master-name> <script-path>
sentinel client-reconfig-script mymaster /var/redis/reconfig.sh
```

修改配置文件，三台集群同样配置，只针对 master 的哨兵

```sh
[root@master etc]# vim sentinel.conf
# 端口
port 26379
# 是否开启保户模式，默认开启，我们关闭
protected-mode:no
# 后台启动
daemonize yes
# pid 守护进程
pidfile /var/run/redis-sentinel.pid
# 日志文件
logfile /usr/local/redis/logs/sentinel.log
# 如果连接方式用的域名，则可以使用该选项
sentinel resolve-hostnames yes
# 主节点信息
sentinel monitor mymaster 11.0.1.3 6379 2
# 主节点登录密码
sentinel auth-pass mymaster redis123
# 这里设置了主机多少秒无响应，则认为挂了
sentinel down-after-milliseconds mymaster 30000
# 哨兵的登录密码
requirepass redis_sentinel123
# 指定了在发生failover主备切换时，最多可以有多少个slave同时对新的master进行同步
sentinel parallel-syncs mymaster 1
# 故障转移的超时时间，这里设置为三分钟
sentinel failover-timeout mymaster 180000

[root@master etc]# vim /usr/lib/systemd/system/redis-sentinel.service
[Unit]
Description=redis-sentinel
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/redis/bin/redis-sentinel /usr/local/redis/etc/sentinel.conf
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target

[root@master etc]# systemctl status redis-sentinel.service
● redis-sentinel.service - redis-sentinel
   Loaded: loaded (/usr/lib/systemd/system/redis-sentinel.service; enabled; vendor preset: disabled)
   Active: active (running) since 四 2023-02-23 14:26:22 CST; 4s ago
  Process: 18707 ExecStop=/bin/kill -s QUIT $MAINPID (code=exited, status=0/SUCCESS)
  Process: 18711 ExecStart=/usr/local/redis/bin/redis-sentinel /usr/local/redis/etc/sentinel.conf (code=exited, status=0/SUCCESS)
 Main PID: 18712 (redis-sentinel)
   CGroup: /system.slice/redis-sentinel.service
           └─18712 /usr/local/redis/bin/redis-sentinel *:26379 [sentinel]

2月 23 14:26:22 master systemd[1]: redis-sentinel.service failed.
2月 23 14:26:22 master systemd[1]: Starting redis-sentinel...
2月 23 14:26:22 master systemd[1]: Started redis-sentinel.
```

**验证**

```sh
[root@salve02 ~]# cp /usr/local/redis/bin/redis-cli /usr/bin/
[root@salve02 ~]# redis-cli -h 127.0.0.1 -p 26379
127.0.0.1:26379> AUTH redis_sentinel123
OK
127.0.0.1:26379> info sentinel
# Sentinel
sentinel_masters:1
sentinel_tilt:0
sentinel_running_scripts:0
sentinel_scripts_queue_length:0
sentinel_simulate_failure_flags:0
master0:name=mymaster,status=ok,address=11.0.1.3:6379,slaves=2,sentinels=3
[root@redis-master ~]# redis-cli
127.0.0.1:6379> AUTH redis123
OK
127.0.0.1:6379> info replication
role:master
master_host:11.0.1.3
master_port:6379
master_link_status:up
master_last_io_seconds_ago:1
master_sync_in_progress:0
slave_repl_offset:122973
slave_priority:100
slave_read_only:1
..............
```

模拟 master 宕机

```sh
[root@master bin]# systemctl stop redis
[root@master bin]# netstat -lntp |grep 6379
tcp        0      0 0.0.0.0:26379           0.0.0.0:*               LISTEN      24043/redis-sentine
tcp6       0      0 :::26379                :::*                    LISTEN      24043/redis-sentine
```

现在查看 redis 的 集群信息，发现之前的 slave 节点已经充当 master 角色

```sh
[root@salve02 ~]# redis-cli -h 127.0.0.1 -p 6379
127.0.0.1:6379> AUTH redis123
OK
127.0.0.1:6379> info replication
# Replication
role:master
master_host:11.0.1.5
master_port:6379
master_link_status:up
master_last_io_seconds_ago:1
master_sync_in_progress:0
slave_repl_offset:122973
slave_priority:100
slave_read_only:1
replica_announced:1
.........
```

查看日志发现

```sh
[root@redis-master ~]# tail -f /usr/local/redis/logs/sentinel.log
1025:X 25 Feb 2023 01:05:06.246 # +failover-state-reconf-slaves master mymaster 11.0.1.3 6379
1025:X 25 Feb 2023 01:05:06.321 * +slave-reconf-sent slave 11.0.1.5:6379 11.0.1.5 6379 @ mymaster 11.0.1.3 6379
1025:X 25 Feb 2023 01:05:07.011 # -odown master mymaster 11.0.1.3 6379 # 哨兵认定主节点 11.0.1.3 挂掉
1025:X 25 Feb 2023 01:05:07.297 * +slave-reconf-inprog slave 11.0.1.5:6379 11.0.1.5 6379 @ mymaster 11.0.1.3 6379
1025:X 25 Feb 2023 01:05:07.297 * +slave-reconf-done slave 11.0.1.5:6379 11.0.1.5 6379 @ mymaster 11.0.1.3 6379
1025:X 25 Feb 2023 01:05:07.387 # +failover-end master mymaster 11.0.1.3 6379  # 故障切换结束
1025:X 25 Feb 2023 01:05:07.387 # +switch-master mymaster 11.0.1.3 6379 11.0.1.5 6379  # 将 11.0.1.3 主节点切换为 11.0.1.5
1025:X 25 Feb 2023 01:05:07.387 * +slave slave 11.0.1.5:6379 11.0.1.4 6379 @ mymaster 11.0.1.5 6379
1025:X 25 Feb 2023 01:05:07.387 * +slave slave 11.0.1.3:6379 11.0.1.3 6379 @ mymaster 11.0.1.5 6379
1025:X 25 Feb 2023 01:05:37.439 # +sdown slave 11.0.1.3:6379 11.0.1.3 6379 @ mymaster 11.0.1.5 6379

[root@salve02 ~]# tail -f /usr/local/redis/logs/redis.log
1021:S 25 Feb 2023 01:04:40.247 * MASTER <-> REPLICA sync started
1021:S 25 Feb 2023 01:04:43.252 # Error condition on socket for SYNC: Connection timed out
1021:S 25 Feb 2023 01:04:43.273 * Connecting to MASTER 11.0.1.3:6379
1021:S 25 Feb 2023 01:04:43.273 * MASTER <-> REPLICA sync started
1021:S 25 Feb 2023 01:04:46.280 # Error condition on socket for SYNC: Connection timed out
1021:S 25 Feb 2023 01:04:46.300 * Connecting to MASTER 11.0.1.3:6379
1021:S 25 Feb 2023 01:04:46.300 * MASTER <-> REPLICA sync started
1021:M 25 Feb 2023 01:05:06.089 * Discarding previously cached master state.      # 这里提到放弃以前的缓存的主状态，也就是放弃了 11.0.1.3 主节点
1021:M 25 Feb 2023 01:05:06.089 # Setting secondary replication ID to ced98b8a3bc448992c4ff36e4073c7d4f9588908, valid up to offset: 55435. New replication ID is 9ce2f7863f725c90e08f15c7bff3bcb0999665bc   # 然后偏移量大道一定程度，哨兵重新拉起来了一个 slave 充当 master 节点，这里将 11.0.1.5 节点定义为 master 节点
1021:M 25 Feb 2023 01:05:06.089 * MASTER MODE enabled (user request from 'id=13 addr=11.0.1.5:32938 laddr=11.0.1.5:6379 fd=7 name=sentinel-5060fa0f-cmd age=111 idle=0 flags=x db=0 sub=0 psub=0 multi=4 qbuf=188 qbuf-free=40766 argv-mem=4 obl=45 oll=0 omem=0 tot-mem=61468 events=r cmd=exec user=default redir=-1')
1021:M 25 Feb 2023 01:05:06.090 # CONFIG REWRITE executed with success.  # 这里将 redis.conf 里面的配置重写成功，因为自身变为 master 节点，所以将关于同步主节点的配置给删除掉了
1021:M 25 Feb 2023 01:05:06.324 * Replica 11.0.1.4:6379 asks for synchronization  # 11.0.1.4 机器作为 slave 同步 master 节点数据
1021:M 25 Feb 2023 01:05:06.324 * Partial resynchronization request from 11.0.1.4:6379 accepted. Sending 285 bytes of backlog starting from offset 55435.
```

查看配置文件

```sh
# 发现本机机器里面之前配置的 11.0.1.3 节点的同步的信息没有了，因为现在自己充当 master 了，所以本地不需要配置了
[root@redis-slave02 ~]# cat /usr/local/redis/etc/redis.conf
bind 0.0.0.0
port 6379
protected-mode no
daemonize yes
pidfile "/var/run/redis_6379.pid"
dir "/usr/local/redis/db"
logfile "/usr/local/redis/logs/redis.log"
requirepass "redis123"
masterauth "redis123"
```

恢复 master

```sh
[root@master bin]# netstat -lntp |grep 6379
tcp        0      0 0.0.0.0:6379            0.0.0.0:*               LISTEN      24089/redis-server  
tcp        0      0 0.0.0.0:26379           0.0.0.0:*               LISTEN      24043/redis-sentine
tcp6       0      0 :::26379                :::*                    LISTEN      24043/redis-sentine
```

然后登录 salve01（现任master），发现之前的 master 现在充当 slave角色了

```sh
[root@slave01 redis]# cp bin/redis-cli /usr/bin/
[root@slave01 redis]# redis-cli -p 6379
127.0.0.1:6379> AUTH redis123
OK
127.0.0.1:6379> info replication
# Replication
role:master
connected_slaves:2
slave0:ip=11.0.1.5,port=6379,state=online,offset=198474,lag=0
slave1:ip=11.0.1.3,port=6379,state=online,offset=198605,lag=0
master_failover_state:no-failover
master_replid:49a7934545f83de24ab8e8c1fc3b52c452892c6a
master_replid2:0ea2b2a0501c241fd67664de968aaf3ba0b9608e
master_repl_offset:198605
second_repl_offset:104878
repl_backlog_active:1
repl_backlog_size:1048576
repl_backlog_first_byte_offset:1
repl_backlog_histlen:198605
127.0.0.1:6379>
```

## 三、高可用

### 1. 实现的原理

在master和backup服务器分别安装哨兵和keepalived，master的优先级为100，backup的优先级为99，在salve服务器上配置vrrp_script检查脚本规则，检查slave当前的角色状态，一旦slave的redis角色状态为master，就把slave的优先级加2变为101，使其获得vip的权限；

当master的redis服务挂掉后，哨兵会将slave提升为新的master，slave检查角色状态为master时将优先级加2获得vip，当原来master的redis服务起来后哨兵将其作为slave加入到主从复制

当变为master的slave节点上redis服务挂掉后，哨兵会将redis的master设置为原来的master节点，vrrp_script检查自己的redis不是master时，将优先级减2变为99，原来的master优先级比slave优先级高，原来的master获得vip权限

### 2. 部署 keepalived

master 环境部署

```sh
! Configuration File for keepalived
global_defs {
   router_id redis_master
}

vrrp_script redis_check {
    script "/etc/keepalived/redis-check.sh 127.0.0.1 6379 redis123" #检查当前redis是否为master
    interval 3                #3秒检查一次
    weight 5        # 利用脚本一直检查当前节点是否为redis的master节点，如果不是即脚本不会正常退出，不会触发keepalived
                    # 如果是则脚本正常退出，即出发keepalived使其权重加5
}

vrrp_instance VI_redis_master {
    state BACKUP
    interface ens33
    virtual_router_id 51
    priority 100
    advert_int 3  #每次多少秒进行一次健康检查
    authentication {
        auth_type PASS
        auth_pass redis
    }
    virtual_ipaddress {
        11.0.1.20
    }
    track_script {
        redis_check
    }
}
```

健康检查脚本

```sh
#!/bin/bash
redis-cli -h $1 -p $2 -a $3 info| grep "role:master"
if [ "$?" -eq 0 ];then
    exit 0    # 如果执行redis-cli命令返回值为0，则正常推出脚本，也就证明该节点为 redis-master 节点
else
    exit 1    # 如果执行redis-cli命令返回值为1，则非正常推出脚本，也就证明该节点的 redis-master 已经不再
fi
```

slave01 部署

```sh
! Configuration File for keepalived
global_defs {
   router_id redis_slave
}

vrrp_script redis_check {
    script "/etc/keepalived/redis-check.sh 127.0.0.1 6379 redis123" #检查当前redis是否为master
    interval 3                #3秒检查一次
    weight 5        # 利用脚本一直检查当前节点是否为redis的master节点，如果不是即脚本不会正常退出，不会触发keepalived
                    # 如果是则脚本正常退出，即出发keepalived使其权重加5
}

vrrp_instance VI_redis {
    state BACKUP
    interface ens33
    virtual_router_id 51
    priority 99
    advert_int 3  #每次多少秒进行一次健康检查
    authentication {
        auth_type PASS
        auth_pass redis
    }
    virtual_ipaddress {
        11.0.1.20
    }
    track_script {
        redis_check
    }
}
```

健康检查脚本

```sh
#!/bin/bash
redis-cli -h $1 -p $2 -a $3 info| grep "role:master"
if [ "$?" -eq 0 ];then
    exit 0    # 如果执行redis-cli命令返回值为0，则正常推出脚本，也就证明该节点为 redis-master 节点
else
    exit 1    # 如果执行redis-cli命令返回值为1，则非正常推出脚本，也就证明该节点的 redis-master 已经不再
fi
```

slave02 部署

```sh
! Configuration File for keepalived
global_defs {
   router_id redis_slave
}

vrrp_script redis_check {
    script "/etc/keepalived/redis-check.sh 127.0.0.1 6379 redis123" #检查当前redis是否为master
    interval 3                #3秒检查一次
    weight 5        # 利用脚本一直检查当前节点是否为redis的master节点，如果不是即脚本不会正常退出，不会触发keepalived
                    # 如果是则脚本正常退出，即出发keepalived使其权重加5
}

vrrp_instance VI_redis {
    state BACKUP
    interface ens33
    virtual_router_id 51
    priority 98
    advert_int 3  #每次多少秒进行一次健康检查
    authentication {
        auth_type PASS
        auth_pass redis
    }
    virtual_ipaddress {
        11.0.1.20
    }
    track_script {
        redis_check
    }
}
```

健康检查脚本

```sh
#!/bin/bash
redis-cli -h $1 -p $2 -a $3 info| grep "role:master"
if [ "$?" -eq 0 ];then
    exit 0    # 如果执行redis-cli命令返回值为0，则正常推出脚本，也就证明该节点为 redis-master 节点
else
    exit 1    # 如果执行redis-cli命令返回值为1，则非正常推出脚本，也就证明该节点的 redis-master 已经不再
fi
```

### 3. 验证

当前 redis 为 master，需停止掉

```sh
[root@master01 keepalived]# ip a|grep 11.0.1.20
    inet 11.0.1.20/32 scope global ens33
[root@master01 keepalived]# redis-cli -h 127.0.0.1 -p 6379 -a redis123 info|grep "role:master"
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
role:master
[root@master01 keepalived]# systemctl stop redis
```

发现 VIP 已经飘到 salve01 了，并且 redis 的 master 角色也一并过来了

```sh
[root@slave01 keepalived]# redis-cli -h 127.0.0.1 -p 6379 -a redis123 info|grep "role:master"
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
role:master
[root@slave01 keepalived]# ip a |grep 11.0.1.20
    inet 11.0.1.20/32 scope global ens33
```

恢复之前停止掉的 redis

```sh
[root@master01 keepalived]# systemctl start redis
```

停止现在 redis 为 master 的服务

```sh
[root@slave01 keepalived]# systemctl stop redis
```

查看又恢复到了之前的机器上

```sh
[root@master01 keepalived]# ip a|grep 11.0.1.20
    inet 11.0.1.20/32 scope global ens33
[root@master01 keepalived]# redis-cli -h 127.0.0.1 -p 6379 -a redis123 info|grep "role:master"
Warning: Using a password with '-a' or '-u' option on the command line interface may not be safe.
role:master
```
