# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

=pod

=head1 LVM

This class defines a volume group (VG) for LVM. It is part of the
blockdevices framework.

The available fields on this class are:

=over 4

=item devname : string

Name of the device.

=item device_list : list of BlockDevices.

The devices the volume group consists of.

=back

=cut

package NCM::LVM;

use strict;

# Don't want warnings for this
no warnings;
use constant PVS => qw(/usr/sbin/pvs -o name,vg_name);

use warnings;

use EDG::WP4::CCM::Element;
use EDG::WP4::CCM::Configuration;
use LC::Process qw(execute output);
use NCM::Blockdevices qw($this_app PART_FILE);
use NCM::BlockdevFactory qw(build build_from_dev);
our @ISA = qw(NCM::Blockdevices);

use constant BASEPATH => "/system/blockdevices/";
use constant DISK     => "physical_devs/";
use constant PVCREATE => '/usr/sbin/pvcreate';
use constant VGCREATE => '/usr/sbin/vgcreate';
use constant PVREMOVE => '/usr/sbin/pvremove';
use constant VGCOPTS  => qw(--);
use constant EXISTS   => 5;
use constant VGREMOVE => qw(vgremove -f);
use constant VGRMOPTS => VGCOPTS;
use constant EXTENTS  => 15;

use constant VGDISPLAY => qw(/usr/sbin/vgdisplay -c);
use constant PVDISPLAY => qw(/usr/sbin/pvdisplay -c);

use constant VOLGROUP => 'volgroup';

use constant VOLGROUP_REQUIRED_PATH => '/system/aii/osinstall/ks/volgroup_required';

our %vgs = ();

sub new
{
    my ($class, $path, $config) = @_;
    my $cache_key = $class->get_cache_key($path, $config);
    return (defined $vgs{$cache_key}) ? $vgs{$cache_key} : $class->SUPER::new($path, $config);
}

=pod

=head2 create

Creates the volume group on the system. It creates the block devices
holding its physical volumes, the physical volumes and then, the
volume group.

Returns 0 on success.

=cut

sub create
{
    my $self = shift;
    my @devnames;

    return 1 if (!$self->is_correct_device);

    if ($self->devexists) {
        $this_app->debug(5, "Volume group $self->{devname} already ", " exists. Leaving");
        return 0;
    }
    foreach my $dev (@{$self->{device_list}}) {
        $dev->create == 0 or return $?;
        execute([PVCREATE, $dev->devpath])
            if !$self->pvexists($dev->devpath);
        return $? if $?;
        push(@devnames, $dev->devpath);
    }
    execute([VGCREATE, $self->{devname}, VGCOPTS, @devnames]);
    $this_app->error("Failed to create volume group $self->{devname}")
        if $?;
    return $?;
}

=pod

=head2 remove

Deletes a volume group, if there are no more logical groups on it.

Note that failing to remove block is not a critical error: there may
be logical volumes on top of it, and the kernel won't allow to remove
this.

Returns 0 on success.

=cut

sub remove
{
    my $self = shift;

    return 1 if (!$self->is_correct_device);

    # Remove the VG only if it has no logical volumes left.
    my @n = split /:/, output((VGDISPLAY, $self->{devname}));
    if ($n[EXISTS]) {
        $this_app->debug(
            5, "Volume group $self->{devname} ",
            "has ", $n[EXISTS],
            " logical volumes left.",
            " Not removing yet"
        );
        return 0;
    }
    if ($self->devexists) {
        execute([VGREMOVE, $self->{devname}]);
        return 0 if $?;
    }
    foreach my $dev (@{$self->{device_list}}) {
        execute([PVREMOVE, $dev->devpath]);
        $this_app->error("Failed to remove labels on PV", $dev->devpath) if $?;
        $dev->remove == 0 or last;
    }
    delete $vgs{$self->{_cache_key}} if exists $self->{_cache_key};
    return $?;
}

sub new_from_system
{
    my ($class, $dev, $cfg) = @_;

    $dev =~ m{dev/mapper/(.*)};
    my $devname = $1;
    $devname =~ s/-{2}/-/g;

    # Have to do it this way because of a nasty bug on vgs.
    my $pvs = output(PVS);
    my @pv;
    while ($pvs =~ m{^\s*(\S+)\s+$devname$}omgc) {
        push(@pv, build_from_dev($1, $cfg));
    }
    my $self = {
        devname     => $devname,
        device_list => \@pv
    };
    return bless($self, $class);
}

