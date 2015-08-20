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

my $protected = {
    mounts => {
        '/Lagoon2' => 1, 
        '/Lagoon3' => 1,
    },
    filesystems => {
        'xfs' => 1,
    },
};

#not protected
$fs0->update_fstab(undef, $protected);
like(get_file('/etc/fstab'), qr{^/dev/sdb1\s+/Lagoon\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs0 entry added to fstab');

set_desired_output('/sbin/blkid /dev/sdb2', 
    '/dev/sdb2: UUID="3ba76f19-ce89-4f33-a818-2d5e34678830" TYPE="ext3" PARTUUID="069218b3-02"');

#protected mountpoint
$fs1->update_fstab(undef, $protected);
like(get_file('/etc/fstab'), qr{^UUID=3ba76f19-ce89-4f33-a818-2d5e34678830\s+/Lagoon2\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs1 entry added to fstab');

set_desired_output('/sbin/blkid /dev/sdb3', 
    '/dev/sdb3: UUID="f1b57f63-b545-44b5-b5c0-a24c578e0613" TYPE="ext3" PARTUUID="069218b3-02"');
#protected mointpoint
$fs2->update_fstab(undef, $protected);
like(get_file('/etc/fstab'), qr{^UUID=f1b57f63-b545-44b5-b5c0-a24c578e0613\s+/Lagoon3\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs2 entry added to fstab');

#protected type
$fs3->update_fstab(undef, $protected);
like(get_file('/etc/fstab'), qr{^LABEL=FSLAB\s+/Lagoon4\s+xfs\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs3 entry added to fstab');

# Now do it again! 
my $newtxt = get_file('/etc/fstab'); #otherwise Can't coerce GLOB to string in substr 
$newtxt =~ s!^/dev/sdb1!/dev/sdc1!m;
$newtxt =~ s!^UUID=f1b57f63-b545-44b5-b5c0-a24c578e0613!UUID=7d03ea2f-8fa0-4cf6-ac30-4c98216420a0!m;
$newtxt =~ s!^LABEL=FSLAB!/dev/sdd1!m;
set_file("fstab_default","$newtxt");
#Different devpath in file
$fs0->update_fstab(undef, $protected);
#Same
$fs1->update_fstab(undef, $protected);
#Different UUID 7d03ea2f-8fa0-4cf6-ac30-4c98216420a0 in file
$fs2->update_fstab(undef, $protected);
$fs3->update_fstab(undef, $protected);
like(get_file('/etc/fstab'), qr{^/dev/sdb1\s+/Lagoon\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs0 entry changed in fstab');
like(get_file('/etc/fstab'), qr{^UUID=3ba76f19-ce89-4f33-a818-2d5e34678830\s+/Lagoon2\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs1 protected in fstab');
like(get_file('/etc/fstab'), qr{^UUID=7d03ea2f-8fa0-4cf6-ac30-4c98216420a0\s+/Lagoon3\s+ext3\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs2 protected in fstab');
like(get_file('/etc/fstab'), qr{^/dev/sdd1\s+/Lagoon4\s+xfs\s+auto\s+0\s+1\s*[^/]*$}m, 
    'Mount fs3 type protected in fstab');

done_testing();
