object template lvm1;

include {"bddummy"};
include {"quattor/blockdevices"};
"/system/blockdevices" = nlist (
    "physical_devs", nlist (
	"hdb", nlist ("label", "none")
	),
    "volume_groups", nlist (
	"Chobits", nlist (
	    "device_list", list ("physical_devs/hdb"),
	)
    )
);
