#!/usr/bin/perl -w
BEGIN {
  unshift(@INC, '/var/ncm/lib/perl');
  unshift(@INC, '/usr/lib/perl');
  unshift(@INC,'/opt/edg/lib/perl');
}

use strict;
use warnings;

use EDG::WP4::CCM::Element;
use EDG::WP4::CCM::Configuration;
use LC::Process qw (execute output);
use EDG::WP4::CCM::Fetch;
use NCM::Blockdevices;
use NCM::Disk;
use NCM::Partition;
use Test::More  tests=>5;
use Data::Dumper;
use CAF::Application;
use NCM::BlockdevFactory qw (build);

our @ISA = qw (CAF::Application);

# Let's start with a clean disk
system ("parted -s /dev/hdb mklabel msdos");

my $fh = EDG::WP4::CCM::Fetch->new ({PROFILE=>"http://uraha.air.tv/spec/factory1.xml",
				     FOREIGN=>1});
$fh->fetchProfile;
my $cm = EDG::WP4::CCM::CacheManager->new ($fh->{CACHE_ROOT});
my $cfg = $cm->getLockedConfiguration (0);
my $o = build ($cfg, "physical_devs/hdb");
is (ref ($o), "NCM::Disk", "Disk correctly instantiated");
$o = build ($cfg, "partitions/hdb1");
is (ref ($o), "NCM::Partition", "Partition correctly instantiated");
$o = build ($cfg, "volume_groups/vg0");
is (ref ($o), "NCM::LVM", "LVM correctly instantiated");
$o = build ($cfg, "md/md0");
is (ref ($o), "NCM::MD", "MD correctly instantiated");
$o = build ($cfg, "logical_volumes/lv0");
is (ref ($o), "NCM::LV", "LV correctly instantiated");
