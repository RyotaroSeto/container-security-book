FROM ubuntu:20.04

RUN apt-get -y update && apt-get --no-install-recommends install curl -y

# 22にするとユーザーがコンテナにSSH接続できるようになるかもしれない。
USER nobody
EXPOSE 23

