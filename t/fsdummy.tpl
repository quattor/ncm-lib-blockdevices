# Dummy helper template for file systems.
template fsdummy;
include {"bddummy"};
bind "/system/filesystems" = structure_filesystem[];
