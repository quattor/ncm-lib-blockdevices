# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
package NCM::Tmpfs;

use strict;
use warnings;

use NCM::Blockdevices qw ($this_app);

our @ISA = qw{NCM::Blockdevices};

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
    $this_app->error ("_size_in_byte method not defined for this class");
}

__END__

=pod

=head1 DESCRIPTION

Dummy module, useful, f.i, for tmpfs handling.

These devices won't appear on the Kickstart file, and all operations
on them always succeed, as nothing is done.

=head1 SEE ALSO

L<NCM::Blockdevices>

=head1 AUTHOR

Luis Fernando Muñoz Mejías <Luis.Fernando.Munoz.Mejias@cern.ch>

=cut
