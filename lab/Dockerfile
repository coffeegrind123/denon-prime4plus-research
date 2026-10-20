FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        qemu-system-arm cpio xz-utils device-tree-compiler kmod curl \
        e2fsprogs gdisk uuid-runtime openssh-client sshpass ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /lab
