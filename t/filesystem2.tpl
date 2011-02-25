object template filesystem2;

include quattor/blockdevices;
include quattor/filesystems;

"/software/components/filesystems/blockdevices" = nlist (
	"physical_devs", nlist (
		"hdb", nlist ("label", "gpt")
		),
	"partitions", nlist (
		"hdb1", nlist (
			"holding_dev", "hdb",
			"size", 4096,
			)
		)
	);

"/software/components/filesystems/filesystemdefs" = list (
	nlist (
		"mount", true,
		"mountpoint", "/Lagoon",
		"preserve", false,
		"format", true,
		"mountopts", "auto",
		"block_device", "partitions/hdb1",
		"type", "ext3",
		"freq", 0,
		"pass", 1
		)
	);
