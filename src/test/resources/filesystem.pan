object template filesystem;

include 'blockdevices';

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

    # append force_filesystem true
    fs=value("/system/filesystems/0");
    fs["ksfsformat"]=true;    
    fs["mountopts"]="oneoption anotheroption";    

    append(fs);

};

