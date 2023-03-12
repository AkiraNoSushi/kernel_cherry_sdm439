# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=Cherry Kernel V2.7.4 - by @AkiraNoSushi & @Flopster101
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=pine
device.name2=olive
device.name3=olivelite
device.name4=olivewood
device.name5=mi439
device.name6=olives
supported.versions=11,12,13
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

# R/W dynamic partitions fix
if [ -d "/dev/block/mapper" ]; then
    blockdev --setrw /dev/block/mapper/system
    blockdev --setrw /dev/block/mapper/vendor
fi

## AnyKernel install
split_boot;

ui_print "Mounting /vendor..."
mount -o rw,remount /vendor

vndk_version=$(file_getprop /vendor/build.prop ro.vendor.build.version.sdk)

if [ $vndk_version -lt 30 ]; then
    abort "Unsupported VNDK version. Aborting..."
fi

ui_print "Detecting WiFi HAL..."

wifi_hal=$(find /vendor/lib64 /vendor/lib -name "libwifi-hal.so" | head -n 1)
if grep -q "pronto_wlan.ko" $wifi_hal; then
    abort "Unsupported WiFi HAL. Aborting..."
fi

ui_print "Detecting camera HAL..."

if [[ ! -z "$(find /vendor/lib64 /vendor/lib -name '*lib2d*')" ]]; then
    patch_cmdline "prebuilt_camera_hal" "prebuilt_camera_hal"
else
    patch_cmdline "prebuilt_camera_hal" ""
fi

flash_boot;
flash_dtbo;

ui_print " "

ui_print "Mounting /system..."
mount -o rw,remount /system

## Patches
# Prevent init from overriding kernel tweaks.
ui_print "Patching system's init..."
# IMO this is kinda destructive but works
find /system/etc/init/ -type f | while read file; do 
sed -Ei 's;[^#](write /proc/sys/(kernel|vm)/(sched|dirty|perf_cpu|page-cluster|stat|swappiness|vfs));#\1;g' $file
done
# Prevent init from overriding ZRAM algorithm
ui_print "Patching vendor's init..."
remove_line "/vendor/etc/init/hw/init.qcom.rc" "comp_algorithm" "global"
# Replace post_boot with ours.
ui_print "Pushing init.qcom.post_boot.sh..."
replace_file "/vendor/bin/init.qcom.post_boot.sh" "0755" "init.qcom.post_boot.sh"
## end install
