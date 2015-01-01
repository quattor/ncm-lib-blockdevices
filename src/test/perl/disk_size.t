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
use helper; 

use NCM::BlockdevFactory qw (build);


my $cfg = get_config_for_profile('blockdevices_size');

my $o = build ($cfg, "physical_devs/sdb");
isa_ok ($o, "NCM::Disk", "Disk correctly instantiated");

ok(! defined($o->size), "Non-existing disk gives undef size");

set_disks({sdb => 1});

set_output("blockdev_sdb_4GB");
is($o->_size_in_byte, 4*1024*1024*1024, "Correct disk size in byte");
is($o->size, 4*1024, "Correct disk size in MiB");

# test interval
# fraction 0.001 (i.e. 4MiB of 4GiB)
# diff 100MiB
is($o->{size}, 4000, "Expected size attribute set to 4000");
my $fraction = $o->{correct}->{size}->{fraction};
my $diff = $o->{correct}->{size}->{diff};
my @int = $o->correct_size_interval();
is_deeply(\@int, [3996, 4004], "Correct interval fraction $fraction diff $diff expected size $o->{size}"); 

# increase fraction, so diff gives shortest interval
$o->{correct}->{size}->{fraction} = 10;
$fraction = $o->{correct}->{size}->{fraction};
@int = $o->correct_size_interval();
is_deeply(\@int, [3900, 4100], "Correct interval fraction $fraction diff $diff expected size $o->{size}"); 

# no conditions, expecte size as boundaries
$o->{correct}->{size} = {};
@int = $o->correct_size_interval();
is_deeply(\@int, [$o->{size}, $o->{size}], "Correct interval no fraction or diff expected size $o->{size}"); 

# 100MiB margin
$o->{correct}->{size}->{diff} = 100;
@int = $o->correct_size_interval();
is_deeply(\@int, [3900, 4100], "Correct interval with 100MiB diff expected size $o->{size}"); 

ok($o->is_correct_size, "Disk has correct size");
ok($o->is_correct_device, "Disk is correct device (only size condition)");


# 10MiB
$o->{correct}->{size}->{diff} = 10;
ok(! $o->is_correct_size, "Disk does not have correct size (with 10MiB diff)");
ok(! $o->is_correct_device, "Disk is not correct device (only size condition)");


delete $o->{correct}->{size}->{diff};
$o->{correct}->{size}->{fraction} = 0.01;
ok(! $o->is_correct_size, "Disk does not have correct size (with 1 percent fraction)");
ok(! $o->is_correct_device, "Disk is not correct device (only size condition)");

# still ok without correct check
delete $o->{correct}->{size};
ok(! $o->is_correct_size, "Disk does not have correct size (no correct size condition defined)");
ok($o->is_correct_device, "Disk is correct device (without any condition, legacy behaviour is to assume it is the correct)");

done_testing();

