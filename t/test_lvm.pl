#!/usr/bin/perl -w

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
use NCM::LVM;
use NCM::Filesystem;
use NCM::Partition;
use Test::More  tests=>44;
use Data::Dumper;
use CAF::Application;
use POSIX;

$ENV{LANG}='C';

#our @ISA = qw (CAF::Application);

system ("parted -s /dev/hdb mklabel gpt");

my $fh = EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/lvm1.xml",
				    FOREIGN=>1});

$fh->fetchProfile;
my $cm = EDG::WP4::CCM::CacheManager->new ($fh->{CACHE_ROOT});

my $cfg = $cm->getLockedConfiguration (0);
my $vg = NCM::LVM->new ("/software/components/filesystems/blockdevices/volume_groups/Chobits", $cfg);
my $err = $vg->create;

ok (!$err, "Volume group successfully created");
$err = $vg->create;
ok (!$err, "We can create twice a volume group");
my $out = `vgdisplay Chobits --verbose 2>/dev/null|grep 'PV Name'|awk '{print \$3}'`;
chomp $out;
is ($out, '/dev/hdb', "Volume contains only a full disk");
$err = $vg->remove;
ok (!$err, "Volume group successfully removed");
$out = `vgscan|wc -l`;
chomp $out;
is ($out, 1, "Volume group actually removed");
my $fh2 = EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/lvm2.xml",
				    FOREIGN=>1});

$fh2->fetchProfile;
my $cm2 = EDG::WP4::CCM::CacheManager->new ($fh2->{CACHE_ROOT});

my $cfg2 = $cm2->getLockedConfiguration (0);
$vg = NCM::LVM->new ("/software/components/filesystems/blockdevices/volume_groups/Tsubasa", $cfg2);
$err = $vg->create;
ok (!$err, "Volume with several devices correctly created");
is ($vg->{device_list}->[0]->{holding_dev}->partitions_in_disk,
    2, "Partitions correctly created");
$out = `vgdisplay Tsubasa --verbose 2>/dev/null|grep 'PV Name'|awk '{print \$3}'`;
is ($out, "/dev/hdb1\n/dev/hdb2\n", "Volume group contains the expected partitions");
$err = $vg->remove;
ok (!$err, "Volume with several devices correctly removed");
is ($vg->{device_list}->[0]->{holding_dev}->partitions_in_disk,
    0, "Partitions correctly removed");
$out =`vgscan |wc -l`;
chomp $out;
is ($out, 1, "Volume group with several devices correctly removed, really");
my $fh3 = EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/lvm3.xml",
				    FOREIGN=>1});

$fh3->fetchProfile;
my $cm3 = EDG::WP4::CCM::CacheManager->new ($fh3->{CACHE_ROOT});

my $cfg3 = $cm3->getLockedConfiguration (0);
$vg = NCM::LV->new ("/software/components/filesystems/blockdevices/logical_volumes/Chii", $cfg3);
#print Dumper ($vg);
$err = $vg->create;
ok (!$err, "Logical volume Chii correctly created");
$err = system ("lvdisplay Chobits/Chii &>/dev/null");
ok (!$err, "Logical volume Chii actually created in volume group Chobits");
$err = $vg->create;
ok (!$err, "Second creation of a logical volume is ignored");
$err = system ("lvdisplay Chobits/Chii &>/dev/null");
ok (!$err, "Second creation of a logical volume is actually ignored");
$err = $vg->remove;
$err = system ("lvdisplay Chobits/Chii &>/dev/null");
ok ($err, "Logical volume actually removed");
is ($vg->{volume_group}->{device_list}->[0]->{holding_dev}->partitions_in_disk,
    0, "Partitions of logical volume correcty removed");
$out = `vgscan|wc -l`;
chomp $out;
is ($out, 1, "Volume group actually removed");
my $fh4 = EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/lvm4.xml",
				    FOREIGN=>1});

$fh4->fetchProfile;
my $cm4 = EDG::WP4::CCM::CacheManager->new ($fh4->{CACHE_ROOT});

