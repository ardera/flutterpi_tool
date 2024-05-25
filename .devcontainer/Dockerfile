FROM mcr.microsoft.com/devcontainers/base:debian

# Install needed packages
RUN apt-get update && apt-get install -y curl git unzip xz-utils zip

USER 1000:1000

ARG FLUTTER_VERSION=3.22.1
RUN git clone -b $FLUTTER_VERSION https://github.com/flutter/flutter.git /home/vscode/flutter

ENV PATH /home/vscode/flutter/bin:/home/vscode/.pub-cache/bin:$PATH

RUN flutter precache

USER root
