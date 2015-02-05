#!/usr/bin/perl
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

use Test::More;
use Test::Quattor qw(filesystem filesystem_lvmforce);
use helper;

use NCM::Filesystem;
use CAF::FileWriter;
use CAF::FileEditor;
use CAF::Object;

my $cfg = get_config_for_profile('filesystem');

set_disks({sdb => 1});

# resolve LABEL/UUID
set_output("fs_sdb1_parted_print_ext3");
set_file("mtab_sdb1_ext3_mounted");
my $fslabel = NCM::Filesystem->new_from_fstab("LABEL=lagoon /Lagoon ext3 defaults 1 2", $cfg);
is($fslabel->{mountpoint}, '/Lagoon', 'Correct mountpoint');
is($fslabel->{block_device}->{devname}, 'sdb1', 'Correct partition found');
is($fslabel->{block_device}->{holding_dev}->{devname}, 'sdb', 'Correct holding device found');

my $fsuuid = NCM::Filesystem->new_from_fstab("UUID=1234-hvhv-1234-hvp /Lagoon ext3 defaults 1 2", $cfg);
is($fsuuid->{mountpoint}, '/Lagoon', 'Correct mountpoint');
is($fsuuid->{block_device}->{devname}, 'sdb1', 'Correct partition found');
is($fsuuid->{block_device}->{holding_dev}->{devname}, 'sdb', 'Correct holding device found');

# regular fs test
my $fs = NCM::Filesystem->new ("/system/filesystems/0", $cfg);
command_history_reset;
set_file("fstab_default");
set_file("mtab_default");
set_output("parted_print_sdb_1prim_gpt");
set_output("file_s_sdb_labeled");
set_output("file_s_sdb1_data");
set_output("fs_lagoon_missing");

$fs->create_if_needed;
ok(command_history_ok([
        "/sbin/parted -s -- /dev/sdb u MiB print",
        "file -s /dev/sdb1",
        "mkfs.ext3 /dev/sdb1"]),
    "mkfs.ext3 called on /dev/sdb1");

