#!/usr/bin/perl -w

BEGIN {
  unshift(@INC, '/var/ncm/lib/perl');
  unshift(@INC, '/usr/lib/perl');
  unshift(@INC,'/opt/edg/lib/perl');
  use dummyapp;

  our $this_app = dummyapp->new;
}

use strict;
use warnings;
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Fetch;
use NCM::Blockdevices;
# use NCM::Disk;
# use NCM::LVM;
# use NCM::Partition;
use NCM::Filesystem;
use Test::More  tests=>16;
use Data::Dumper;
use CAF::Application;
use POSIX;

$ENV{LANG}='C';


#our @ISA = qw (CAF::Application);

system ("parted -s /dev/sda mklabel gpt");
my $fh = EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.ft.uam.es/spec/filesystem1.xml",
				    FOREIGN=>1});

$fh->fetchProfile;
my $cm = EDG::WP4::CCM::CacheManager->new ($fh->{CACHE_ROOT});

my $cfg = $cm->getLockedConfiguration (0);

my $fs = NCM::Filesystem->new ("/system/filesystems/0", $cfg);

$fs->create_if_needed;
my $out = `grep /Lagoon /etc/fstab`;
ok (!$?, "Filesystem correctly added to fstab");
my @flds = split / /, $out;
warn "@flds";
chomp (@flds);
is ($flds[0], "/dev/sda1", "Filesystem in the correct block device");
is ($flds[2], "ext3", "Correct filesystem type");
is ($flds[3], "auto", "Correct mount options");
is ($flds[4], 0, "Correct freq");
is ($flds[5], 1, "Correct pass");
my $err = system ("grep /Lagoon /etc/mtab &>/dev/null");
ok (!$err, "Filesystem correctly mounted");
open (FH, ">/Lagoon/Revy");
close (FH);
$fs->create_if_needed;
ok (-r "/Lagoon/Revy", "Re-creation does nothing");
$fs->remove_if_needed;
ok (-r "/Lagoon/Revy", "Filesystem was kept");
$err = system ("grep /Lagoon /etc/fstab &>/dev/null");
ok (!$err, "Filesystem remains on fstab");
system ("umount /Lagoon");
system ("sed -i /Lagoon/d /etc/fstab");
$fs->create_if_needed;
ok (-r "/Lagoon/Revy", "Lost filesystem re-discovered");
my $fh2 = EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.ft.uam.es/spec/filesystem2.xml",
				     FOREIGN=>1});

$fh2->fetchProfile;
my $cm2 = EDG::WP4::CCM::CacheManager->new ($fh2->{CACHE_ROOT});

my $cfg2 = $cm2->getLockedConfiguration (0);

$fs = NCM::Filesystem->new ("/system/filesystems/0", $cfg2);
$err = $fs->remove_if_needed;
ok (!$err, "Filesystem correctly removed");
$err = system ("grep /Lagoon /etc/fstab &> /dev/null");
ok ($err, "Filesystem removed from fstab");
$err = system ("grep /Lagoon /etc/mtab &> /dev/null");
ok ($err, "Filesystem unmounted");
$err = system ("grep sda1 /proc/partitions &>/dev/null");
ok ($err, "Partition removed");
$fs->create_if_needed;
$err = system ("grep /Lagoon /etc/fstab &>/dev/null");
ok (!$err, "Filesystem correctly re-created");
$fs->remove_if_needed;
