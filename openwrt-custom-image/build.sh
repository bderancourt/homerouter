#!/bin/bash
set -x
set -e

# https://firmware-selector.openwrt.org/
readonly IMAGEBUILDER_URL=https://downloads.openwrt.org/releases/22.03.3/targets/x86/64/openwrt-imagebuilder-22.03.3-x86-64.Linux-x86_64.tar.xz
IMAGEBUILDER_FILENAME=$(basename $IMAGEBUILDER_URL)
readonly IMAGEBUILDER_FILENAME
readonly OUTPUT=output

# cleaning images directory
if [ -d $OUTPUT ]; then
    rm -rf $OUTPUT
fi
mkdir $OUTPUT

# download openwrt image builder if it doesn't already exist
if [ ! -f "$IMAGEBUILDER_FILENAME" ]; then
    wget $IMAGEBUILDER_URL
fi

IMAGEBUILDER_PATH=$(tar --exclude="*/*" -tf "$IMAGEBUILDER_FILENAME" | sed 's:/*$::')
readonly IMAGEBUILDER_PATH

# if already deflated, clean directory
if [ -d "$IMAGEBUILDER_PATH" ]; then
    (cd "$IMAGEBUILDER_PATH" && make clean)
    rm -rf "$IMAGEBUILDER_PATH/files"
    # overwriting .config with the default one
    tar -Jxf "$IMAGEBUILDER_FILENAME" "$IMAGEBUILDER_PATH/.config"
else
    # deflate
    tar -Jxf "$IMAGEBUILDER_FILENAME"
fi

# copy custom files to impage builder 'files' path
cp -rv custom_files/* "$IMAGEBUILDER_PATH/files"

mkdir -p "$IMAGEBUILDER_PATH/files/etc/dropbear"
cp ~/.ssh/id_rsa.pub "$IMAGEBUILDER_PATH/files/etc/dropbear/authorized_keys"

# update rootfs partition size to 256
sed -i "s/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/g" "$IMAGEBUILDER_PATH/.config"

# build custom image
(cd "$IMAGEBUILDER_PATH" && make image PROFILE=generic FILES="files" PACKAGES="\
htop vim less usbutils dmesg ip-full ifstat luci pciutils lm-sensors smartmontools \
coreutils-base64 coreutils-md5sum coreutils-sha1sum \
lsblk losetup resize2fs parted \
curl drill luci-app-ddns \
dnsmasq-full stubby -dnsmasq \
docker dockerd luci-app-dockerman docker-compose kmod-macvlan kmod-ipvlan \
luci-app-sqm sqm-scripts \
-ppp -ppp-mod-pppoe \
-kmod-amazon-ena -kmod-amd-xgbe -kmod-bnx2 -kmod-e1000e -kmod-e1000 \
-kmod-forcedeth -kmod-igb -kmod-ixgbe -kmod-r8169 -kmod-tg3")

# move generated images to output dir
mv "$IMAGEBUILDER_PATH"/bin/targets/x86/64/* "$OUTPUT"
gunzip "$OUTPUT"/openwrt-22.03.3-x86-64-generic-squashfs-combined-efi.img.gz
gunzip "$OUTPUT"/openwrt-22.03.3-x86-64-generic-ext4-combined-efi.img.gz
qemu-img convert -f raw -O vmdk "$OUTPUT"/openwrt-22.03.3-x86-64-generic-squashfs-combined-efi.img \
 "$OUTPUT"/openwrt-22.03.3-x86-64-generic-squashfs-combined-efi.vmdk
