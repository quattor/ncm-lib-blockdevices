#${PMpre} NCM::VXVM${PMpost}

=pod

=head1 VXVM

This class defines a VXVM volume. It is part of the
blockdevices framework.

=cut

use EDG::WP4::CCM::Path qw(unescape);
use parent qw(NCM::Blockdevices);

our $reporter = $main::this_app;

sub _initialize
{
    my ($self, $path, $config, %opts) = @_;

    $self->SUPER::_initialize(%opts);

    if ($path =~ m!/([^/]+)$!) {
        $self->{devname} = unescape($1);
    } else {
        $self->error("cannot determine devname from $path");
    }

    return $self;
}

sub create
{
    my $self = shift;
    $self->verbose("create not supported");
    return 0;
}

sub remove
{
    my $self = shift;

    return 0;
}


=pod

=head2 devexists

Returns true if the device already exists in the system.

=cut

sub devexists
{
    my $self = shift;

    return (-b $self->devpath);
}

sub devpath
{
    my $self = shift;

    return "/dev/vx/dsk/$self->{devname}";
}

sub should_print_ks
{
    return 0;
}

sub should_create_ks
{
    return 0;
}


1;
