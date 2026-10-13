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
  # 第一步：去掉将被删除行的前一行末尾的续行反斜杠
  sed -i '\#define KernelPackage/crypto-aead#,/endef/{
    N
    /CONFIG_CRYPTO_GENIV@lt6\.6\|geniv\.ko@lt6\.6/{
      s/\\\n/\n/
    }
    P
    D
  }' "$TARGET_FILE"
  # 第二步：删除 GENIV 相关行
  sed -i '\#define KernelPackage/crypto-aead#,/endef/{
    /CONFIG_CRYPTO_GENIV@lt6\.6/d
    /geniv\.ko@lt6\.6/d
  }' "$TARGET_FILE"
  echo "geniv fix applied."
fi

# Fix kmod-nft-fullcone build failure on kernel 5.4 (build 3, 2026-10-13)
# Lean 在 2026-10-03（commit 2a12d239）给 firewall4/nftables 加了 +kmod-nft-fullcone 硬依赖，
# 该模块源码（2023-05-17）与回滚的 5.4.255 内核 API 不兼容（nft_reg_load16 const 限定符被 -Werror 拦截）；
# .config 早已明确选用 iptables 版 fullcone。去掉该硬依赖，恢复 9-29 可构建状态。
for _f in package/network/config/firewall4/Makefile package/network/utils/nftables/Makefile; do
  if [ -f "$_f" ]; then
    echo "Stripping +kmod-nft-fullcone from $_f ..."
    sed -i 's/+kmod-nft-fullcone//g' "$_f"
  fi
done
unset _f
