object template t6;

include quattor/blockdevices;

include quattor/filesystems;

"/software/components/filesystems/blockdevices" = nlist (
	"physical_devs",
	nlist (
		"hdb", nlist ("label", "gpt")
	),
	"partitions", nlist (
	    "hdb1", nlist ("holding_dev", "hdb")
	)
);

"/software/components/filesystems/filesystemdefs" = list (
    nlist ("mountpoint", "/Mokona",
	"type", "ext3",
	"format", true,
	"preserve", false,
	"block_device", "partitions/hdb1",
	"mount", true,
	"mkfsopts", "-F",
	"label", "Mokona"
    )
);
