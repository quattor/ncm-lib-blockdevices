#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;

use Test::More;
use Test::Quattor qw(blockdevices_gpt_partition_flags);
use helper qw(set_output);

use NCM::Partition;

# the config has a "bug" in the sense that logical/extended partitions 
# make no sense when using gpt (they are treated as names)
# should still work though
my $cfg = get_config_for_profile('blockdevices_gpt_partition_flags');
command_history_reset;

set_output("parted_print_sdb_label_gpt"); # no partitions, has gpt label
set_output("file_s_sdb_labeled"); # file -s works too
# disk is now considered empty, it will be removed and label recreated
set_output("dd_init_1000");
set_output("parted_init_sdb_gpt");
set_output("parted_mkpart_sdb_prim1");
my $sdb1 = NCM::Partition->new ("/system/blockdevices/partitions/sdb1", $cfg);
is ($sdb1->create, 0, "Partition $sdb1->{devname} on logical partitions test created correctly");

# these should all have run
ok(command_history_ok([
    '/sbin/parted -s -- /dev/sdb mklabel gpt',
    '/sbin/parted -s -- /dev/sdb u MiB mkpart primary 0 100',
    '/sbin/parted -s -- /dev/sdb set 1 bad off',
    '/sbin/parted -s -- /dev/sdb set 1 good on',
    ]), 'Command history gpt partition with tags'
);

my $fh = CAF::FileWriter->new("target/test/ks");
select($fh);
$sdb1->create_pre_ks();
like($fh, qr{for flagval in 'bad off' 'good on'}, "flagval for loop");
like($fh, qr{parted /dev/sdb -s -- set 1 \$flagval}, "parted set flagval");


done_testing();
