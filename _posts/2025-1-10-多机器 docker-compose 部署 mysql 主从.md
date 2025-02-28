---
layout: post
title: 2025-1-10-多机器 docker-compose 部署 mysql 主从
date: 2025-1-10
tags: Linux-Docker

---

### 1. mysql-master

- 172.16.246.115

```sh
[root@mysql-master docker-app]# mkdir -pv mysql-master/{data,conf,script}
[root@mysql-master mysql-master]#  cat docker-compose.yml 
services:
  mysql-master:
    image: mysql:8.0.29-debian
    #image: mysql:8.0.29-debian  # 次镜像包含 mysqlbinlog
    container_name: mysql-master
    ports:
      - 13306:3306
    privileged: true
    restart: always
    command:
    -  "--server-id=1"
    -  "--log-bin=mysql-bin"
    -  "--sync_binlog=1"
    volumes:
      - ./data:/var/lib/mysql
      - ./conf/my.cnf:/etc/mysql/my.cnf
      - /etc/localtime:/etc/localtime
      - /usr/share/zoneinfo/Asia/Shanghai:/etc/timezone
      - ./script:/docker-entrypoint-initdb.d/
      - ./backup:/data/backup  # 用于后期存放备份的目录
    environment:
      TZ: Asia/Shanghai
      MYSQL_ROOT_PASSWORD: "123456"
      MASTER_SYNC_USER: "sync_admin" #设置脚本中定义的用于同步的账号
      MASTER_SYNC_PASSWORD: "123456" #设置脚本中定义的用于同步的密码
      ADMIN_USER: "root" #当前容器用于拥有创建账号功能的数据库账号
      ADMIN_PASSWORD: "123456"
      ALLOW_HOST: "172.16.246.118" #允许同步账号的host地址
    networks:
    - docker-app

networks:
  docker-app:
    external: true
```

```sh
[root@mysql-master mysql-master]# cat script/create_sync_user.sh 
#!/bin/bash

# 定义用于同步的用户名
MASTER_SYNC_USER=${MASTER_SYNC_USER:-sync_admin}
# 定义用于同步的用户密码
MASTER_SYNC_PASSWORD=${MASTER_SYNC_PASSWORD:-123456}
# 定义用于登录mysql的用户名
ADMIN_USER=${ADMIN_USER:-root}
# 定义用于登录mysql的用户密码
ADMIN_PASSWORD=${ADMIN_PASSWORD:-123456}
# 定义运行登录的host地址
ALLOW_HOST=${ALLOW_HOST:-%}

# 输出当前设置
echo -e "\033[1;36m开始执行 MySQL 主从同步账号授权脚本...\033[0m"
echo -e "\033[1;32m同步账号用户名: $MASTER_SYNC_USER\033[0m"
echo -e "\033[1;32m同步账号密码: $MASTER_SYNC_PASSWORD\033[0m"
echo -e "\033[1;32mMySQL 管理员用户名: $ADMIN_USER\033[0m"
echo -e "\033[1;32mMySQL 管理员密码: $ADMIN_PASSWORD\033[0m"
echo -e "\033[1;32m允许从哪个主机连接: $ALLOW_HOST\033[0m"

# 定义创建账号的SQL语句
CREATE_USER_SQL="CREATE USER '$MASTER_SYNC_USER'@'$ALLOW_HOST' IDENTIFIED BY '$MASTER_SYNC_PASSWORD';"
# 定义赋予同步账号权限的SQL语句，更多权限来保证复制正常
GRANT_PRIVILEGES_SQL="GRANT REPLICATION SLAVE, REPLICATION CLIENT, SHOW DATABASES, SELECT ON *.* TO '$MASTER_SYNC_USER'@'$ALLOW_HOST';"
# 定义刷新权限的SQL语句
FLUSH_PRIVILEGES_SQL="FLUSH PRIVILEGES;"

# 输出创建用户信息
echo -e "\033[1;33m正在创建同步账号: $MASTER_SYNC_USER\033[0m"
mysql -u"$ADMIN_USER" -p"$ADMIN_PASSWORD" -e "$CREATE_USER_SQL"
if [ $? -eq 0 ]; then
    echo -e "\033[1;32m同步账号创建成功: $MASTER_SYNC_USER\033[0m"
else
    echo -e "\033[1;31m同步账号创建失败: $MASTER_SYNC_USER\033[0m"
    exit 1
fi

# 输出授予权限信息
echo -e "\033[1;33m正在授予同步账号权限...\033[0m"
mysql -u"$ADMIN_USER" -p"$ADMIN_PASSWORD" -e "$GRANT_PRIVILEGES_SQL"
if [ $? -eq 0 ]; then
    echo -e "\033[1;32m同步账号权限授予成功\033[0m"
else
    echo -e "\033[1;31m同步账号权限授予失败\033[0m"
    exit 1
fi

# 输出刷新权限信息
echo -e "\033[1;33m正在刷新权限...\033[0m"
mysql -u"$ADMIN_USER" -p"$ADMIN_PASSWORD" -e "$FLUSH_PRIVILEGES_SQL"
if [ $? -eq 0 ]; then
    echo -e "\033[1;32m权限刷新成功\033[0m"
else
    echo -e "\033[1;31m权限刷新失败\033[0m"
    exit 1
fi

# 输出完成信息
echo -e "\033[1;36mMySQL 主节点授权从节点允许同步已完成!!!\033[0m"
```