# set empty fstab
set_file("fstab_default");
$fs->update_fstab;
like(get_file('/etc/fstab'), qr#^/dev/sdb1\s+/Lagoon\s+ext3\s+auto\s+0\s+1\s*#m, 'Mount entry added to fstab');
# do it again! should still work
my $newtxt = get_file('/etc/fstab'); #otherwise Can't coerce GLOB to string in substr
set_file("fstab_default","$newtxt");
$fs->update_fstab;
like(get_file('/etc/fstab'), qr#^/dev/sdb1\s+/Lagoon\s+ext3\s+auto\s+0\s+1\s*#m, 'Mount entry added to fstab');

# try update_fstab with existing CAF::FileEditor instance
my $fh = CAF::FileEditor->new("target/test/update_fstab");
ok(! $fh, "Empty / new file is logical false.");
$fs->update_fstab($fh);
like("$fh", qr#^/dev/sdb1\s+/Lagoon\s+ext3\s+auto\s+0\s+1\s*#m, 'Mount entry added to temporary fstab');
$fh->close();

# test mounted call;
set_file("mtab_default");
is($fs->mounted, '', 'Mountpoint not mounted');
set_file("mtab_sdb1_ext3_mounted");
is($fs->mounted,1, 'Mountpoint mounted');
# sdb1 is now mounted

# pretend ext3 is there
set_output("file_s_sdb1_ext3");
command_history_reset;
$fs->create_if_needed;
ok(!command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'No mkfs.ext3 called');
ok(!command_history_ok(["gparted"]), 'No gparted called');
ok(!command_history_ok(["dd"]), 'No dd called');

# test create if needed with fstab
set_file("fstab_default");

is($fs->mountpoint_in_fstab, '', 'No mountpoint in fstab');
set_file("fstab_sdb1_ext3_commented");
is($fs->mountpoint_in_fstab, '', 'Mountpoint commented in fstab');
set_file("fstab_sdb1_ext3_with_comment");
is($fs->mountpoint_in_fstab, 1, 'Mountpoint in fstab and also commented in fstab');
set_file("fstab_sdb1_ext3");
is($fs->mountpoint_in_fstab, 1, 'Mountpoint in fstab');


command_history_reset;
my $nofs = NCM::Filesystem->new ("/system/filesystems/1", $cfg);
# this test is actually a test of the profile
ok(!($nofs->{preserve} || !$nofs->{format}), 'Allow removal');
command_history_reset;
set_file("fstab_sdb1_ext3");
$nofs->remove_if_needed;
ok(command_history_ok([
    "/bin/umount /Lagoon",
    "/sbin/parted -s -- /dev/sdb u MiB rm 1",
    ]),
    "Removal commands called"
);
unlike(get_file('/etc/fstab'), qr#\s+/Lagoon\s+#, 'Mountpoint removed to fstab');

#
# test has_filesystem
#
my $sdb1=$fs->{block_device};
is($sdb1->{devname}, 'sdb1', 'Correct partition found');

set_output("file_s_sdb1_data");
is($sdb1->has_filesystem, '', 'Partition sdb1 has no filesystem');
set_output("file_s_sdb1_ext3");
is($sdb1->has_filesystem, 1, 'Partition sdb1 has filesystem');
is($sdb1->has_filesystem('ext3'), 1, 'Partition sdb1 has ext3 filesystem');
is($sdb1->has_filesystem('ext4'), '', 'Partition sdb1 does not have ext4 filesystem');
is($sdb1->has_filesystem('superfilesystem'), 1, 'fs superfilesystem is not supported, but sdb1 has a supported filesystem');

set_output("file_s_sdb1_btrfs");
is($sdb1->has_filesystem, 1, 'Partition sdb1 has filesystem');
is($sdb1->has_filesystem('btrfs'), 1, 'Partition sdb1 has btrfs filesystem');
is($sdb1->has_filesystem('ext3'), '', 'Partition sdb1 does not have ext3 filesystem');
is($sdb1->has_filesystem('superfilesystem'), 1, 'fs superfilesystem is not supported, but sdb1 has a supported filesystem');

# supported filesystems
# impossible file -s  output (it's joined from multiple file -s runs)
# no output for jfs and reiser
set_output("file_s_sdb1_all_supported");
is($sdb1->has_filesystem, 1, 'Partition sdb1 has filesystem');
is($sdb1->has_filesystem('superfilesystem'), 1, 'fs superfilesystem is not supported, but sdb1 has a supported filesystem');

is($sdb1->has_filesystem('ext2'), 1, 'Partition sdb1 has ext3 filesystem');
is($sdb1->has_filesystem('ext3'), 1, 'Partition sdb1 has ext3 filesystem');
is($sdb1->has_filesystem('ext4'), 1, 'Partition sdb1 has ext4 filesystem');
is($sdb1->has_filesystem('xfs'), 1, 'Partition sdb1 has xfs filesystem');
is($sdb1->has_filesystem('btrfs'), 1, 'Partition sdb1 has btrfs filesystem');

#
# formatfs
#

# force_filesystem is set to true
#   mkfs is called
set_output("file_s_sdb1_data");
command_history_reset;
$fs->formatfs;
ok(command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'mkfs.ext3 called');

# regular filesystem type, filesystem present
#   no mkfs is called
set_output("file_s_sdb1_ext3");
command_history_reset;
$fs->formatfs;
ok(!command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'No mkfs.ext3 called');

# type none
#   no mkfs called
my $nonefs = NCM::Filesystem->new ("/system/filesystems/2", $cfg);
set_output("file_s_sdb1_data");
command_history_reset;
$nonefs->formatfs;
ok(!command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'none type No mkfs.ext3 called');

set_output("file_s_sdb1_ext3");
command_history_reset;
$nonefs->formatfs;
ok(!command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'none type No mkfs.ext3 called');

# force_filesystemtype is set to false
my $forcefalsefs = NCM::Filesystem->new ("/system/filesystems/3", $cfg);
#   regular filesystem type, no filesystem present
#     mkfs is called
set_output("file_s_sdb1_data");
command_history_reset;
$forcefalsefs->formatfs;
ok(command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'force false mkfs.ext3 called');
#   regular filesystem type, filesystem present
#     no mkfs is called
set_output("file_s_sdb1_ext3");
command_history_reset;
$forcefalsefs->formatfs;
ok(!command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'force false ext3 No mkfs.ext3 called');

# filesystem is present and it's the wrong one
#   mkfs not called
set_output("file_s_sdb1_btrfs");
command_history_reset;
$forcefalsefs->formatfs;
ok(!command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'force false btrfs No mkfs.ext3 called');

# force_filesystemtype is set to true
my $forcetruefs = NCM::Filesystem->new ("/system/filesystems/4", $cfg);
# regular filesystem type, no filesystem present
#  mkfs is called
set_output("file_s_sdb1_data");
command_history_reset;
$forcetruefs->formatfs;
ok(command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'force true mkfs.ext3 called');

# filesystem is present and it's the correct one
#   mkfs not called
set_output("file_s_sdb1_ext3");
command_history_reset;
$forcetruefs->formatfs;
ok(!command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'force true ext3 No mkfs.ext3 called');

# filesystem is present and it's the wrong one
#   mkfs called
set_output("file_s_sdb1_btrfs");
command_history_reset;
$forcetruefs->formatfs;
ok(command_history_ok(["mkfs.ext3.*/dev/sdb1"]), 'force true btrfs mkfs.ext3 called');

#
# create if needed
#
# is mounted, not needed, ever
set_file("mtab_sdb1_ext3_mounted");
is($fs->is_create_needed, 0, 'Mountpoint mounted');
is($forcefalsefs->is_create_needed, 0, 'Mountpoint mounted');
is($forcetruefs->is_create_needed, 0, 'Mountpoint mounted');

# not mounted, mountpoint exists in fstab
set_file("mtab_default");
set_file("fstab_sdb1_ext3");
is($fs->is_create_needed, 0, 'create not needed, mountpoint in fstab');
is($forcefalsefs->is_create_needed, 0, 'create not needed, mountpoint in fstab');
is($forcetruefs->is_create_needed, 1, 'create needed, mountpoint in fstab but ignored');

# not mounted, not in fstab
set_file("fstab_default");
is($fs->is_create_needed, 1, 'create needed, mountpoint not in fstab');
is($forcefalsefs->is_create_needed, 1, 'create needed, mountpoint not in fstab');
is($forcetruefs->is_create_needed, 1, 'create needed, mountpoint not in fstab but ignored anyway');

# test some ks functions, those just print to default FH
my $fhfs = CAF::FileWriter->new("target/test/ksfs");

my $origfh = select($fhfs);

ok(!exists($fs->{ksfsformat}), 'ksfsformat not defined');
$fs->print_ks;
like($fhfs, qr{^part\s/Lagoon\s--onpart\ssdb1}m, 'Default print_ks');
like($fhfs, qr{\s--noformat(\s|$)?}m, 'Default print_ks --noformat');
unlike($fhfs, qr{\s--fstype}m, 'Default print_ks noformat has no fstype');

my $fhfs_ksfsformat = CAF::FileWriter->new("target/test/ksfs_ksformat");
my $fs_ksfsformat = NCM::Filesystem->new ("/system/filesystems/5", $cfg);
select($fhfs_ksfsformat);
ok($fs_ksfsformat->{ksfsformat}, 'ksfsformat set');
$fs_ksfsformat->print_ks;
like($fhfs_ksfsformat, qr{^part\s/Lagoon\s--onpart\ssdb1}m, 'Default print_ks');
unlike($fhfs_ksfsformat, qr{\s--noformat(\s|$)?}m, 'ksfsformat has no --noformat');
like($fhfs_ksfsformat, qr{--fstype=ext3\s--fsoptions='oneoption anotheroption'}m, 'ksfsformat print_ks has fsttype and fsopts/mountopts');

# softraid test
my $fhfs_md = CAF::FileWriter->new("target/test/ksfs_md");
my $fs_md = NCM::Filesystem->new ("/system/filesystems/6", $cfg);
select($fhfs_md);
ok(!exists($fs_md->{ksfsformat}), 'ksfsformat not defined');
$fs_md->print_ks;
like($fhfs_md, qr{^raid\s/Lagoon\s--device=md0}m, 'Default print_ks for md');
like($fhfs_md, qr{\s--noformat(\s|$)?}m, 'Default print_ks --noformat for md');
unlike($fhfs_md, qr{\s--fstype}m, 'Default print_ks noformat has no fstype for md');

# logical volume test
my $fhfs_vol = CAF::FileWriter->new("target/test/ksfs_vol");
my $fs_vol = NCM::Filesystem->new ("/system/filesystems/7", $cfg);
select($fhfs_vol);
ok(!exists($fs_vol->{ksfsformat}), 'ksfsformat not defined');
$fs_vol->print_ks;
like($fhfs_vol, qr{^logvol\s/Lagoon\s--vgname=vg0\s--name=lv0}m, 'Default print_ks for logvol');
like($fhfs_vol, qr{\s--noformat(\s|$)?}m, 'Default print_ks --noformat for logvol');
unlike($fhfs_vol, qr{\s--fstype}m, 'Default print_ks noformat has no fstype for logvol');

# preserve / no format
my $fhfs_vol_del = CAF::FileWriter->new("target/test/ksfs_vol_del");
select($fhfs_vol_del);
$fs_vol->del_pre_ks;
is("$fhfs_vol_del", '', "Not removing anything in ks pre");

# This one is formattable/no preserve
my $fs_vol1 = NCM::Filesystem->new ("/system/filesystems/8", $cfg);
my $fhfs_vol1_del = CAF::FileWriter->new("target/test/ksfs_vol1_del");
select($fhfs_vol1_del);
$fs_vol1->del_pre_ks;
like($fhfs_vol1_del, qr{^lvm lvremove\s+/dev/vg0/lv1}m, "Removing LV in ks pre");

like($fhfs_vol1_del, qr{^lvm vgreduce\s+--removemissing vg0}m, "Removing unused PVs from vg0 in ks pre");
like($fhfs_vol1_del, qr{^lvm vgremove\s+vg0}m, "Remove PV vg0 in ks pre");
like($fhfs_vol1_del, qr{^lvm pvremove\s+/dev/sdb1}m, "Remove sdb1 partition as physical volume in ks pre");
like($fhfs_vol1_del, qr{^\s+parted /dev/sdb -s rm 1}m, "Remove sdb1 partition from disk sdb in ks pre");

# Check the force options (e.g. required fro EL7)

# reset the LVM vgs cache (these vgs should have new attribute).
use NCM::LVM;
NCM::LVM::_reset_cache;

my $cfg_force = get_config_for_profile('filesystem_lvmforce');
my $fs_vol1_force = NCM::Filesystem->new ("/system/filesystems/8", $cfg_force);
my $fhfs_vol1_del_force = CAF::FileWriter->new("target/test/ksfs_vol1_del_force");
select($fhfs_vol1_del_force);
$fs_vol1_force->del_pre_ks;
like($fhfs_vol1_del_force, qr{^lvm lvremove\s--force\s/dev/vg0/lv1}m, "Removing LV in ks pre (--force)");

like($fhfs_vol1_del_force, qr{^lvm vgreduce\s--force\s--removemissing vg0}m, "Removing unused PVs from vg0 in ks pre (--force)");
like($fhfs_vol1_del_force, qr{^lvm vgremove\s--force\svg0}m, "Remove PV vg0 in ks pre (--force)");
like($fhfs_vol1_del_force, qr{^lvm pvremove\s--force\s/dev/sdb1}m, "Remove sdb1 partition as physical volume in ks pre (--force)");

# restore FH for DESTROY
select($origfh);

done_testing();
