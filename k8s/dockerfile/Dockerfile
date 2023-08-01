FROM centos:7

RUN sed -e 's|^mirrorlist=|#mirrorlist=|g' -e 's|^#baseurl=http://mirror.centos.org/centos|baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos|g' -i.bak /etc/yum.repos.d/CentOS-*.repo && \
    yum -y install git net-tools telnet wget curl nginx nginx-all-modules gperftools perl-devel perl-ExtUtils-Embed gd gd-devel libxslt-devel libxml2 libxml2-dev libmaxminddb-devel gcc make openssl openssl-devel

RUN mkdir -p /var/cache/nginx/proxy_temp && \
    mkdir -p /var/cache/nginx/proxy_cache && \
    mkdir /data && \
    mkdir /var/log/nginx && \
    mkdir -p /usr/share/nginx/client_body_temp && \
    cd /usr/share/nginx && \
    mkdir build-cache-purge && \
    wget https://blog.linuxtian.top/data/1-jekyll%E5%8D%9A%E5%AE%A2%E7%9B%B8%E5%85%B3/2019-11-10-Jekyll-01-%E6%90%AD%E5%BB%BA%E5%8D%9A%E5%AE%A2/2.3.tar.gz && \
    tar zxvf 2.3.tar.gz -C build-cache-purge && \
    git clone https://github.com/leev/ngx_http_geoip2_module.git && \
    wget https://blog.linuxtian.top/data/1-jekyll%E5%8D%9A%E5%AE%A2%E7%9B%B8%E5%85%B3/2019-11-10-Jekyll-01-%E6%90%AD%E5%BB%BA%E5%8D%9A%E5%AE%A2/nginx-1.20.1.tar.gz && \
    tar zxvf nginx-1.20.1.tar.gz && \
    cd nginx-1.20.1 && \
    ./configure --prefix=/usr/share/nginx --sbin-path=/usr/sbin/nginx --modules-path=/usr/lib64/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/run/nginx.pid  --user=nginx --group=nginx --with-http_ssl_module --with-stream --add-module=/usr/share/nginx/build-cache-purge/ngx_cache_purge-2.3 --add-module=/usr/share/nginx/ngx_http_geoip2_module

RUN cd /usr/share/nginx/nginx-1.20.1 && \
    make -j4 && make install && \
    sed -i '/^include\ \/usr\/share\/nginx\/modules\/\*.conf/s/^/#/' /etc/nginx/nginx.conf && \
    mkdir -p /usr/share/GeoIP/ && \
    wget -O /usr/share/GeoIP/GeoLite2-Country.mmdb https://blog.linuxtian.top/data/1-jekyll%E5%8D%9A%E5%AE%A2%E7%9B%B8%E5%85%B3/2019-11-10-Jekyll-01-%E6%90%AD%E5%BB%BA%E5%8D%9A%E5%AE%A2/GeoLite2-Country.mmdb && \
    wget -O /usr/share/GeoIP/GeoLite2-City.mmdb https://blog.linuxtian.top/data/1-jekyll%E5%8D%9A%E5%AE%A2%E7%9B%B8%E5%85%B3/2019-11-10-Jekyll-01-%E6%90%AD%E5%BB%BA%E5%8D%9A%E5%AE%A2/GeoLite2-City.mmdb && \
    wget -O /usr/share/GeoIP/GeoLite2-ASN.mmdb https://blog.linuxtian.top/data/1-jekyll%E5%8D%9A%E5%AE%A2%E7%9B%B8%E5%85%B3/2019-11-10-Jekyll-01-%E6%90%AD%E5%BB%BA%E5%8D%9A%E5%AE%A2/GeoLite2-ASN.mmdb
    useradd -M -s /usr/sbin/nologin nginx

COPY nginx.conf /etc/nginx/
COPY stylepage /etc/nginx/stylepage
CMD ["nginx", "-g", "daemon off;"]
