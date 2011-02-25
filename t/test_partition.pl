#!/usr/bin/perl -w

# Module for testing Partition and Disk classes.
######################################################################
#                              WARNING
######################################################################
#
# It is supposed to use /dev/hdb as its playground. It will destroy
# it!!
#
######################################################################
BEGIN {
  unshift(@INC, '/var/ncm/lib/perl');
  unshift(@INC, '/usr/lib/perl');
  unshift(@INC,'/opt/edg/lib/perl');
}

use strict;
use warnings;
use EDG::WP4::CCM::CacheManager;
use EDG::WP4::CCM::Fetch;
use NCM::Blockdevices;
use NCM::Disk;
use NCM::Partition;
use Test::More  tests=>41;
use Data::Dumper;
use CAF::Application;
use NCM::Filesystem;

our @ISA = qw (CAF::Application);


######################################################################
#                              WARNING
######################################################################
#
# I'm REALLY destroying /dev/hdb!!!!!
#
######################################################################
system ("parted -s /dev/hdb mklabel msdos");
# Too late to complain. Now, shut up.

my $fh = EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/t1.xml",
				    FOREIGN=>1});

$fh->fetchProfile;
my $cm = EDG::WP4::CCM::CacheManager->new ($fh->{CACHE_ROOT});

my $cfg = $cm->getLockedConfiguration (0);

my $part = NCM::Partition->new ("/software/components/filesystems/blockdevices/partitions/hdb1", $cfg);

my $ret = $part->create;
is ($ret, 0, "parted created correctly");
is ($part->{holding_dev}->partitions_in_disk, 1,
    "partition created correctly");
$ret = $part->remove;
is ($ret, 0, "parted removed correctly");
is ($part->{holding_dev}->partitions_in_disk, 0,
   "partition removed correctly");

my $fh2 = EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/t2.xml",
				    FOREIGN=>1});

$fh2->fetchProfile;

my $cm2 = EDG::WP4::CCM::CacheManager->new ($fh2->{CACHE_ROOT});

my $cfg2 = $cm2->getLockedConfiguration (0);

my $part1 = NCM::Partition->new ("/software/components/filesystems/blockdevices/partitions/hdb1", $cfg2);
my $part2 = NCM::Partition->new ("/software/components/filesystems/blockdevices/partitions/hdb2", $cfg2);
ok ($part2->{holding_dev} == $part1->{holding_dev},
    "Using the same disk instance");

$ret = $part1->create;
is ($ret, 0, "parted 1 created correctly");
$ret = $part2->create;
is ($ret, 0, "parted 2 created correctly");
is ($part1->{holding_dev}->partitions_in_disk, 2,
    "partitions 1 and 2 created correctly");
$ret = $part1->remove;
is ($ret, 0, "parted 1 removed correctly");
$ret = $part2->remove;
is ($ret, 0, "parted 2 removed correctly");
is ($part2->{holding_dev}->partitions_in_disk, 0,
   "partition removed correctly");


$ret = $part1->create;
is ($ret, 0, "parted 1 created correctly (second)");
$ret = $part2->create;
is ($ret, 0, "parted 2 created correctly (second)");
is ($part1->{holding_dev}->partitions_in_disk, 2,
    "partitions 1 and 2 created correctly (second)");

$ret = $part2->remove;
is ($ret, 0, "parted 2 removed correctly (second)");
system ("/bin/grep $part2->{devname} /proc/partitions > /dev/null");
isnt ($?, 0, "Partition 2 was actually removed");
system ("/bin/grep $part1->{devname} /proc/partitions > /dev/null");
is ($?, 0, "Partition 1 was kept");
$ret = $part1->remove;
is ($ret, 0, "parted 2 removed correctly");
is ($part1->{holding_dev}->partitions_in_disk, 0,
   "partition removed correctly");

$part1->create;
$ret = $part1->create;
is ($ret, 0, "Repeated parted ignored");
is ($part1->{holding_dev}->partitions_in_disk, 1,
    "Repeated partition creation ignored");

my $fh3 = EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/t3.xml",
				    FOREIGN=>1});

$fh3->fetchProfile;

my $cm3 = EDG::WP4::CCM::CacheManager->new ($fh3->{CACHE_ROOT});

my $cfg3 = $cm3->getLockedConfiguration (0);

