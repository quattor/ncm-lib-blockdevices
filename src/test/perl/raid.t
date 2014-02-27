#!/usr/bin/perl 
# -*- mode: cperl -*-
use strict;
use warnings;
use Test::More;
use Test::Quattor qw(factory1);

use CAF::Object;
$CAF::Object::NoAction = 1;

use cmddata;
sub set_output {
    my $cmdshort = shift;
    my $cmdline= $cmddata::cmds{$cmdshort}{cmd}|| die "Undefined cmd for cmdshort $cmdshort";
    my $out=$cmddata::cmds{$cmdshort}{out} || "";
    my $err=$cmddata::cmds{$cmdshort}{err} || "";
    my $ec=$cmddata::cmds{$cmdshort}{ec} || 0;
    set_desired_output($cmdline, $out);
    set_desired_err($cmdline, $err);
    set_command_status($cmdline, $ec);
};

# can't run this early enough
# triggers a: Use of uninitialized value $out in pattern match (m//) at 
# .../target/lib/perl/NCM/Partition.pm line 88.
# retest it here, also check the constant (that's the one being used)
set_output("parted_version_2");  # force this version
use NCM::Partition;
is(NCM::Partition->extra_args(),(), "No extra args for parted, version OK");
is(NCM::Partition::PARTEDEXTRA, (), "No extra args for parted");

# mock devexists, it has a -b test, which can't be mocked
# e.g. http://stackoverflow.com/questions/1954529/perl-mocking-d-f-and-friends-how-to-put-them-into-coreglobal
use NCM::Disk;
*NCM::Disk::devexists   = \&main::mock_devexists;
sub mock_devexists { return 1; }

use NCM::MD;

my $cfg = get_config_for_profile('factory1');
my $md = NCM::MD->new ("/system/blockdevices/md/md0", $cfg);
is (ref ($md), "NCM::MD", "MD correctly instantiated");

# doesn't exist yet
set_output("file_s_sdb_data"); # sdb exists (test via file -s)
set_output("parted_print_sdb_2prim"); # sdb has 2 partitions
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
