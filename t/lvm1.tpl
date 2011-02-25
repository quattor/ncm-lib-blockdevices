object template lvm1;

include quattor/blockdevices;

"/software/components/filesystems/blockdevices" = nlist (
    "physical_devs", nlist (
	"hdb", nlist ("label", "none")
	),
    "volume_groups", nlist (
	"Chobits", nlist (
	    "device_list", list ("physical_devs/hdb"),
	)
    )
);