$part1 = NCM::Partition->new ("/software/components/filesystems/blockdevices/partitions/hdb1", $cfg3);
$part2 = NCM::Partition->new ("/software/components/filesystems/blockdevices/partitions/hdb2", $cfg3);
my $part3 = NCM::Partition->new ("/software/components/filesystems/blockdevices/partitions/hdb3", $cfg3);

$part1->create;
$part2->create;
$ret = $part3->create;

is ($part1->{holding_dev}->partitions_in_disk, 3, "Three creations OK");
is ($ret, 0, "Partition grows to the end of the disk");
$part2->create;
system ("grep $part2->{devname} /proc/partitions > /dev/null");
is ($?, 0, "Partition re-created with correct ID");
system ("parted /dev/hdb mklabel gpt");
my $fh4 =  EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/t4.xml",
				    FOREIGN=>1});

$fh4->fetchProfile;

my $cm4 = EDG::WP4::CCM::CacheManager->new ($fh4->{CACHE_ROOT});

my $cfg4 = $cm4->getLockedConfiguration (0);
my $fs = NCM::Filesystem->new ("/software/components/filesystems/filesystemdefs/0", $cfg4);
$fs->create_if_needed;
my $disk = NCM::Disk->new_from_system ("/dev/hdb", $cfg4);
is (ref ($fs->{block_device}), "NCM::Disk",
    'Correct block device instantiated: disk');
is ($disk->{label}, 'none', "Correct disk label: the disk was empty");
is ($disk->{devname}, 'hdb', 'Correct disk name');
is ($disk->devpath, '/dev/hdb', 'Correct device path');
my $fs2 = NCM::Filesystem->new_from_fstab ("/dev/hdb /Mokona ext3 defaults 0 0", $cfg4);
is ($fs2->{mountpoint}, $fs->{mountpoint}, "Correct mountpoint from system");
ok ($fs2->{format} && !$fs2->{preserve}, "Filesystem from system must be destroyed");
$ret = $fs2->remove_if_needed;
ok (!$ret, "Filesystem from system correctly removed");

my $fh5 =  EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/t5.xml",
				    FOREIGN=>1});

$fh5->fetchProfile;

my $cm5 = EDG::WP4::CCM::CacheManager->new ($fh5->{CACHE_ROOT});

my $cfg5 = $cm5->getLockedConfiguration (0);
undef $fs;
$fs = NCM::Filesystem->new ("/software/components/filesystems/filesystemdefs/0", $cfg5);
is (ref ($fs->{block_device}), "NCM::Partition",
    "Filesystem on partition correctly defined");
$ret = $fs->create_if_needed;
ok (!$ret, "Filesystem /Mokona successfully created on /dev/hdb1");
$ret = system (qw {grep -q /dev/hdb1.*/Mokona /etc/fstab});
ok (!$ret, "Correct entry for /Mokona on fstab");
$part = NCM::Partition->new_from_system ("/dev/hdb1", $cfg5);
is ($part->{devname}, 'hdb1', 'Correct partition name from system');
$fs2 = NCM::Filesystem->new_from_fstab ("/dev/hdb1 /Mokona ext3 defaults 0 0", $cfg5);
is (ref ($fs2->{block_device}), "NCM::Partition",
    "Correct block device from system: partition");
$fs2->remove_if_needed;

my $fh6 =  EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/t6.xml",
				    FOREIGN=>1});

$fh6->fetchProfile;

my $cm6 = EDG::WP4::CCM::CacheManager->new ($fh6->{CACHE_ROOT});

my $cfg6 = $cm6->getLockedConfiguration (0);
undef $fs;
$fs = NCM::Filesystem->new ("/software/components/filesystems/filesystemdefs/0", $cfg6);
is (ref ($fs->{block_device}), "NCM::Partition",
    "Filesystem on partition correctly defined");
$ret = $fs->create_if_needed;
ok (!$ret, "Filesystem /Mokona successfully created on /dev/hdb1");
$ret = system (qw {grep -q LABEL=Mokona.*/Mokona /etc/fstab});
ok (!$ret, "Correct entry for /Mokona on fstab");
$part = NCM::Partition->new_from_system ("/dev/hdb1", $cfg6);
is ($part->{devname}, 'hdb1', 'Correct partition name from system');
$fs2 = NCM::Filesystem->new_from_fstab ("/dev/hdb1 /Mokona ext3 defaults 0 0", $cfg6);
is (ref ($fs2->{block_device}), "NCM::Partition",
    "Correct block device from system: partition");
$fs2->remove_if_needed;
