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

#$Test::Quattor::log_cmd=1;
#$Test::Quattor::log_cmd_missing=1;

use helper qw(set_output);

use NCM::Partition;

my $cfg = get_config_for_profile('blockdevices_msdos');

set_output("parted_print_sdb_label_msdos"); # no partitions, has msdos label
set_output("file_s_sdb_labeled"); # file -s works too
# disk is now considered empty, it will be removed and label recreated
set_output("dd_init_1000");
set_output("parted_init_sdb_msdos");
set_output("parted_mkpart_sdb_prim1");
my $sdb1 = NCM::Partition->new ("/system/blockdevices/partitions/sdb1", $cfg);
is ($sdb1->create, 0, "Partition $sdb1->{devname} on logical partitions test created correctly");
set_output("parted_print_sdb_1prim_msdos"); # needed to update for begin/end calculations

set_output("parted_mkpart_sdb_prim2");
my $sdb2 = NCM::Partition->new ("/system/blockdevices/partitions/sdb2", $cfg);
is ($sdb2->create, 0, "Partition $sdb2->{devname} on logical partitions test created correctly");
set_output("parted_print_sdb_2prim_msdos"); # needed to update for begin/end calculations

set_output("parted_mkpart_sdb_ext1");
my $sdb3 = NCM::Partition->new ("/system/blockdevices/partitions/sdb3", $cfg);
is ($sdb3->create, 0, "Partition $sdb3->{devname} on logical partitions test created correctly");
set_output("parted_print_sdb_2prim_1ext_msdos"); # needed to update for begin/end calculations

set_output("parted_mkpart_sdb_log1_msdos");
my $sdb5 = NCM::Partition->new ("/system/blockdevices/partitions/sdb5", $cfg);
is ($sdb5->create, 0, "Partition $sdb5->{devname} on logical partitions test created correctly");
set_output("parted_print_sdb_2prim_1ext_1log_msdos"); # all partitions

ok($sdb1->devexists, 'Partition sdb1 exists (on msdos label)');
ok($sdb2->devexists, 'Partition sdb2 exists (on msdos label)');
ok($sdb3->devexists, 'Partition sdb3 exists (on msdos label)');
ok($sdb5->devexists, 'Partition sdb5 exists (on msdos label)');


done_testing();
