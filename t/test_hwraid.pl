#!/usr/bin/perl -w

#!/usr/bin/perl -w
BEGIN {
  unshift(@INC, '/var/ncm/lib/perl');
  unshift(@INC, '/usr/lib/perl');
  unshift(@INC,'/opt/edg/lib/perl');
  use dummyapp;

  our $this_app = dummyapp->new ($0, qw (--verbose --debug 5));
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
use Test::More  tests=>14;
use Data::Dumper;
use CAF::Application;
use NCM::HWRaid;

use LC::Exception;

my $ec = LC::Exception::Context->new->will_store_all;

$ec->error_handler (sub { my ($ec, $e) = @_; $e->has_been_reported(1); return ();});

our @ISA = qw (CAF::Application);

sub init_raid ()
{
    system ("echo '3ware,c0,u1,RAID-5,64k,-,-,-'|hwraidman destroy");
    system ("echo '3ware,c0,-,RAID-5,64k,-,-,-'|hwraidman create");
}

my $fh = EDG::WP4::CCM::Fetch->new ({PROFILE => "http://uraha.ft.uam.es/spec/hwraid1.xml",
				     FOREIGN => 1});
$fh->fetchProfile;


my $cm = EDG::WP4::CCM::CacheManager->new ($fh->{CACHE_ROOT});
my $cfg = $cm->getLockedConfiguration (0);
my $disk = NCM::Disk->new ("/system/blockdevices/physical_devs/sdb", $cfg);
my $hwraid = NCM::HWRaid->new ("_1", $cfg, $disk);

system (qw (dd if=/dev/zero of=/dev/sdb bs=1M count=10));
system (qw (parted /dev/sdb mklabel gpt));
init_raid;
ok ($hwraid->is_consistent,
    "The RAID array doesn't match the described on the profile, but we can recover from this");
init_raid;
is ($hwraid->destroy_if_needed, 0, "destroy_if_needed exits successfully when destroying stuff");
system ("hwraidman info|grep -q u1");
ok ($? != 0, "HW RAID really destroyed from destroy_if_needed");
is ($hwraid->create_if_needed, 0, "Successfully created a RAID array from create_if_needed");
system ("hwraidman info|grep -q u1");
is ($?, 0, "HW RAID really created from create_if_needed");
is ($hwraid->destroy_if_needed, 0, "destroy_if_needed behaves nicely on a correct RAID");
system ("hwraidman info|grep -q u1");
is ($?, 0, "Correct HW RAID kept after destroy_if_needed");
init_raid;
is ($hwraid->create, 0, "HWRaid->create finishes successfully");
system ("hwraidman info|grep -q u1");
is ($?, 0, "HW RAID successfully created from create");
$fh = EDG::WP4::CCM::Fetch->new ({PROFILE => "http://uraha.ft.uam.es/spec/hwraid2.xml",
				  FOREIGN => 1});
$fh->fetchProfile;

$cm = EDG::WP4::CCM::CacheManager->new ($fh->{CACHE_ROOT});
$cfg = $cm->getLockedConfiguration (0);
$disk = NCM::Disk->new ("/system/blockdevices/physical_devs/sdb", $cfg);
$hwraid = NCM::HWRaid->new ("raid/_0/ports/_0", $cfg, $disk);
is ($hwraid, undef, "Refused to create a RAID object from non-raid description");
$fh = EDG::WP4::CCM::Fetch->new ({PROFILE => "http://uraha.ft.uam.es/spec/hwraid1.xml",
				  FOREIGN => 1});
$fh->fetchProfile;
$cm = EDG::WP4::CCM::CacheManager->new ($fh->{CACHE_ROOT});
$cfg = $cm->getLockedConfiguration (0);
$disk = NCM::Disk->new ("/system/blockdevices/physical_devs/sdb", $cfg);
ok (exists ($disk->{raid}), "Disk object has a RAID attribute");
is (ref ($disk->{raid}), "NCM::HWRaid", "Disk object correctly instanciates its RAID attribute");
init_raid;
is ($disk->create, 0, "Partition table successfully created on a RAID array");
system ("hwraidman info|grep -q u1.*RAID-1");
is ($?, 0, "RAID array successfully created by a Disk object");
