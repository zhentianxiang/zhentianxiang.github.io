#!/bin/bash

# 读取环境变量的值并用换行符替换分号
ALLOWED_COUNTRIES=$(printenv ALLOWED_COUNTRIES | tr ',' '\n' | sed 's/^/        /')

# 使用awk执行替换命令并将结果直接写入test.txt
awk -v countries="$ALLOWED_COUNTRIES" '{gsub("ALLOWED_COUNTRIES", countries)}1' /etc/nginx/nginx.conf > /etc/nginx/nginx.conf.bak
mv /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf

# 启动 Nginx
nginx -g "daemon off;"
