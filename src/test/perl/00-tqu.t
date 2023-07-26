BEGIN {
    our $TQU = <<'EOF';
[load]
prefix=NCM::
modules=BlockdevFactory,Blockdevices,Disk,File,Filesystem,HWRaid,VG,LV,MD,Partition,Tmpfs,VXVM,Proc
[doc]
# no pan code in ncm-lib-blockdevices
panpaths=NOPAN
EOF
}
use Test::Quattor::Unittest;
