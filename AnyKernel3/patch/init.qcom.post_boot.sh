#!/vendor/bin/sh
function configure_zram_parameters() {
    MemTotalStr=`cat /proc/meminfo | grep MemTotal`
    MemTotal=${MemTotalStr:16:8}

    # Zram disk - 75% for Go devices.
    # For 512MB Go device, size = 384MB, set same for Non-Go.
    # For 1GB Go device, size = 768MB, set same for Non-Go.
    # For >=2GB Non-Go devices, size = 50% of RAM size. Limit the size to 4GB.

    RamSizeGB=`echo "($MemTotal / 1048576 ) + 1" | bc`
    zRamSizeBytes=`echo "$RamSizeGB * 1024 * 1024 * 1024 / 2" | bc`
    if [ $zRamSizeBytes -gt 4294967296 ]; then
        zRamSizeBytes=4294967296
    fi

    if [ -f /sys/block/zram0/disksize ]; then
        if [ -f /sys/block/zram0/use_dedup ]; then
            echo 1 > /sys/block/zram0/use_dedup
        fi
        if [ $MemTotal -le 524288 ]; then
            echo 402653184 > /sys/block/zram0/disksize
        elif [ $MemTotal -le 1048576 ]; then
            echo 805306368 > /sys/block/zram0/disksize
        else
            # modify by zfc 18-12-26 for C3H-391 to change zram to 1.5G
            echo 1610612736 > /sys/block/zram0/disksize
        fi
        mkswap /dev/block/zram0
        swapon /dev/block/zram0 -p 32758
    fi
}

function configure_memory_parameters() {
    # Set Memory parameters.
    #
    # Set per_process_reclaim tuning parameters
    # All targets will use vmpressure range 50-70,
    # All targets will use 512 pages swap size.
    #
    # Set Low memory killer minfree parameters
    # 32 bit Non-Go, all memory configurations will use 15K series
    # 32 bit Go, all memory configurations will use uLMK + Memcg
    # 64 bit will use Google default LMK series.
    #
    # Set ALMK parameters (usually above the highest minfree values)
    # vmpressure_file_min threshold is always set slightly higher
    # than LMK minfree's last bin value for all targets. It is calculated as
    # vmpressure_file_min = (last bin - second last bin ) + last bin
    #
    # Set allocstall_threshold to 0 for all targets.
    #

    arch_type=`uname -m`

    echo "4687,9374,14061,18748,23435,74992" > /sys/module/lowmemorykiller/parameters/minfree

    # Calculate vmpressure_file_min as below & set for 64 bit:
    # vmpressure_file_min = last_lmk_bin + (last_lmk_bin - last_but_one_lmk_bin)
    if [ "$arch_type" == "aarch64" ]; then
        minfree_series=`cat /sys/module/lowmemorykiller/parameters/minfree`
        minfree_1="${minfree_series#*,}" ; rem_minfree_1="${minfree_1%%,*}"
        minfree_2="${minfree_1#*,}" ; rem_minfree_2="${minfree_2%%,*}"
        minfree_3="${minfree_2#*,}" ; rem_minfree_3="${minfree_3%%,*}"
        minfree_4="${minfree_3#*,}" ; rem_minfree_4="${minfree_4%%,*}"
        minfree_5="${minfree_4#*,}"

        vmpres_file_min=$((minfree_5 + (minfree_5 - rem_minfree_4)))
        echo $vmpres_file_min > /sys/module/lowmemorykiller/parameters/vmpressure_file_min
    else
        echo 53059 > /sys/module/lowmemorykiller/parameters/vmpressure_file_min
    fi

    # Disable adaptive LMK for all targets &
    # use Google default LMK series for all 64-bit targets >=2GB.
    echo 0 > /sys/module/lowmemorykiller/parameters/enable_adaptive_lmk

    # Enable oom_reaper
    if [ -f /sys/module/lowmemorykiller/parameters/oom_reaper ]; then
        echo 1 > /sys/module/lowmemorykiller/parameters/oom_reaper
    fi

    # Set allocstall_threshold to 0 for all targets.
    # Set swappiness to 100 for all targets
    echo 0 > /sys/module/vmpressure/parameters/allocstall_threshold
    echo 100 > /proc/sys/vm/swappiness

    # Disable wsf for all targets beacause we are using efk.
    # wsf Range : 1..1000 So set to bare minimum value 1.
    echo 1 > /proc/sys/vm/watermark_scale_factor

    configure_zram_parameters
}

bootmode=`getprop ro.bootmode`
if [ "charger" != $bootmode ]; then
        start vendor.hbtp
fi

