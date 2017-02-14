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
my $fraction = $o->{validate}->{size}->{fraction};
my $diff = $o->{validate}->{size}->{diff};
my @int = $o->valid_size_interval();
is_deeply(\@int, [3996, 4004], "Correct interval fraction $fraction diff $diff expected size $o->{size}"); 

# increase fraction, so diff gives shortest interval
$o->{validate}->{size}->{fraction} = 10;
$fraction = $o->{validate}->{size}->{fraction};
@int = $o->valid_size_interval();
is_deeply(\@int, [3900, 4100], "Correct interval fraction $fraction diff $diff expected size $o->{size}"); 

# no conditions, expecte size as boundaries
$o->{validate}->{size} = {};
@int = $o->valid_size_interval();
is_deeply(\@int, [$o->{size}, $o->{size}], "Correct interval no fraction or diff expected size $o->{size}"); 

# 100MiB margin
$o->{validate}->{size}->{diff} = 100;
@int = $o->valid_size_interval();
is_deeply(\@int, [3900, 4100], "Correct interval with 100MiB diff expected size $o->{size}"); 

ok($o->is_valid_size, "Disk has valid size");
ok($o->is_valid_device, "Disk is valid device (only size condition)");


# 10MiB
$o->{validate}->{size}->{diff} = 10;
ok(! $o->is_valid_size, "Disk does not have valid size (with 10MiB diff)");
ok(! $o->is_valid_device, "Disk is not valid device (only size condition)");


delete $o->{validate}->{size}->{diff};
$o->{validate}->{size}->{fraction} = 0.01;
ok(! $o->is_valid_size, "Disk does not have valid size (with 1 percent fraction)");
ok(! $o->is_valid_device, "Disk is not valid device (only size condition)");

# still ok without valid check
delete $o->{validate}->{size};
ok(! $o->is_valid_size, "Disk does not have valid size (no correct size condition defined)");
ok($o->is_valid_device, "Disk is valid device (without any condition, legacy behaviour is to assume it is the correct)");

# No remove/create
command_history_reset;

$o->{validate}->{size}->{fraction} = 0.01;
ok(! $o->is_valid_device, "Disk is not valid device (only size condition)");
is($o->create, 1, "Create returns 1 with invalid device");
# No parted mklabel nor dd (have to be 2 checks).
ok(! command_history_ok(['/bin/dd']), "No dd with invalid device during remove");
ok(! command_history_ok(['parted']), "No parted (for mklabel) with invalid device during create");

command_history_reset;
is($o->remove, 1, "Remove returns 1 with invalid device");
ok(! command_history_ok(['/bin/dd']), "No dd with invalid device during remove");

# test some ks functions, those just print to default FH
my $fhks = CAF::FileWriter->new("target/test/ksdisksize");
my $origfh = select($fhks);

@int = $o->valid_size_interval();
$o->ks_pre_is_valid_size;
my $command = join(" ", "valid_disksize_MiB", $o->devpath, @int);
like("$fhks", qr{^$command$}m, "Found valid min/max");
like("$fhks", qr{^if\s+\[\s+\$\?\s+-ne\s+0\s+\]}m, "Found valid condition");
like("$fhks", qr{exit\s+1}m, "Found valid exit");

my $fhks2 = CAF::FileWriter->new("target/test/ksdisksize2");
select($fhks2);
$o->ks_pre_is_valid_size;
like("$fhks2", qr{^$command$}m, "Found valid min/max with ks_is_valid_device");
like("$fhks2", qr{^if\s+\[\s+\$\?\s+-ne\s+0\s+\]}m, "Found valid condition  with ks_is_valid_device");
like("$fhks2", qr{exit\s+1}m, "Found valid exit with ks_is_valid_device");

my $fhks3 = CAF::FileWriter->new("target/test/ksdisksize3");
select($fhks3);
$o->ks_is_valid_device;
like("$fhks2", qr{^$command$}m, "Found valid min/max with ks_is_valid_device");
like("$fhks2", qr{^if\s+\[\s+\$\?\s+-ne\s+0\s+\]}m, "Found valid condition  with ks_is_valid_device");
like("$fhks2", qr{exit\s+1}m, "Found valid exit with ks_is_valid_device");

# restore FH for DESTROY
select($origfh);

done_testing();

