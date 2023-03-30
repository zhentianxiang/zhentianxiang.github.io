---
layout: post
title: Shell-脚本编程04-编程之sed与awk
date: 2020-11-25
tags: Linux-Shell脚本
---

## 一、正则表达式

正则表达式概述 使用单个字符串来描述、匹配一系列符合某个句法规则的字符串，由普通字符与特殊字 符组成，一般在使用脚本编程、文件编辑器中，如 php、python、shell 等，简写为 regex、 regexp、RE。用来检索、替换符合模式的文本。具有强大的文本匹配功能，能够在文本海洋 中快速高效地处理文本。

### 1.正则表达式层次

基础正则表达式

扩展正则表达式

### 2.Linux 中常用的文本处理工具

grep

sed

awk

### 3.基础正则表达式

是常用的正则表达式部分

常用元字符:

```
\ 转义字符。例如:“\!”将逻辑否的!看做普通字符

^ 匹配字符串开始的位置，以...为开头的

$ 匹配字符串结束的位置，以...结束的 . 匹配任意的一个字符

* 匹配前面子表达式 0 词或者多次

[list] 匹配 list 列表中的一个字符，例如:[abc]、[a-z]、[a-z0-9]

[^list] 匹配任意不在 list 表中的一个字符，例如:[^a-z]、[^0-9]、[^A-Z0-9]

\{n\} 匹配前面子表达式 n 次

\{n,\} 匹配前面子表达式至少 n 次

\{n,m\} 匹配前面子表达式最少 n 次，最大 m 次
```

**常见的转义字符**

| 转义字符 |               意义               |
| :------: | :------------------------------: |
|    \a    |            响铃(BEL)             |
|    \b    |  退格(BS)，将当前位置移到前一列  |
|    \n    | 换行(LF)将当前位置移到下一行开头 |
|    \t    | 水平制表(HT)调到下一个 TAB 位置  |
|    \v    |           垂直制表(VT)           |
|   \ \    |      代表一个反斜杠字符“\”       |

**示例：**

```
[root@tianxiang ~]# nl test.txt
     1	gd
     2	god
     3	good
     4	goood
     5	gooood
     6	gold
     7	glad
     8	gaad
     9	abcdEfg
    10	food
    11	60115127Z
    12	HELLO
    13	010-66668888
    14	0666-5666888
    15	IP 192.168.100.150
    16	IP 173.16.16.1
    17	pay $180
[root@tianxiang ~]#
```

打印出包含“$”字符的行:

```
[root@tianxiang ~]# sed -n '/\$/p' test.txt

[root@tianxiang ~]# awk '/\$/ {print}' test.txt

[root@tianxiang ~]# grep '\$' test.txt

pay $180
```

过滤出以小写字母开头的行:

```
[root@tianxiang ~]# grep "^[a-z]" test.txt

[root@tianxiang ~]# sed -n '/^[a-z]/p' test.txt

gd
god
good
goood
gooood
gold
glad
gaad
abcdEfg
food
pay $180
```

过滤出以数字结尾的行:

```
[root@tianxiang ~]# grep "[0-9]$" test.txt

[root@tianxiang ~]# sed -n '/[0-9]$/p' test.txt

[root@tianxiang ~]# awk '/[0-9]$/{print}' test.txt

010-66668888
0666-5666888
IP 192.168.1.108
IP 173.16.16.1
pay $180
```

过滤出 go 于 d 之间任意一个字符的行:

```
[root@tianxiang ~]# grep "go.d" test.txt

[root@tianxiang ~]# sed -n '/go.d/p' test.txt

[root@tianxiang ~]# awk '/go.d/{print}' test.txt

good
gold
```

过滤出 go 于 d 之间任意两个字符的行:

```
[root@tianxiang ~]# grep "g..d" test.txt

[root@tianxiang ~]# sed -n '/g..d/p' test.txt

[root@tianxiang ~]# awk '/g..d/{print}' test.txt

good
gold
glad
gaad
```

过滤出g和d之间没有o或者有多个o的行:

```
[root@tianxiang ~]# grep "go*d" test.txt

[root@tianxiang ~]# sed -n '/go*d/p' test.txt

[root@tianxiang ~]# awk '/go*d/{print}' test.txt

gd
god
good
goood
gooood
```

