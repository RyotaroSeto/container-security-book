FROM ubuntu:20.04

RUN apt-get update && apt-get install curl
EXPOSE 22