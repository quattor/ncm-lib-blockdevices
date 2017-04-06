#!/usr/bin/perl
# -*- mode: cperl -*-
# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

use strict;
use warnings;
use Test::More;

use Test::Quattor qw(lvm-aii-requires lvm-aii-not-requires);

use helper;

use NCM::VG;

=pod

=head1 SYNOPSIS

Tests for the C<NCM::VG> module.

=head1 TESTS

=head2 Initialisation

We create several objects, and check the C<_volgroup_required> flag.
See L<https://github.com/quattor/ncm-lib-blockdevices/issues/28> for
more details.

=cut

my $cfg = get_config_for_profile('lvm-aii-requires');
my $lvm = NCM::VG->new ("/system/blockdevices/volume_groups/vg0", $cfg);
isa_ok($lvm, "NCM::VG", "VG correctly instantiated");

ok($lvm->{_volgroup_required}, "True value for volgroup required");

$cfg = get_config_for_profile('lvm-aii-not-requires');

# Clean up the cache. We really want a different object now.
%NCM::VG::vgs = ();

$lvm = NCM::VG->new("/system/blockdevices/volume_groups/vg0", $cfg);
ok(!$lvm->{_volgroup_required}, "False value when volgroup is not required") or
    diag("Weird volgroup_required: $lvm->{_volgroup_required}");

done_testing();

__END__

=pod

=head1 TODO

Way more tests.

=cut