过滤出g和ad之间有字母l或a的行:

```
[root@tianxiang ~]# grep "g[la]ad" test.txt

[root@tianxiang ~]# sed -n '/g[la]ad/p' test.txt

[root@tianxiang ~]# awk '/g[la]ad/{print}' test.txt

glad
gaad
```

过滤出行内有非小写字母的行:

```
[root@tianxiang ~]# grep [^a-z] test.txt

[root@tianxiang ~]# sed -n '/[^a-z]/p' test.txt

abcdEfg
60115127Z
HELLO
010-66668888
0666-5666888
IP 192.168.1.108
IP 173.16.16.1
pay $180
```

过滤出电话号码:

```
[root@tianxiang ~]# grep "[0-9]\{3,4\}-[0-9]\{7,8\}" test.txt

[root@tianxiang ~]# sed -n '/[0-9]\{3,4\}-[0-9]\{7,8\}/p' test.txt

010-66668888
0666-5666888
```

过滤出 IP 地址:

```
[root@tianxiang ~]# grep "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" test.txt

[root@tianxiang ~]# sed -n '/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/p' test.txt

IP 192.168.1.108
IP 173.16.16.1
```

### 4.扩展正则表达式

是多对基础正则表达式的扩充深化

扩展元字符:

```
+ 匹配前面子表达式 1 次以上

? 匹配前面子表达式 0 次或者 1 次

() 将括号中的字符串作为一个整体

| 以或的方式匹配字条串
```

**示例:**

过滤出字母g与d之间至少有1个字母o的行:

```
[root@tianxiang ~]# egrep go+d test.txt

[root@tianxiang ~]# awk '/go+d/{print}' test.txt

god
good
goood
gooood
```

过滤出字母g与d之间没有字母o或只有1个o的行:

```
[root@tianxiang ~]# egrep go?d test.txt

[root@tianxiang ~]# awk '/go?d/{print}' test.txt

gd
god
```

过滤出字母 g 与 d 之间两个字母 o 一起出现至少 1 次的行:

```
[root@tianxiang ~]# egrep "g(oo)+d" test.txt

[root@tianxiang ~]# awk '/g(oo)+d/{print}' test.txt

good
gooood
```

过滤出字母g与d之间是la或者是aa的行:

```
[root@tianxiang ~]# egrep "g(la|aa)d" test.txt

[root@tianxiang ~]# awk '/g(la|aa)d/{print}' test.txt

glad
gaad
```

## 二、sed 命令

sed 是文本处理工具，读取文本内容，根据指定的条件进行处理，可实现增删改查的功 能。被广泛应用于 shell 脚本，以完成自动化处理任务。sed 依赖于正则表达式。

### 1.格式:

sed ‘编辑命令’ 文件 1 文件 2…

### 2.常用选项:

> -e 指定要执行的命令，只有一个编辑命令时可省略
>
> -n 只输出处理后的行，读入时不显示，不对原文件进行修改
>
> -i 直接编辑原文件，不输出结果

### 3编辑命令格式:

/[地址 1[,地址 2]]/操作 [参数]

**(1)地址:**

可为行数、正则表达式、$，没有地址代表全文

**(2)操作:**

p 打印(输出)

d 删除(整行)

s 替换(字符串)

c 替换(整行)

r 读取指定文件(到行后)

a append，追加指定内容到行后

i insert，追加指定内容到行前

w 另存为

n 表示读入下一行内容

H 复制到剪贴板

g 将剪贴板中的内容覆盖到指定行

G 将剪贴板中的内容追加到指定行后

**示例：**

```
[root@tianxiang ~]# nl test.txt
     1	gd
     2	god
     3	good
     4	goood
     5	gooood
     6	gold
     7	glad
     8	gaad
     9	abcdEfg
    10	food
    11	60115127Z
    12	HELLO
    13	010-66668888
    14	0666-5666888
    15	IP 192.168.100.150
    16	IP 173.16.16.1
    17	pay $180
[root@tianxiang ~]#
```

【p 打印】

