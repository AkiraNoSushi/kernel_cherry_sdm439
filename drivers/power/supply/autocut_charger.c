/*
 * drivers/power/autocut_charger.c
 * drivers/power/supply/autocut_charger.c
 *
 * AutoCut Charger.
 *
 * Copyright (C) 2019, Ryan Andri <https://github.com/ryan-andri>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version. For more details, see the GNU
 * General Public License included with the Linux kernel or available
 * at www.gnu.org/licenses
 */

#include <linux/module.h>
#include <linux/workqueue.h>
#include <linux/power_supply.h>

/* Error counter */
static int error_enable_cnt;
static int error_disable_cnt;

static struct delayed_work autocut_charger_work;

static bool set_charging_control(struct power_supply *batt_psy, bool enable)
{
	union power_supply_propval val = {0, };
	int rc;

	val.intval = enable;
	rc = power_supply_set_property(batt_psy,
			POWER_SUPPLY_PROP_BATTERY_CHARGING_ENABLED, &val);
	if (rc) {
		if (enable) {
			error_enable_cnt++;
			pr_err("autocut_charger: Failed to enable battery charging!\n");
		} else {
			error_disable_cnt++;
			pr_err("autocut_charger: Failed to disable battery charging!\n");
		}

		if (error_enable_cnt >= 5 ||
			error_disable_cnt >= 5) {
			cancel_delayed_work_sync(&autocut_charger_work);
			pr_err("autocut_charger: Worker die, charging driver not supported!\n");
			return false;
		}

		return true;
	}

	error_enable_cnt = 0;
	error_disable_cnt = 0;

	return true;
}

static void autocut_charger_worker(struct work_struct *work)
{
	struct power_supply *batt_psy = power_supply_get_by_name("battery");
	struct power_supply *usb_psy = power_supply_get_by_name("usb");
	union power_supply_propval present = {0,}, charging_enabled = {0,};
	union power_supply_propval bat_percent;

	power_supply_get_property(batt_psy,
		POWER_SUPPLY_PROP_CAPACITY, &bat_percent);
	power_supply_get_property(batt_psy,
		POWER_SUPPLY_PROP_BATTERY_CHARGING_ENABLED, &charging_enabled);
	power_supply_get_property(usb_psy,
		POWER_SUPPLY_PROP_PRESENT, &present);

	if (present.intval) {
		if (charging_enabled.intval && bat_percent.intval >= 100) {
			if (!set_charging_control(batt_psy, false))
				return;
		} else if (!charging_enabled.intval && bat_percent.intval < 100) {
			if (!set_charging_control(batt_psy, true))
				return;
		}
	} else {
		if (!charging_enabled.intval) {
			if(!set_charging_control(batt_psy, true))
				return;
		}
	}

	schedule_delayed_work(&autocut_charger_work, msecs_to_jiffies(1000));
}

static int __init autocut_charger_init(void)
{
	error_enable_cnt = 0;
	error_disable_cnt = 0;

	if (!strstr(saved_command_line, "androidboot.mode=charger")) {
		INIT_DELAYED_WORK(&autocut_charger_work, autocut_charger_worker);
		/* start worker in at least 20 seconds after boot completed */
		schedule_delayed_work(&autocut_charger_work, msecs_to_jiffies(20000));
		pr_info("%s: Initialized.\n", __func__);
	}

	return 0;
}
late_initcall(autocut_charger_init);

static void __exit autocut_charger_exit(void)
{
	if (!strstr(saved_command_line, "androidboot.mode=charger"))
		cancel_delayed_work_sync(&autocut_charger_work);
}
module_exit(autocut_charger_exit);

