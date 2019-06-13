#!/bin/sh -x

DISK=riscv_disk
BBL=bbl

GUEST_IP=10.0.2.20

sudo qemu-system-riscv64 \
      -machine virt \
      -kernel $BBL \
      -nographic \
      -append "root=/dev/vda ro" \
      -m 128 \
      -drive file=$DISK,format=raw,id=hd0      \
      -device virtio-blk-device,drive=hd0       \
      -netdev user,id=net0,hostfwd=tcp::2323-$GUEST_IP:23,hostfwd=tcp::8080-$GUEST_IP:80 \
      -device virtio-net-device,netdev=net0

