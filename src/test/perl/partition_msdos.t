#!/usr/bin/perl
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

use Test::More;
use Test::Quattor qw(blockdevices_msdos);
use helper;

use NCM::Disk;
use NCM::Partition;

is(join(' ',NCM::Partition::PARTEDEXTRA), 'u MiB', "Always extra args 'u MiB' for parted");

my $cfg = get_config_for_profile('blockdevices_msdos');
command_history_reset;
set_output("parted_print_sdb_label_msdos"); # no partitions, has msdos label
set_output("file_s_sdb_labeled"); # file -s works too
# disk is now considered empty, it will be removed and label recreated
set_output("dd_init_1000");
set_output("parted_init_sdb_msdos");
set_output("parted_mkpart_sdb_prim1");

set_disks({sdb => 1});

my $sdb1 = NCM::Partition->new ("/system/blockdevices/partitions/sdb1", $cfg);
is ($sdb1->create, 0, "Partition $sdb1->{devname} on logical partitions test created correctly");
is ($sdb1->begin, 0, 'Begin from 0 (no offset) for 1st partition'); 
set_output("parted_print_sdb_1prim_msdos"); # needed to update for begin/end calculations
is($sdb1->{holding_dev}->partitions_in_disk, 1, "partition created correctly");
is(scalar(keys %NCM::Disk::disks), 1, "One known disk in NCM::Disk");

set_output("parted_mkpart_sdb_prim2");
my $sdb2 = NCM::Partition->new ("/system/blockdevices/partitions/sdb2", $cfg);
is ($sdb2->create, 0, "Partition $sdb2->{devname} on logical partitions test created correctly");
is ($sdb2->begin, 100, 'Begin from 0 (no offset) for 2nd partition'); 
set_output("parted_print_sdb_2prim_msdos"); # needed to update for begin/end calculations
is($sdb1->{holding_dev}, $sdb2->{holding_dev}, "Using the same disk instance sdb1 sdb2");
is($sdb2->{holding_dev}->partitions_in_disk, 2, "partition created correctly");
is(scalar(keys %NCM::Disk::disks), 1, "One known disk in NCM::Disk");

set_output("parted_mkpart_sdb_ext1");
my $sdb3 = NCM::Partition->new ("/system/blockdevices/partitions/sdb3", $cfg);
is ($sdb3->create, 0, "Partition $sdb3->{devname} on logical partitions test created correctly");
is ($sdb3->begin, 200, 'Begin from 0 (no offset) for 3rd partition'); 
set_output("parted_print_sdb_2prim_1ext_msdos"); # needed to update for begin/end calculations
is($sdb1->{holding_dev}, $sdb3->{holding_dev}, "Using the same disk instance sdb1 sdb3");
is($sdb2->{holding_dev}, $sdb3->{holding_dev}, "Using the same disk instance sdb2 sdb3");
is($sdb3->{holding_dev}->partitions_in_disk, 3, "partition created correctly");

set_output("parted_mkpart_sdb_log1_msdos");
my $sdb5 = NCM::Partition->new ("/system/blockdevices/partitions/sdb5", $cfg);
is ($sdb5->create, 0, "Partition $sdb5->{devname} on logical partitions test created correctly");
is ($sdb5->begin, 200, 'Begin from 0 (no offset) for 5th partition'); 


set_output("parted_print_sdb_2prim_1ext_1log_msdos"); # all partitions
is($sdb1->{holding_dev}, $sdb5->{holding_dev}, "Using the same disk instance sdb1 sdb5");
is($sdb2->{holding_dev}, $sdb5->{holding_dev}, "Using the same disk instance sdb2 sdb5");
is($sdb3->{holding_dev}, $sdb5->{holding_dev}, "Using the same disk instance sdb3 sdb5");
is($sdb5->{holding_dev}->partitions_in_disk, 4, "partition created correctly");


ok($sdb1->devexists, 'Partition sdb1 exists (on msdos label)');
ok($sdb2->devexists, 'Partition sdb2 exists (on msdos label)');
ok($sdb3->devexists, 'Partition sdb3 exists (on msdos label)');
ok($sdb5->devexists, 'Partition sdb5 exists (on msdos label)');

# these should all have run
ok(command_history_ok([
    '/bin/dd if=/dev/zero count=1000 of=/dev/sdb',
    '/sbin/parted -s -- /dev/sdb mklabel msdos',
    '/sbin/parted -s -- /dev/sdb u MiB mkpart primary 0 100',
    '/sbin/parted -s -- /dev/sdb u MiB mkpart primary 100 200',
    '/sbin/parted -s -- /dev/sdb u MiB mkpart extended 200 2700',
    '/sbin/parted -s -- /dev/sdb u MiB mkpart logical 200 1224',
    ]), 'Command history msdos'
);

command_history_reset;

set_output('parted_rm_5');
is($sdb5->remove, 0, 'Partition sdb5 removed (on msdos label)');
set_output("parted_print_sdb_2prim_1ext_msdos");
ok(command_history_ok([
        "/sbin/parted -s -- /dev/sdb u MiB rm 5"
    ]), 'Command history partiton removal'
);

# Test get_clear_mb
is($sdb1->get_clear_mb(), 1, "Default minimal clearmb of 1");


done_testing();
