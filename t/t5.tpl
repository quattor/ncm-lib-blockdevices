object template t5;

include {'bddummy'};
include {"quattor/blockdevices"};

include {"quattor/filesystems"};
include {"fsdummy"};
"/system/blockdevices" = nlist (
	"physical_devs",
	nlist (
		"hdb", nlist ("label", "gpt")
	),
	"partitions", nlist (
	    "hdb1", nlist ("holding_dev", "hdb")
	)
);

"/system/filesystems" = list (
    nlist ("mountpoint", "/Mokona",
	"type", "ext3",
	"format", true,
	"preserve", false,
	"block_device", "partitions/hdb1",
	"mount", true,
	"mkfsopts", "-F"
    )
);
