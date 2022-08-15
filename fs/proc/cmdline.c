#include <linux/fs.h>
#include <linux/init.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/sdm439.h>
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

	if (!plain_partitions) {
		patch_sar_flags(new_command_line);
	}

	proc_create("cmdline", 0, NULL, &cmdline_proc_fops);
	return 0;
}
fs_initcall(proc_cmdline_init);
