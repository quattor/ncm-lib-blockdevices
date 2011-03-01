# ${license-info}
# ${developer-info
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
use LC::Process qw (execute output);
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

our %disks = ();

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
     my $host = $config->getElement (HOSTNAME)->getValue;
     my $domain = $config->getElement (DOMAINNAME)->getValue;
     my $cache_key = $host . "." . $domain . ":" . $path;
     return $disks{$cache_key} if exists $disks{$cache_key};
     return $class->SUPER::new ($path, $config);
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

     # It is a bug in the templates if this happens
     $this_app->error("Host $host.$domain: disk $self->{devname} is not defined under " . HWPATH) unless $hw;

     # Inherit the topology from the physical device unless it is explicitely
     # overridden
     $self->_set_alignment($st,
	     ($hw && exists $hw->{alignment}) ? $hw->{alignment} : 0,
	     ($hw && exists $hw->{alignment_offset}) ? $hw->{alignment_offset} : 0);

     $self->{cache_key} = $host . "." . $domain . ":" . $path;
     $disks{$self->{cache_key}} = $self;
     return $self;
}

sub new_from_system
{
     my ($class, $dev, $cfg) = @_;

     my ($devname) = $dev =~ m{/dev/(.*)};

     my $host = $cfg->getElement (HOSTNAME)->getValue;
     my $domain = $cfg->getElement (DOMAINNAME)->getValue;
     my $cache_key = $host . "." . $domain . ":/system/blockdevices/physical_devs/" . $devname;
     return $disks{$cache_key} if exists $disks{$cache_key};

     my $self = { devname	=> $devname,
		  label	=> 'none'
		};
     return bless ($self, $class);
}


# Returns the number of partitions $self holds.
sub partitions_in_disk
{
     my $self = shift;

     local $ENV{LANG} = 'C';

     my $line = output (PARTED, $self->devpath, PARTEDP);

     my @n = $line=~m/^\s*\d\s/mg;
     unless ($line =~ m/^(?:Disk label type|Partition Table): (\w+)/m) {
	  return 0;
     } 
     return $1 eq 'loop'? 0:scalar (@n);
}

# Sets the readahead for the device.
sub set_readahead
{
     my $self = shift;

     open (FH, RCLOCAL);
     my @lines = <FH>;
     close (FH);
     chomp (@lines);
     my $re = join (" ", SETRA) . ".*", $self->devpath;
     my $f = 0;
     @lines = map {
	  if (m/$re/) {
	       $f = 1;
	       join (" ", SETRA, $self->{readahead}, $self->devpath);
	  }
	  else {
	       $_;
	  }
     } @lines;
     push (@lines,
	   "# Readahead set by Disk.pm\n",
	   join (" ", SETRA, $self->{readahead}, $self->devpath))
	  unless $f;
     open (FH, ">".RCLOCAL);
     print FH join ("\n", @lines), "\n";
     close (FH);
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
	       my @partedcmdlist=(PARTED, $self->devpath,
				  CREATE, $self->{label});
	       $this_app->debug (5, "Calling parted: ", join(" ",@partedcmdlist));
	       execute (\@partedcmdlist);
	       sleep (SLEEPTIME);
	  }
	  else {
	       my $buffout;
	       $this_app->debug (5, "Disk ", $self->devpath,": create (zeroing partition table)");
	       execute ([DD, DDARGS, "of=".$self->devpath],"stdout" => \$buffout, "stderr" => "stdout");
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
         my $buffout;
         $this_app->debug (5, "Disk ", $self->devpath,": remove (zeroing partition table)");
         execute ([DD, DDARGS, "of=".$self->devpath],"stdout" => \$buffout, "stderr" => "stdout");
         $this_app->debug (5, "dd output:\n ", $buffout);

         delete $disks{$self->{cache_key}};
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
     return $self->{label} eq 'msdos';
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
# Hack for RHEL 6: force re-reading the partition table
rereadpt () {
	sync
	sleep 2
	hdparm -z \$1
}

fdisk $path <<end_of_fdisk
o
w
end_of_fdisk

rereadpt $path

EOF
}

sub del_pre_ks
{
}

1;
