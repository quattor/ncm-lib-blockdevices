#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use helper qw(set_output);
use Test::More;
use Test::Quattor qw(blockdevices_gpt_partition_offset);

use NCM::Partition;

is(join(' ',NCM::Partition::PARTEDEXTRA), 'u MB', "Always extra args 'u MB' for parted");

# the config has a "bug" in the sense that logical/extended partitions 
# make no sense when using gpt (they are treated as names)
# should still work though
my $cfg = get_config_for_profile('blockdevices_gpt_partition_offset');
command_history_reset;

set_output("parted_print_sdb_label_gpt"); # no partitions, has gpt label
set_output("file_s_sdb_labeled"); # file -s works too
# disk is now considered empty, it will be removed and label recreated
set_output("dd_init_1000");
set_output("parted_init_sdb_gpt");
set_output("parted_mkpart_sdb_prim1_offset");
my $sdb1 = NCM::Partition->new ("/system/blockdevices/partitions/sdb1", $cfg);
is ($sdb1->{offset}, 1, 'Offset set for 1st partition');
is ($sdb1->create, 0, "Partition $sdb1->{devname} on logical partitions test created correctly");
is ($sdb1->begin, 1, 'Correct offset for 1st partition'); 

set_output("parted_print_sdb_1prim_gpt_offset"); # needed to update for begin/end calculations
is($sdb1->{holding_dev}->partitions_in_disk, 1, "partition created correctly");

set_output("parted_mkpart_sdb_prim2_offset");
my $sdb2 = NCM::Partition->new ("/system/blockdevices/partitions/sdb2", $cfg);
ok (! exists($sdb2->{offset}), 'Offset not set for 2nd partition');
is ($sdb2->create, 0, "Partition $sdb2->{devname} on logical partitions test created correctly");
is ($sdb2->begin, 101, 'Begin from 101 (no offset) for 2nd partition'); 
set_output("parted_print_sdb_2prim_gpt_offset"); # needed to update for begin/end calculations
is($sdb1->{holding_dev}, $sdb2->{holding_dev}, "Using the same disk instance sdb1 sdb2");
is($sdb2->{holding_dev}->partitions_in_disk, 2, "partition created correctly");

set_output("parted_mkpart_sdb_ext1_offset");
my $sdb3 = NCM::Partition->new ("/system/blockdevices/partitions/sdb3", $cfg);
is ($sdb3->create, 0, "Partition $sdb3->{devname} on logical partitions test created correctly");
is ($sdb3->begin, 202, 'Begin from 202 (offset 1) for 3rd partition'); 
set_output("parted_print_sdb_2prim_1ext_gpt_offset"); # needed to update for begin/end calculations
is($sdb1->{holding_dev}, $sdb3->{holding_dev}, "Using the same disk instance sdb1 sdb3");
is($sdb2->{holding_dev}, $sdb3->{holding_dev}, "Using the same disk instance sdb2 sdb3");
is($sdb3->{holding_dev}->partitions_in_disk, 3, "partition created correctly");

set_output("parted_mkpart_sdb_log1_gpt_offset");
my $sdb4 = NCM::Partition->new ("/system/blockdevices/partitions/sdb4", $cfg);
is ($sdb4->create, 0, "Partition $sdb4->{devname} on logical partitions test created correctly");
is ($sdb4->begin, 2702, 'Begin from 2702 (no offset) for 4th partition'); 
set_output("parted_print_sdb_2prim_1ext_1log_gpt_offset"); # all partitions
is($sdb1->{holding_dev}, $sdb4->{holding_dev}, "Using the same disk instance sdb1 sdb4");
is($sdb2->{holding_dev}, $sdb4->{holding_dev}, "Using the same disk instance sdb2 sdb4");
is($sdb3->{holding_dev}, $sdb4->{holding_dev}, "Using the same disk instance sdb3 sdb4");
is($sdb4->{holding_dev}->partitions_in_disk, 4, "partition created correctly");

ok($sdb1->devexists, 'Partition sdb1 exists (on gpt label)');
ok($sdb2->devexists, 'Partition sdb2 exists (on gpt label)');
ok($sdb3->devexists, 'Partition sdb3 exists (on gpt label)');
ok($sdb4->devexists, 'Partition sdb4 exists (on gpt label)');

# these should all have run
ok(command_history_ok([
    '/bin/dd if=/dev/zero count=1000 of=/dev/sdb',
    '/sbin/parted -s -- /dev/sdb mklabel gpt',
    '/sbin/parted -s -- /dev/sdb u MB mkpart primary 1 101',
    '/sbin/parted -s -- /dev/sdb u MB mkpart primary 101 201',
    '/sbin/parted -s -- /dev/sdb u MB mkpart extended 202 2702',
    '/sbin/parted -s -- /dev/sdb u MB mkpart logical 2702 3726',
    ]), 'Command history gpt partition with offset'
);

done_testing();
