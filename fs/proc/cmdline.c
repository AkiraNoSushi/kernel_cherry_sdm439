#include <linux/fs.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <asm/setup.h>

static char new_command_line[COMMAND_LINE_SIZE];

static int cmdline_proc_show(struct seq_file *m, void *v)
{
	seq_printf(m, "%s\n", new_command_line);
	return 0;
}

static int cmdline_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, cmdline_proc_show, NULL);
}

static const struct file_operations cmdline_proc_fops = {
	.open		= cmdline_proc_open,
	.read		= seq_read,
	.llseek		= seq_lseek,
	.release	= single_release,
};

static void patch_flag_set_val(char *cmd, const char *flag, const char *val)
{
	size_t flag_len, val_len;
	char *start, *end;

	start = strstr(cmd, flag);
	if (!start)
		return;

	flag_len = strlen(flag);
	val_len = strlen(val);
	end = start + flag_len + strcspn(start + flag_len, " ");
	memmove(start + flag_len + val_len, end, strlen(end) + 1);
	memcpy(start + flag_len, val, val_len);
}

static void patch_flag_remove_flag(char *cmd, const char *flag)
{
	char *offset_addr = cmd;
	offset_addr = strstr(cmd, flag);
	if (offset_addr) {
		size_t i, len, offset;

		len = strlen(cmd);
		offset = offset_addr - cmd;

		for (i = 1; i < (len - offset); i++) {
			if (cmd[offset + i] == ' ')
				break;
		}

		memmove(offset_addr, &cmd[offset + i + 1], len - i - offset);
	} else {
		printk("%s: Unable to find flag \"%s\"\n", __func__, flag);
	}
}

static void patch_safetynet_flags(char *cmd)
{
	patch_flag_set_val(cmd, "androidboot.flash.locked=", "1");
	patch_flag_set_val(cmd, "androidboot.verifiedbootstate=", "green");
	patch_flag_set_val(cmd, "androidboot.veritymode=", "enforcing");
	patch_flag_set_val(cmd, "androidboot.vbmeta.device_state=", "locked");
}

static void patch_sar_flags(char *cmd)
{
	patch_flag_remove_flag(cmd, "root=PARTUUID=");
	patch_flag_remove_flag(cmd, "rootwait");
	/* This flag is skip_initramfs, Omit the last 2 characters to avoid getting patched by Magisk */
	patch_flag_remove_flag(cmd, "skip_initram");
}

static int __init proc_cmdline_init(void)
{
	strcpy(new_command_line, saved_command_line);

	/*
	 * Patch various flags from command line seen by userspace in order to
	 * pass SafetyNet checks.
	 */
	patch_safetynet_flags(new_command_line);

	patch_sar_flags(new_command_line);

	proc_create("cmdline", 0, NULL, &cmdline_proc_fops);
	return 0;
}
fs_initcall(proc_cmdline_init);
