#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

use Test::More;
use Test::Quattor qw(factory);
use helper;

use NCM::Blockdevices qw ($reporter);
use NCM::BlockdevFactory qw (build);
use CAF::Object;

$CAF::Object::NoAction = 1;

is(join(' ',NCM::BlockdevFactory::PARTEDEXTRA), 'u MiB', "Always extra args 'u MiB' for parted");

my $cfg = get_config_for_profile('factory');

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
$o = build ($cfg, "vxvm/vcslab.local/gnr.0" );
is (ref ($o), "NCM::VXVM", "VXVM correctly instantiated");

$o = build ($cfg, "unknown/unknown");
ok(! defined($o), 'build returns undef with unknown blockdevice');
is($self->{ERROR}, 1, "Errors for an unknown blockdevice");

done_testing();
