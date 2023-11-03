#${PMpre} NCM::Blockdevices${PMpost}

=pod

=head1 NAME

NCM::Blockdevices

=cut

use Cwd qw(abs_path);

use CAF::Process;
use POSIX qw(ceil floor);

use constant BLKID => "/sbin/blkid";
use constant FILES => qw (file -s);

use constant PART_FILE  => '/tmp/created_partitions';
use constant HOSTNAME   => "/system/network/hostname";
use constant DOMAINNAME => "/system/network/domainname";

use constant GET_SIZE_BYTES  => qw (/sbin/blockdev --getsize64);

# Lowest supported version is 5.0
# FIXME: there is a circular dependency between aii-ks and
# ncm-lib-blockdevices. Eventually, we should have a better solution, but
# duplicating these constants here avoids deeper changes for now.
use constant ANACONDA_VERSION_EL_5_0 => version->new("11.1");
use constant ANACONDA_VERSION_EL_6_0 => version->new("13.21");
use constant ANACONDA_VERSION_EL_7_0 => version->new("19.31");
use constant ANACONDA_VERSION_EL_8_0 => version->new("29.19");
use constant ANACONDA_VERSION_EL_9_0 => version->new("34.25");
use constant ANACONDA_VERSION_LOWEST => ANACONDA_VERSION_EL_5_0;

use parent qw(CAF::Object Exporter);

our $reporter = $main::this_app;

our @EXPORT_OK = qw ($reporter PART_FILE ANACONDA_VERSION_EL_5_0 ANACONDA_VERSION_EL_6_0 ANACONDA_VERSION_EL_7_0 ANACONDA_VERSION_EL_8_0 ANACONDA_VERSION_EL_9_0);

sub get_cache_key {
     my ($self, $path, $config) = @_;
     my $host = $config->getElement (HOSTNAME)->getValue;
     my $domain = $config->getElement (DOMAINNAME)->getValue;
     return $host . "." . $domain . ":" . $path;
}

sub _initialize
{
    my ($self, %opts) = @_;
    $self->{log} = $opts{log} || $reporter;
    $self->{anaconda_version} = $opts{anaconda_version} || ANACONDA_VERSION_LOWEST;
    return $_[0];
}

sub create
{
	my $self = shift;
	$self->error ("create method not defined for this class");
}

sub remove
{
	my $self = shift;
	$self->error ("remove method not defined for this class");

}

sub grow
{
	my $self = shift;
	$self->error ("grow method not defined for this class");

}

sub shrink
{
	my $self = shift;
	$self->error ("shrink method not defined for this class");

}

sub decide
{
	my $self = shift;
	$self->error ("decide method not defined for this class");
}

sub devexists
{
	my $self = shift;
	$self->error ("devexists method not defined for this class");
}


sub should_print_ks
{
	my $self = shift;
	$self->error ("should_print_ks method not defined for this class");
}

sub should_create_ks
{
	my $self = shift;
	$self->error ("should_create_ks method not defined for this class");
}

# Return the size of metadata to wipe in MB
sub get_clear_mb
{
	my $self = shift;
	$self->error ("get_clear_mb is no longer implemented");
}

=pod

=head2 is_valid_device

Returns true if this is the device that corresponds with the device
described in the profile.

The method can log an error, as it is more of a sanity check then a test.

=cut

sub is_valid_device
{
    my $self = shift;
    # Legacy behaviour is no checking; always assuming valid device.
    $self->verbose ("is_valid_device method not defined. Returning true for legacy behaviour.");
    return 1;
}

# Returns size in byte (assumes devpath exists).
# Is used by size
sub _size_in_byte
{
    my $self = shift;
    my $size = CAF::Process->new([GET_SIZE_BYTES, $self->devpath], log => $self)->output();
    chomp($size);
    return $size;
}

=pod

=head2 size

Returns size in MiB if the device exists in the system.
Returns undef if the device doesn't exist.

=cut

sub size
{
    my $self = shift;
    my $size;
    if ($self->devexists) {
        my $bytes = $self->_size_in_byte();
        $size = $bytes / (1024 * 1024);
        $self->verbose("Device $self->{devname}, has size $size MiB ($bytes byte)");
    } else {
        $self->verbose("No size for device $self->{devname}, devpath ",
                           $self->devpath, " doesn't exist");
    }
    return $size;
}

=pod

=head2 valid_size_interval

Compute the smallest interval for the expected C<size>
given the conditions (one or more of):

=over

=item fraction : double

The difference between the found and the expected size is at most
C<fraction> of the expected size. C<fraction> is a double
(e.g. 1 percent is 0.01).

=item diff : long

The difference between the found and the expected size (in MiB) is at most
C<diff> MiB.

=back

=cut

