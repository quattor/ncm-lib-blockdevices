# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
################################################################################

package NCM::BlockdevFactory;

use strict;
use warnings;

use EDG::WP4::CCM::Configuration;
use EDG::WP4::CCM::Element;
use CAF::Process;
use NCM::Blockdevices qw ($reporter);
use NCM::MD;
use NCM::LVM;
use NCM::LV;
use NCM::Disk;
use NCM::Partition;
use NCM::File;
use NCM::Tmpfs;
use NCM::VXVM;
use constant BASEPATH	=> "/system/blockdevices/";
use constant PARTED	=> qw (/sbin/parted -s --);
use constant PARTEDEXTRA => qw (u MiB);
use constant PARTEDP	=> 'print';

our @ISA = qw (Exporter);

our @EXPORT_OK = qw (build build_from_dev);

=pod

=head2 build

Returns the object describing the block device passed as an argument.

=cut

sub build
{
    my ($config, $dev) = @_;

    if ($dev =~ m!^volume_groups/!) {
        return NCM::LVM->new (BASEPATH . $dev, $config);
    }
    elsif ($dev =~ m!^md/!) {
        return NCM::MD->new (BASEPATH . $dev, $config);
    }
    elsif ($dev =~ m!^partitions/!) {
        return NCM::Partition->new (BASEPATH . $dev, $config);
    }
    elsif ($dev =~ m!^physical_devs/!) {
        return NCM::Disk->new (BASEPATH . $dev, $config);
    }
    elsif ($dev =~ m!^files/!) {
        return NCM::File->new (BASEPATH . $dev, $config);
    }
    elsif ($dev =~ m!^logical_volumes/!) {
        return NCM::LV->new (BASEPATH . $dev, $config);
    }
    elsif ($dev eq "tmpfs") {
        return NCM::Tmpfs->new(BASEPATH . $dev, $config);
    }
    elsif ($dev =~ m!^vxvm/!) {
        return NCM::VXVM->new(BASEPATH . $dev, $config);
    }

    $self->error("Unable to find block device implementation for device $dev");

    return undef;
}

sub build_from_dev
{
    my ($dev, $config) = @_;

    $self->debug (5, "Creating block device structure for $dev device");
    if ($dev =~ m{^/dev/md\d+$}) {
        return NCM::MD->new_from_system ($dev, $config);
    }
    elsif (($dev =~ m{^/dev/mapper/}) ||
           (-l $dev && (my $rd = readlink ($dev)) =~ m{^/dev/mapper})) {
        # Check this one out!!
        return NCM::LV->new_from_system (defined $rd? $rd:$dev, $config);
    }
    elsif ($dev =~ m{^/dev/}) {
        # This is the most generic way I can think of deciding
        # whether a path refers to a full disk or to a
        # partition.
        # TODO why output and not execute?
        CAF::Process->new([PARTED, $dev, PARTEDEXTRA, PARTEDP], log => $self)->output();
        if ($?) {
            return NCM::Disk->new_from_system ($dev, $config);
        }
        else {
            return NCM::Partition->new_from_system ($dev, $config);
        }
    }
    else {
        return NCM::File->new_from_system ($dev, $config);
    }
}

1;
