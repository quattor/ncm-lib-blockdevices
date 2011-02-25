# ${license-info}
# ${developer-info
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

our @ISA = qw/CAF::Object Exporter/;

our $this_app = $main::this_app;

our @EXPORT_OK = qw ($this_app);

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
	$this_app->error ("should_print method not defined for this class");
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

Returns true if the block device has been formatted with any filesystem.

=cut
sub has_filesystem
{
    my $self = shift;

    my $p = $self->devpath;
    $p = readlink ($p) if -l $p;
    my $f = output (FILES, $p);
    return $f =~ m{ext[2-4]|reiser|jfs|xfs}i;
}

1;
