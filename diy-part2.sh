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
