object template blockdevices_gpt_partition_flags;

# this one is gpt
include 'blockdevices';

"/system/blockdevices/partitions" = {
    SELF['sdb1']['flags']= nlist(
        'bad', false,
        'good', true,
    ); 
    SELF;
};