```
[root@tianxiang ~]# sed -n '12p' test.txt 		  //输出第 12 行内容

HELLO

[root@tianxiang ~]# sed -n '3,5p' test.txt       //输出 3~5 行的内容

good
goood
gooood

[root@tianxiang ~]# sed -n 'p;n' test.txt		    //输出所有奇数行

gd
good
gooood
glad
abcdEfg
60115127Z
010-66668888
IP 192.168.1.108
pay $180

[root@tianxiang ~]# sed -n 'n;p' test.txt	       //输出所有偶数行

god
goood
gold
gaad
food
HELLO
0666-5666888
IP 173.16.16.1

[root@tianxiang ~]# sed -n '1,5{p;n}' test.txt   //输出 1~5 行之间的奇数行(第 1,3,5 行)

gd
good
gooood

[root@tianxiang ~]# sed -n '/H/p' test.txt		  //输出包含字母 H 的行

HELLO

[root@tianxiang ~]# sed -n '/[A-Z]/p' test.txt        //输出所有包含大写字母的行

abcdEfg
60115127Z
HELLO
IP 192.168.1.108
IP 173.16.16.1

[root@tianxiang ~]# sed -n '$p' test.txt         //输出最后一行

pay $180  
```

【d 删除(整行)】

```
[root@tianxiang ~]# sed '16d' test.txt         //删除第 16 行

gd         
god
good
goood
gooood
gold
glad
gaad
abcdEfg
food
60115127Z
HELLO
010-66668888
0666-5666888
IP 192.168.1.108
pay $18
[root@tianxiang ~]# cat -n test.txt
     1	gd
     2	god
     3	good
     4	goood
     5	gooood
     6
     7
     8	gold
     9	glad
    10
    11	gaad
    12	abcdEfg
    13	food
    14	60115127Z
    15	HELLO
    16	010-66668888
    17	0666-5666888
    18	IP 192.168.100.150
    19	IP 173.16.16.1
    20	pay $180
[root@tianxiang ~]# sed -i '/^$/d' test.txt          //删除空行

[root@tianxiang ~]# cat test.txt

gd
god
good
goood
gooood
gold
glad
gaad
abcdEfg
food
60115127Z
HELLO
010-66668888
0666-5666888
IP 192.168.1.108
IP 173.16.16.1
pay $180

[root@tianxiang ~]# sed -e '1d' -e '3d' test.txt      //删除第 1 行和第 3 行

god   
goood
gooood
gold
glad

[root@tianxiang ~]# sed -e '1d;3d' test.txt          //同样，删除第 1 行和第 3 行

god
goood
gooood
gold
glad
```

【s 替换(字符串)】

```
[root@tianxiang ~]# sed 's/o/O/g' test.txt           //将所有小写 o 替换为大写 O

(g 表示若同一行有多个小写 o，全部替换，若不加 g，则只替换每行的第一个小写 o)

gd
gOd
gOOd
gOOOd
gOOOOd
gOld
glad
gaad
abcdEfg
fOOd
60115127Z
HELLO
010-66668888
0666-5666888
IP 192.168.1.108
IP 173.16.16.1
pay $180

[root@tianxiang ~]# sed '/^IP/ s/^/#/' test.txt         //以 IP 开头的行，行首加上#

gd
god
good
goood
gooood
gold
glad
gaad
abcdEfg
food
60115127Z
HELLO
010-66668888
0666-5666888
#IP 192.168.1.108
#IP 173.16.16.1
pay $180

[root@tianxiang ~]# sed 's/$/EOF/' test.txt              //在每行行尾插入字符串 EOF

gdEOF
godEOF
goodEOF
gooodEOF
goooodEOF
goldEOF
gladEOF
gaadEOF
abcdEfgEOF
foodEOF
60115127ZEOF
HELLOEOF
010-66668888EOF
0666-5666888EOF
IP 192.168.1.108EOF
IP 173.16.16.1EOF
pay $180EOF

[root@tianxiang ~]# sed '20,25 s@/sbin/nologin@/bin/bash@' /etc/passwd
//将/etc/passwd 文件 20~25 行的/sbin/nologin 替换为/bin/bash。如果用 s///的形式， 将会多次使用转义符\，我们可以使用其他符号，如@进行分隔
```

