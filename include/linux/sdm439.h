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

#ifndef _LINUX_SDM439_H
#define _LINUX_SDM439_H

enum SDM439_devices {
    DEVICE_UNKNOWN = -1,
    XIAOMI_PINE,
    XIAOMI_OLIVES
};

extern enum SDM439_devices sdm439_devices;

extern int sdm439_current_device;

#endif
