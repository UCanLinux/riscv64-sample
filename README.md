# Building a busybox based RiscV-64-bit GNU/Linux system image from scratch for the virt machine

This repository has a derivative work from [busybear-linux](https://github.com/michaeljclark/busybear-linux.git)
and has only a few minor differences.

The differences are

 - `user mode network stack` used at qemu
 - created `read only` root file system, so it resistant to sudden power-off
 - the disk image is created from scratch
 - has a skeleton file system
 - the skeleton file system is filled by means of busybox, toolchain and Linux kernel
 - has a telnet server, a http server and a NFS client example

## quick start
This repo has a ready to run bbl bootloader with Linux kernel and ready to mount a root file system named `riscv_disk`

```
# clone this repository
git clone https://github.com/UCanLinux/riscv64-sample.git sample
cd sample
export PATH=.:$PATH
./run.sh
login as root, password is root
power-off the system with poweroff command
```

## files and directories

```
|-- bbl                  BBL bootloader with Linux kernel
|-- bbl_logo_file        Boot loader logo file
|-- busybox.config       config file for busybox
|-- hello.c              hello world code in C
|-- kernel.config        config file for Linux kernel
|-- qemu-system-riscv64  qemu program for 64 bit RISC-V systems
|-- README.md            this file
|-- riscv_disk           ready to mount root file system
|-- run.sh               run qemu program
`-- skeleton             skeleton file for the root file system

```

## create project home

You need about 15GB disk space. The project home is `/opt/riscv`

```
export RISCV=/opt/riscv

sudo mkdir -p $RISCV/src
sudo chown -R yourOwner:yourGroup $RISCV

# clone this repository to under src/ directory
cd $RISCV/src
git clone https://github.com/UCanLinux/riscv64-sample.git  sample 
```

## toolchain
```
cd $RISCV/src
git clone --recursive https://github.com/riscv/riscv-gnu-toolchain toolchain
cd toolchain
./configure --prefix=$RISCV
make linux -j$(nproc)
```

## Linux
```
cd $RISCV/src
git clone https://github.com/riscv/riscv-linux.git linux
cd linux
git checkout riscv-linux-4.20

make ARCH=riscv defconfig
make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- menuconfig
# OR
cp ../sample/kernel.config .config
make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- menuconfig

make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu-  all -j$(nproc)
```

## boot loader, BBL
```
cd $RISCV/src
git clone https://github.com/riscv/riscv-pk.git pk
cd pk
mkdir build 
cd build
../configure --enable-logo --host=riscv64-unknown-linux-gnu --with-payload=$RISCV/src/linux/vmlinux --prefix=$RISCV

cp $RISCV/src/sample/bbl_logo_file $RISCV/src/pk/build   # optional

make -j$(nproc)
make install

# strip bbl file
cd $RISCV/riscv64-unknown-linux-gnu/bin
chmod 755 bbl
riscv64-unknown-linux-gnu-strip bbl
```

## busybox
```
cd $RISCV/src/
git clone git://busybox.net/busybox.git
cd busybox
git checkout 1_30_stable  # checkout the latest stable branch
make menuconfig

cp ../sample/busybox.config .config  # optional
make menuconfig

make CROSS_COMPILE=riscv64-unknown-linux-gnu- all -j$(nproc)

make CROSS_COMPILE=riscv64-unknown-linux-gnu- install
```

## build root file system
```
cd $RISCV/src/sample
mkdir RootFS
cd RootFS
cp -a ../skeleton/* .

# install linux commands provided by busybox
cd $RISCV/src/sample/RootFS
cp -a ../../busybox/_install/* .

# install modules from Linux kernel
cd $RISCV/src/linux
make ARCH=riscv CROSS_COMPILE=riscv64-unknown-linux-gnu- INSTALL_MOD_PATH=$RISCV/src/RootFS modules_install

# install libraries from toolchain
cd $RISCV/src/sample/RootFS
cp -a /opt/riscv/sysroot/lib  .

# remove unneeded libraries and files
cd $RISCV/src/sample/RootFS/lib
rm -f *.a *.la *.spec *fortran* ../linuxrc

# create empty directories

cd $RISCV/src/sample/RootFS
mkdir dev home mnt proc sys tmp var

cd etc/network
mkdir if-down.d  if-post-down.d  if-pre-up.d  if-up.d 
```

## create a disk with 50MB capacity
```
cd $RISCV/src/sample
dd if=/dev/zero of=riscv_disk bs=1M count=50
```

## make a root filesystem 
```
mkfs.ext2 -L riscv-rootfs riscv_disk

sudo mkdir /mnt/rootfs
sudo mount riscv_disk /mnt/rootfs

sudo cp -a RootFS/* /mnt/rootfs

sudo chown -R -h root:root /mnt/rootfs/
df /mnt/rootfs
cd $RISCV/src/sample
sudo umount /mnt/rootfs
file riscv_disk
```

## qemu
```
cd $RISCV/src
git clone https://git.qemu.org/git/qemu.git
cd qemu
./configure --target-list=riscv64-softmmu,riscv32-softmmu --prefix=$RISCV
make -j$(nproc)
make install

export PATH=$RISCV/bin:$PATH
```

## start Linux 
```
cd $RISCV/src/sample
cp $RISCV/riscv64-unknown-linux-gnu/bin/bbl .
./run.sh

bbl loader
 ____  _        __     __ 
|  _ \(_)___  __\ \   / / 
| |_) | / __|/ __\ \ / /  
|  _ <| \__ \ (__ \ V /   
|_| \_\_|___/\___| \_/    

INSTRUCTION SETS WANT TO BE FREE

[    0.000000] OF: fdt: Ignoring memory range 0x80000000 - 0x80200000
[    0.000000] Linux version 4.20.0+ (nazim@nkoc) (gcc version 8.3.0 (GCC)) #1 SMP Wed Jun 12 20:38:32 +03 2019
[    0.000000] printk: bootconsole [early0] enabled
[    0.000000] initrd not found or empty - disabling initrd
[    0.000000] Zone ranges:
[    0.000000]   DMA32    [mem 0x0000000080200000-0x0000000087ffffff]
[    0.000000]   Normal   [mem 0x0000000088000000-0x0000087fffffffff]
[    0.000000] Movable zone start for each node
[    0.000000] Early memory node ranges
[    0.000000]   node   0: [mem 0x0000000080200000-0x0000000087ffffff]
[    0.000000] Initmem setup node 0 [mem 0x0000000080200000-0x0000000087ffffff]
[    0.000000] software IO TLB: mapped [mem 0x83e3c000-0x87e3c000] (64MB)
[    0.000000] elf_hwcap is 0x112d
[    0.000000] percpu: Embedded 17 pages/cpu @(____ptrval____) s29400 r8192 d32040 u69632
[    0.000000] Built 1 zonelists, mobility grouping on.  Total pages: 31815
[    0.000000] Kernel command line: root=/dev/vda ro
[    0.000000] Dentry cache hash table entries: 16384 (order: 5, 131072 bytes)
[    0.000000] Inode-cache hash table entries: 8192 (order: 4, 65536 bytes)
[    0.000000] Sorting __ex_table...
[    0.000000] Memory: 53044K/129024K available (4941K kernel code, 332K rwdata, 1712K rodata, 176K init, 802K bss, 75980K reserved, 0K cma-reserved)
[    0.000000] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
[    0.000000] rcu: Hierarchical RCU implementation.
[    0.000000] rcu: 	RCU restricting CPUs from NR_CPUS=8 to nr_cpu_ids=1.
[    0.000000] rcu: RCU calculated value of scheduler-enlistment delay is 25 jiffies.
[    0.000000] rcu: Adjusting geometry for rcu_fanout_leaf=16, nr_cpu_ids=1
[    0.000000] NR_IRQS: 0, nr_irqs: 0, preallocated irqs: 0
[    0.000000] plic: mapped 53 interrupts to 1 (out of 2) handlers.
[    0.000000] clocksource: riscv_clocksource: mask: 0xffffffffffffffff max_cycles: 0x24e6a1710, max_idle_ns: 440795202120 ns
[    0.000000] Console: colour dummy device 80x25
[    0.000000] printk: console [tty0] enabled
[    0.004000] printk: bootconsole [early0] disabled
[    0.000000] OF: fdt: Ignoring memory range 0x80000000 - 0x80200000
[    0.000000] Linux version 4.20.0+ (nazim@nkoc) (gcc version 8.3.0 (GCC)) #1 SMP Wed Jun 12 20:38:32 +03 2019
[    0.000000] printk: bootconsole [early0] enabled
[    0.000000] initrd not found or empty - disabling initrd
[    0.000000] Zone ranges:
[    0.000000]   DMA32    [mem 0x0000000080200000-0x0000000087ffffff]
[    0.000000]   Normal   [mem 0x0000000088000000-0x0000087fffffffff]
[    0.000000] Movable zone start for each node
[    0.000000] Early memory node ranges
[    0.000000]   node   0: [mem 0x0000000080200000-0x0000000087ffffff]
[    0.000000] Initmem setup node 0 [mem 0x0000000080200000-0x0000000087ffffff]
[    0.000000] software IO TLB: mapped [mem 0x83e3c000-0x87e3c000] (64MB)
[    0.000000] elf_hwcap is 0x112d
[    0.000000] percpu: Embedded 17 pages/cpu @(____ptrval____) s29400 r8192 d32040 u69632
[    0.000000] Built 1 zonelists, mobility grouping on.  Total pages: 31815
[    0.000000] Kernel command line: root=/dev/vda ro
[    0.000000] Dentry cache hash table entries: 16384 (order: 5, 131072 bytes)
[    0.000000] Inode-cache hash table entries: 8192 (order: 4, 65536 bytes)
[    0.000000] Sorting __ex_table...
[    0.000000] Memory: 53044K/129024K available (4941K kernel code, 332K rwdata, 1712K rodata, 176K init, 802K bss, 75980K reserved, 0K cma-reserved)
[    0.000000] SLUB: HWalign=64, Order=0-3, MinObjects=0, CPUs=1, Nodes=1
[    0.000000] rcu: Hierarchical RCU implementation.
[    0.000000] rcu: 	RCU restricting CPUs from NR_CPUS=8 to nr_cpu_ids=1.
[    0.000000] rcu: RCU calculated value of scheduler-enlistment delay is 25 jiffies.
[    0.000000] rcu: Adjusting geometry for rcu_fanout_leaf=16, nr_cpu_ids=1
[    0.000000] NR_IRQS: 0, nr_irqs: 0, preallocated irqs: 0
[    0.000000] plic: mapped 53 interrupts to 1 (out of 2) handlers.
[    0.000000] clocksource: riscv_clocksource: mask: 0xffffffffffffffff max_cycles: 0x24e6a1710, max_idle_ns: 440795202120 ns
[    0.000000] Console: colour dummy device 80x25
[    0.000000] printk: console [tty0] enabled
[    0.004000] printk: bootconsole [early0] disabled
[    0.004000] Calibrating delay loop (skipped), value calculated using timer frequency.. 20.00 BogoMIPS (lpj=40000)
[    0.004000] pid_max: default: 32768 minimum: 301
[    0.008000] Mount-cache hash table entries: 512 (order: 0, 4096 bytes)
[    0.008000] Mountpoint-cache hash table entries: 512 (order: 0, 4096 bytes)
[    0.048000] rcu: Hierarchical SRCU implementation.
[    0.052000] smp: Bringing up secondary CPUs ...
[    0.052000] smp: Brought up 1 node, 1 CPU
[    0.104000] devtmpfs: initialized
[    0.112000] random: get_random_u32 called from bucket_table_alloc+0x70/0x176 with crng_init=0
[    0.116000] clocksource: jiffies: mask: 0xffffffff max_cycles: 0xffffffff, max_idle_ns: 7645041785100000 ns
[    0.116000] futex hash table entries: 256 (order: 2, 16384 bytes)
[    0.120000] NET: Registered protocol family 16
[    0.180000] vgaarb: loaded
[    0.184000] SCSI subsystem initialized
[    0.184000] usbcore: registered new interface driver usbfs
[    0.184000] usbcore: registered new interface driver hub
[    0.188000] usbcore: registered new device driver usb
[    0.200000] clocksource: Switched to clocksource riscv_clocksource
[    0.224000] NET: Registered protocol family 2
[    0.236000] tcp_listen_portaddr_hash hash table entries: 256 (order: 0, 4096 bytes)
[    0.236000] TCP established hash table entries: 1024 (order: 1, 8192 bytes)
[    0.236000] TCP bind hash table entries: 1024 (order: 2, 16384 bytes)
[    0.236000] TCP: Hash tables configured (established 1024 bind 1024)
[    0.240000] UDP hash table entries: 256 (order: 1, 8192 bytes)
[    0.240000] UDP-Lite hash table entries: 256 (order: 1, 8192 bytes)
[    0.240000] NET: Registered protocol family 1
[    0.248000] RPC: Registered named UNIX socket transport module.
[    0.248000] RPC: Registered udp transport module.
[    0.248000] RPC: Registered tcp transport module.
[    0.248000] RPC: Registered tcp NFSv4.1 backchannel transport module.
[    0.264000] workingset: timestamp_bits=62 max_order=14 bucket_order=0
[    0.292000] NFS: Registering the id_resolver key type
[    0.292000] Key type id_resolver registered
[    0.292000] Key type id_legacy registered
[    0.292000] nfs4filelayout_init: NFSv4 File Layout Driver Registering...
[    0.316000] NET: Registered protocol family 38
[    0.316000] Block layer SCSI generic (bsg) driver version 0.4 loaded (major 254)
[    0.316000] io scheduler noop registered
[    0.316000] io scheduler deadline registered
[    0.316000] io scheduler cfq registered (default)
[    0.316000] io scheduler mq-deadline registered
[    0.316000] io scheduler kyber registered
[    0.460000] Serial: 8250/16550 driver, 4 ports, IRQ sharing disabled
[    0.468000] 10000000.uart: ttyS0 at MMIO 0x10000000 (irq = 10, base_baud = 230400) is a 16550A
[    0.504000] printk: console [ttyS0] enabled
[    0.504000] [drm] radeon kernel modesetting enabled.
[    0.532000] loop: module loaded
[    0.556000] virtio_blk virtio0: [vda] 131072 512-byte logical blocks (67.1 MB/64.0 MiB)
[    0.592000] libphy: Fixed MDIO Bus: probed
[    0.600000] ehci_hcd: USB 2.0 'Enhanced' Host Controller (EHCI) Driver
[    0.600000] ehci-pci: EHCI PCI platform driver
[    0.600000] ehci-platform: EHCI generic platform driver
[    0.600000] ohci_hcd: USB 1.1 'Open' Host Controller (OHCI) Driver
[    0.600000] ohci-pci: OHCI PCI platform driver
[    0.600000] ohci-platform: OHCI generic platform driver
[    0.604000] usbcore: registered new interface driver uas
[    0.604000] usbcore: registered new interface driver usb-storage
[    0.608000] mousedev: PS/2 mouse device common for all mice
[    0.608000] usbcore: registered new interface driver usbhid
[    0.612000] usbhid: USB HID core driver
[    0.616000] NET: Registered protocol family 10
[    0.632000] Segment Routing with IPv6
[    0.632000] sit: IPv6, IPv4 and MPLS over IPv4 tunneling driver
[    0.636000] NET: Registered protocol family 17
[    0.636000] Key type dns_resolver registered
[    0.684000] EXT4-fs (vda): mounted filesystem without journal. Opts: (null)
[    0.684000] VFS: Mounted root (ext4 filesystem) readonly on device 254:0.
[    0.692000] devtmpfs: mounted
[    0.724000] Freeing unused kernel memory: 176K
[    0.724000] This architecture does not have kernel memory protection.
[    0.724000] Run /sbin/init as init process


 _   _  ____            _     _                  
| | | |/ ___|__ _ _ __ | |   (_)_ __  _   ___  __
| | | | |   / _` | '_ \| |   | | '_ \| | | \ \/ /
| |_| | |__| (_| | | | | |___| | | | | |_| |>  < 
 \___/ \____\__,_|_| |_|_____|_|_| |_|\__,_/_/\_\
Welcome to RiscV

UCanLinux login: root
Password: root

root@UCanLinux:~ # uname -a

Linux UCanLinux 4.20.0+ #1 SMP Wed Jun 12 20:38:32 +03 2019 riscv64 GNU/Linux

root@UCanLinux:~ # cat /proc/filesystems 
nodev	sysfs
nodev	rootfs
nodev	ramfs
nodev	bdev
nodev	proc
nodev	cgroup
nodev	cgroup2
nodev	tmpfs
nodev	devtmpfs
nodev	sockfs
nodev	bpf
nodev	pipefs
nodev	rpc_pipefs
nodev	devpts
	ext3
	ext4
	ext2
	vfat
	msdos
nodev	nfs
nodev	nfs4
nodev	autofs
nodev	mqueue

root@UCanLinux:~ # cat /etc/network/interfaces 

auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
  address     10.0.2.20
  netmask 255.255.255.0
  broadcast  10.0.2.255
  gateway      10.0.2.2

root@UCanLinux:~ # pstree -p

init(1)-+-httpd(67)
        |-klogd(64)
        |-sh(81)---pstree(86)
        |-syslogd(62)
        `-telnetd(69)

root@UCanLinux:~ # top -b -n1

Mem: 16900K used, 36320K free, 36K shrd, 348K buff, 2988K cached
CPU:  6.2% usr 25.0% sys  0.0% nic 68.7% idle  0.0% io  0.0% irq  0.0% sirq
Load average: 0.00 0.00 0.00 1/37 89
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
   89    81 root     R     3020  5.6   0 31.2 top -b -n1
    1     0 root     S     3020  5.6   0  0.0 init
   81     1 root     S     3020  5.6   0  0.0 -sh
   62     1 root     S     3020  5.6   0  0.0 syslogd
   64     1 root     S     3020  5.6   0  0.0 klogd
   67     1 root     S     3020  5.6   0  0.0 httpd -h /var/www
   69     1 root     S     3020  5.6   0  0.0 telnetd -f /etc/issue
   13     2 root     SW       0  0.0   0  0.0 [kdevtmpfs]
    7     2 root     IW       0  0.0   0  0.0 [kworker/u2:0-ev]
   22     2 root     IW       0  0.0   0  0.0 [kworker/0:1-eve]
    2     0 root     SW       0  0.0   0  0.0 [kthreadd]
    3     2 root     IW<      0  0.0   0  0.0 [rcu_gp]
    4     2 root     IW<      0  0.0   0  0.0 [rcu_par_gp]
    5     2 root     IW       0  0.0   0  0.0 [kworker/0:0-eve]
    6     2 root     IW<      0  0.0   0  0.0 [kworker/0:0H-kb]
    8     2 root     IW<      0  0.0   0  0.0 [mm_percpu_wq]
    9     2 root     SW       0  0.0   0  0.0 [ksoftirqd/0]
   10     2 root     IW       0  0.0   0  0.0 [rcu_sched]
   11     2 root     SW       0  0.0   0  0.0 [migration/0]
   12     2 root     SW       0  0.0   0  0.0 [cpuhp/0]
   14     2 root     IW<      0  0.0   0  0.0 [netns]
   15     2 root     SW       0  0.0   0  0.0 [oom_reaper]
   16     2 root     IW<      0  0.0   0  0.0 [writeback]
   17     2 root     SW       0  0.0   0  0.0 [kcompactd0]
   18     2 root     IW<      0  0.0   0  0.0 [crypto]
   19     2 root     IW<      0  0.0   0  0.0 [kblockd]
   20     2 root     IW<      0  0.0   0  0.0 [ata_sff]
   21     2 root     IW<      0  0.0   0  0.0 [rpciod]
   23     2 root     IW<      0  0.0   0  0.0 [kworker/u3:0]
   24     2 root     IW<      0  0.0   0  0.0 [xprtiod]
   25     2 root     SW       0  0.0   0  0.0 [kswapd0]
   26     2 root     IW<      0  0.0   0  0.0 [nfsiod]
   28     2 root     IW       0  0.0   0  0.0 [kworker/u2:1]
   40     2 root     SW       0  0.0   0  0.0 [khvcd]
   41     2 root     IW<      0  0.0   0  0.0 [kworker/0:1H-kb]
   42     2 root     IW<      0  0.0   0  0.0 [ipv6_addrconf]
   43     2 root     IW<      0  0.0   0  0.0 [ext4-rsv-conver]

root@UCanLinux:~ # free

              total        used        free      shared  buff/cache   available
Mem:          53220       13560       36324          36        3336       37396
Swap:             0           0           0

root@UCanLinux:~ # df -a

Filesystem           1K-blocks      Used Available Use% Mounted on
/dev/root                49574     34316     12698  73% /
devtmpfs                 26520         0     26520   0% /dev
tmpfs                    26608         4     26604   0% /tmp
sysfs                        0         0         0   0% /sys
proc                         0         0         0   0% /proc
devpts                       0         0         0   0% /dev/pts
tmpfs                    26608         0     26608   0% /dev/shm
tmpfs                    26608         0     26608   0% /mnt
tmpfs                    26608        32     26576   0% /var


root@UCanLinux:~ # ifconfig

eth0      Link encap:Ethernet  HWaddr 52:54:00:12:34:56  
          inet addr:10.0.2.20  Bcast:10.0.2.255  Mask:255.255.255.0
          inet6 addr: fec0::5054:ff:fe12:3456/64 Scope:Site
          inet6 addr: fe80::5054:ff:fe12:3456/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:2 errors:0 dropped:0 overruns:0 frame:0
          TX packets:7 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:220 (220.0 B)  TX bytes:602 (602.0 B)

lo        Link encap:Local Loopback  
          inet addr:127.0.0.1  Mask:255.0.0.0
          inet6 addr: ::1/128 Scope:Host
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)

root@UCanLinux:~ # cat /etc/resolv.conf 

nameserver 8.8.8.8
nameserver 8.8.4.4

root@UCanLinux:/proc # cat /proc/cpuinfo 

processor	: 0
hart		: 0
isa		: rv64imafdcu
mmu		: sv48


root@UCanLinux:/etc # cat /proc/cmdline 

root=/dev/vda ro

root@UCanLinux:/etc # route

Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         10.0.2.2        0.0.0.0         UG    0      0        0 eth0
10.0.2.0        *               255.255.255.0   U     0      0        0 eth0

root@UCanLinux:~ # cat /proc/interrupts

           CPU0       
  7:          4  SiFive PLIC   7  virtio1
  8:        125  SiFive PLIC   8  virtio0
 10:       4442  SiFive PLIC  10  ttyS0
IPI0:         0  Rescheduling interrupts
IPI1:         0  Function call interrupts

# update root file system

root@UCanLinux:~ # touch hede
touch: hede: Read-only file system

root@UCanLinux:~ # mount -o remount,rw /
root@UCanLinux:~ # touch foo
root@UCanLinux:~ # mount -o remount,ro /

# set date and time

root@UCanLinux:~ # date
Thu Jan  1 00:00:06 UTC 1970

root@UCanLinux:~ # ntpd -d -n -q

root@UCanLinux:~ # date
Thu Jun 13 12:45:40 UTC 2019
```

Power-off the system with poweroff command, or directly close the terminal.

### telnet connection 
From host side,
```
$ telnet localhost 2323
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.

  _   _  ____            _     _                  
 | | | |/ ___|__ _ _ __ | |   (_)_ __  _   ___  __
 | | | | |   / _` | '_ \| |   | | '_ \| | | \ \/ /
 | |_| | |__| (_| | | | | |___| | | | | |_| |>  < 
  \___/ \____\__,_|_| |_|_____|_|_| |_|\__,_/_/\_\
  Welcome to RiscV

  UCanLinux login: root
  Password: root

  root@UCanLinux:~ # exit
  Connection closed by foreign host.
```

### http connection
```
$ firefox http://localhost:8080
```

### share the `sample` directory with NFS 
At the host side,
```
$ cat /etc/exports
/opt/riscv/src/sample *(rw,no_subtree_check,insecure,no_root_squash)

$ sudo exportfs -avr
exporting *:/opt/riscv/src/sample
```
Enter the following mount command in the guest machine with your host IP.

```
root@UCanLinux:~ # mount -t nfs -o nolock 192.168.1.17:/opt/riscv/src/sample /mnt/nfs

root@UCanLinux:~ # df /mnt/nfs

Filesystem           1K-blocks      Used Available Use% Mounted on
192.168.1.17:/opt/riscv/src/sample
                     247891968 228905984   6370304  97% /mnt/nfs

root@UCanLinux:~ # /mnt/nfs/hello
hello RiscV

root@UCanLinux:~ # umount /mnt/nfs

root@UCanLinux:~ # poweroff
```

## Copyright and License

This practise has been written by and is
copyright (C) 2019 by NaazIm Koch <koch@UCanLinux.com> and
provided under the "MIT license".


