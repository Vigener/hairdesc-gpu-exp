FROM ubuntu:22.04

# 対話的プロンプトを無効化
ENV DEBIAN_FRONTEND=noninteractive

# MPI等のミニマムな実行・ビルド環境のインストール
# Typstやuv、関連フォントはローカルで使用するため除外
RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    gdb \
    make \
    openmpi-bin \
    libopenmpi-dev \
    libomp-dev \
    htop \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# わかりやすいユーザーの作成 (mpiuser)
ARG USERNAME=mpiuser
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash

# デフォルトユーザーとワークディレクトリの設定
USER $USERNAME
WORKDIR /workspace
