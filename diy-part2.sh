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
# (参考 yinzhefuyun 成功构建：5.4 老内核编不过 geniv.ko，从 crypto.mk 里去掉)
TARGET_FILE="package/kernel/linux/modules/crypto.mk"
if [ -f "$TARGET_FILE" ]; then
  echo "Patching $TARGET_FILE to remove geniv ..."
  sed -i '/define KernelPackage\/crypto-aead/,/endef/{
    /CONFIG_CRYPTO_GENIV@lt6\.6/d
    /geniv\.ko@lt6\.6/d
  }' "$TARGET_FILE"
  # 去掉被删行前一行末尾多余的反斜杠续行符
  sed -i '/define KernelPackage\/crypto-aead/,/endef/{
    s|$(LINUX_DIR)/crypto/aead.ko \\|$(LINUX_DIR)/crypto/aead.ko|
  }' "$TARGET_FILE"
  echo "geniv fix applied."
fi
