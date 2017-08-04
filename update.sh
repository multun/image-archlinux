#!/bin/bash -e

# A POSIX variable
OPTIND=1 # Reset in case getopts has been used previously in the shell.

while getopts "A:a:q:u:d:" opt; do
    case "$opt" in
    A)  ARCH_ARCH=$OPTARG
        ;;
    a)  ARCH=$OPTARG
        ;;
    q)  QEMU_ARCH=$OPTARG
        ;;
    u)  QEMU_VER=$OPTARG
        ;;
    d)  DOCKER_REPO=$OPTARG
        ;;
    esac
done

shift $((OPTIND-1))

[ "$1" = "--" ] && shift

MIRROR="${MIRROR:-http://archlinuxarm.org/}"
REPO="${MIRROR}/os"
ROOTFS="rootfs"

mkdir -p "${ROOTFS}/usr/bin"

# fetch the base archlinuxarm rootfs
[ -f base_rootfs_${ARCH_ARCH}.tar.gz ] || \
  curl -fsSL "${REPO}/ArchLinuxARM-${ARCH_ARCH}-latest.tar.gz" -o base_rootfs_${ARCH_ARCH}.tar.gz


# install qemu-user-static
if [ -n "${QEMU_ARCH}" ]; then
    if [ ! -f x86_64_qemu-${QEMU_ARCH}-static.tar.gz ]; then
        wget -N https://github.com/multiarch/qemu-user-static/releases/download/${QEMU_VER}/x86_64_qemu-${QEMU_ARCH}-static.tar.gz
    fi
    tar -xvf x86_64_qemu-${QEMU_ARCH}-static.tar.gz -C $ROOTFS/usr/bin/
fi


# create tarball of rootfs
if [ ! -f rootfs.tar.xz ]; then
    tar --numeric-owner -C $ROOTFS -c . | xz > rootfs.tar.xz
fi

# clean rootfs
rm -f $ROOTFS/usr/bin/qemu-*-static

# create Dockerfile
cat > Dockerfile <<EOF
FROM scratch

ADD base_rootfs_${ARCH_ARCH}.tar.gz /
ADD rootfs.tar.xz /

ENV ARCH_ARCH=${ARCH_ARCH} ARCH=${ARCH} DOCKER_REPO=${DOCKER_REPO}
EOF

# add qemu-user-static binary
if [ -n "${QEMU_ARCH}" ]; then
    cat >> Dockerfile <<EOF

# Add qemu-user-static binary for amd64 builders
ADD x86_64_qemu-${QEMU_ARCH}-static.tar.gz /usr/bin
EOF
fi

# build
docker build -t "${DOCKER_REPO}:${ARCH}-latest" .
docker run --rm "${DOCKER_REPO}:${ARCH}-latest" /bin/sh -ec "echo Hello from Archlinux !; set -x; uname -a"
