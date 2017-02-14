#${PMpre} NCM::Tmpfs${PMpost}

=pod

=head1 NAME

NCM::Tmpfs

=head1 DESCRIPTION

Dummy module, useful, f.i, for tmpfs handling.

These devices won't appear on the Kickstart file, and all operations
on them always succeed, as nothing is done.

=cut

use NCM::Blockdevices qw ($reporter);

use parent qw(NCM::Blockdevices);

# Returns 0 on success.
sub create
{
    return 0;
}

# Returns 0 on success.
sub remove
{
    return 0;
}

sub devpath
{
    return "tmpfs";
}

sub should_print_ks
{
    return 0;
}

sub should_create_ks
{
    return 0;
}

# Returns size in bytes (assumes devpath exists).
# Is used by size_in_MiB
sub _size_in_byte
{
    my $self = shift;
    $self->error ("_size_in_byte method not defined for this class");
}

1;
