object template t1;

include {"bddummy"};
include {"quattor/blockdevices"};

#include {"quattor/filesystems"};
include {"bddummy"};
"/system/blockdevices" = nlist (
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
