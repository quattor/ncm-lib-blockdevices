object template raid2;

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

"/software/components/filesystems/filesystemdefs" = list (
    nlist ("block_device", "md/md0",
	"type", "ext3",
	"mount", true,
	"mountopts", "defaults",
	"preserve", true,
	"format", false,
	"mountpoint", "/Mokona"
    )
);
