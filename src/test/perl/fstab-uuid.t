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
my $fs3 = NCM::Filesystem->new ("/system/filesystems/3", $cfg);

# set empty fstab
set_file("fstab_default");

# no match uuid or label
$fs0->update_fstab;
like(get_file('/etc/fstab'), qr{^/dev/sdb1\s+/Lagoon\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 'Mount fs0 entry added to fstab');

set_desired_output('/sbin/blkid /dev/sdb2', 
    '/dev/sdb2: UUID="3ba76f19-ce89-4f33-a818-2d5e34678830" TYPE="ext3" PARTUUID="069218b3-02"');
#use uuid 3ba76f19-ce89-4f33-a818-2d5e34678830
$fs1->update_fstab;
like(get_file('/etc/fstab'), qr{^UUID=3ba76f19-ce89-4f33-a818-2d5e34678830\s+/Lagoon2\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs1 entry added to fstab');

set_desired_output('/sbin/blkid /dev/sdb3', 
    '/dev/sdb3: UUID="f1b57f63-b545-44b5-b5c0-a24c578e0613" TYPE="ext3" PARTUUID="069218b3-02"');
#use uuid f1b57f63-b545-44b5-b5c0-a24c578e0613
$fs2->update_fstab;
like(get_file('/etc/fstab'), qr{^UUID=f1b57f63-b545-44b5-b5c0-a24c578e0613\s+/Lagoon3\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs2 entry added to fstab');

#use label
$fs3->update_fstab;
like(get_file('/etc/fstab'), qr{^LABEL=FSLAB\s+/Lagoon4\s+xfs\s+auto\s+0\s+1\s*[^/]*$}m, 'Mount fs3 entry added to fstab');

# do it again! should still work
my $newtxt = get_file('/etc/fstab'); #otherwise Can't coerce GLOB to string in substr 
set_file("fstab_default","$newtxt");
$fs0->update_fstab;
$fs1->update_fstab;
#Different UUID 7d03ea2f-8fa0-4cf6-ac30-4c98216420a0 than in file
set_desired_output('/sbin/blkid /dev/sdb3', 
    '/dev/sdb3: UUID="7d03ea2f-8fa0-4cf6-ac30-4c98216420a0" TYPE="ext3" PARTUUID="069218b3-02"');
$fs2->update_fstab;
$fs3->update_fstab;
like(get_file('/etc/fstab'), qr{^/dev/sdb1\s+/Lagoon\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs0 entry added to fstab (retest)');
like(get_file('/etc/fstab'), qr{^UUID=3ba76f19-ce89-4f33-a818-2d5e34678830\s+/Lagoon2\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs1 entry added to fstab (retest)');
like(get_file('/etc/fstab'), qr{^UUID=7d03ea2f-8fa0-4cf6-ac30-4c98216420a0\s+/Lagoon3\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs2 entry added to fstab (retest)');
like(get_file('/etc/fstab'), qr{^LABEL=FSLAB\s+/Lagoon4\s+xfs\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs3 entry added to fstab (retest)');


$newtxt = get_file('/etc/fstab'); #otherwise Can't coerce GLOB to string in substr 
set_file("fstab_default","$newtxt\n" . 'PARTUUID=069218b3-02   /Lagoon2   ext3  auto 0 1' );
$fs1->update_fstab;
like(get_file('/etc/fstab'), qr{^PARTUUID=069218b3-02\s+/Lagoon2\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs1 entry added to fstab with PARTUUID');

done_testing();
