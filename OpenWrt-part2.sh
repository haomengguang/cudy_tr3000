#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: OpenWrt-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# # 修改 分区大小，默认 mod 分区大小为 112MB：0x7000000。改为 114MB：0x7200000 version < 24.10.3
# sed -i '/label = "ubi"/{n;s/reg = <0x5c0000 0x[0-9a-f]\+>/reg = <0x5c0000 0x7200000>/}' target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dts

# # 修改 分区大小，默认 mod 分区大小为 112MB：0x7000000。改为 114MB：0x7200000  version > 24.10.2
# sed -i '/&ubi/ { n; s/reg = <0x5c0000 0x[0-9a-f]\+>;/reg = <0x5c0000 0x7200000>;/; }' target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dts

# echo "target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dts"
# cat target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1.dts 

# 给 ubootmod 变体补 NMBM 与 SPI 校准，属性逐字取自同版本 stock 变体
# ubi reg 保持上游 0x7a40000 不动
cat >> target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts <<'EOF'

&spi_nand {
    spi-cal-enable;
    spi-cal-mode = "read-data";
    spi-cal-datalen = <7>;
    spi-cal-data = /bits/ 8 <0x53 0x50 0x49 0x4E 0x41 0x4E 0x44>;
    spi-cal-addrlen = <5>;
    spi-cal-addr = /bits/ 32 <0x0 0x0 0x0 0x0 0x0>;

    mediatek,nmbm;
    mediatek,bmt-max-ratio = <1>;
    mediatek,bmt-max-reserved-blocks = <64>;
};
EOF

D=target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts
grep -q 'mediatek,nmbm' "$D" || { echo "ERROR: nmbm missing"; exit 1; }
grep -q 'reg = <0x5c0000 0x7a40000>;' "$D" || { echo "ERROR: ubi reg unexpected"; exit 1; }
echo "=== patched $D ==="
cat "$D"

#Modify default IP
sed -i 's/192.168.1.1/192.168.9.1/g' package/base-files/files/bin/config_generate
sed -i 's/192.168.0.1/192.168.9.1/g' package/base-files/files/bin/config_generate

# 更改默认 Shell 为 zsh
sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# 修改设备名称
sed -i 's/OpenWrt/Cudy_TR3000/g' package/base-files/files/bin/config_generate

#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $BUILD_MARK-$BUILD_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

# 修改 argon 为默认主题,可根据你喜欢的修改成其他的（不选择那些会自动改变为默认主题的主题才有效果）
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile



# 修复 gcc14  mbedtls
sed -i 's|TARGET_CFLAGS := $(filter-out -O%,$(TARGET_CFLAGS)) -Wno-unterminated-string-initialization|TARGET_CFLAGS := $(filter-out -O%,$(TARGET_CFLAGS)) -Wno-unterminated-string-initialization -Wno-error=attributes -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=0|' package/libs/mbedtls/Makefile
sed -i '/-DENABLE_PROGRAMS:Bool=ON/s/$/ \\/' package/libs/mbedtls/Makefile
sed -i '/-DENABLE_PROGRAMS:Bool=ON/a \	-DENABLE_WERROR=OFF' package/libs/mbedtls/Makefile

#允许root用户编译
export FORCE_UNSAFE_CONFIGURE=1


# change br-lan ip
echo -e "view log check br-lan ip"
cat package/base-files/files/bin/config_generate |grep 192


# Temperature
JS_FILE="feeds/luci/modules/luci-mod-status/htdocs/luci-static/resources/view/status/include/10_system.js"
PO_FILE="feeds/luci/modules/luci-base/po/zh_Hans/base.po"

sed -i "s/uci.load('system')/&,/" $JS_FILE
sed -i "/uci.load('system')/a \ \t\t\tL.resolveDefault(fs.exec('/bin/sh', ['-c', 'cat /sys/class/hwmon/hwmon*/temp1_input']), {})" $JS_FILE
sed -i "/unixtime[[:space:]]*=[[:space:]]*data\[7\];/a \ \t\tvar tempData = data[9] || {};" $JS_FILE
sed -i "/luciversion = luciversion.branch/a \ \t\tvar stdout = (tempData \&\& tempData.stdout) ? tempData.stdout.trim() : ''; var lines = stdout.split(/\\\\s+/); var cT = lines[1] ? (parseInt(lines[1])\/1000).toFixed(1) : (lines[0] ? (parseInt(lines[0])\/1000).toFixed(1) : 'N/A'); var w1 = lines[2] ? (parseInt(lines[2])\/1000).toFixed(1) : 'N/A'; var w2 = lines[3] ? (parseInt(lines[3])\/1000).toFixed(1) : 'N/A'; var tempVal = 'CPU: ' + cT + '°C WiFi: ' + w1 + '°C ' + w2 + '°C';" $JS_FILE

sed -i "/_('Architecture'),/a \ \t\t\t_('Temperature'),      tempVal," $JS_FILE

sed -i '/if (tempinfo.tempinfo) {/,/}/ s/^/\/\//' $JS_FILE

if [ -f "$PO_FILE" ]; then
    if ! grep -q "Temperature" "$PO_FILE"; then
        echo -e '\nmsgid "Temperature"\nmsgstr "温度"' >> "$PO_FILE"
    fi
fi
