#${PMpre} NCM::MD${PMpost}

=pod

=head1 NAME

NCM::MD

This class defines a software RAID device. It is part of the
blockdevices framework.

=cut


use EDG::WP4::CCM::Path qw(unescape);

use CAF::FileReader;
use CAF::Process;
use NCM::Blockdevices qw ($reporter PART_FILE);
use NCM::BlockdevFactory qw (build build_from_dev);
use parent qw(NCM::Blockdevices);

use constant BASEPATH	=> "/system/blockdevices/";
use constant MDSTAT => "/proc/mdstat";
use constant MDPATH	=> "md/";
use constant MDASSEMBLE => qw (/sbin/mdadm --assemble);
use constant MDCREATE	=> qw (/sbin/mdadm --create --run);
use constant MDZERO	=> qw (/sbin/mdadm --zero-superblock);
use constant MDLEVEL	=> '--level=';
use constant MDDEVS	=> '--raid-devices=';
use constant MDSTRIPE	=> '--chunk=';
use constant MDMETADATA => '--metadata=';
use constant MDSTOP	=> qw (/sbin/mdadm --stop);
use constant MDFAIL	=> qw (/sbin/mdadm --fail);
use constant MDREMOVE	=> qw (/sbin/mdadm --remove);
use constant MDQUERY	=> qw (/sbin/mdadm --detail);
use constant MDQRY	=> qw (/sbin/mdadm -Q);
use constant PARTED     => qw (parted -s --);
use constant USEEXISTING    => "--useexisting";

our %mds = ();

=pod

=head2 _initialize

Where the object is actually created.

=cut

sub _initialize
{
    my ($self, $path, $config, %opts) = @_;

    $self->{log} = $opts{log} || $reporter;
    my $st = $config->getElement($path)->getTree;
    $path=~m!/([^/]+)$!;
    $self->{devname} = unescape($1);
    $st->{raid_level} =~ m!(\d)$!;
    $self->{raid_level} = $1;
    $self->{stripe_size} = $st->{stripe_size};
    $self->{metadata} = $st->{metadata} || "0.90";
    foreach my $devpath (@{$st->{device_list}}) {
        my $dev = NCM::BlockdevFactory::build ($config, $devpath, %opts);
        push (@{$self->{device_list}}, $dev);
    }
    # TODO: compute the alignment from the properties of the component devices
    # and the RAID parameters
    $self->_set_alignment($st, 0, 0);
    $self->{_cache_key} = $self->get_cache_key($path, $config);
    return $mds{$self->{_cache_key}} = $self;
}

=pod

=head2 new

Class constructor. It ensures there is only one object for each
software RAID device.

=cut

sub new
{
    my ($class, $path, $config, %opts) = @_;
    my $cache_key = $class->get_cache_key($path, $config);
    return (exists $mds{$cache_key}) ? $mds{$cache_key} : $class->SUPER::new ($path, $config, %opts);
}

=pod

=head2 create

Creates the MD device on the system, according to $self's state.

Returns 0 on success.

=cut

sub create
{
    my $self = shift;

    return 1 if (! $self->is_valid_device);

    my @devnames;

    if ($self->devexists) {
        $self->debug (5, "Device ", $self->devpath, " already exists.",
                      " Leaving.");
        return 0;
    }
    foreach my $dev (@{$self->{device_list}}) {
        $dev->create==0 or return $?;
        push (@devnames, $dev->devpath);
    }
    CAF::Process->new([MDCREATE, $self->devpath, MDLEVEL.$self->{raid_level},
                       MDSTRIPE.$self->{stripe_size}, MDMETADATA.$self->{metadata},
                       MDDEVS.scalar(@{$self->{device_list}}), @devnames],
                       log => $self
                       )->execute();
    $? && $self->error ("Couldn't create ", $self->devpath);
    return $?;
}

=pod

=head2 remove

Removes the MD device and all its associated devices from the system.

Returns 0 on success.

=cut

sub remove
{
    my $self = shift;

    return 1 if (! $self->is_valid_device);

    CAF::Process->new([MDSTOP, $self->devpath], log => $self)->execute();
    foreach my $dev (@{$self->{device_list}}) {
        CAF::Process->new([MDZERO, $dev->devpath],
                          log => $self)->execute();
        $dev->remove==0 or return $?;
    }
    delete $mds{$self->{_cache_key}} if exists $self->{_cache_key};
    $? && $self->error ("Couldn't destroy ", $self->devpath);
    return $?;
}

=pod

=head2 devexists

Returns true if the device exists on the system.

=cut

