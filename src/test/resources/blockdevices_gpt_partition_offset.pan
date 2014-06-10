object template blockdevices_gpt_partition_offset;

# this one is gpt
include 'blockdevices';

"/system/blockdevices/partitions" = {
    # we can align the first partiton to 1MiB, like ks pre does    
    SELF['sdb1']['offset']=1; 
    SELF['sdb3']['offset']=1;
    SELF;
};
