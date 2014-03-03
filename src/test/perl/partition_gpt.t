#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use Test::More;

use Test::Quattor qw(blockdevices_gpt);

use helper qw(set_output);

use NCM::Partition;

# the config has a "bug" in the sense that logical/extended partitions 
# make no sense when using gpt (they are treated as names)
# should still work though
my $cfg = get_config_for_profile('blockdevices_gpt');

set_output("parted_print_sdb_label_gpt"); # no partitions, has gpt label
set_output("file_s_sdb_labeled"); # file -s works too
# disk is now considered empty, it will be removed and label recreated
set_output("dd_init_1000");
set_output("parted_init_sdb_gpt");
set_output("parted_mkpart_sdb_prim1");
my $sdb1 = NCM::Partition->new ("/system/blockdevices/partitions/sdb1", $cfg);
is ($sdb1->create, 0, "Partition $sdb1->{devname} on logical partitions test created correctly");
set_output("parted_print_sdb_1prim_gpt"); # needed to update for begin/end calculations

set_output("parted_mkpart_sdb_prim2");
my $sdb2 = NCM::Partition->new ("/system/blockdevices/partitions/sdb2", $cfg);
is ($sdb2->create, 0, "Partition $sdb2->{devname} on logical partitions test created correctly");
set_output("parted_print_sdb_2prim_gpt"); # needed to update for begin/end calculations

set_output("parted_mkpart_sdb_ext1");
my $sdb3 = NCM::Partition->new ("/system/blockdevices/partitions/sdb3", $cfg);
is ($sdb3->create, 0, "Partition $sdb3->{devname} on logical partitions test created correctly");
set_output("parted_print_sdb_2prim_1ext_gpt"); # needed to update for begin/end calculations

set_output("parted_mkpart_sdb_log1_gpt");
my $sdb4 = NCM::Partition->new ("/system/blockdevices/partitions/sdb4", $cfg);
is ($sdb4->create, 0, "Partition $sdb4->{devname} on logical partitions test created correctly");
set_output("parted_print_sdb_2prim_1ext_1log_gpt"); # all partitions

ok($sdb1->devexists, 'Partition sdb1 exists (on gpt label)');
ok($sdb2->devexists, 'Partition sdb2 exists (on gpt label)');
ok($sdb3->devexists, 'Partition sdb3 exists (on gpt label)');
ok($sdb4->devexists, 'Partition sdb4 exists (on gpt label)');

done_testing();
