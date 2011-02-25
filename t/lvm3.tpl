object template lvm3;

include quattor/blockdevices;

"/software/components/filesystems/blockdevices" = nlist (
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
		"Chobits", nlist (
			"device_list", list ("partitions/hdb1",
					     "partitions/hdb2"),
			)
		),
	"logical_volumes", nlist ("Chii", nlist (
					  "size", 1024,
					  "volume_group", "Chobits"
					  )
		)
	);
