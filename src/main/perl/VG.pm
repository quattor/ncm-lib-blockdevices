#${PMpre} NCM::VG${PMpost}

=pod

=head1 NAME

NCM::LVM

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

use constant PVS => ('/usr/sbin/pvs', '-o', 'name,vg_name');

use CAF::Process;

use NCM::Blockdevices qw ($reporter PART_FILE);
use NCM::BlockdevFactory qw(build build_from_dev);
use parent qw(NCM::Blockdevices);

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

use constant LVMFORCE => '--force';

use constant AII_LVMFORCE_PATH => "/system/aii/osinstall/ks/lvmforce";


our %vgs = ();

# private method to reset the cache. For unittests only.
sub _reset_cache
{
    %vgs = ();
}

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

    return 1 if (!$self->is_valid_device);

    if ($self->devexists) {
        $self->debug(5, "Volume group $self->{devname} already ", " exists. Leaving");
        return 0;
    }
    foreach my $dev (@{$self->{device_list}}) {
        $dev->create == 0 or return $?;
        CAF::Process->new([PVCREATE, $dev->devpath], log => $self)->execute()
            if !$self->pvexists($dev->devpath);
        return $? if $?;
        push(@devnames, $dev->devpath);
    }
    CAF::Process->new([VGCREATE, $self->{devname}, VGCOPTS, @devnames], log => $self)->execute();
    $self->error("Failed to create volume group $self->{devname}") if $?;
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

    return 1 if (!$self->is_valid_device);

    # Remove the VG only if it has no logical volumes left.
    my $output = CAF::Process->new([VGDISPLAY, $self->{devname}], log => $self)->output();
    my @n = split /:/, $output;
    if ($n[EXISTS]) {
        $self->debug(
            5, "Volume group $self->{devname} has",
            $n[EXISTS], " logical volumes left. Not removing yet"
        );
        return 0;
    }
    if ($self->devexists) {
        CAF::Process->new([VGREMOVE, $self->{devname}], log => $self)->execute();
        return 0 if $?;
    }
    foreach my $dev (@{$self->{device_list}}) {
        CAF::Process->new([PVREMOVE, $dev->devpath], log => $self)->execute();
        $self->error("Failed to remove labels on PV", $dev->devpath) if $?;
        $dev->remove == 0 or last;
    }
    delete $vgs{$self->{_cache_key}} if exists $self->{_cache_key};
    return $?;
}

sub new_from_system
{
    my ($class, $dev, $cfg, %opts) = @_;

    $dev =~ m{dev/mapper/(.*)};
    my $devname = $1;
    $devname =~ s/-{2}/-/g;

    my $log = $opts{log} || $reporter;

    # Have to do it this way because of a nasty bug on vgs.
    my $pvs = CAF::Process->new([PVS], log => $log)->output();
    my @pv;
    while ($pvs =~ m{^\s*(\S+)\s+$devname$}omgc) {
        push(@pv, build_from_dev($1, $cfg, %opts));
    }
    my $self = {
        devname     => $devname,
        device_list => \@pv,
        log => $log,
    };
    return bless($self, $class);
}

=pod

=head2 _initialize

Where the object creation is actually done

=cut

sub _initialize
{
    my ($self, $path, $config, %opts) = @_;

    $self->{log} = $opts{log} || $reporter;
    my $st = $config->getElement($path)->getTree;
    if ($config->elementExists(VOLGROUP_REQUIRED_PATH)) {
        $self->{_volgroup_required} = $config->getElement(VOLGROUP_REQUIRED_PATH)->getTree();
    } else {
        $self->{_volgroup_required} = 0;
    }
    $path =~ m!/([^/]+)$!;
    $self->{devname} = $1;
    foreach my $devpath (@{$st->{device_list}}) {
        my $dev = NCM::BlockdevFactory::build($config, $devpath, %opts);
        push(@{$self->{device_list}}, $dev);
    }

    # Defaults to false is not defined in AII
    $self->{ks_lvmforce} = $config->elementExists(AII_LVMFORCE_PATH) ?
         $config->getElement(AII_LVMFORCE_PATH)->getValue : 0;

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

    my $output = CAF::Process->new([VGDISPLAY, $self->{devname}], log => $self)->output();
    my @l = split(":", $output);
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

    my $output = CAF::Process->new([PVDISPLAY, $path], log => $self)->output();

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
    # -> Is this still valid? In >= sl6, exitcode can be used
    my $output = CAF::Process->new([VGDISPLAY, $self->{devname}], log => $self)->output();
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

    $self->ks_is_valid_device;

    my $force = $self->{ks_lvmforce} ? LVMFORCE : '';

    # The removal will succeed only if there are no logical volumes on
    # this volume group. If that's the case, remove all the physical
    # volumes too.
    # Better check explicitly (e.g. when --force is enabled)
    print <<EOF;
lvm lvdisplay $self->{devname} | grep $self->{devname}
[ \$? -ne 0 ] &&
lvm vgreduce $force --removemissing $self->{devname} &&
lvm vgremove $force $self->{devname} && (
EOF

    foreach (@{$self->{device_list}}) {
        print "lvm pvremove $force ", $_->devpath, "\n";
        $_->del_pre_ks;
    }
    print ")\n";

}

sub create_ks
{
    my ($self) = @_;

    return unless $self->should_create_ks;

    $self->ks_is_valid_device;

    my $force = $self->{ks_lvmforce} ? LVMFORCE : '';

    my $path = $self->devpath;

    print <<EOC;
if [ ! -e $path ]
then
EOC

    my @devs = ();
    foreach my $pv (@{$self->{device_list}}) {
        $pv->create_ks;
        print " " x 4, "lvm pvcreate $force ", $pv->devpath, "\n";
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
