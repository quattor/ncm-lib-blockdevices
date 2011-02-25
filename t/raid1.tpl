object template raid1;

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
			"size", 4096,
			)
		),
	"md", nlist (
		"md0", nlist (
			"device_list", list (
				"partitions/hdb1",
				"partitions/hdb2"
				),
			"raid_level", "RAID1",
			"stripe_size", 32
			)
		)
	);
