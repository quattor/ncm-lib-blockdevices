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
use Test::Quattor qw(fstab);

use helper; 

my $cfg = get_config_for_profile('fstab');

$CAF::Object::NoAction = 1;
# regular fs test
my $fs0 = NCM::Filesystem->new ("/system/filesystems/0", $cfg);
my $fs1 = NCM::Filesystem->new ("/system/filesystems/1", $cfg);
my $fs2 = NCM::Filesystem->new ("/system/filesystems/2", $cfg);

# set empty fstab
set_file("fstab_default");

$fs0->update_fstab;
like(get_file('/etc/fstab'), qr{^/dev/sdb1\s+/Lagoon\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 'Mount fs0 entry added to fstab');

$fs1->update_fstab;
like(get_file('/etc/fstab'), qr{^/dev/sdb2\s+/Lagoon2\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 'Mount fs1 entry added to fstab');

$fs2->update_fstab;
like(get_file('/etc/fstab'), qr{^/dev/sdb3\s+/Lagoon3\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 'Mount fs2 entry added to fstab');

# do it again! should still work
my $newtxt = get_file('/etc/fstab'); #otherwise Can't coerce GLOB to string in substr 
set_file("fstab_default","$newtxt");
$fs0->update_fstab;
$fs1->update_fstab;
$fs2->update_fstab;
like(get_file('/etc/fstab'), qr{^/dev/sdb1\s+/Lagoon\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 'Mount fs0 entry added to fstab (retest)');
like(get_file('/etc/fstab'), qr{^/dev/sdb2\s+/Lagoon2\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 'Mount fs1 entry added to fstab (retest)');
like(get_file('/etc/fstab'), qr{^/dev/sdb3\s+/Lagoon3\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 'Mount fs2 entry added to fstab (retest)');

done_testing();
