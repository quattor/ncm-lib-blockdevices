object template lvm4;

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
			"size", 1024,
			),
		"hdb3", nlist (
			"holding_dev", "hdb",
			"size", 2048,
			),
		"hdb4", nlist (
			"holding_dev", "hdb",
			)
		),
	"volume_groups", nlist (
		"Chobits", nlist (
			"device_list", list ("partitions/hdb1",
					     "partitions/hdb2",
					     "partitions/hdb3"),
			),
		"Tsubasa", nlist (
			"device_list", list ("partitions/hdb4")
			)
		),
	"logical_volumes", nlist ("Chii", nlist (
					  "size", 1024,
					  "volume_group", "Chobits"
					  ),
				  "Sumomo", nlist (
					  "size", 2048,
					  "volume_group", "Chobits"
					  ),
				  "Sakura", nlist (
					  "size", 512,
					  "volume_group", "Tsubasa"
					  ),
				  "Mokona", nlist (
					  "size", 16384,
					  "volume_group", "Tsubasa"
					  )
		)
	);
