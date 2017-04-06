unique template blockdevices;

# keep BlockDevices happy
"/system/network/hostname" = 'x';
"/system/network/domainname" = 'y';

"/hardware/harddisks/sdb" = dict(
    "capacity", 4000,
);

"/system/blockdevices" = dict(
	"physical_devs", dict(
		"sdb", dict("label", "gpt"),
        escape("mapper/abcdef123"), dict("label", "gpt"),
		),
	"partitions", dict(
		"sdb1", dict(
			"holding_dev", "sdb",
			"size", 100,
			"type", "primary", # no defaults !
			),
        "sdb2", dict(
            "holding_dev", "sdb",
            "size", 100,
            "type", "primary", # no defaults !
            ),
        "sdb3", dict(
            "holding_dev", "sdb",
            "size", 2500,
            "type", "extended",
            ),
        "sdb4", dict(
            "holding_dev", "sdb",
            "type", "logical",
            "size", 1024,
            ),
        escape("mapper/abcdef123p1"), dict(
            "holding_dev", escape("mapper/abcdef123"),
            "type", "logical",
            "size", 1024,
            ),
        ),
	"volume_groups", dict(
		"vg0", dict (
			"device_list", list ("partitions/sdb1"),
			)
		),
	"md", dict(
		"md0", dict(
			"device_list", list("partitions/sdb1", "partitions/sdb2"),
			"raid_level", "RAID0",
			"stripe_size", 64,
			),
        escape("md/myname"), dict(
            "device_list", list ("partitions/sdb3", "partitions/sdb4"),
            "raid_level", "RAID0",
            "stripe_size", 64,
            "metadata", "1.2",
            ),
		),
	"files", dict(
		escape ("/home/mejias/kk.ext3"), dict(
			"size", 400,
			"owner", "mejias",
			"group", "users",
			"permissions", 0600
			)
		),
	"logical_volumes", dict(
		"lv0", dict (
			"size", 800,
			"volume_group", "vg0"
			),
        "lv1", dict (
            "size", 800,
            "volume_group", "vg0"
            ),
        ),
    "vxvm", dict(
        "vcslab.local", dict("gnr.0", dict(
            "dev_path", "/dev/vx/dsk/vcslab.local/gnr.0",
            "disk_group", "vcslab.local",
            "volume", "gnr.0"
        ))
	)
);

"/system/filesystems" = list(
    dict(
        "mount", true,
        "mountpoint", "/Lagoon",
        "preserve", true,
        "format", false,
        "mountopts", "auto",
        "block_device", "partitions/sdb1",
        "type", "ext3",
        "freq", 0,
        "pass", 1
        )
    );
