#!/usr/bin/perl
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use CAF::Object;
use Test::More;
use Test::Quattor qw(lv-create);
use Test::Quattor::RegexpTest;

use Cwd;
use helper;

use NCM::LV;

=pod

=head1 SYNOPSIS

Tests for the C<NCM::LV> module.

=head1 TESTS

=head2 Initialisation

We create several objects, and check

=cut

$CAF::Object::NoAction = 1;
my $cfg = get_config_for_profile('lv-create');
my $lv = NCM::LV->new ("/system/blockdevices/logical_volumes/lv0", $cfg);
isa_ok($lv, "NCM::LV", "LV correctly instantiated");

set_output("lv0_create_not_ok");
set_output("lv0_not_present");
my $out = $lv->create;
ok($out, 'create not succeeded');

set_output("lv0_create_ok");

$out = $lv->create;
ok(!$out, 'create succeeded');

$lv = NCM::LV->new ("/system/blockdevices/logical_volumes/lvCold", $cfg);
isa_ok($lv, "NCM::LV", "LV with cache correctly instantiated");

set_desired_output("/usr/sbin/lvs vg1/lvCold", 
    "LV    VG     Attr       LSize   Pool        Origin        Data%  Meta%  Move Log Cpy%Sync Convert  \n  lvCold vg1 Cwi-a-C--- 100.00g [lvCache] [lvCold_corig] 0.00   10.74           100.00  ");

set_output("lvCold_not_present");
set_output("lvCache_not_present");
$out = $lv->create;
ok(!$out, "Create ok");

my $cold_create = get_command('/usr/sbin/lvcreate -L 1000 -n lvCold vg1 /dev/sdc');
ok(defined($cold_create), 'cold lv created');
my $cache_create = get_command('/usr/sbin/lvcreate --type cache-pool --chunksize 128 -L 100 -n lvCache vg1 /dev/sdd');
ok(defined($cache_create), 'cache lv created');
my $convert = get_command('/usr/sbin/lvconvert -y --type cache --cachemode writeback --cachepool vg1/lvCache vg1/lvCold');
ok(!defined($convert), 'cache already existed');

set_desired_output("/usr/sbin/lvs vg1/lvCold", "  LV    VG     Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert\n  lvCold vg1 -wi-a----- 100.00g");

$out = $lv->create;
ok(!$out, "Create ok");

$convert = get_command('/usr/sbin/lvconvert -y --type cache --cachemode writeback --cachepool vg1/lvCache vg1/lvCold');
ok(defined($convert), 'convert to cache');

# test some ks functions, those just print to default FH
my $fhmd = CAF::FileWriter->new("target/test/kslv");

my $origfh = select($fhmd);

$lv->create_ks;

diag "$fhmd";
my $regexpdir= getcwd()."/src/test/resources/regexps";
Test::Quattor::RegexpTest->new(
    regexp => "$regexpdir/lvm_create_lv_cache",
    text => "$fhmd"
)->test();


select($origfh);




done_testing();

__END__

=pod

=head1 TODO

Way more tests.

=cut
