object template t7;

include {"bddummy"};
include {"quattor/blockdevices"};

"/system/blockdevices" = nlist (
	"physical_devs",
	nlist (
	    "hdb", nlist ("label", "msdos")
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
		"type", "extended",
		),
	    "hdb5", nlist (
		"holding_dev", "hdb",
		"type", "logical",
		"size", 1024,
		),
	    )
	);
