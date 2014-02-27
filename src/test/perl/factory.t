#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use Test::More;
use NCM::BlockdevFactory qw (build);
use CAF::Object;
use Test::Quattor qw(blockdevices_gpt);

$CAF::Object::NoAction = 1;

my $cfg = get_config_for_profile('blockdevices_gpt');

my $o = build ($cfg, "physical_devs/sdb");
is (ref ($o), "NCM::Disk", "Disk correctly instantiated");
$o = build ($cfg, "partitions/sdb1");
is (ref ($o), "NCM::Partition", "Partition correctly instantiated");
$o = build ($cfg, "volume_groups/vg0");
is (ref ($o), "NCM::LVM", "LVM correctly instantiated");
$o = build ($cfg, "md/md0");
is (ref ($o), "NCM::MD", "MD correctly instantiated");
$o = build ($cfg, "logical_volumes/lv0");
is (ref ($o), "NCM::LV", "LV correctly instantiated");

done_testing();