【c 替换(整行)】

```
[root@tianxiang ~]# sed '2cAAAAAAAAAAAAAAA' test.txt         //将第 2 行替换为 AAAAAAA...

gd
AAAAAAAAAAAAAAA
good
goood
gooood
gold
glad
gaad
abcdEfg
food
60115127Z
HELLO
010-66668888
0666-5666888
IP 192.168.1.108
IP 173.16.16.1
pay $180

[root@tianxiang ~]# sed '5,$cAAAAAAAAAAA\nBBBBBBBBBBBB' test.txt //把第 5 行至最后一行的内容替换为两行，AAAAAA...和 BBBBBBB...(\n 为换行)

gd
god
good
goood
AAAAAAAAAAA
BBBBBBBBBBBB
```

【r 读取指定文件(到行后)】

```
[root@tianxiang ~]# sed '5r /etc/resolv.conf' test.txt       //读取/etc/resolv.conf 文件内容在第 5 行后

gd
god
good
goood
gooood
# Generated by NetworkManager
search amber.com
# No nameservers found; try putting DNS servers into your
# ifcfg files in /etc/sysconfig/network-scripts like so: #
# DNS1=xxx.xxx.xxx.xxx
# DNS2=xxx.xxx.xxx.xxx
# DOMAIN=lab.foo.com bar.foo.com gold
glad
gaad
abcdEfg
food
60115127Z
HELLO
010-66668888
0666-5666888
IP 192.168.1.108
IP 173.16.16.1
pay $180
```

【a 追加指定内容到行后】

```
[root@tianxiang ~]# sed '2aNNNNNNNNNNNNNNNNNN' test.txt         //在第 2 行后添加 NNNN...

gd     
god
NNNNNNNNNNNNNNNNNN
good
......

[root@tianxiang ~]# sed '/[0-9]/a==============' test.txt       //在所有带数字的行下追加====...

gd
god
good
goood
gooood
gold
glad
gaad
abcdEfg
food
60115127Z
==============
HELLO
010-66668888
==============
0666-5666888
==============
IP 192.168.1.108
==============
IP 173.16.16.1
==============
pay $180
==============
```

【i 追加指定内容到行前】

```
[root@tianxiang ~]# sed '2iNNNNNNNNNNNNNNNNNN' test.txt      //在第 2 行前追加 NNNNN...

gd
NNNNNNNNNNNNNNNNNN
god
......
```

【w 另存为】

```
[root@tianxiang ~]# sed '15,16w out.txt' test.txt           //将 15~16 行内容另存到 out.txt 文件中
[root@tianxiang ~]# cat out.txt
IP 192.168.1.108 IP 173.16.16.1
```

【H 复制到剪贴板】 【G 将剪贴板中的内容追加到指定行后】

```
[root@tianxiang ~]# sed '/IP/ {H;d};$G' test.txt gd         //将包含字母 IP 的行剪切到最后一行下

god
good
goood
gooood
gold
glad
gaad
abcdEfg
food
60115127Z
HELLO
010-66668888
0666-5666888
pay $180
IP 192.168.1.108
IP 173.16.16.1

[root@tianxiang ~]# sed '1,5H;15,16G' test.txt gd         //将 1~5 行内容复制到 15 行、16 行下

god
good
goood
gooood
gold
glad
gaad
abcdEfg
food
60115127Z
HELLO
010-66668888
0666-5666888
IP 192.168.1.108
gd
god
good
goood gooood
IP 173.16.16.1
gd
god
good
goood
gooood
pay $180
```

## 三、awk 命令

awk 也是一个强大的编辑工具，它比 sed 的功能更加强大，可以在无交互的情况下实现 相当复杂的文本操作。

### 1格式:

awk 选项 ‘模式或条件{编辑指令}’ 文件 1 文件 2

awk -f 脚本文件 文件1 文件2

### 2.编辑指令的分隔

每一条编辑指令若包含多条语句，则以分号隔开。如果有多条编辑指令，则使用以分号 或者空格分隔的多个{ }区域。

### 3.区块构成

BEGIN { 编辑指令 } //开始处理第一行文本之前的操作

