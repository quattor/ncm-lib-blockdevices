object template t3;

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
			),
		"hdb2", nlist (
			"holding_dev", "hdb",
			"size", 8192,
			),
		"hdb3", nlist (
			"holding_dev", "hdb",
			)
		)
	);
