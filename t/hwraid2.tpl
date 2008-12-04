# Tests a RAID array with two disks:

object template hwraid2;

include {"bddummy"};
include {"quattor/blockdevices"};
#include {"quattor/physdevices"};

"/system/blockdevices/physical_devs" = nlist (
    "sdb", nlist ("label", "gpt",
	"device_path", "raid/_0/ports/_0"));

"/hardware/cards/raid/_0/vendor" = "3ware";
"/hardware/cards/raid/_0/ports/_0" = nlist (
    "name", "Seagate Barracuda",
    "capacity", 400000,
    "interface", "sata",
    );

"/hardware/cards/raid/_0/ports/_1" = value ("/hardware/cards/raid/_0/ports/_0");
"/hardware/cards/raid/_0/ports/_2" = value ("/hardware/cards/raid/_0/ports/_0");
"/hardware/cards/raid/_0/ports/_3" = value ("/hardware/cards/raid/_0/ports/_0");
