#${PMpre} NCM::File${PMpost}

=pod

=head1 NAME

NCM::File

This class defines a file that can be used later as a pseudo-block
device that holds another filesystem. It is part of the blockdevices
framework.

=cut

use EDG::WP4::CCM::Path qw (unescape);
use CAF::Process;
use NCM::Blockdevices qw ($reporter);
use parent qw(NCM::Blockdevices);

use constant BASEPATH	=> "/system/blockdevices/";
use constant DD		=> qw (/bin/dd if=/dev/zero bs=1M);
use constant SIZE	=> 'count=';
use constant OUT	=> 'of=';


sub _initialize
{
    my ($self, $path, $config, %opts) = @_;

    $self->SUPER::_initialize(%opts);

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

Returns 0 on success.

=cut

sub create
{
	my $self = shift;

    return 1 if (! $self->is_valid_device);

	# Don't overwrite existing files. Data loss and symlink
	# attacks!
	return 0 if (-e $self->devpath);

	CAF::Process->new([DD, SIZE.$self->{size}, OUT.$self->devpath], log => $self)->execute();
	if ($?) {
		$self->error ("Couldn't create file: ", $self->devpath);
	} else {
		chmod ($self->{permissions}, $self->devpath);
		chown ($self->{owner}, $self->{group}, $self->devpath);
	}
	return $?;
}

=pod

=head2 remove

Removes the file.

Returns 0 on success.

=cut

sub remove
{
	my $self = shift;

    return 1 if (! $self->is_valid_device);

	return unlink ($self->devpath);
}

=pod

=head2 devexists

Returns true if the file exists in the system.

=cut


sub devexists
{
    my $self = shift;
    return -f $self->devpath;
}

# Returns size in byte (assumes devpath exists).
# Is used by size
sub _size_in_byte
{
    my $self = shift;
    return -s $self->devpath;
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
	my ($class, $dev, $cfg, %opts) = @_;

	my $self = {
        devname => $dev,
        log => ($opts{log} || $reporter),
    };
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
