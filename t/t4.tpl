object template t4;

include quattor/blockdevices;

include quattor/filesystems;

"/software/components/filesystems/blockdevices" = nlist (
	"physical_devs",
	nlist (
		"hdb", nlist ("label", "gpt")
	)
);

"/software/components/filesystems/filesystemdefs" = list (
    nlist ("mountpoint", "/Mokona",
	"type", "ext3",
	"format", true,
	"preserve", false,
	"block_device", "physical_devs/hdb",
	"mount", true,
	"mkfsopts", "-F"
    )
);
