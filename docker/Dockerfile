FROM ruby:2.6.0

ADD myBlog.tar.gz /root/

RUN apt-get update && apt-get -y install make gcc g++ curl gpg libnss3-dev iproute2 net-tools telnet iputils-ping vim

RUN gem update --system && \
    gem install sass-embedded -v 1.58.3 && \
    gem install jekyll && \
    jekyll new myBlog && \
    cd /myBlog && gem install jekyll bundler && bundle install && \
    cp -ra /root/myBlog/jekyll-template/ /myBlog/ && cd /myBlog/jekyll-template && \
    bundle install

EXPOSE 4000/tcp

WORKDIR /myBlog/jekyll-template

ENTRYPOINT ["/usr/local/bin/bundle","exec","jekyll serve -H 0.0.0.0 -P 4000"]