```sh
[root@mysql-master mysql-master]# docker-compose up -d
[root@mysql-master mysql-master]# docker-compose ps
NAME           IMAGE                 COMMAND                  SERVICE        CREATED          STATUS          PORTS
mysql-master   mysql:8.0.29          "docker-entrypoint.s…"   mysql-master   29 minutes ago   Up 29 minutes   33060/tcp, 0.0.0.0:13306->3306/tcp, :::13306->3306/tcp
```

### 2. master-slave

- 172.16.246.118

```sh
[root@mysql-slave docker-app]# mkdir -pv mysql-slave/{data,conf,script}
[root@mysql-slave docker-app]# cd mysql-slave/
[root@mysql-slave mysql-slave]# cat docker-compose.yml
services:
  mysql-slave:
    image: mysql:8.0.29
    #image: mysql:8.0.29-debian  # 次镜像包含 mysqlbinlog
    container_name: mysql-slave
    ports:
      - 13306:3306
    privileged: true
    restart: always
    command:
    -  "--server-id=2"
    volumes:
      - ./data:/var/lib/mysql
      - ./conf/my.cnf:/etc/mysql/my.cnf
      - /etc/localtime:/etc/localtime
      - /usr/share/zoneinfo/Asia/Shanghai:/etc/timezone
      - ./script:/docker-entrypoint-initdb.d/
      - ./backup:/data/backup  # 用于后期存放备份的目录
    environment:
      TZ: Asia/Shanghai
      MYSQL_ROOT_PASSWORD: "123456"
      MASTER_SYNC_USER: "sync_admin" #设置脚本中定义的用于同步的账号
      MASTER_SYNC_PASSWORD: "123456" #设置脚本中定义的用于同步的密码
      ADMIN_USER: "root" #当前容器用于拥有创建账号功能的数据库账号
      ADMIN_PASSWORD: "123456"
      MASTER_HOST: "172.16.246.115"
      MASTER_PORT: "13306"
    networks:
    - docker-app

networks:
  docker-app:
    external: true
```

