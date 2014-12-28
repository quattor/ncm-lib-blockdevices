#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

use Test::More;
use Test::Quattor qw(blockdevices_size);
use helper; # mocks NCM::Disk devexists to always true

use NCM::BlockdevFactory qw (build);

my $cfg = get_config_for_profile('blockdevices_size');

my $o = build ($cfg, "physical_devs/sdb");
isa_ok ($o, "NCM::Disk", "Disk correctly instantiated");

set_output("blockdev_sdb_4GB");
is($o->_size_in_byte, 4*1024*1024*1024, "Correct disk size in byte");
is($o->size, 4*1024, "Correct disk size in MiB");


done_testing();

