# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=Cherry Kernel - by @AkiraNoSushi & @SimplyJoel
do.devicecheck=1
do.modules=1
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=pine
device.name2=olive
device.name3=olivelite
device.name4=olivewood
supported.versions=10,11
supported.patchlevels=
'; } # end properties

# shell variables
block=/dev/block/by-name/boot;
is_slot_device=0;
ramdisk_compression=auto;


## AnyKernel methods (DO NOT CHANGE)
# import patching functions/variables - see for reference
. tools/ak3-core.sh;

## AnyKernel install
split_boot;
flash_boot;
flash_dtbo;

ui_print " "

ui_print "Mounting /vendor and /system..."
mount -o rw,remount /vendor
mount -o rw,remount /system

# Prima
ui_print "Setting up Prima..."
if [ -d "/vendor/lib/modules" ]; then
    cp pronto_wlan.ko modules/vendor/lib/modules
fi
if [ -f "/system/lib/modules/pronto_wlan.ko" ]; then
    cp pronto_wlan.ko modules/system/lib/modules
fi

# Patches
# Prevent init from overriding kernel tweaks.
ui_print "Patching init..."
# IMO this is kinda destructive but works
find /system/etc/init/ -type f | while read file; do 
sed -Ei 's;[^#](write /proc/sys/(kernel|vm)/(sched|dirty|perf_cpu|page-cluster|stat|swappiness|vfs));#\1;g' $file
done
# lmkd props
ui_print "Patching system's build.prop..."
patch_prop /system/build.prop "ro.lmk.kill_heaviest_task" "true"
patch_prop /system/build.prop "ro.config.low_ram" "false"
patch_prop /system/build.prop "ro.lmk.use_minfree_levels" "true"
patch_prop /system/build.prop "ro.lmk.medium" "300"
patch_prop /system/build.prop "ro.lmk.critical_upgrade" "true"
patch_prop /system/build.prop "ro.lmk.upgrade_pressure" "95"
patch_prop /system/build.prop "ro.lmk.downgrade_pressure" "60"
patch_prop /system/build.prop "ro.lmk.log_stats" "true"
patch_prop /system/build.prop "ro.lmk.use_psi" "true"
# Replace post_boot with ours.
ui_print "Pushing init.qcom.post_boot.sh..."
replace_file "/vendor/bin/init.qcom.post_boot.sh" "0755" "init.qcom.post_boot.sh"
## end install