{ 编辑指令 } //针对每一行文本的处理操作

END { 编辑指令 } //处理完最后一行文本之后的操作

### 4.awk 的执行流程

(1)首先执行 BEGIN { } 区块中的初始化操作;

(2)然后从指定的数据文件中循环读取一个数据行(自动更新 NF、NR、$0、$1…… 等内建变量的值)，并执行’模式或条件{ 编辑指令 }’;

(3)最后执行 END { } 区块中的后续处理操作

### 5.awk 的内置变量

- FS:指定每行文本的字段分隔符，缺省为空格或制表位
- NF:当前处理的行的字段个数(列数)
- NR:当前处理的行的序数(行数)
- $0:当前处理的行的整行内容
- $n:当前处理的第 n 个字段(第 n 列)

### 6.awk 的使用

在使用的过程中，可以使用逻辑操作符&&，表示“与”，||表示“或”，!表示“非”;还可 以进行简单的数学运算，如+、-、*、/、%、^分别表示加、减、乘、除、取余、乘方

**示例**

```
打印出全文内容(等同于 cat):

[root@tianxiang ~]# awk '{print}' test.txt

[root@tianxiang ~]# awk '{print $0}' test.txt

输出第 1 行~第 3 行的内容:

[root@tianxiang ~]# awk 'NR==1,NR==3{print}' test.txt

[root@tianxiang ~]# awk '(NR>=1)&&(NR<=3){print}' test.txt

输出第 1 行和第 3 行的内容:

[root@tianxiang ~]# awk 'NR==1||NR==3{print}' test.txt

输出所有奇数行:

[root@tianxiang ~]# awk '(NR%2)==1{print}' test.txt

输出所有偶数行:

[root@tianxiang ~]# awk '(NR%2)==0{print}' test.txt

输出所有以大写字母 I 开头的行:

[root@tianxiang ~]# awk '/^I/{print}' test.txt

打印出以:为分隔符的第一列和第三列内容:

[root@tianxiang ~]# awk -F':' '{print $1}' passwd.bak          //显示用户名和 UID 号

输出密码为空的用户行:

[root@tianxiang ~]# awk -F: '$2==""{print}' /etc/shadow

[root@tianxiang ~]# awk 'BEGIN{FS=":"};$2==""{print}' /etc/shadow

统计当前所有系统用户的用户名、UID、GID、登录的 shell，制成 Windows 系统中的 EXCEL 表格:(工作中常用到)

[root@tianxiang ~]# awk -F: '{print $1","$3","$4","$7}' /etc/passwd >users.csv    //$7 可以用$NF代替(最后一列) 将此文件复制到 Windows 电脑中
```

打开后，可以根据需求，修改表格，另存为成 excel 表格即可

![img](/images/posts/Shell-脚本编程/Shell-脚本编程04-编程之sed与awk/1.png)

### 7.当前内存使用率超过 85%时报警(取整数部分):

![img](/images/posts/Shell-脚本编程/Shell-脚本编程04-编程之sed与awk/2.png)

```
[root@tianxiang ~]# [ $(free -m|awk '/cache:/ {print int($3/($3+$4)*100)}') -gt 85 ] &&echo "内存使 用率已超过 85%!"
```

### 8.查看当前 shell 最近使用最多的 10 个命令:

知识点补充:

sort:排序。 sort -r 反向排序; sort -n 以数字的值的大小为排序依据 uniq:去除重复项。 uniq -c 在每行前加上表示相应行目出现次数的前缀编号

```
[root@tianxiang ~]# history |awk '{print $2}'|sort|uniq -c|sort -nr|head -10
[root@tianxiang ~]# history |awk '{print $2}'|sort|uniq -c|sort -nr|sed -n '1,10p'
[root@tianxiang ~]# history |awk '{print $2}'|sort|uniq -c|sort -nr|awk 'NR<=10{print}'
[root@tianxiang ~]# history |awk '{print $2}'|sort|uniq -c|sort -nr|awk 'NR==1,NR==10{print}'
155 vim
115 sed
83 ls
67 awk
54 ./dns.sh
47 cat
46 cd
38 grep
36 egrep
29 ./kaoshi.sh
```