```sh
[root@mysql-slave mysql-slave]# cat script/slave.sh 
#!/bin/bash

# 定义连接 master 进行同步的账号
SLAVE_SYNC_USER="${SLAVE_SYNC_USER:-sync_admin}"
# 定义连接 master 进行同步的账号密码
SLAVE_SYNC_PASSWORD="${SLAVE_SYNC_PASSWORD:-123456}"
# 定义 slave 数据库账号
ADMIN_USER="${ADMIN_USER:-root}"
# 定义 slave 数据库密码
ADMIN_PASSWORD="${ADMIN_PASSWORD:-123456}"
# 定义连接 master 数据库 host 地址
MASTER_HOST="${MASTER_HOST:-127.0.0.1}"
# 定义连接 master 数据库端口
MASTER_PORT="${MASTER_PORT:-3306}"

# 等待 10s，保证 master 数据库启动成功，不然会连接失败
sleep 10

# 连接 master 数据库，查询二进制数据，并解析出 logfile 和 pos，这里同步用户要开启 REPLICATION CLIENT 权限，才能使用 SHOW MASTER STATUS;
RESULT=$(mysql -u"$SLAVE_SYNC_USER" -h"$MASTER_HOST" -P"$MASTER_PORT" -p"$SLAVE_SYNC_PASSWORD" -e "SHOW MASTER STATUS;" | grep -v grep | tail -n 1)

# 解析出 logfile 和 pos
LOG_FILE_NAME=$(echo "$RESULT" | awk '{print $1}')
LOG_FILE_POS=$(echo "$RESULT" | awk '{print $2}')

# 判断是否能获取到日志文件和位置
if [ -z "$LOG_FILE_NAME" ] || [ -z "$LOG_FILE_POS" ]; then
    echo -e "\033[1;31mError: Failed to get master status.\033[0m"
    exit 1
fi

# 设置连接 master 的同步相关信息
SYNC_SQL="CHANGE MASTER TO MASTER_HOST='$MASTER_HOST', MASTER_PORT=$MASTER_PORT, MASTER_USER='$SLAVE_SYNC_USER', MASTER_PASSWORD='$SLAVE_SYNC_PASSWORD', MASTER_LOG_FILE='$LOG_FILE_NAME', MASTER_LOG_POS=$LOG_FILE_POS;"

# 开启同步
START_SYNC_SQL="START SLAVE;"

# 查看同步状态
STATUS_SQL="SHOW SLAVE STATUS\G;"

# 执行同步操作
mysql -u"$ADMIN_USER" -p"$ADMIN_PASSWORD" -e "$SYNC_SQL $START_SYNC_SQL $STATUS_SQL"

# 检查同步是否启动成功
SLAVE_STATUS=$(mysql -u"$ADMIN_USER" -p"$ADMIN_PASSWORD" -e "SHOW SLAVE STATUS\G;" | grep "Slave_IO_Running" | awk '{print $2}')
if [ "$SLAVE_STATUS" == "Yes" ]; then
    echo -e "\033[1;36mMySQL replication is running normally!!!\033[0m"
else
    echo -e "\033[1;31mError: MySQL replication failed to start.\033[0m"
fi
```

```sh
[root@mysql-master mysql-slave]# docker-compose up -d
[root@mysql-master mysql-slave]# docker-compose ps
NAME           IMAGE                 COMMAND                  SERVICE        CREATED          STATUS          PORTS
mysql-slave   mysql:8.0.29          "docker-entrypoint.s…"   mysql-master   29 minutes ago   Up 29 minutes   33060/tcp, 0.0.0.0:13306->3306/tcp, :::13306->3306/tcp
```

### 3. 脚本工具

全量备份脚本

```sh
[root@mysql-master mysql-master]# cat save-sql.sh 
#!/bin/bash

# 定义 MySQL 登录信息
MYSQL_USER="root"
MYSQL_PASSWORD="123456"
BACKUP_DIR="/data/backup"

# 检查备份目录是否存在，如果不存在则创建
if [ ! -d "$BACKUP_DIR" ]; then
    echo "备份目录不存在，正在创建..."
    mkdir -p "$BACKUP_DIR"
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32m备份目录创建成功！\033[0m"
    else
        echo -e "\033[1;31m创建备份目录失败！\033[0m"
        exit 1
    fi
fi

# 获取所有数据库名，过滤掉系统数据库
DATABASES=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW DATABASES;" | sed '1d' | grep -Ev "(information_schema|performance_schema|sys|mysql)")

# 循环备份每一个数据库
for DB in $DATABASES; do
    echo "正在备份数据库: $DB"
    mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --databases "$DB" > "$BACKUP_DIR/$DB.sql"
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32m数据库 $DB 备份成功！\033[0m"
    else
        echo -e "\033[1;31m数据库 $DB 备份失败！\033[0m"
    fi
done
```

