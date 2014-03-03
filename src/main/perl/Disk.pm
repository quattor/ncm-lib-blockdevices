# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
################################################################################

=pod

=head1 Disk

This class describes a disk or a hardware RAID device. It is part of
the blockdevices framework.

The available fields on this class are:

=over 4

=item * devname : string

Name of the device.

=item * num_spares : integer

Number of hot spare drives on the RAID device. It only applies to
hardware RAID.

=item * label : string

Label (type of partition table) to be used on the disk.

=cut

package NCM::Disk;

use strict;
use warnings;
use NCM::Blockdevices qw ($this_app);
use CAF::Process;
use CAF::FileEditor;
use EDG::WP4::CCM::Element qw (unescape);
use LC::Exception;
#use NCM::HWRaid;

my $ec = LC::Exception::Context->new->will_store_all;

our @ISA = qw (NCM::Blockdevices);

use constant DD		=> "/bin/dd";
use constant CREATE	=> "mklabel";
use constant GREP	=> "/bin/grep";
use constant GREPARGS	=> "-c";
use constant NOPART	=> "none";
use constant RCLOCAL	=> "/etc/rc.local";

use constant HWPATH	=> "/hardware/harddisks/";
use constant HOSTNAME	=> "/system/network/hostname";
use constant DOMAINNAME	=> "/system/network/domainname";
use constant IGNOREDISK => "/system/aii/osinstall/ks/ignoredisk";

use constant FILES	=> qw (file -s);
use constant SLEEPTIME	=> 2;
use constant RAIDSLEEP	=> 10;
use constant PARTED	=> qw (/sbin/parted -s --);
use constant PARTEDP	=> 'print';
use constant SETRA	=> qw (/sbin/blockdev --setra);
use constant DDARGS	=> qw (if=/dev/zero count=1000);

=pod

=head2 %disks

Holds all the disk objects instantiated so far. It is indexed by host name
and Pan path (i.e: host1:/system/blockdevices/disks/sda).

=cut

our %disks;

=pod

=head2 new ($path, $config)

Returns a Disk object. It receives as arguments the path in the
profile for the device and the configuration object.

Only one Disk instance per disk is created. If several partitions use
the same disk (they point to the same path) the same object is
returned.

=cut

sub new
{
    my ($class, $path, $config) = @_;
    # Only one instance per disk is allowed, but disks of different hosts
    # should be separate objects
    my $cache_key = $class->get_cache_key($path, $config);
    $disks{$cache_key} ||= $class->SUPER::new ($path, $config);
    return $disks{$cache_key};
}

=pod

=head2 _initialize

Where the object creation is actually done.

=cut

sub _initialize
{
    my ($self, $path, $config) = @_;
    my $st = $config->getElement($path)->getTree;
    $path =~ m(.*/([^/]+));
    $self->{devname} = unescape ($1);
    $self->{num_spares} = $st->{num_spares};
    $self->{label} = $st->{label};
    $self->{readahead} = $st->{readahead};

    my $hw;
    $hw = $config->getElement(HWPATH . $1)->getTree if $config->elementExists(HWPATH . $1);
    my $host = $config->getElement (HOSTNAME)->getValue;
    my $domain = $config->getElement (DOMAINNAME)->getValue;

    # If the disk is mentioned by the "ignoredisk --drives=..." statement,
    # then partitions/logical volumes/etc. on this disk should also be ignored
    # in the Anaconda configuration (but not in the %pre script)
    if ($config->elementExists(IGNOREDISK)) {
        my $ignore = $config->getElement(IGNOREDISK)->getTree();
        foreach my $dev (@{$ignore}) {
            $self->{_ignore_print_ks} = 1 if $dev eq $self->{devname};
        }
    }

    # It is a bug in the templates if this happens
    $this_app->error("Host $host.$domain: disk $self->{devname} is not defined under " . HWPATH) unless $hw;

    # Inherit the topology from the physical device unless it is explicitely
    # overridden
    $self->_set_alignment($st,
                          ($hw && exists $hw->{alignment}) ? $hw->{alignment} : 0,
                          ($hw && exists $hw->{alignment_offset}) ? $hw->{alignment_offset} : 0);

    $self->{_cache_key} = $self->get_cache_key($path, $config);
    $disks{$self->{_cache_key}} = $self;
    return $self;
}

sub new_from_system
{
    my ($class, $dev, $cfg) = @_;

    my ($devname) = $dev =~ m{/dev/(.*)};

    my $cache_key = $class->get_cache_key("/system/blockdevices/physical_devs/" . $devname, $cfg);
    return $disks{$cache_key} if exists $disks{$cache_key};

    my $self = {devname    => $devname,
                label            => 'none',
                _cache_key    => $cache_key
                };
    return bless ($self, $class);
}


