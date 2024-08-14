#include <linux/module.h>

static int __init kmod_common_init(void) {
    printk("Hello, World!\n");
    return 0;
}
static void __exit kmod_common_exit(void) {
    printk("Goodbye, World!\n");
}

module_init(kmod_common_init);
module_exit(kmod_common_exit);

MODULE_LICENSE("GPL");