sub valid_size_interval
{
    my $self = shift;

    my @conds = sort keys %{$self->{validate}->{size}};
    $self->verbose("Going to use ", scalar @conds, " conditions: ", join(", ", @conds));

    my ($min, $max);

    # Update min and max with possible new minimum and maximum.
    my $update_min_max = sub {
        my ($nmin, $nmax) = @_;
        if (defined($min)) {
            $min = $nmin if ($nmin > $min);
        } else {
            $min = $nmin;
        }
        if (defined($max)) {
            $max = $nmax if ($nmax < $max);
        } else {
            $max = $nmax;
        }
    };

    foreach my $cond (@conds) {
        if ($cond eq "diff") {
            my $diff =  $self->{validate}->{size}->{diff};
            $update_min_max->($self->{size} - $diff, $self->{size} + $diff);
            $self->verbose("Diff defined $diff, updated min/max $min / $max");
        } elsif ($cond eq "fraction") {
            my $frac = $self->{validate}->{size}->{fraction};
            $update_min_max->((1-$frac) * $self->{size}, (1+$frac) * $self->{size});
            $self->verbose("Fraction defined $frac, updated min/max $min / $max");
        } else {
            $self->error("is_valid_size unknown condition $cond");
            return;
        }
    };


    if(!defined($min)) {
        $self->info("Minimum undefined after the conditions, using expected size $self->{size}");
        $min = $self->{size};
    }

    if(!defined($max)) {
        $self->info("Maximum undefined after the conditions, using expected size $self->{size}");
        $max = $self->{size};
    }

    $min = 0 if ($min < 0);
    $max = 0 if ($max < 0);

    if($min > $max) {
        $self->error("is_valid_size minimum $min larger then maximum $max");
        return;
    }


    return ($min, $max);
}

=pod

=head2 is_valid_size

Returns true if the size of this device
lies in the C<valid_size_interval>.

Returns undef if device does not exists.

Logs error if attributes are missing (like C<size>),
possibly due to incomplete profiles.

=cut

sub is_valid_size
{
    my $self = shift;

    if(! defined($self->{size})) {
        $self->error("Attribute 'size' not found in profile");
        # considered failed. don't specify "validate/size" if you don't want this to run?
        return 0;
    }

    if(! $self->{validate}->{size}) {
        $self->error("Sub-path 'validate/size' not found in profile");
        # considered failed. the code calling this method should check the existance
        return 0;
    }

    my $size = $self->size;

    return if (!defined($size));

    if($self->{size} == 0) {
        if ($self->{size} == $size) {
            $self->verbose("expected size 0 matches found size");
            return 1;
        } else {
            $self->error("expected size 0 not supported");
            # considered failed. don't specify "validate/size" if you don't want this to run?
            return 0;
        }
    }

    my $diff = abs($self->{size} - $size);
    my $msg = "found size $size MiB and expected size $self->{size} MiB";
    $self->verbose("Size difference of $diff MiB between $msg");

    my ($min, $max) = $self->valid_size_interval();

    if($size >= $min && $size <= $max) {
        $self->verbose("Found size $size in allowed interval [$min,$max] MiB");
    } else {
        $self->error("Found size $size outside allowed interval [$min,$max] MiB");
        return 0;
    }
    return 1;
}

=pod

=head2 ks_is_valid_device

Print the kickstart pre bash code to determine if
the device is the valid device or not.

=cut

sub ks_is_valid_device
{
    my $self = shift;
    $self->verbose ("ks_is_valid_device method not defined. Not printing anything for legacy behaviour.");
    return 1;
}

=pod

=head2 ks_pre_is_valid_size

Kickstart code in pre section to determine if device has valid size.
Uses the bash function C<valid_disksize_MiB> available in the pre section.

=cut

sub ks_pre_is_valid_size
{
    my $self = shift;

    if(! defined($self->{size})) {
        $self->error("Attribute 'size' not found in profile");
        # considered failed. don't specify "validate/size" if you don't want this to run?
        return;
    }

    if(! $self->{validate}->{size}) {
        $self->error("Sub-path 'validate/size' not found in profile");
        # considered failed. the code calling this method should check the existance
        return;
    }

    if($self->{size} == 0) {
        $self->error("Expected size 0 not supported in kickstart");
        # considered failed. don't specify "validate/size" if you don't want this to run?
        return;
    }

    my $devpath = $self->devpath;
    my ($min, $max) = $self->valid_size_interval();
    # require integer for bash comparison
    # use ceil(min) and floor(max) so min > real min and max < real max
    $min = ceil($min);
    $max = floor($max);

    # TODO: %pre --erroronfail to avoid boot loop
    #  (but then requires console access/power control to get past)

    # The valid_disksize_MiB also logs/echoes some error messages
    print <<"EOF";
valid_disksize_MiB $devpath $min $max
if [ \$? -ne 0 ]; then
    echo "[ERROR] Invalid size for $devpath. Exiting pre with exitcode 1."
    exit 1
fi
EOF

    return 0;
}