# Returns the number of partitions $self holds.
sub partitions_in_disk
{
    my $self = shift;

    local $ENV{LANG} = 'C';

    my $line =  CAF::Process->new([PARTED, $self->devpath, PARTEDP], log => $this_app)->output();

    my @n = $line=~m/^\s*\d\s/mg;
    unless ($line =~ m/^(?:Disk label type|Partition Table): (\w+)/m) {
        return 0;
    }
    return $1 eq 'loop'? 0:scalar (@n);
}

# Sets the readahead for the device by modifying /etc/rc.local.
#   It does NOT actually set the readahead (SETRA and RCLOCAL are not run/executed.). 
sub set_readahead
{
    my $self = shift;

    my $comment = " # Readahead set by Disk.pm";
    my $re = join (" ", SETRA) . ".*", $self->devpath;
    my $okcmd = join (" ", SETRA, $self->{readahead}, $self->devpath);
    
    my $fh = CAF::FileEditor->open (RCLOCAL, log => $this_app);
                                            
    $fh->add_or_replace_lines ($re,
                               $okcmd,
                               $okcmd.$comment, # append comment
                               ENDING_OF_FILE);
    $fh->close();
}


=pod

=head1 Methods exposed to ncm-filesystems

=head2 create

If the disk has no partitions or filesystems, it creates a new
partition table in the disk. Otherwise, it does nothing.

=head2 disk_empty

Returns true if the disk has no partitions or filesystems in it.

=cut

sub disk_empty
{
    my $self = shift;

    return !($self->partitions_in_disk || $self->has_filesystem);
}

sub create
{
    my $self = shift;
    if ($self->disk_empty) {
        $self->set_readahead if $self->{readahead};
        $self->remove;

        if ($self->{label} ne NOPART) {
            $this_app->debug (5, "Initialising block device ",$self->devpath);
            CAF::Process->new([PARTED, $self->devpath,
                               CREATE, $self->{label}],
                              log => $this_app)->execute();
            sleep (SLEEPTIME);
        }
        else {
            $this_app->debug (5, "Disk ", $self->devpath,": create (zeroing partition table)");
            my $buffout = CAF::Process->new([DD, DDARGS, "of=".$self->devpath], log => $this_app)->output();
            $this_app->debug (5, "dd output:\n", $buffout);
        }
        return $?;
    }
    return 0;
}

=pod

=head2 remove

If there are no partitions on $self, removes the disk instance and
allows the disk to be re-defined.

=cut

sub remove
{
    my $self = shift;
    unless ($self->partitions_in_disk) {
        $this_app->debug (5, "Disk ", $self->devpath,": remove (zeroing partition table)");
        my $buffout = CAF::Process->new([DD, DDARGS, "of=".$self->devpath], log => $this_app)->output();
        $this_app->debug (5, "dd output:\n", $buffout);
        #delete $disks{$self->{_cache_key}};
    }
    return 0;
}

sub devpath
{
    my $self = shift;
    return "/dev/" . $self->{devname};
}

=pod

=head2 devexists

Returns true if the disk exists in the system.

=cut

sub devexists
{
    my $self = shift;
    return (-b $self->devpath);
}

=pod

=head1 Methods exposed to AII

The following methods are for AII use only. They control the
specification of the block device on the Kickstart file.

=head2 should_print_ks

Returns whether block devices on this disk should appear on the
Kickstart file. This is true if the disk has an 'msdos' label.

=cut

sub should_print_ks
{
    my $self = shift;
    return 0 if (exists $self->{_ignore_print_ks} && $self->{_ignore_print_ks});
    return ($self->{label} eq 'msdos' || $self->{label} eq 'gpt');
}

=head2 should_create_ks

Returns whether block devices on this disk should appear on the
%pre script. This is true if the disk has an 'msdos' label.

=cut

sub should_create_ks
{
    my $self = shift;
    return ($self->{label} eq 'msdos' || $self->{label} eq 'gpt');
}

=pod

=head2 print_ks

If the disk must be printed, it prints the related Kickstart commands.

=cut

sub print_ks
{
}

=pod

=head2 clearpart_ks

Prints the Bash code to create a new msdos label on the disk

=cut

sub clearpart_ks
{
    my $self = shift;

    my $path = $self->devpath;

    print <<EOF;
wipe_metadata $path 1

parted $path -s -- mklabel $self->{label}

rereadpt $path

EOF
}

sub del_pre_ks
{
}

1;
