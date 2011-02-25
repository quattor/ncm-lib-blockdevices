object template factory1;

include {"bddummy"};
include {"quattor/blockdevices"};
include {"bddummy"};
"/system/blockdevices" = nlist (
	"physical_devs", nlist (
		"hdb", nlist ("label", "gpt")
		),
	"partitions", nlist (
		"hdb1", nlist (
			"holding_dev", "hdb",
			"size", 4096,
			)
		),
	"volume_groups", nlist (
		"vg0", nlist (
			"device_list", list ("partitions/hdb1"),
			)
		),
	
	"md", nlist (
		"md0", nlist (
			"device_list", list ("partitions/hdb1"),
			"raid_level", "RAID0",
			"stripe_size", 64,
			)
		),
	"files", nlist (
		escape ("/home/mejias/kk.ext3"), nlist (
			"size", 400,
			"owner", "mejias",
			"group", "users",
			"permissions", 0600
			)
		),
	"logical_volumes", nlist (
		"lv0", nlist (
			"size", 4096,
			"volume_group", "vg0"
			),
		)
	);
		
