variable "project_id" {}

variable "packet_facility" {}

variable "talos_version" {}

variable "boot_args" {
  default = [
    "page_poison=1",
    "slab_nomerge",
    "pti=on",
    "random.trust_cpu=on",
    "serial",
    "console=tty0",
    "console=ttyS1,115200n8",
    "printk.devkmsg=on",
  ]
}
