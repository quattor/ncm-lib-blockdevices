# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package NCM::Blockdevices;

use strict;
use warnings;

use Cwd qw(abs_path);

use EDG::WP4::CCM::Element;
use EDG::WP4::CCM::Configuration;
use CAF::Object;
use CAF::Process;
use Exporter;
use constant BLKID	=> "/sbin/blkid";
use constant FILES => qw (file -s);

use constant PART_FILE  => '/tmp/created_partitions';
use constant HOSTNAME	=> "/system/network/hostname";
use constant DOMAINNAME	=> "/system/network/domainname";

use constant GET_SIZE_BYTES  => qw (/sbin/blockdev --getsize64);

our @ISA = qw/CAF::Object Exporter/;

our $this_app = $main::this_app;

our @EXPORT_OK = qw ($this_app PART_FILE get_disk_uuid);

sub get_cache_key {
     my ($self, $path, $config) = @_;
     my $host = $config->getElement (HOSTNAME)->getValue;
     my $domain = $config->getElement (DOMAINNAME)->getValue;
     return $host . "." . $domain . ":" . $path;
}

sub _initialize
{
	return $_[0];
}

# Set the alignment from either the profile or the given defaults
sub _set_alignment
{
	my ($self, $cfg, $align, $offset) = @_;

	$self->{alignment} = ($cfg && exists $cfg->{alignment}) ?
		$cfg->{alignment} : $align;
	$self->{alignment_offset} = ($cfg && exists $cfg->{alignment_offset}) ?
		$cfg->{alignment_offset} : $offset;
}

sub create
{
	my $self = shift;
	$this_app->error ("create method not defined for this class");
}

sub remove
{
	my $self = shift;
	$this_app->error ("remove method not defined for this class");

}

sub grow
{
	my $self = shift;
	$this_app->error ("grow method not defined for this class");

}

sub shrink
{
	my $self = shift;
	$this_app->error ("shrink method not defined for this class");

}

sub decide
{
	my $self = shift;
	$this_app->error ("decide method not defined for this class");
}

sub devexists
{
	my $self = shift;
	$this_app->error ("devexists method not defined for this class");
}


sub should_print_ks
{
	my $self = shift;
	$this_app->error ("should_print_ks method not defined for this class");
}

sub should_create_ks
{
	my $self = shift;
	$this_app->error ("should_create_ks method not defined for this class");
}

=pod

=head2 is_correct_device

Returns true if this is the device that corresponds with the device 
described in the profile.

The method can log an error, as it is more of a sanity check then a test.

=cut

sub is_correct_device
{
    my $self = shift;
    # Legacy behaviour is no checking; always assuming correct device.
    $this_app->verbose ("is_correct_device method not defined. Returning true for legacy behaviour.");
    return 1;
}

# Returns size in byte (assumes devpath exists).
# Is used by size
sub _size_in_byte
{
    my $self = shift;
    my $size = CAF::Process->new([GET_SIZE_BYTES, $self->devpath], log => $this_app)->output();
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
        $this_app->verbose("Device $self->{devname}, has size $size MiB ($bytes byte)");
    } else {
        $this_app->verbose("No size for device $self->{devname}, devpath ",
                           $self->devpath, " doesn't exist");
    }
    return $size;
}

=pod 

=head2 correct_size_interval

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

sub correct_size_interval
{
    my $self = shift;

    my @conds = sort keys %{$self->{correct}->{size}};
    $this_app->verbose("Going to use ", scalar @conds, " conditions: ", join(", ", @conds));    

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
            my $diff =  $self->{correct}->{size}->{diff};
            $update_min_max->($self->{size} - $diff, $self->{size} + $diff);
            $this_app->verbose("Diff defined $diff, updated min/max $min / $max");
        } elsif ($cond eq "fraction") {
            my $frac = $self->{correct}->{size}->{fraction};
            $update_min_max->((1-$frac) * $self->{size}, (1+$frac) * $self->{size});
            $this_app->verbose("Fraction defined $frac, updated min/max $min / $max");
        } else {
            $this_app->error("is_correct_size unknown condition $cond");
            return;
        }
    };


    if(!defined($min)) {
        $this_app->info("Minimum undefined after the conditions, using expected size $self->{size}");
        $min = $self->{size};
    }
    
    if(!defined($max)) {
        $this_app->info("Maximum undefined after the conditions, using expected size $self->{size}");
        $max = $self->{size};
    }

    $min = 0 if ($min < 0);
    $max = 0 if ($max < 0);

    if($min > $max) {
        $this_app->error("is_correct_size minimum $min larger then maximum $max");
        return;
    }


    return ($min, $max);
}

=pod

=head2 is_correct_size

Returns true if the size of this device
lies in the C<correct_size_interval>.

Returns undef if device does not exists.

Logs error if attributes are missing (like C<size>), 
possibly due to incomplete profiles.

=cut

