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
use Test::Quattor qw(filesystem);

use helper; 

my $cfg = get_config_for_profile('filesystem');

# resolve LABEL
set_output("fs_sdb1_parted_print_ext3");
set_file_contents("/etc/mtab", "/dev/sdb1 /Lagoon ext3 rw 0 0");
my $fslabel = NCM::Filesystem->new_from_fstab("LABEL=lagoon /Lagoon ext3 defaults 1 2", $cfg);
is($fslabel->{mountpoint}, '/Lagoon', 'Correct mountpoint');
is($fslabel->{block_device}->{devname}, 'sdb1', 'Correct partition found');
is($fslabel->{block_device}->{holding_dev}->{devname}, 'sdb', 'Correct holding device found');


# regular fs test
my $fs = NCM::Filesystem->new ("/system/filesystems/0", $cfg);
command_history_reset;
set_output("parted_print_sdb_1prim_gpt");
set_output("file_s_sdb_labeled");
set_output("file_s_sdb1_data");
set_output("fs_lagoon_missing");
$fs->create_if_needed;
ok(command_history_ok(["/bin/grep -q .*/Lagoon.*/etc/fstab", 
                       "/sbin/parted -s -- /dev/sdb print", 
                       "file -s /dev/sdb1", 
                       "mkfs.ext3.*/dev/sdb1"]), 
    "mkfs.ext3 called on /dev/sdb1");

done_testing();

