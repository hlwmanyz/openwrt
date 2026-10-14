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
