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
use NCM::Disk;
use CAF::Object;
use Test::Quattor qw(blockdevices_readahead);

use helper; # at least to set the this_app log 

$CAF::Object::NoAction = 1;

my $cfg = get_config_for_profile('blockdevices_readahead');

my $o = build ($cfg, "physical_devs/sdb");
is (ref ($o), "NCM::Disk", "Disk correctly instantiated");

my $okcmd= join (" ", NCM::Disk::SETRA, 2048, $o->devpath);
my $wrongcmd= join (" ", NCM::Disk::SETRA, 1024, $o->devpath);

set_file_contents(NCM::Disk::RCLOCAL, "#Nothing\n");
$o->set_readahead;
like(get_file(NCM::Disk::RCLOCAL), qr{^$okcmd}m, 'Readahead inserted in rclocal');

set_file_contents(NCM::Disk::RCLOCAL, "#Nothing\n$wrongcmd\n");
$o->set_readahead;
like(get_file(NCM::Disk::RCLOCAL), qr{^$okcmd}m, 'Readahead updated in rclocal');
unlike(get_file(NCM::Disk::RCLOCAL), qr{$wrongcmd}, 'Wrong readahead removed in rclocal');

done_testing();