sub is_correct_size
{
    my $self = shift;
    
    if(! defined($self->{size})) {
        $this_app->error("Attribute 'size' not found in profile");
        # considered failed. don't specify "correct/size" if you don't want this to run?
        return 0;
    }

    if(! $self->{correct}->{size}) {
        $this_app->error("Sub-path 'correct/size' not found in profile");
        # considered failed. the code calling this method should check the existance 
        return 0;
    }

    my $size = $self->size;
    
    return if (!defined($size));

    if($self->{size} == 0) {
        if ($self->{size} == $size) {
            $this_app->verbose("expected size 0 matches found size");
            return 1;
        } else {            
            $this_app->error("expected size 0 not supported");
            # considered failed. don't specify "correct/size" if you don't want this to run?
            return 0;
        }
    }
    
    my $diff = abs($self->{size} - $size);
    my $msg = "found size $size MiB and expected size $self->{size} MiB";
    $this_app->verbose("Size difference of $diff MiB between $msg");    

    my ($min, $max) = $self->correct_size_interval();

    if($size >= $min && $size <= $max) {
        $this_app->verbose("Found size $size in allowed interval [$min,$max] MiB");
    } else {
        $this_app->error("Found size $size outside allowed interval [$min,$max] MiB");
        return 0;
    }
    return 1;
}

=pod

=head2 ks_is_correct_device

Print the kickstart pre bash code to determine if
the device is the correct device or not.

=cut

sub ks_is_correct_device
{
    my $self = shift;
    $this_app->verbose ("ks_is_correct_device method not defined. Not printing anything for legacy behaviour.");
    return 1;
}

=pod

=head2 ks_pre_is_correct_size

Kickstart code in pre section to determine if device has correct size.
Uses the bash function C<correct_disksize_MiB> available in the pre section.

=cut

sub ks_pre_is_correct_size
{
    my $self = shift;
    
    if(! defined($self->{size})) {
        $this_app->error("Attribute 'size' not found in profile");
        # considered failed. don't specify "correct/size" if you don't want this to run?
        return;
    }

    if(! $self->{correct}->{size}) {
        $this_app->error("Sub-path 'correct/size' not found in profile");
        # considered failed. the code calling this method should check the existance 
        return;
    }

    if($self->{size} == 0) {
        $this_app->error("Expected size 0 not supported in kickstart");
        # considered failed. don't specify "correct/size" if you don't want this to run?
        return;
    }
    
    my $devpath = $self->devpath;
    my ($min, $max) = $self->correct_size_interval();

    # TODO: %pre --erroronfail to avoid boot loop 
    #  (but then requires console access/power control to get past)

    # The correct_disksize_MiB also logs/echoes some error messages
    print <<"EOF";
correct_disksize_MiB $devpath $min $max
if [ \$? -ne 0 ]; then
    echo "[ERROR] Incorrect size for $devpath. Exiting pre with exitcode 1."
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
    
    # Anaconda doesn't recognize existing SWAP labels, if
    # we want a label on swap, we'll have to re-format the
    # partition and let it set its own label.
    # (Re)formatting in the kickstart commands section can 
    # also be forced if needed (e.g. EL7 anaconda does not
    # allow to use an existing filesystem as /)
    if (($fs->{type} eq "swap" && exists $fs->{label}) ||
        (exists($fs->{ksfsformat}) && $fs->{ksfsformat})) {
            push(@format, "--fstype=$fs->{type}");
            if (exists($fs->{mountopts})) {
                push(@format, "--fsoptions='$fs->{mountopts}'");
            }
            if (exists($fs->{mkfsopts})) {
                $this_app->warn("mkfsopts $fs->{mkfsopts} set for mountpoint $fs->{mountpoint}",
                                "This is not supported in ksfsformat and ignored here");
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
            $this_app->warn("Requested filesystem $fs is not supported.",
                            " Fallback to default supported filesystems.");
        } else {
            $fsregex = $fs;
        };
    };

    my $p = abs_path($self->devpath);
    my $f =  CAF::Process->new([FILES, $p], log => $this_app)->output();

    $this_app->debug(4, "Checking for filesystem on device $p",
                        " with regexp '$fsregex' in output $f.");
    
    # case insensitive match 
    # e.g. file -s returns uppercase filesystem for xfs adn btrfs
    return $f =~ m{\s$fsregex\s+file}i;
}

=pod

=head2 get_disk_uuid

Fetches the (PART)UUID of the device with blkid. Returns undef when not found.
type can be an empty string or 'PART'

=cut

sub get_disk_uuid
{
    my ($self, $type, $device) = @_;
    
    my $output = CAF::Process->new([BLKID, $device], log => $this_app)->output();
    if($type =~ m/^(PART)?$/) {
        my $re = qr!\s${type}UUID="(\S+)"!m ;
        if($output && $output =~ m/$re/m){
        return $1;
        }
    }
}

1;
