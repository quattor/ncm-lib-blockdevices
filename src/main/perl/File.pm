# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
################################################################################

=pod

=head1 File

This class defines a file that can be used later as a pseudo-block
device that holds another filesystem. It is part of the blockdevices
framework.

=cut

package NCM::File;

use strict;
use warnings;

use EDG::WP4::CCM::Element qw (unescape);
use EDG::WP4::CCM::Configuration;
use LC::Process qw (execute output);
use NCM::Blockdevices qw ($this_app);
our @ISA = qw (NCM::Blockdevices);

use constant BASEPATH	=> "/system/blockdevices/";
use constant DD		=> qw (/bin/dd if=/dev/zero bs=1M);
use constant SIZE	=> 'count=';
use constant OUT	=> 'of=';


sub _initialize
{
    my ($self, $path, $config) = @_;

    my $st = $config->getElement($path)->getTree;

    $path =~ m!/([^/]+)$!;
    $self->{devname} = unescape ($1);
    my @vals = getpwnam ($st->{owner});
    $self->{size} = $st->{size};
    $self->{owner} = $vals[2];
    @vals = getgrnam($st->{group});
    $self->{group} = $vals[2];
    $self->{permissions} = $st->{permissions};
    return $self;
}

=pod

=head2 create

Creates the file, with the desired name, size ownership and
permissions.

=cut

sub create
{
	my $self = shift;

	# Don't overwrite existing files. Data loss and symlink
	# attacks!
	return 0 if (-e $self->devpath);

	execute ([DD, SIZE.$self->{size}, OUT.$self->devpath]);
	if ($?) {
		$this_app->error ("Couldn't create file: ", $self->devpath);
	} else {
		chmod ($self->{permissions}, $self->devpath);
		chown ($self->{owner}, $self->{group}, $self->devpath);
	}
	return $?;
}

=pod

=head2 remove

Removes the file.

=cut

sub remove
{
	my $self = shift;

	return unlink ($self->devpath);
}

=pod

=head2 devpath

Returns the absolute path to the file.

=cut

sub devpath
{
	my $self = shift;
	return $self->{devname};
}

=pod

=head2 new_from_system

=cut

sub new_from_system
{
	my ($class, $dev, $cfg) = @_;

	my $self = { devname => $dev };
	return bless ($self, $class);
}


=pod

=head1 Methods for AII use

=head2 should_print_ks

Returns whether the File should be printed on the kickstart. This is
always false.

=cut

sub should_print_ks
{
	return 0;
}

=head2 should_create_ks

Returns whether the File should be printed on the %pre script. This is
always false.

=cut

sub should_create_ks
{
	return 0;
}

1;
