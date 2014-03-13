#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use Test::More;

use Test::Quattor qw(raid);

use helper qw(set_output);

use NCM::MD;

my $cfg = get_config_for_profile('raid');
my $md = NCM::MD->new ("/system/blockdevices/md/md0", $cfg);
is (ref ($md), "NCM::MD", "MD correctly instantiated");

# doesn't exist yet
set_output("file_s_sdb_data"); # sdb exists (test via file -s)
set_output("parted_print_sdb_2prim_gpt"); # sdb has 2 partitions
set_output("grepq_no_md0");
set_output("mdadm_create_2");
my $err = $md->create;
# err is $?, ie the process exitcode
ok (!$err, "Software RAID md0 successfully created");

set_output("file_s_md0_data");
ok (!$md->has_filesystem, "MD detects it doesn't have any filesystems");

set_output("md0_stop");
set_output("mdzero_sdb1");
set_output("mdzero_sdb2");
$err = $md->remove;
ok (!$err, "Software RAID md0 successfully removed");


done_testing();