sub devexists
{
    my $self = shift;
    # First try to assemble to check for stopped raid arrays
    my @devnames = ();
    foreach my $dev (@{$self->{device_list}}) {
        push (@devnames, $dev->devpath);
    }

    CAF::Process->new([MDASSEMBLE, $self->devpath, @devnames],
                       log => $self)->execute();
    CAF::Process->new([MDQRY, $self->devpath], log => $self)->execute();
    my $ec = $?;
    $self->debug(3, "querying $self->{devname} returned $ec");
    return ($ec == 0);
}


=pod

=head2 is_valid_device

Returns true if this is the device that corresponds with the device
described in the profile.

The method can log an error, as it is more of a sanity check then a test.

Implemented by checking if all devices in C<device_list> are valid.

=cut

sub is_valid_device
{
    my $self = shift;

    foreach my $dev (@{$self->{device_list}}) {
        if (! $dev->is_valid_device) {
            $self->error("$dev->{devname} from device_list is not valid device.");
            return 0;
        }
    }

    return 1;
}

=pod

=head2 devpath

Return the path in /dev/ of the MD device.

=cut

sub devpath
{
    my $self = shift;
    return "/dev/$self->{devname}";
}

=pod

=head2 new_from_system

=cut

sub new_from_system
{
    my ($class, $dev, $cfg, %opts) = @_;

    $dev =~ m{/dev/(md.*)$};
    my $devname = $1;

    my $self = {
        devname => $devname,
        log => ($opts{log} || $reporter),
    };
    bless ($self, $class);

    my $lines =  CAF::Process->new([MDQUERY, $dev],
                                   log => $self)->output();
    my @devlist;
    $lines =~ m{Raid Level : (\w+)$}omg;
    my $level = uc ($1);
    while ($lines =~ m{\w\s+(/dev.*)$}omg) {
        push (@devlist, NCM::BlockdevFactory::build_from_dev ($1, $cfg, %opts));
    }
    $self->{raid_level} = $level;
    $self->{device_list} = \@devlist;
    return $self;
}

=pod

=head1 Methods exposed to AII

=head2 should_print_ks

=cut

sub should_print_ks
{
    my $self = shift;
    foreach (@{$self->{device_list}}) {
        return 0 unless $_->should_print_ks;
    }
    return 1;
}

sub should_create_ks
{
    my $self = shift;
    foreach (@{$self->{device_list}}) {
        return 0 unless $_->should_create_ks;
    }
    return 1;
}

sub print_ks
{
    my ($self, $fs) = @_;

    return unless $self->should_print_ks;

    my $useexisting = '';
    if ($fs->{useexisting_md}) {
        $self->debug(5, 'useexisting flag enabled');
        $useexisting = USEEXISTING;
    }
    if (scalar (@_) == 2) {
        (my $naming = $self->{devname}) =~ s!^md/!!;
        $_->print_ks foreach (@{$self->{device_list}});
        print join(" ",
                   "raid",
                   $fs->{mountpoint},
                   "--device=$naming",
                   $self->ksfsformat($fs),
                   $useexisting,
                   "\n");
    }
}

sub del_pre_ks
{
    my $self = shift;

    $self->ks_is_valid_device;

    print join (" ", MDSTOP, $self->devpath), "\n";
    foreach my $dev (@{$self->{device_list}}) {
        print join (" ", MDZERO, $dev->devpath), "\n";
        $dev->del_pre_ks;
    }
}

sub create_ks
{
    my ($self, $fs) = @_;

    return unless $self->should_create_ks;

    $self->ks_is_valid_device;

    my @devnames = ();
    my $path = $self->devpath;
    print <<EOC;
export PATH=/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin
if  ! grep -q $self->{devname} /proc/mdstat
then
EOC
    foreach my $dev (@{$self->{device_list}}) {
        $dev->create_ks;
        if (ref ($dev) eq 'NCM::Partition') {
            my $hdpath = $dev->{holding_dev}->devpath;
            my $hdname = $dev->{holding_dev}->{devname};
            my $n = $dev->partition_number;
            print join (" ", PARTED, $hdpath, 'set', $n,'raid', 'on'), "\n";
        }
        push (@devnames, $dev->devpath);
        print "sed -i '\\:@{[$dev->devpath]}\$:d' @{[PART_FILE]}\n";
    }
    my $ndev = scalar(@devnames);
    print <<EOC;
    sleep 5; mdadm --create --run $path --level=$self->{raid_level} --metadata=$self->{metadata} \\
        --chunk=$self->{stripe_size} --raid-devices=$ndev \\
         @devnames
    echo @{[$self->devpath]} >> @{[PART_FILE]}
EOC
    print "fi\n";
}

=pod

=head2 ks_is_valid_device

Print the kickstart pre bash code to determine if
the device is the valid device or not.

Currently supports checking the device_list.

=cut

sub ks_is_valid_device
{
    my $self = shift;

    foreach my $dev (@{$self->{device_list}}) {
        $dev->ks_is_valid_device;
    }

}

1;
