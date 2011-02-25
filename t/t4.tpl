object template t4;

include {"bddummy"};

include {"quattor/blockdevices"};

include {"quattor/filesystems"};
include {"fsdummy"};
"/system/blockdevices" = nlist (
	"physical_devs",
	nlist (
		"hdb", nlist ("label", "gpt")
	)
);

"/system/filesystems" = list (
    nlist ("mountpoint", "/Mokona",
	"type", "ext3",
	"format", true,
	"preserve", false,
	"block_device", "physical_devs/hdb",
	"mount", true,
	"mkfsopts", "-F"
    )
);