# Apply settings for sdm429/sda429/sdm439/sda439

for cpubw in /sys/class/devfreq/*qcom,mincpubw*
do
    echo "cpufreq" > $cpubw/governor
done

for cpubw in /sys/class/devfreq/*qcom,cpubw*
do
    echo "bw_hwmon" > $cpubw/governor
    echo 20 > $cpubw/bw_hwmon/io_percent
    echo 30 > $cpubw/bw_hwmon/guard_band_mbps
done

for gpu_bimc_io_percent in /sys/class/devfreq/soc:qcom,gpubw/bw_hwmon/io_percent
do
    echo 40 > $gpu_bimc_io_percent
done

# Apply settings for sdm439/sda439

echo "schedutil" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo "schedutil" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor

# sched_load_boost as -6 is equivalent to target load as 85.
echo -6 > /sys/devices/system/cpu/cpu0/sched_load_boost
echo -6 > /sys/devices/system/cpu/cpu1/sched_load_boost
echo -6 > /sys/devices/system/cpu/cpu2/sched_load_boost
echo -6 > /sys/devices/system/cpu/cpu3/sched_load_boost

# sched_load_boost as -6 is equivalent to target load as 85.
echo -6 > /sys/devices/system/cpu/cpu4/sched_load_boost
echo -6 > /sys/devices/system/cpu/cpu5/sched_load_boost
echo -6 > /sys/devices/system/cpu/cpu6/sched_load_boost
echo -6 > /sys/devices/system/cpu/cpu7/sched_load_boost

# EAS scheduler (big.Little cluster related) settings
echo 93 > /proc/sys/kernel/sched_upmigrate
echo 83 > /proc/sys/kernel/sched_downmigrate
echo 140 > /proc/sys/kernel/sched_group_upmigrate
echo 120 > /proc/sys/kernel/sched_group_downmigrate

# Bring up all cores online
echo 1 > /sys/devices/system/cpu/cpu1/online
echo 1 > /sys/devices/system/cpu/cpu2/online
echo 1 > /sys/devices/system/cpu/cpu3/online
echo 1 > /sys/devices/system/cpu/cpu4/online
echo 1 > /sys/devices/system/cpu/cpu5/online
echo 1 > /sys/devices/system/cpu/cpu6/online
echo 1 > /sys/devices/system/cpu/cpu7/online

# Enable core control
echo 2 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus
echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/max_cpus
echo 68 > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
echo 40 > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
echo 100 > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
echo 1 > /sys/devices/system/cpu/cpu0/core_ctl/is_big_cluster
echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/task_thres

# Set Memory parameters
configure_memory_parameters

#disable sched_boost
echo 0 > /proc/sys/kernel/sched_boost

# Disable L2-GDHS low power modes
echo N > /sys/module/lpm_levels/system/pwr/pwr-l2-gdhs/idle_enabled
echo N > /sys/module/lpm_levels/system/pwr/pwr-l2-gdhs/suspend_enabled
echo N > /sys/module/lpm_levels/system/perf/perf-l2-gdhs/idle_enabled
echo N > /sys/module/lpm_levels/system/perf/perf-l2-gdhs/suspend_enabled

# Enable low power modes
echo 0 > /sys/module/lpm_levels/parameters/sleep_disabled

# Let kernel know our image version/variant/crm_version
if [ -f /sys/devices/soc0/select_image ]; then
    image_version="10:"
    image_version+=`getprop ro.build.id`
    image_version+=":"
    image_version+=`getprop ro.build.version.incremental`
    image_variant=`getprop ro.product.name`
    image_variant+="-"
    image_variant+=`getprop ro.build.type`
    oem_version=`getprop ro.build.version.codename`
    echo 10 > /sys/devices/soc0/select_image
    echo $image_version > /sys/devices/soc0/image_version
    echo $image_variant > /sys/devices/soc0/image_variant
    echo $oem_version > /sys/devices/soc0/image_crm_version
fi

# Change console log level as per console config property
console_config=`getprop persist.console.silent.config`
case "$console_config" in
    "1")
        echo "Enable console config to $console_config"
        echo 0 > /proc/sys/kernel/printk
        ;;
    *)
        echo "Enable console config to $console_config"
        ;;
esac

# Parse misc partition path and set property
misc_link=$(ls -l /dev/block/bootdevice/by-name/misc)
real_path=${misc_link##*>}
setprop persist.vendor.mmi.misc_dev_path $real_path

# CABC high
echo 0300 > /sys/devices/virtual/graphics/fb0/msm_fb_dispparam
# IE on
echo 0010 > /sys/devices/virtual/graphics/fb0/msm_fb_dispparam
