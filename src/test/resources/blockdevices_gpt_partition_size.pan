object template blockdevices_gpt_partition_size;

# this one is gpt
include 'blockdevices';

# size check for holding_dev
"/system/blockdevices/physical_devs/sdb/validate/size/diff" = 100;

