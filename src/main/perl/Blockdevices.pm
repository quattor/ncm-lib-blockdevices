# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
################################################################################

package NCM::Blockdevices;

use strict;
use warnings;

use EDG::WP4::CCM::Element;
use EDG::WP4::CCM::Configuration;
use CAF::Object;
use LC::Process qw (output);
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
with that filesystem (if it is supported). If the filesystem is not supported,                                                                                                           
returns false.                                                                                                                                                                           
                                                                                                                                                                                         
Current supported filesystems are ext2-4, reiser, jfs, xfs, btrfs and swap.                                                                                                              
                                                                                                                                                                                         
=cut                                                                                                                                                                                     
sub has_filesystem
{
    my $self = shift;
    my $fs = shift;

    my $all_fs_regex = "ext[2-4]|reiser|jfs|xfs|btrfs|swap";
    my $fsregex = $all_fs_regex;

    if (defined($fs)) {
        # a supported fs?                                                                                                                                                                
        return 0 if ($fs !~ m{$all_fs_regex});
        $fsregex = $fs;
    };

    my $p = $self->devpath;
    $p = readlink ($p) if -l $p;
    my $f = output (FILES, $p);

    return $f =~ m{$fsregex}i;
}

1;