=pod

=head2 _initialize

Where the object creation is actually done

=cut

sub _initialize
{
    my ($self, $path, $config) = @_;
    my $st = $config->getElement($path)->getTree;
    if ($config->elementExists(VOLGROUP_REQUIRED_PATH)) {
        $self->{_volgroup_required} = $config->getElement(VOLGROUP_REQUIRED_PATH)->getTree();
    } else {
        $self->{_volgroup_required} = 0;
    }
    $path =~ m!/([^/]+)$!;
    $self->{devname} = $1;
    foreach my $devpath (@{$st->{device_list}}) {
        my $dev = NCM::BlockdevFactory::build($config, $devpath);
        push(@{$self->{device_list}}, $dev);
    }

    # TODO: check the requirements of the component devices
    $self->_set_alignment($st, 0, 0);
    $self->{_cache_key} = $self->get_cache_key($path, $config);
    return $vgs{$self->{_cache_key}} = $self;
}

=pod

=head2 free_extents

Returns the number of physical extents available on the volume group.

=cut

sub free_extents
{
    my $self = shift;

    local $ENV{LANG} = 'C';

    my @l = split(":", output(VGDISPLAY, $self->{devname}));
    return $l[EXTENTS];
}

=pod

=head2 devpath

Returns the absolute path to the block device file.

=cut

sub devpath
{
    my $self = shift;

    return "/dev/$self->{devname}";
}

=pod 

=head2 pvexists

Returns true if the given partition is a physical volume.

=cut

sub pvexists
{
    my ($self, $path) = @_;

    output(PVDISPLAY, $path);
    return !$?;
}

=pod

=head2 devexists

Returns true if the volume group already exists.

=cut

sub devexists
{
    my $self = shift;

    # Ugly hack because SL's vgdisplay sucks: the volume exists if
    # vgdisplay has any output
    my $output = output(VGDISPLAY, $self->{devname});
    my @lines = split /:/, $output;
    return scalar(@lines) > 1;
}

=pod

=head1 Methods exposed to AII

=head2 should_print_ks

Returns whether the volume group should be specified at the Kickstart
file. That is, if all its physical volumes should be specified at the
kickstart.

=cut

sub should_print_ks
{
    my $self = shift;

    foreach (@{$self->{device_list}}) {
        return 0 unless $_->should_print_ks;
    }
    return 1;
}

=pod

=head2 should_create_ks

Returns whether the volume group should be defined in the
%pre script.

=cut

sub should_create_ks
{
    my $self = shift;

    foreach (@{$self->{device_list}}) {
        return 0 unless $_->should_create_ks;
    }
    return 1;
}

=pod

=head2 print_ks

If the logical volume must be printed, it prints the appropriate
kickstart commands.

=cut

sub print_ks
{
    my $self = shift;
    return unless $self->should_print_ks;

    $_->print_ks foreach (@{$self->{device_list}});
    print "\n" . VOLGROUP . " $self->{devname} --noformat\n" if $self->{_volgroup_required};
}

=pod

=head2 del_pre_ks

Generates the Bash code for removing the volume group from the system,
if that's needed.

=cut

sub del_pre_ks
{
    my $self = shift;

    $self->ks_is_correct_device;

    # The removal will succeed only if there are no logical volumes on
    # this volume group. If that's the case, remove all the physical
    # volumes too.
    print <<EOF;
lvm vgreduce --removemissing $self->{devname} &&
lvm vgremove $self->{devname} && (
EOF

    foreach (@{$self->{device_list}}) {
        print "lvm pvremove ", $_->devpath, "\n";
        $_->del_pre_ks;
    }
    print ")\n";

}

sub create_ks
{
    my ($self) = @_;

    return unless $self->should_create_ks;

    $self->ks_is_correct_device;

    my $path = $self->devpath;

    print <<EOC;
if [ ! -e $path ]
then
EOC

    my @devs = ();
    foreach my $pv (@{$self->{device_list}}) {
        $pv->create_ks;
        print " " x 4, "lvm pvcreate ", $pv->devpath, "\n";
        push(@devs, $pv->devpath);
        print " " x 4, "sed -i '\\:", $pv->devpath, "\$:d' @{[PART_FILE]}\n";
    }

    print <<EOF;
    lvm vgcreate $self->{devname} @devs
    echo @{[$self->devpath]} >> @{[PART_FILE]}
fi
EOF
}

1;
