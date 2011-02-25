object template t1;

include quattor/blockdevices;

#include quattor/filesystems;

"/software/components/filesystems/blockdevices" = nlist (
	"physical_devs",
	nlist (
		"hdb", nlist ("label", "gpt")
		),
	"partitions",
	nlist (
		"hdb1", nlist (
			"holding_dev", "hdb",
			"size", 4096,
			)
		)
	);
