#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use Test::More;
use NCM::Filesystem;
use CAF::Object;
use Test::Quattor qw(filesystem filesystem_removed);

use helper; 

my $cfg = get_config_for_profile('filesystem');

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
        "/sbin/parted -s -- /dev/sdb print", 
        "file -s /dev/sdb1", 
        "mkfs.ext3 /dev/sdb1"]), 
    "mkfs.ext3 called on /dev/sdb1");

# set empty fstab
set_file("fstab_default");
$fs->update_fstab;
like(get_file('/etc/fstab'), qr#/dev/sdb1\s+/Lagoon\s+ext3\s+auto\s+0\s+1\s*#, 'Mount entry added to fstab');

# test mounted call; 
set_file("mtab_default");
is($fs->mounted,0, 'Mountpoint not mounted');
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

# TODO
# test create if needed with fstab
# with mountpoint
# with mountpoint in comment
# without mountpoint
# returns 0 without calling create

command_history_reset;
diag('removing filesystems');
my $nofs_cfg = get_config_for_profile('filesystem');
my $nofs = NCM::Filesystem->new ("/system/filesystems/0", $nofs_cfg);
command_history_reset;
$nofs->remove_if_needed;
# TODO 
#   should call parted delete
#   fstab should not have that line anymore

done_testing();

