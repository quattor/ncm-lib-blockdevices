object template lvm5;

include {"bddummy"};
include {"quattor/blockdevices"};
include {"quattor/filesystems"};
include {"fsdummy"};
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


"/system/filesystems" = list (
    nlist (
	"mount", true,
	"mountpoint", "/Mokona",
	"preserve", true,
	"format", false,
	"mountopts", "auto",
	"block_device", "logical_volumes/Chii",
	"type", "ext3"
    )
);