my $cfg4 = $cm4->getLockedConfiguration (0);
$vg = NCM::LV->new ("/software/components/filesystems/blockdevices/logical_volumes/Chii", $cfg4);
$err = $vg->create;
ok (!$err, "First logical volume on Chobits successfully created");
my $vg2 = NCM::LV->new ("/software/components/filesystems/blockdevices/logical_volumes/Sakura", $cfg4);
$err = $vg2->create;
ok (!$err, "First logical volume on Tsubasa successfully created");
$out = `lvdisplay -c Chobits/Chii|cut -d: -f7`;
chomp $out;
$err = $?;
ok (!$err, "Chobits/Chii actually created");
is ($out, 1024*1024*2, "Chobits/Chii has the correct size");
$out = `lvdisplay -c Tsubasa/Sakura|cut -d: -f7`;
chomp $out;
$err = $?;
ok (!$err, "Tsubasa/Sakura actually created");
is ($out, 512*1024*2, "Tsubasa/Sakura has the correct size");
my $vg3 = NCM::LV->new ("/software/components/filesystems/blockdevices/logical_volumes/Sumomo", $cfg4);
$err = $vg3->create;
ok (!$err, "Second logical volume on Chobits successfully created");
my $vg4 = NCM::LV->new ("/software/components/filesystems/blockdevices/logical_volumes/Mokona", $cfg4);
$err = $vg4->create;
ok (!$err, "Second logical volume on Tsubasa successfully created");
$out = `lvdisplay -c Chobits/Sumomo|cut -d: -f7`;
chomp $out;
$err = $?;
ok (!$err, "Chobits/Sumomo actually created");
is ($out, 2048*1024*2, "Chobits/Sumomo has the correct size");
$out = `lvdisplay -c Tsubasa/Mokona|cut -d: -f7`;
chomp $out;
$err = $?;
ok (!$err, "Tsubasa/Mokona actually created");
is ($out, 16384*1024*2, "Tsubasa/Mokona has the correct size");
$err = $vg2->remove;
ok (!$err, "Tsubasa/Sakura removed");
$err = $vg->remove;
ok (!$err, "Chobits/Chii removed");
`lvdisplay Chobits/Chii`;
$err = $?;
ok ($err, "Chobits/Chii actually removed");
`lvdisplay Chobits/Sumomo`;
$err = $?;
ok (!$err, "Chobits/Sumomo kept");
`lvdisplay Tsubasa/Sakura`;
$err = $?;
ok ($err, "Tsubasa/Sakura removed");
`lvdisplay Tsubasa/Mokona`;
$err = $?;
ok (!$err, "Tsubasa/Mokona kept");
$vg3->remove;
$vg4->remove;
$out = `vgdisplay`;
chomp $out;
is ($out, '', "All logical volumes removed");

my $fh5 = EDG::WP4::CCM::Fetch->new({PROFILE=>"http://uraha.air.tv/spec/lvm5.xml",
				     FOREIGN=>1});

$fh5->fetchProfile;
my $cm5 = EDG::WP4::CCM::CacheManager->new ($fh5->{CACHE_ROOT});

my $cfg5 = $cm5->getLockedConfiguration (0);

my $fs = NCM::Filesystem->new ("/software/components/filesystems/filesystemdefs/0",
			       $cfg5);
ok (!$fs->create_if_needed, "Filesystem on top of an LVM correctly created");
my $l = `grep Mokona /etc/fstab`;
chomp $l;
my $fs2 = NCM::Filesystem->new_from_fstab ($l, $cfg5);
is (ref ($fs2->{block_device}), 'NCM::LV',
    "Correct block device from fstab");
is (ref ($fs2->{block_device}->{volume_group}), 'NCM::LVM',
    "Correct volume group from fstab");
is (scalar (@{$fs2->{block_device}->{volume_group}->{device_list}}),
    2, "All partitions were inserted");
$fs2->remove_if_needed;
$err = system ("lvdisplay Chobits/Chii &>/dev/null");;
ok ($err, 'All logical volumes from system were removed');
$out = `vgdisplay`;
chomp $out;
is ($out, '', 'All volume groups from system were removed');
$out = `pvdisplay`;
chomp $out;
is ($out, '', 'All physical volumes from system were removed');
