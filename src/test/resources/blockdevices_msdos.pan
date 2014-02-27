object template blockdevices_msdos;

include 'blockdevices';

"/system/blockdevices/physical_devs/sdb/label"="msdos";

"/system/blockdevices/partitions" = {
    # the 1st logical is part 5
    SELF['sdb5']=SELF['sdb4'];
    SELF['sdb4']=null;
    SELF;
};
