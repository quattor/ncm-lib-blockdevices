#${PMpre} NCM::BlockdevFactory${PMpost}

=head1 NAME

NCM::BlockdevFactory

=cut

use NCM::Blockdevices qw ($reporter);
use NCM::MD;
use NCM::VG;
use NCM::LV;
use NCM::Disk;
use NCM::Partition;
use NCM::File;
use NCM::Tmpfs;
use NCM::VXVM;

use CAF::Process;

use constant BASEPATH => "/system/blockdevices/";
use constant PARTED	=> qw (/sbin/parted -s --);
use constant PARTEDEXTRA => qw (u MiB);
use constant PARTEDP	=> 'print';

use parent qw(Exporter);

our @EXPORT_OK = qw (build build_from_dev);

=pod

=head2 build

Returns the object describing the block device passed as an argument.

=cut

sub build
{
    my ($config, $dev, %opts) = @_;

    my @args = (BASEPATH . $dev, $config, %opts);

    if ($dev =~ m!^volume_groups/!) {
        return NCM::VG->new (@args);
    }
    elsif ($dev =~ m!^md/!) {
        return NCM::MD->new (@args);
    }
    elsif ($dev =~ m!^partitions/!) {
        return NCM::Partition->new (@args);
    }
    elsif ($dev =~ m!^physical_devs/!) {
        return NCM::Disk->new (@args);
    }
    elsif ($dev =~ m!^files/!) {
        return NCM::File->new (@args);
    }
    elsif ($dev =~ m!^logical_volumes/!) {
        return NCM::LV->new (@args);
    }
    elsif ($dev eq "tmpfs") {
        return NCM::Tmpfs->new(@args);
    }
    elsif ($dev =~ m!^vxvm/!) {
        return NCM::VXVM->new(@args);
    }

    ($opts{log} || $reporter)->error("Unable to find block device implementation for device $dev");

    return;
}

sub build_from_dev
{
    my ($dev, $config, %opts) = @_;

    my @args = ($dev, $config, %opts);
    ($opts{log} || $reporter)->debug (5, "Creating block device structure for $dev device");
    if ($dev =~ m{^/dev/md\d+$}) {
        return NCM::MD->new_from_system (@args);
    } elsif (($dev =~ m{^/dev/mapper/}) || (-l $dev && (my $rd = readlink ($dev)) =~ m{^/dev/mapper})) {
        # Check this one out!!
        $args[0] = defined ($rd) ? $rd : $dev;
        return NCM::LV->new_from_system (@args);
    } elsif ($dev =~ m{^/dev/}) {
        # This is the most generic way I can think of deciding
        # whether a path refers to a full disk or to a partition.
        # TODO why output and not execute?
        CAF::Process->new([PARTED, $dev, PARTEDEXTRA, PARTEDP], log => ($opts{log} || $reporter))->output();
        if ($?) {
            return NCM::Disk->new_from_system (@args);
        } else {
            return NCM::Partition->new_from_system (@args);
        }
    } else {
        return NCM::File->new_from_system (@args);
    }
}

1;
