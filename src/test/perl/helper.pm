# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}

package helper;

use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw(set_output);

use Test::More;
use Test::Quattor;

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
# triggers a: Use of uninitialized value $out in pattern match (m//) at 
# .../target/lib/perl/NCM/Partition.pm line 88.
# retest it here, also check the constant (that's the one being used)
set_output("parted_version_2");  # force this version
use NCM::Partition;
is(NCM::Partition->extra_args(),(), "No extra args for parted, version OK");
is(NCM::Partition::PARTEDEXTRA, (), "No extra args for parted");

# mock devexists, it has a -b test, which can't be mocked
# e.g. http://stackoverflow.com/questions/1954529/perl-mocking-d-f-and-friends-how-to-put-them-into-coreglobal
use NCM::Disk;
*NCM::Disk::devexists   = \&main::mock_devexists;
sub mock_devexists { return 1; }

