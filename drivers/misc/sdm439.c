/*
 * Author: @AkiraNoSushi
 *
 * This software is licensed under the terms of the GNU General Public
 * License version 2, as published by the Free Software Foundation, and
 * may be copied, distributed, and modified under those terms.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 */

#include <linux/sdm439.h>
#include <linux/init.h>
#include <linux/module.h>
#include <linux/of_fdt.h>
#include <linux/string.h>

int sdm439_current_device = DEVICE_UNKNOWN;
EXPORT_SYMBOL(sdm439_current_device);

int sdm439_init(void) {
	const char *machine_name = of_flat_dt_get_machine_name();
    if (strncmp(machine_name, "PINE", 4) == 0) {
      sdm439_current_device = XIAOMI_PINE;
    } else if (strncmp(machine_name, "Olive", 5) == 0) {
      sdm439_current_device = XIAOMI_OLIVES;
    }
    return 0;
}

void sdm439_exit(void) {
	return;
}

rootfs_initcall(sdm439_init); // runs before regular drivers init
module_exit(sdm439_exit);

MODULE_AUTHOR("AkiraNoSushi");
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("Detects on what Xiaomi SDM439 device is Linux currently running on");
