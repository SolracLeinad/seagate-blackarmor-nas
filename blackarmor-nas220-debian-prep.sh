#!/bin/bash -e
#
# blackarmor-nas220-debian-prep.sh V1.00
#
# Install Debian GNU/Linux to a Seagate Blackarmor NAS 220
#
# (C) 2018-2019 Hajo Noerenberg
#
#
# http://www.noerenberg.de/
# https://github.com/hn/seagate-blackarmor-nas
#
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3.0 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.txt>.
#

DEBDIST=stretch
DEBMIRROR=https://deb.debian.org/debian/dists/$DEBDIST/main/installer-armel/current/images/kirkwood
PREPDIR=blackarmor-nas220-debian

if [ ! -x /usr/bin/mkimage ]; then
	echo "'mkimage' missing, install 'u-boot-tools' package first"
	exit 1
fi

KERNELVER=$(wget -qO- $DEBMIRROR/netboot/ | sed -n 's/.*vmlinuz-\([^\t ]*\)-marvell.*/\1/p')

echo "Using Debian dist '$DEBDIST' with kernel $KERNELVER for installation."

test -d $PREPDIR || mkdir -v $PREPDIR
cd $PREPDIR

rm -vf uImage-dtb uInitrd

if false; then # intentionally disabled
	test -x /usr/bin/arm-none-eabi-gcc || apt-get install gcc-arm-none-eabi
	wget -nc ftp://ftp.denx.de/pub/u-boot/u-boot-2017.11.tar.bz2
	tar xjf u-boot-2017.11.tar.bz2
	cd u-boot-2017.11
	export CROSS_COMPILE=arm-none-eabi-
	export ARCH=arm
	make nas220_defconfig
	make -j2
	./tools/mkimage -n ./board/Seagate/nas220/kwbimage.cfg -T kwbimage -a 0x00600000 -e 0x00600000 -d u-boot.bin ../u-boot.kwb
	cd ..
else
	wget -nv -nc https://raw.githubusercontent.com/hn/seagate-blackarmor-nas/master/u-boot.kwb
fi

if [ -f u-boot-env.txt -a -x ./u-boot-2017.11/tools/mkenvimage ]; then
	./u-boot-2017.11/tools/mkenvimage -p 0 -s 65536 -o u-boot-env.bin u-boot-env.txt
else
	wget -nv -nc https://raw.githubusercontent.com/hn/seagate-blackarmor-nas/master/u-boot-env.bin
fi

wget -nv -nc $DEBMIRROR/netboot/initrd.gz
wget -nv -nc $DEBMIRROR/netboot/vmlinuz-$KERNELVER-marvell
wget -nv -nc $DEBMIRROR/device-tree/kirkwood-blackarmor-nas220.dtb

echo

cat vmlinuz-$KERNELVER-marvell kirkwood-blackarmor-nas220.dtb > vmlinuz-$KERNELVER-marvell-kirkwood-blackarmor-nas220-dtb

mkimage -A arm -O linux -T kernel -C none -a 0x40000 -e 0x40000 \
	-n "Linux-$KERNELVER + nas220.dtb" \
	-d vmlinuz-$KERNELVER-marvell-kirkwood-blackarmor-nas220-dtb uImage-dtb

echo

mkimage -A arm -O linux -T ramdisk -C none \
	-n "Debian $DEBDIST netboot initrd" -d initrd.gz uInitrd

echo

UBOOTKWBASIZE=0x$(printf "%x" $((512 * $(($(($(stat -c "%s" u-boot.kwb) + 511)) / 512)))))
echo "u-boot.kwb file size (512-byte aligned): $UBOOTKWBASIZE"   
UBOOTENVASIZE=0x$(printf "%x" $((512 * $(($(($(stat -c "%s" u-boot-env.bin) + 511)) / 512)))))
echo "u-boot-env.bin file size (512-byte aligned): $UBOOTENVASIZE"   
echo
echo "Execute the following commands on the Blackarmor NAS:"
echo
echo "usb start"
echo "fatload usb 0:1 0x800000 u-boot.kwb"
echo "nand erase 0x0 $UBOOTKWBASIZE"
echo "nand write 0x800000 0x0 $UBOOTKWBASIZE"
echo "fatload usb 0:1 0x800000 u-boot-env.bin"
echo "nand erase 0xA0000 $UBOOTENVASIZE"
echo "nand write 0x800000 0xA0000 $UBOOTENVASIZE"

echo

