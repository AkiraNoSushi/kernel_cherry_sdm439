#Strip WLAN module and rename to pronto_wlan.ko
aarch64-linux-gnu-strip --strip-unneeded --strip-debug out/drivers/staging/prima/wlan.ko
cp out/drivers/staging/prima/wlan.ko out/drivers/staging/prima/pronto_wlan.ko
