# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

=pod

=head1 helper module

A helper module that gives runs common checks, overwrites NCM::Disk devexists
and provides set_output, a wrapper around the data in the cmddata module and the
set_desired_output, set_desired_err and set_command_status functions.

=cut

package helper;

use strict;
use warnings;
use base 'Exporter';
use Test::MockModule;
our @EXPORT = qw(set_output);

use Test::More;
use Test::Quattor;

$Test::Quattor::log_cmd=$ENV{QUATTOR_TEST_LOG_CMD} || 0;
$Test::Quattor::log_cmd_missing=$ENV{QUATTOR_TEST_LOG_CMD_MISSING}  || 0;

# force this_app, so most log => $this_app works
# in particular, this is not mocked in FileWriter/FileEditor
use NCM::Component;
my $cmp=NCM::Component->new("dummy");
use NCM::Blockdevices;
$NCM::Blockdevices::this_app = $cmp;

use CAF::Object;
$CAF::Object::NoAction = 1;

use cmddata;
sub set_output {
    my $cmdshort = shift;
    my $cmdline= $cmddata::cmds{$cmdshort}{cmd}|| die "Undefined cmd for cmdshort $cmdshort";
    my $out=$cmddata::cmds{$cmdshort}{out} || "";
    my $err=$cmddata::cmds{$cmdshort}{err} || "";
    my $ec=$cmddata::cmds{$cmdshort}{ec} || 0;
    set_desired_output($cmdline, $out);
    set_desired_err($cmdline, $err);
    set_command_status($cmdline, $ec);
};

# can't run this early enough
# retest it here, also check the constant (that's the one being used)
set_output("parted_version_2");  # force this version
use NCM::Partition;
is(NCM::Partition->extra_args(),(), "No extra args for parted, version OK");
is(NCM::Partition::PARTEDEXTRA, (), "No extra args for parted");

# mock devexists, it has a -b test, which can't be mocked
our $mockdisk = Test::MockModule->new('NCM::Disk');
$mockdisk->mock('devexists', 1);

1;