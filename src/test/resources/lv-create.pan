object template lv-create;

include 'blockdevices';

"/hardware/harddisks/sdc" = dict(
    "capacity", 4000, 
);
"/hardware/harddisks/sdd" = dict(
    "capacity", 200, 
);

prefix '/system/blockdevices';

"physical_devs" = merge(SELF, dict (
    "sdc", dict ("label", "gpt"),
    "sdd", dict ("label", "gpt")
));

"volume_groups" = merge(SELF, dict (
    "vg1", dict (
        "device_list", list ("physical_devs/sdc", "physical_devs/sdd"),
    )
));

"logical_volumes" = merge(SELF, dict (
    "lvCold", dict (
        "size", 1000,
        "volume_group", "vg1",
        "devices" , list("physical_devs/sdc"),
        "cache", dict(
            "cache_lv", "lvCache",
            "cachemode" , "writethrough"
        ),
    ),
    "lvCache", nlist (
        "size", 100,
        "volume_group", "vg1",
        "devices" , list("physical_devs/sdd"),
        "type", "cache-pool"
    ),
));  