导入脚本

```sh
[root@mysql-master mysql-master]# cat import-sql.sh 
#!/bin/bash

# 定义 MySQL 登录信息
MYSQL_USER="root"
MYSQL_PASSWORD="123456"
BACKUP_DIR="/data/backup"

# 检查备份目录是否存在
if [ ! -d "$BACKUP_DIR" ]; then
    echo -e "\033[1;31m备份目录不存在！\033[0m"
    exit 1
fi

# 遍历备份目录下所有的 .sql 文件
for SQL_FILE in $BACKUP_DIR/*.sql; do
    # 检查文件是否存在
    if [ -f "$SQL_FILE" ]; then
        DB_NAME=$(basename "$SQL_FILE" .sql)
        echo "正在导入数据库: $DB_NAME 从文件 $SQL_FILE"
        
        # 导入数据库
        mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" < "$SQL_FILE"
        
        if [ $? -eq 0 ]; then
            echo -e "\033[1;32m数据库 $DB_NAME 导入成功！\033[0m"
        else
            echo -e "\033[1;31m数据库 $DB_NAME 导入失败！\033[0m"
        fi
    else
        echo -e "\033[1;31m未找到备份文件: $SQL_FILE\033[0m"
    fi
done
```

增量备份binlog脚本

```sh
[root@mysql-master mysql-master]# cat data/incremental-backup.sh 
#!/bin/bash

# 定义 MySQL 登录信息
MYSQL_USER="root"
MYSQL_PASSWORD="123456"
BINLOG_DIR="/data/backup"  # 存储二进制日志的目录

# 检查二进制日志备份目录是否存在
if [ ! -d "$BINLOG_DIR" ]; then
    echo -e "\033[1;31m二进制日志备份目录不存在，正在创建...\033[0m"
    mkdir -p "$BINLOG_DIR"
    if [ $? -eq 0 ]; then
        echo -e "\033[1;32m二进制日志备份目录创建成功！\033[0m"
    else
        echo -e "\033[1;31m创建二进制日志备份目录失败！\033[0m"
        exit 1
    fi
fi

# 获取当前的二进制日志文件和位置
CURRENT_BINLOG=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW MASTER STATUS\G" | grep 'File' | awk '{print $2}')
CURRENT_LOG_POS=$(mysql -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e "SHOW MASTER STATUS\G" | grep 'Position' | awk '{print $2}')

# 定义增量备份文件名
INCREMENTAL_BACKUP_FILE="$BINLOG_DIR/$CURRENT_BINLOG-$CURRENT_LOG_POS.sql"

# 输出当前备份信息
echo "当前二进制日志文件: $CURRENT_BINLOG"
echo "当前二进制日志位置: $CURRENT_LOG_POS"
echo "增量备份文件将保存到: $INCREMENTAL_BACKUP_FILE"

# 备份当前的二进制日志（增量备份）
echo "正在备份二进制日志文件 $CURRENT_BINLOG 从位置 $CURRENT_LOG_POS 开始..."
mysqlbinlog --no-defaults --start-position=$CURRENT_LOG_POS --stop-never "/var/lib/mysql/$CURRENT_BINLOG" > "$INCREMENTAL_BACKUP_FILE"

# 检查备份结果
if [ $? -eq 0 ]; then
    echo -e "\033[1;32m增量备份成功！备份文件: $INCREMENTAL_BACKUP_FILE\033[0m"
else
    echo -e "\033[1;31m增量备份失败！\033[0m"
    exit 1
fi

# 备份完成后，你可以考虑删除已经备份的二进制日志（例如，每月或每周）
# 你也可以设定一个保留策略来删除旧的日志
```