=pod

=head2 ksfsformat

Given a filesystem instance C<fs>, return the kickstart formatting command
to be used in the kickstart commands section.
It defaults to C<--noformat> unless the C<ksfsformat> boolean is true, or it
is a labeled swap filesystem. If C<ksfsformat> is true and C<mkfsopts> are used,
a warning is issued (as the kickstart commands do not support mkfs options).

=cut

sub ksfsformat
{
    my ($self, $fs) = @_;

    my @format;

    my $force_format = 0;
    # Anaconda doesn't recognize existing SWAP labels, if
    # we want a label on swap, we'll have to re-format the
    # partition and let it set its own label.
    $force_format ||= $fs->{type} eq "swap" && exists $fs->{label};

    # (Re)formatting in the kickstart commands section can
    # also be forced if needed (e.g. EL7 anaconda does not
    # allow to use an existing filesystem as /)
    # TODO: Remove once aii-ks passes anaconda_version
    $force_format ||= exists($fs->{ksfsformat}) && $fs->{ksfsformat};

    # EL7+ anaconda does not allow a preformatted / filesystem.
    $force_format ||= $self->{anaconda_version} >= ANACONDA_VERSION_EL_7_0 && $fs->{mountpoint} eq '/';

    # EL7+ anaconda does not write a preformatted swap partition to /etc/fstab
    $force_format ||= $self->{anaconda_version} >= ANACONDA_VERSION_EL_7_0 && $fs->{type} eq 'swap';

    if ($force_format) {
        push(@format, "--fstype=$fs->{type}");
        if (exists($fs->{mountopts})) {
            push(@format, "--fsoptions='$fs->{mountopts}'");
        }
        if (exists($fs->{mkfsopts})) {
            if ($self->{anaconda_version} >= ANACONDA_VERSION_EL_7_0) {
                push(@format, "--mkfsoptions='$fs->{mkfsopts}'");
            } else {
                $self->warn("mkfsopts $fs->{mkfsopts} set for mountpoint $fs->{mountpoint}",
                            "This is not supported in ksfsformat and ignored here");
            }
        }
    } else {
        push(@format, "--noformat");
    }

    return @format;
}

sub print_ks
{}

sub print_pre_ks
{}

sub del_pre_ks
{}

sub create_ks
{
}


=pod

=head2 has_filesystem

Returns true if the block device has been formatted with a supported filesystem.
If a second argument is set, returns true if the block device has been formatted
with that filesystem (if it is supported).
If the filesystem is not supported, print warning and check with all supported
filesystems (default behaviour, returning false might lead to removal of data).

Current supported filesystems are ext2-4, reiser, jfs, xfs, btrfs and swap.

=cut
sub has_filesystem
{
    my ($self, $fs) = @_;

    my $all_fs_regex = '(ext[2-4]|reiser|jfs|xfs|btrfs|swap)';
    my $fsregex = $all_fs_regex;

    if ($fs) {
        # a supported fs?
        # case sensitive, should be enforced via schema
        if ($fs !~ m{^$all_fs_regex$}) {
            $self->warn("Requested filesystem $fs is not supported.",
                            " Fallback to default supported filesystems.");
        } else {
            $fsregex = $fs;
        };
    };

    my $devpath = $self->devpath;
    my $abspath = abs_path($devpath);
    if (defined($abspath)) {
        $self->debug(4, "abs_path $abspath found for $devpath.");
        $devpath = $abspath;
    } else {
        $self->warn("No abs_path found for $devpath. Possibly missing parent directory.");
    };

    my $f = CAF::Process->new([FILES, $devpath], log => $self)->output();

    $self->debug(4, "Checking for filesystem on device $devpath",
                        " with regexp '$fsregex' in output $f.");

    # case insensitive match
    # e.g. file -s returns uppercase filesystem for xfs adn btrfs
    return $f =~ m{\s$fsregex\s+file}i;
}

=pod

=head2 get_uuid

Fetches the (PART)UUID of the device with blkid. Returns undef when not found.
If part is true, we use PARTUUID instead of UUID

=cut

sub get_uuid
{
    my ($self, $part) = @_;
    my $device = $self->devpath;
    my $uuid;
    my $output = CAF::Process->new([BLKID, $device], log => $self, keeps_state => 1)->output();
    $part = $part ? 'PART' : '';
    my $re = qr!\s${part}UUID="(\S+)"!m ;
    if($output && $output =~ m/$re/m){
        $uuid = $1;
    }
    if (!defined($uuid)){
        $self->warn("${part}UUID of device $device could not be found");
    }
    return $uuid;
}

1;
