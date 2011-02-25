object template lvm2;

include {"bddummy"};
include {"quattor/blockdevices"};
"/system/blockdevices" = nlist (
    "physical_devs", nlist (
	"hdb", nlist ("label", "gpt")
	),
    "partitions", nlist (
	"hdb1", nlist (
	    "holding_dev", "hdb",
	    "size", 4096,
	    ),
	"hdb2", nlist (
	    "holding_dev", "hdb",
	    ),
    ),
    "volume_groups", nlist (
	"Tsubasa", nlist (
	    "device_list", list ("partitions/hdb1",
		"partitions/hdb2"),
	)
    )
);
