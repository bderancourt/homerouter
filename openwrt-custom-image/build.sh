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

# copy custom files templates folder to tmp dir
tmpdir=$(mktemp -d)
echo "tmpdir=$tmpdir"
cp -rv custom_files_templates/* "$tmpdir"

# source custom_files_envs to process the 'custom files templates' files
set -a
# shellcheck disable=SC1091
source custom_files_envs
set +a

# prepare all the variables in custom_files_envs for the env substitute command
# shellcheck disable=SC2016
env_to_substitute=$(sed 's/[=#].*//' custom_files_envs | awk NF | xargs printf '${%s} ')
echo $env_to_substitute

# for each 'custom files templates' file, replace the variables
find "$tmpdir" -type f -print0 | while IFS= read -r -d '' file
do
    dirname=$(dirname "$file")
    basename=$(basename "$file")
    ( cd "$dirname" && envsubst "$env_to_substitute" < "$basename" | sponge "$basename")
done

# copy custom files templates to impage builder 'files' path
cp -rv "$tmpdir" "$IMAGEBUILDER_PATH/files"
rm -rf "$tmpdir"

# update rootfs partition size to 256
sed -i "s/CONFIG_TARGET_ROOTFS_PARTSIZE=.*/CONFIG_TARGET_ROOTFS_PARTSIZE=512/g" "$IMAGEBUILDER_PATH/.config"

# don't build squashfs images
sed -i "s/CONFIG_TARGET_ROOTFS_SQUASHFS=.*/CONFIG_TARGET_ROOTFS_SQUASHFS=n/g" "$IMAGEBUILDER_PATH/.config"

# build custom image
(cd "$IMAGEBUILDER_PATH" && make image PROFILE=generic FILES="files" PACKAGES="\
htop vim less usbutils dmesg ip-full ifstat luci ntpdate pciutils lm-sensors \
lsblk losetup resize2fs parted \
curl drill luci-app-ddns \
dnsmasq-full stubby -dnsmasq \
docker dockerd luci-app-dockerman docker-compose kmod-macvlan kmod-ipvlan \
luci-app-sqm sqm-scripts \
-ppp -ppp-mod-pppoe \
-kmod-amazon-ena -kmod-amd-xgbe -kmod-bnx2 -kmod-e1000e -kmod-e1000 \
-kmod-forcedeth -kmod-igb -kmod-ixgbe -kmod-r8169 -kmod-tg3")

# move generated images to output dir
mv "$IMAGEBUILDER_PATH"/bin/targets/x86/64/*combined-efi.img.gz* "$OUTPUT"
gunzip "$OUTPUT"/openwrt-22.03.3-x86-64-generic-ext4-combined-efi.img.gz
#sudo dd if=openwrt-rockchip-armv8-friendlyarm_nanopi-r4s-ext4-sysupgrade.img of=/dev/sdc bs=32M
