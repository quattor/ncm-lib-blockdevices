# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

=pod

=head1 VXVM

This class defines a VXVM volume. It is part of the
blockdevices framework.

=cut

package NCM::VXVM;

use strict;
use warnings;

use NCM::Blockdevices;
use EDG::WP4::CCM::Element qw (unescape);

our @ISA = qw{NCM::Blockdevices};

our $this_app = $main::this_app;

sub _initialize
{
    my ($self, $path, $config) = @_;

    if ($path =~ m!/([^/]+)$!) {
        $self->{devname} = unescape($1);
    } else {
        $this_app->error("cannot determine devname from $path");
    }

    return $self;
}

sub create
{
    $this_app->verbose("create not supported");
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
