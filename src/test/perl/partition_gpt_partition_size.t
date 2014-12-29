#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

use Test::More;
use Test::Quattor qw(blockdevices_gpt_partition_size);
use helper;

use NCM::Partition;

my $cfg = get_config_for_profile('blockdevices_gpt_partition_size');
command_history_reset;

set_output("parted_print_sdb_label_gpt"); # no partitions, has gpt label
set_output("file_s_sdb_labeled"); # file -s works too
# disk is now considered empty, it will be removed and label recreated
set_output("dd_init_1000");
set_output("parted_init_sdb_gpt");
set_output("parted_mkpart_sdb_prim1");
my $sdb1 = NCM::Partition->new ("/system/blockdevices/partitions/sdb1", $cfg);


ok(! defined($sdb1->size), "Non-existing partition sdb1 gives undef size");
ok(! defined($sdb1->{holding_dev}->size), "Non-existing holding_dev sdb gives undef size");

set_output("blockdev_sdb_4GB");

#set_output("parted_print_sdb_2prim_1ext_1log_msdos");
set_output("blockdev_sdb1_100MiB");
set_output("blockdev_sdb2_100MiB");
set_output("blockdev_sdb3_1kiB");
set_output("blockdev_sdb5_1GiB");


set_disks({sdb => 1});
set_parts({sdb1 => 1});

is($sdb1->_size_in_byte, 100*1024*1024, "Correct partition sdb1 size in byte");
is($sdb1->size, 100, "Correct partition sdb1 size in MiB");

is($sdb1->{holding_dev}->size, 4096, "Correct sdb1 holding_dev size in MiB");

done_testing();
