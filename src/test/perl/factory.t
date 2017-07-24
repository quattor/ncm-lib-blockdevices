use strict;
use warnings;

use Test::More;
use Test::Quattor qw(factory);
use helper;

use NCM::Blockdevices qw ($reporter);
use NCM::BlockdevFactory qw (build build_from_dev);
use CAF::Object;

$CAF::Object::NoAction = 1;

my $cfg = get_config_for_profile('factory');

=head1 build

=cut

my %test = (
    Disk => "physical_devs/sdb",
    Partition => "partitions/sdb1",
    VG => "volume_groups/vg0",
    MD => "md/md0",
    LV => "logical_volumes/lv0",
    VXVM => "vxvm/vcslab.local/gnr.0",
);
foreach my $name (sort keys %test) {
    my $inst = build($cfg, $test{$name});
    isa_ok($inst, "NCM::$name", "$name correctly instantiated");
}

my $inst = build ($cfg, "unknown/unknown");
ok(! defined($inst), 'build returns undef with unknown blockdevice');
is($reporter->{ERROR}, 1, "Errors for an unknown blockdevice");

=head1 _find_class / build_from_dev

=cut

my $dminfo = <<EOF;
vg0-scratch:LVM
small_osd_01p2:part2
mpathao:mpath
mpathv:mpath
small_osd_09:mpath
mpathab:mpath
mpathi:mpath
small_osd_01p1:part1
vg0-var:LVM
mpathan:mpath
zero1:
mpathba:mpath
EOF

set_desired_output('dmsetup info -C --noheadings --separator : -o name,subsystem', $dminfo);

my $part_label = <<EOF;
Model: Unknown (unknown)
Disk /dev/sdb1: 1024MiB
Sector size (logical/physical): 512B/512B
Partition Table: loop
Disk Flags:

Number  Start    End      Size     File system  Flags
 1      0.00MiB  1024MiB  1024MiB  ext2

EOF

set_desired_output('/sbin/parted -s -- /dev/sdb1 u MiB print', $part_label);
set_command_status('/sbin/parted -s -- /dev/sdb1 u MiB print', 0);

my $part_no_label = <<EOF;
Error: /dev/sda1: unrecognised disk label
Model: Unknown (unknown)
Disk /dev/sda1: 190781MiB
Sector size (logical/physical): 512B/4096B
Partition Table: unknown
Disk Flags:
EOF

set_desired_output('/sbin/parted -s -- /dev/sda1 u MiB print', $part_no_label);
set_command_status('/sbin/parted -s -- /dev/sda1 u MiB print', 1);

my $disk_label = <<EOF;
Model: ATA INTEL SSDSC2BX20 (scsi)
Disk /dev/sda: 190782MiB
Sector size (logical/physical): 512B/4096B
Partition Table: msdos
Disk Flags:

Number  Start    End        Size       Type     File system  Flags
 1      1.00MiB  190782MiB  190781MiB  primary
EOF
set_desired_output('/sbin/parted -s -- /dev/sda u MiB print', $disk_label);
set_command_status('/sbin/parted -s -- /dev/sda u MiB print', 0);

mkdir('target/test') if ! -d 'target/test';
mkdir('target/test/factory');
# make broken link
symlink('/dev/mapper/followthelinktodevmapper', 'target/test/factory/somelink');

%test = (
    LV => [qw(/dev/mapper/abc /dev/mapper/vg0-scratch target/test/factory/somelink)],
    Disk => [qw(/dev/sda /dev/mapper/zero1 /dev/mapper/small_osd_09 /dev/mapper/mpathv)],
    Partition => [qw(/dev/sda1 /dev/sdb1 /dev/mapper/small_osd_01p1)],
    File => [qw(anthing/else)],
    MD => [qw(/dev/md123)],
    );

foreach my $name (sort keys %test) {
    foreach my $dev (@{$test{$name}}) {
        is(NCM::BlockdevFactory::_find_class($reporter, $dev), $name, "dev $dev mapped to class $name");
    };
}

isa_ok(build_from_dev("/dev/sdb1", $cfg), 'NCM::Partition', 'build_from_dev sdb1 returns NCM::Partition instance');

done_testing();
