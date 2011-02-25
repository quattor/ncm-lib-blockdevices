# Tests a RAID array with two disks:

object template hwraid1;

include {"bddummy"};
include {"quattor/blockdevices"};
#include {"quattor/physdevices"};

"/system/blockdevices/physical_devs" = nlist (
    "sdb", nlist ("label", "gpt",
	"device_path", "_1"));
"/system/blockdevices/hwraid/_1" = nlist (
    "raid_level", "RAID1",
    "num_spares", 0,
    "device_list", list ("raid/_0/ports/_2",
	"raid/_0/ports/_3")
    );

"/hardware/cards/raid/_0/vendor" = "3ware";
"/hardware/cards/raid/_0/ports/_0" = nlist (
    "name", "Seagate Barracuda",
    "capacity", 400000,
    "interface", "sata",
    );

"/hardware/cards/raid/_0/ports/_1" = value ("/hardware/cards/raid/_0/ports/_0");
"/hardware/cards/raid/_0/ports/_2" = value ("/hardware/cards/raid/_0/ports/_0");
"/hardware/cards/raid/_0/ports/_3" = value ("/hardware/cards/raid/_0/ports/_0");
