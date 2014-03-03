#!/usr/bin/perl 
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use Test::More;
use NCM::Filesystem;
use CAF::Object;
use Test::Quattor qw(filesystem);

use helper; 

my $cfg = get_config_for_profile('filesystem');

my $fs = NCM::Filesystem->new ("/system/filesystems/0", $cfg);

command_history_reset;
set_output("parted_print_sdb_1prim_gpt");
set_output("file_s_sdb_labeled");
set_output("file_s_sdb1_data");
set_output("fs_lagoon_missing");
$fs->create_if_needed;
ok(command_history_ok(["mkfs.ext3.*/dev/sdb1"]), "mkfs.ext3 called on /dev/sdb1");

done_testing();

