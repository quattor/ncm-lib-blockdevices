# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
################################################################################

package NCM::Blockdevices;

use strict;
use warnings;

use Cwd qw(abs_path);

use EDG::WP4::CCM::Element;
use EDG::WP4::CCM::Configuration;
use CAF::Object;
use CAF::Process;
use Exporter;
use constant FILES => qw (file -s);

use constant PART_FILE  => '/tmp/created_partitions';
use constant HOSTNAME	=> "/system/network/hostname";
use constant DOMAINNAME	=> "/system/network/domainname";

our @ISA = qw/CAF::Object Exporter/;

our $this_app = $main::this_app;

our @EXPORT_OK = qw ($this_app PART_FILE);

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

# Returns size in bytes (assumes devpath exists).
# Is used by size_in_MiB
sub _size_in_byte
{
    my $self = shift;
    $this_app->error ("_size_in_byte method not defined for this class");
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
        $this_app->verbose("Device ", $self->devname, " has size $size MiB ($bytes byte)");
    } else {
        $this_app->verbose("No size for device ", $self->devname, 
                           ", devpath ", $self->devpath, " doesn't exist");
    }
    return $size;
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

1;
