#${PMpre} NCM::BlockdevFactory${PMpost}

=head1 NAME

NCM::BlockdevFactory

=cut

use NCM::Blockdevices qw ($reporter);
use Module::Load;
use CAF::Process;
use Readonly;

Readonly my $BASEPATH => "/system/blockdevices";
Readonly my @PARTED	=> qw (/sbin/parted -s --);
Readonly my @PARTEDEXTRA => qw (u MiB);
Readonly my $PARTEDPRINT => 'print';
# if all is put in qw(), perl warns with 'Possible attempt to separate words with commas'
Readonly my $DMINFO => [qw(dmsetup info -C --noheadings --separator : -o), 'name,subsystem'];

# Pattern or compiled pattern to map the device taken fom the
# pan path /system/blockdevices/<device> to the NCM:: class
# If the pattern is a string, it is a partial pattern
# (actual used one is '^<string>/')
# Patterns are tried in alphabetical order of the key name,
# so make sure 2 patterns cannot match the same device
Readonly my %BUILD_MAP => (
    Disk => 'physical_devs',
    File => 'files',
    LV => 'logical_volumes',
    MD => 'md',
    Partition => 'partitions',
    Proc => qr{^proc$},
    Tmpfs => qr{^tmpfs$},
    VG => 'volume_groups',
    VXVM => 'vxvm',
);

use parent qw(Exporter);

our @EXPORT_OK = qw (build build_from_dev);


sub _mk_instance
{
    my ($log, $name, $args, $from_system) = @_;

    my $method = $from_system ? 'new_from_system' : 'new';

    local $@;
    my $pack = "NCM::$name";
    eval {
        load $pack;
    };
    if ($@) {
        $log->error("bad Perl code in $pack: $@");
        return;
    }

    my $instance;
    eval {
        $instance = $pack->$method(@$args);
    };
    if ($@) {
        $log->error("blockdevice $pack instantiation via $method fails: $@");
        return;
    }

    return $instance;
}

=head2 build

Returns the object describing the block device passed as an argument.

=cut

sub build
{
    my ($config, $dev, %opts) = @_;

    my $log = $opts{log} || $reporter;
    my @args = ("$BASEPATH/$dev", $config, %opts);

    foreach my $name (sort keys %BUILD_MAP) {
        my $reg = $BUILD_MAP{$name};

        $reg = qr{^$reg/} if (ref($reg) eq '');

        return _mk_instance($log, $name, \@args, 0) if ($dev =~ m/$reg/);
    }

    $log->error("Unable to find block device implementation for device $dev");
    return;
}

# Return the NCM:: class name based on device name
sub _find_class
{
    my ($log, $dev) = @_;
    my $name = 'File';
    my $dminfo = CAF::Process->new($DMINFO, log => $log)->output();
    my %dminfomap = map {$_->[0] => $_->[1]} map {[split(':')]} grep {m/:/} split("\n", $dminfo);

    if (-l $dev) {
        my $rd = readlink($dev);
        $dev = $rd if $rd =~ m{^/dev/mapper/}
    }

    if ($dev =~ m{^/dev/md\d+$}) {
        $name = 'MD';
    } elsif ($dev =~ m{^/dev/mapper/(\S+)}) {
        if (exists($dminfomap{$1})) {
            my $type = $dminfomap{$1} || ''; # zero gives undef, replace with empty string
            if ($type eq 'LVM') {
                $name = 'LV';
            } elsif ($type =~ m/^part/) {
                $name = 'Partition';
            } else {
                $name = 'Disk'; # eg mpath, zero
            }
        } else {
            # old fallback
            $name = 'LV';
        }
    } elsif ($dev =~ m{^/dev/}) {
        # This is the most generic way I can think of deciding
        # whether a path refers to a full disk or to a partition.
        my $output = CAF::Process->new([@PARTED, $dev, @PARTEDEXTRA, $PARTEDPRINT], log => $log)->output();
        if ($?) {
            # no disk label
            # guess based on name
            # additional p to indicate partition if the disk device ends with digits
            if ($dev =~ m/^(\S+)((?<=\d)p)?\d+$/) {
                CAF::Process->new([@PARTED, $1, @PARTEDEXTRA, $PARTEDPRINT], log => $log)->execute();
                # is $1 a disk-like device with a partition table?
                $name = $? ? 'Disk' : 'Partition';
            } else {
                $name = 'Disk';
            }
        } else {
            $name = $output =~ m/^Partition\s*Table:\s*loop$/mi ? 'Partition' : 'Disk';
        }
    }

    return $name;
}

sub build_from_dev
{
    my ($dev, $config, %opts) = @_;

    my $log = $opts{log} || $reporter;
    my @args = ($dev, $config, %opts);
    $log->debug (5, "Creating block device structure for $dev device");

    my $name = _find_class($log, $dev);
    return _mk_instance($log, $name, \@args, 1)
}

1;
