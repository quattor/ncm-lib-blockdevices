unique template filesystems;

# do not preserve
"/system/filesystems" = {
    # always make a copy

    # apppend formattable/unpreserved fs
    fs=value("/system/filesystems/0");
    fs["format"] = true;
    fs["preserve"] = false;
    append(fs);

    # append none type
    fs=value("/system/filesystems/0");
    fs["type"]="none";    
    append(fs);

    # append force_filesystem false
    fs=value("/system/filesystems/0");
    fs["force_filesystemtype"]=false;    
    append(fs);

    # append force_filesystem true
    fs=value("/system/filesystems/0");
    fs["force_filesystemtype"]=true;    
    append(fs);

    # append ksfsformat test
    fs=value("/system/filesystems/0");
    fs["ksfsformat"]=true;    
    fs["mountopts"]="oneoption anotheroption";    
    append(fs);

    # append md0 test
    fs=value("/system/filesystems/0");
    fs["block_device"]="md/md0";    
    append(fs);

    # append logvol test
    fs=value("/system/filesystems/0");
    fs["block_device"]="logical_volumes/lv0";    
    append(fs);

    fs=value("/system/filesystems/0");
    fs["block_device"]="logical_volumes/lv1";    
    fs["format"] = true;
    fs["preserve"] = false;
    append(fs);

};

