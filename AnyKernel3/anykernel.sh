# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers

## AnyKernel setup
# begin properties
properties() { '
kernel.string=Cherry Kernel V2.4 - by @AkiraNoSushi & @Flopster101
do.devicecheck=1
do.modules=1
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=pine
device.name2=olive
device.name3=olivelite
device.name4=olivewood
supported.versions=10,11,12
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

ui_print "Mounting /vendor..."
mount -o rw,remount /vendor

vndk_version=$(file_getprop /vendor/build.prop ro.vendor.build.version.sdk)

if [ $vndk_version -lt 30 ]; then
    # Add legacy_omx param if VNDK < 30
    patch_cmdline "legacy_omx" "legacy_omx"
else
    # Remove legacy_omx param if VNDK => 30
    patch_cmdline "legacy_omx" ""
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
# Patch WiFI HAL
ui_print "Detecting WiFi HAL..."
wifi_hal=$(find /vendor/lib64 /vendor/lib -name "libwifi-hal.so" | head -n 1)
if grep -q "pronto_wlan.ko" $wifi_hal; then
    ui_print "Patching WiFi HAL..."
    func_hex_offset=$(./tools/readelf $wifi_hal -sW | grep "is_wifi_driver_loaded" | awk '{print $2}')
    func_dec_offset=$(printf "%d" "0x"$func_hex_offset)
    hal_arch=$(./tools/readelf -h $wifi_hal | grep "Class" | awk '{print $2}')
    if [ $hal_arch == "ELF64" ]; then
        # patch:
        #   mov w0, #0x1
        #   ret
        printf '\x20\x00\x80\x52\xc0\x03\x5f\xd6' | ./tools/busybox dd of=$wifi_hal bs=1 seek=$func_dec_offset conv=notrunc status=none
    else
        # patch:
        #   mov r0, #0x1
        #   mov pc, lr
        # We must substract 1 to function address because of Thumb's least-significant bit
        printf '\x01\x20\xf7\x46' | ./tools/busybox dd of=$wifi_hal bs=1 seek=$[$func_dec_offset-1] conv=notrunc status=none
    fi
    # Give WiFi HAL fwpath sysfs privileges
    ui_print "Patching vendor's init..."
    insert_line /vendor/etc/init/hw/init.qcom.rc "chown wifi wifi /sys/module/wlan/parameters/fwpath" after "    chmod 0660 /sys/kernel/dload/dload_mode" $(printf "\n    chown wifi wifi /sys/module/wlan/parameters/fwpath")
    if ! grep -q "allow qti_init_shell sysfs_wlan_fwpath" /vendor/etc/selinux/vendor_sepolicy.cil; then
        ui_print "Patching vendor's SELinux policy..."
        echo "(allow qti_init_shell sysfs_wlan_fwpath_${vndk_version}_0 (file (write lock append map open)))" >> /vendor/etc/selinux/vendor_sepolicy.cil
    fi
else
    ui_print "No WiFi HAL patching needed."
fi
# IORap
ui_print "Patching system's build.prop..."
patch_prop /system/build.prop "ro.iorapd.enable" "true"
patch_prop /system/build.prop "iorapd.perfetto.enable" "true"
patch_prop /system/build.prop "iorapd.readahead.enable" "true"
# Replace post_boot with ours.
ui_print "Pushing init.qcom.post_boot.sh..."
replace_file "/vendor/bin/init.qcom.post_boot.sh" "0755" "init.qcom.post_boot.sh"
## end install
