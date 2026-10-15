#!/bin/bash
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# set zram_comp_algo default to lz4
sed -i 's/zram_comp_algo="lzo"/zram_comp_algo="lz4"/g' package/system/zram-swap/files/zram.init
echo vm.swappiness=10 >> package/base-files/files/etc/sysctl.conf

# Fix kmod-crypto-aead geniv build failure on kernel 5.4
TARGET_FILE="package/kernel/linux/modules/crypto.mk"
if [ -f "$TARGET_FILE" ]; then
  echo "Patching $TARGET_FILE to remove geniv ..."
  sed -i '\#define KernelPackage/crypto-aead#,/endef/{
    N
    /CONFIG_CRYPTO_GENIV@lt6\.6\|geniv\.ko@lt6\.6/{
      s/\\\n/\n/
    }
    P
    D
  }' "$TARGET_FILE"
  sed -i '\#define KernelPackage/crypto-aead#,/endef/{
    /CONFIG_CRYPTO_GENIV@lt6\.6/d
    /geniv\.ko@lt6\.6/d
  }' "$TARGET_FILE"
  echo "geniv fix applied."
fi

# Fix kmod-nft-fullcone build failure on kernel 5.4
for _f in package/network/config/firewall4/Makefile package/network/utils/nftables/Makefile; do
  if [ -f "$_f" ]; then
    echo "Stripping +kmod-nft-fullcone from $_f ..."
    sed -i 's/+kmod-nft-fullcone//g' "$_f"
  fi
done
unset _f

# 恢复回滚版的 ipq-wifi board 固件包（主线已删除 asus_rt-acrh17，需与回滚的 image Makefile 配套）
# 工作流的回滚未覆盖 package/firmware/ipq-wifi/，导致无线 board-2.bin 缺失、无线页面不显示
if [ -d "package/firmware/ipq-wifi" ]; then
  echo "Restoring ipq-wifi from 61d090c ..."
  rm -rf package/firmware/ipq-wifi
  git checkout 61d090cddb5d0949c3a4d5c4639e5bb19a3a4bed -- package/firmware/ipq-wifi/
fi

# 只为华硕 RT-ACRH17/RT-AC42U 生成镜像：删掉其它机型的 TARGET_DEVICES，
# 避免缺 U-Boot 等外部依赖导致构建失败（回滚版源码的 Kconfig 设备选择未生效）
# 注意：必须放在 $(eval $(call BuildImage)) 之前，否则 foreach 展开时列表为空
IMG_MK="target/linux/ipq40xx/image/Makefile"
if [ -f "$IMG_MK" ]; then
  echo "Pinning TARGET_DEVICES to asus_rt-acrh17 ..."
  sed -i '/^TARGET_DEVICES +=/d' "$IMG_MK"
  sed -i '/^\$(eval \$(call BuildImage))$/d' "$IMG_MK"
  printf 'TARGET_DEVICES += asus_rt-acrh17\n\n$(eval $(call BuildImage))\n' >> "$IMG_MK"
fi
unset IMG_MK

# 默认 root 密码设为 'password'（MD5 crypt）
ROOT_HASH='$1$wEeCo9Pr$3Gl/N4mJWkccZ5QTo8qij1'
if [ -f "package/base-files/files/etc/shadow" ]; then
  echo "Setting default root password ..."
  sed -i "s|^root::|root:${ROOT_HASH}:|" package/base-files/files/etc/shadow
fi
unset ROOT_HASH

# 首次开机自动启用无线：2.4G SSID=openwrt，5G SSID=openwrt_5G，均无密码
# 注意：RT-ACRH17 上 radio0=5GHz，radio1=2.4GHz（与常规相反）
mkdir -p files/etc
cat > files/etc/rc.local << 'RCLOCAL'
# Put your custom commands here that should be executed once
# the system init finished. By default this file does nothing.

# First-boot: enable wifi with open SSIDs (runs once)
# RT-ACRH17: radio0=5GHz, radio1=2.4GHz
if [ ! -f /etc/.wifi_default_done ]; then
  for i in $(seq 1 30); do
    [ -f /etc/config/wireless ] && break
    sleep 2
  done
  if [ -f /etc/config/wireless ]; then
    uci set wireless.radio0.disabled='0'
    uci set wireless.default_radio0.ssid='openwrt_5G'
    uci set wireless.default_radio0.encryption='none'
    uci delete wireless.default_radio0.key 2>/dev/null
    uci set wireless.radio1.disabled='0'
    uci set wireless.default_radio1.ssid='openwrt'
    uci set wireless.default_radio1.encryption='none'
    uci delete wireless.default_radio1.key 2>/dev/null
    uci commit wireless
    wifi reload
  fi
  touch /etc/.wifi_default_done
fi

# First-boot: ZeroTier safeguard - if the UCI 'secret' looks like a 16-char
# Network ID (user mistakenly put Network ID in the "client secret" field),
# remove it so zerotier-one generates a proper identity instead of crashing.
# The correct way to join a network is: zerotier-cli join <network_id>
if [ ! -f /etc/.zt_secret_fixed ]; then
  ZT_SEC="$(uci get zerotier.global.secret 2>/dev/null)"
  if echo "$ZT_SEC" | grep -qE '^[0-9a-fA-F]{16}$'; then
    logger -t zerotier-fix "Removing Network ID mistakenly set as secret; use 'zerotier-cli join <id>' instead"
    uci delete zerotier.global.secret
    uci commit zerotier
    rm -f /var/lib/zerotier-one/identity.secret /var/lib/zerotier-one/identity.public
  fi
  touch /etc/.zt_secret_fixed
fi

exit 0
RCLOCAL

# Patch AirConnect: add audio codec selection (LuCI dropdown + init script support)
# 补丁文件在 $GITHUB_WORKSPACE/patches/airconnect/
PATCH_DIR="$GITHUB_WORKSPACE/patches/airconnect"
if [ -d "$PATCH_DIR" ]; then
  echo "Applying AirConnect codec patch..."
  cp "$PATCH_DIR/airconnect.js" package/luci-app-airconnect/htdocs/luci-static/resources/view/airconnect.js
  cp "$PATCH_DIR/airconnect.po" package/luci-app-airconnect/po/zh_Hans/airconnect.po
  cp "$PATCH_DIR/airconnect.init" package/airconnect/files/airconnect.init
  cp "$PATCH_DIR/airconnect.config" package/airconnect/files/airconnect.config
  echo "AirConnect codec patch applied."
fi
