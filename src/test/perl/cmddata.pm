# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package cmddata;

use strict;
use warnings;

# bunch of commands and their output
our %cmds;
our %files;

$cmds{dd_init}{cmd}="dd if=/dev/zero of=/dev/sdb bs=1M count=1"; 
$cmds{dd_init}{out} = <<'EOF';
1+0 records in
1+0 records out
1048576 bytes (1.0 MB) copied, 0.0111167 s, 94.3 MB/s
EOF

$cmds{dd_init_1000}{cmd}="dd if=/dev/zero count=1000 of=/dev/sdb";
$cmds{dd_init_1000}{out} = <<'EOF';
1000+0 records in
1000+0 records out
512000 bytes (512 kB) copied, 0.0491846 s, 10.4 MB/s
EOF

$cmds{mdadm_create_1}{cmd}="/sbin/mdadm --create --run /dev/md0 --level=0 --chunk=64 --raid-devices=1 /dev/sdb1";
$cmds{mdadm_create_1}{ec}= 2;
$cmds{mdadm_create_1}{out}= <<'EOF';
mdadm: '1' is an unusual number of drives for an array, so it is probably
     a mistake.  If you really mean it you will need to specify --force before
     setting the number of drives.
EOF

$cmds{mdadm_create_2}{cmd}="/sbin/mdadm --create --run /dev/md0 --level=0 --chunk=64 --raid-devices=2 /dev/sdb1 /dev/sdb2";
$cmds{mdadm_create_2}{out}= <<'EOF';
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
EOF

$cmds{grepq_no_md0}{cmd}="/bin/grep -q md0 /proc/mdstat";
$cmds{grepq_no_md0}{ec}=1;

$cmds{grepq_md0}{cmd}="/bin/grep -q md0 /proc/mdstat";
$cmds{grepq_md0}{ec}=0;

$cmds{file_s_nomd0}{cmd}="file -s /dev/md0";
$cmds{file_s_nomd0}{err} = "/dev/md0: ERROR: cannot open `/dev/md0' (No such file or directory)";
$cmds{file_s_nomd0}{ec} = 1;

$cmds{file_s_md0_data}{cmd}="file -s /dev/md0";
$cmds{file_s_md0_data}{out} = "/dev/md0: data";

$cmds{file_s_sdb_nodata}{cmd}="file -s /dev/sdb";
$cmds{file_s_sdb_nodata}{out}="/dev/sdb: ERROR: cannot open `/dev/sdb' (No such file or directory)";
$cmds{file_s_sdb_nodata}{ec}=1;

$cmds{file_s_sdb_data}{cmd}="file -s /dev/sdb";
$cmds{file_s_sdb_data}{out}="/dev/sdb: data";

$cmds{file_s_sdb_partitioned}{cmd}="file -s /dev/sdb";
$cmds{file_s_sdb_partitioned}{out}="/dev/sdb: x86 boot sector; partition 1: ID=0xee, starthead 0, startsector 1, 8388607 sectors, extended partition table (last)\011, code offset 0x0";

$cmds{parted_print_sdb_nopart}{cmd}="/sbin/parted -s -- /dev/sdb print";
$cmds{parted_print_sdb_nopart}{err}="Error: /dev/sdb: unrecognised disk label";
$cmds{parted_print_sdb_nopart}{ec}=1;

# tested with this version
# avoids appending MB to some commands under EL5, screwing up mocked commands
$cmds{parted_version_2}{cmd}="/sbin/parted -v";
$cmds{parted_version_2}{out} = <<'EOF';
parted (GNU parted) 2.1
Copyright (C) 2009 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>.
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by <http://parted.alioth.debian.org/cgi-bin/trac.cgi/browser/AUTHORS>.
EOF

$cmds{parted_init_sdb_gpt}{cmd}="/sbin/parted -s /dev/sdb mklabel gpt";

$cmds{parted_print_sdb_gptlabel}{cmd}="/sbin/parted -s -- /dev/sdb print";
$cmds{parted_print_sdb_gptlabel}{out}= <<'EOF';
Model: ATA QEMU HARDDISK (scsi)
Disk /dev/sdb: 4295MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt

Number  Start  End  Size  File system  Name  Flags

EOF

$cmds{parted_print_sdb_2prim}{cmd}="/sbin/parted -s -- /dev/sdb print";
$cmds{parted_print_sdb_2prim}{out}= <<'EOF';
Model: ATA QEMU HARDDISK (scsi)
Disk /dev/sdb: 4295MB
Sector size (logical/physical): 512B/512B
Partition Table: gpt

Number  Start   End    Size    File system  Name     Flags
 1      17.4kB  100MB  100MB                primary
 2      101MB   200MB  99.6MB               primary

EOF

$files{proc_mdstat_no_md0} = <<'EOF';
Personalities : 
unused devices: <none>
EOF

$files{proc_mdstat_md0} = <<'EOF';
Personalities : [raid0] 
md0 : active raid0 sdb2[1] sdb1[0]
      194816 blocks super 1.2 64k chunks
      
unused devices: <none>
EOF

$cmds{md0_stop}{cmd}="/sbin/mdadm --stop /dev/md0";
$cmds{md0_stop}{out}="mdadm: stopped /dev/md0";

$cmds{mdzero_sdb1}{cmd}="/sbin/mdadm --zero-superblock /dev/sdb1";
$cmds{mdzero_sdb2}{cmd}="/sbin/mdadm --zero-superblock /dev/sdb2";

$files{proc_mdstat_md0_removed} = <<'EOF';
Personalities : [raid0] 
unused devices: <none>
EOF

