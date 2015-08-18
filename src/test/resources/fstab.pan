object template fstab;

include 'blockdevices';

# do not preserve
"/system/filesystems" = {
    # always make a copy

    fs=value("/system/filesystems/0");
    fs["block_device"] = "partitions/sdb2";
    fs["mountpoint"] = "/Lagoon2";
    append(fs);

    fs=value("/system/filesystems/0");
    fs["block_device"] = "partitions/sdb3";
    fs["mountpoint"] = "/Lagoon3";
    append(fs);

    fs=value("/system/filesystems/0");
    fs["block_device"] = "partitions/sdb4";
    fs["mountpoint"] = "/Lagoon4";
    fs["label"] = "FSLAB";
    append(fs);

};

