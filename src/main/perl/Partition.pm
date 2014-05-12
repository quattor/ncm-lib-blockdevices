# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
################################################################################

=pod

=head1 Partition

This class describes a disk partition. It is part of the blockdevices
framework.

The fields available on this class (should be private!) are:

=over 4

=item * size : integer

Partition's size.

=item * offset : integer

Offset to determine the start of partition relative to the previous partition 
or beginning of disk.

=item * devname : string

The name of the blockdevice (sda1).

=item * grow : boolean

Whether the partition should grow to fill the whole disk.

=item * holding_dev : Disk

An object modelling the disk that holds the partition.

=item * begin : real

The exact point where the partition should start.

=back

=cut

package NCM::Partition;

use strict;
use warnings;

use EDG::WP4::CCM::Element qw (unescape);
use EDG::WP4::CCM::Configuration;
use NCM::Blockdevices qw ($this_app PART_FILE);
use CAF::Process;
our @ISA = qw (NCM::Blockdevices Exporter);

our @EXPORT_OK = qw (partition_compare);

use constant {
    PARTED		=> "/sbin/parted",
    CREATE		=> "mkpart",
    DELETE		=> "rm",
    #	TYPE		=> "primary"
};

# Regular expression for checking where the partition begins. The format of a Parted line is:
# <minor> <begin> <end> <size (SL5 only)> <partition type (DOS-labels only)>
use constant BEGIN_RE	=> '^\s*(\d+)\w*\s+(\d+\.?\d+)\w*\s+(\d+\.?\d+)\w*';
use constant BEGIN_TAIL_RE=> '\s+(?:\d+\.?\d+\w*)?\s*(primary|extended|logical)';
use constant MSDOS	=> 'msdos';

# On recent kernels, partitions tend to appear slightly later than
# when they are expected. We'll have to wait a little for this to
# work.
use constant SLEEPTIME => 4;

use constant PARTEDEXTRA => qw (u MiB);
use constant PARTEDARGS	=> qw (-s --);

use constant BASEPATH	=> "/system/blockdevices/";
use constant DISK	=> "physical_devs/";
use constant BLOCKDEV	=> qw (/sbin/blockdev --rereadpt --);
use constant PARTEDP	=> 'print';

# Returns 1 if $a must be created before $b, -1 if $b must be created
# before $a, 0 if it doesn't matter. See bug #26137.
sub partition_compare ($$)
{
    my ($a, $b) = @_;
    $a->devpath =~ m!\D(\d+)$!;
    my $an = $1;
    $b->devpath =~ m!\D(\d+)$!;
    my $bn = $1;
    return $an <=> $bn;
}

=pod

=head2 new_from_system

Creates a partition object from its path on the disk.

=cut

sub new_from_system
{
    my ($class, $dev, $cfg) = @_;

    $dev =~ m{/dev/(.*)};
    my $devname = $1;
    my $disk;
    if ($dev =~ m{(/dev/ciss/c\d+d\+)p\d+}) {
        $disk = $1;
    }
    else {
        $dev =~ m{(/dev/.*\D)\d+$};
        $disk = $1;
    }
    my $self = {devname	=> $devname,
                holding_dev	=> NCM::Disk->new_from_system ($disk, $cfg)
                };
    return bless ($self, $class);
}

=pod

=head2 _initialize ($path, $config)

Creates a new Partition object. It receives as arguments the path in
the profile for the device and the configuration object.

=cut

sub _initialize
{
    my ($self, $path, $config) = @_;
    my $st = $config->getElement($path)->getTree;
    # The block device is indexed by disk name
    $path =~ m!([^/]+)$!;
    # Watch for MEGARAID devices
    $self->{devname} = unescape ($1);
    $self->{size} = $st->{size} if exists $st->{size};
    $self->{type} = $st->{type};
    $self->{offset} = $st->{offset} if exists $st->{offset};
    $self->{holding_dev} = NCM::Disk->new (BASEPATH . DISK .
                                           $st->{holding_dev},
                                           $config);
    $self->_set_alignment($st, 0, 0);
    return $self;
}

=pod

=head2 create

Creates the physical partition. This may involve creating the
partition table on the holding physical device.

Extended partitions are not supported.

=cut

sub create
{
    my $self = shift;

    # Check the device doesn't exist already.
    if ($self->devexists) {
        $this_app->debug (5, "Partition $self->{devname} already exists: ",
                             "leaving");
        return 0
    }

    my $hdname =  "/dev/" . $self->{holding_dev}->{devname};
    $this_app->debug (5, "Partition $self->{devname}: ",
                         "creating holding device ",$hdname );
    my $err = $self->{holding_dev}->create;
    return $err if $err;
    $this_app->debug (5, "Partition $self->{devname}: ",
                         "creating" );
    # TODO: deal with type/name/nothing
    #   type is only type on msdos, becomes name on gpt
    # from the parted guide http://www.gnu.org/software/parted/manual/html_node/mkpart.html
    #   mkpart [part-type fs-type name] start end
    #   ... 
    #   part-type is one of ‘primary’, ‘extended’ or ‘logical’, and may be specified only with ‘msdos’ or ‘dvh’ partition tables. 
    #   A name must be specified for a ‘gpt’ partition table. 
    #   Neither part-type nor name may be used with a ‘sun’ partition table. 
    #
    my @partedcmdlist=(PARTED, PARTEDARGS, $hdname, PARTEDEXTRA, CREATE,
                       $self->{type}, $self->begin, $self->end);
    if ( $self->{holding_dev}->{label} eq "msdos" &&
        $self->{size} >= 2200000 ) {
        $this_app->warn("Partition $self->{devname}: partition larger than 2.2TB defined on msdos partition table");
    }

    $this_app->debug (5, "Calling parted: ", join(" ",@partedcmdlist));
    CAF::Process->new(\@partedcmdlist, log => $this_app)->execute();

    $? && $this_app->error ("Failed to create $self->{devname}");
    sleep (SLEEPTIME);
    return $?;
}

=pod

=head2 remove

Removes the physical partition and asks the holding physical device
for erasing its partition table.

=cut

sub remove
{
    my $self = shift;

    $this_app->debug (5, "Removing $self->{devname}");
    my $num = $self->partition_number;
    $self->{begin} = undef;

    if ($self->devexists) {
        CAF::Process->new([PARTED, PARTEDARGS, $self->{holding_dev}->devpath,
                           PARTEDEXTRA, DELETE, $num],
                           log => $this_app)->execute();
        if ($?) {
            $this_app->error ("Couldn't remove partition ",
                              $self->{devname});
            return $?;
        }
    }
    sleep (SLEEPTIME);
    return $self->{holding_dev}->remove;
}

=pod

=head2 grow

To be done

=cut

sub grow
{
}

=pod

=head2 shrink

To be done

=cut

sub shrink
{
}

=pod

=head2 decide

To be done

=cut

sub decide
{
}

=pod

=head2 devpath

Returns the absolute path in the system to this block device (f.i:
/dev/sda1).

=cut

sub devpath
{
    my $self = shift;
    return "/dev/$self->{devname}";
}

# Returns the point where the partition must start. This is a private
# method. It should work fine with > 10 partitions.
sub begin
{
    my $self = shift;
    return $self->{begin} if (defined $self->{begin});

    # Parse parted's output because SL sucks so badly.
    local $ENV{LANG} = 'C';
    my $npart = $self->partition_number;
    my $out = CAF::Process->new([PARTED, PARTEDARGS, $self->{holding_dev}->devpath,
                                 PARTEDEXTRA, PARTEDP],
                                 log => $this_app)->output();
    my @lines = split /\n/, $out;
    @lines = grep (m{^\s*\d+\s}, @lines);
    my $st = 0;
    my $re = BEGIN_RE;
    
    my $label = $self->{holding_dev}->{label};
    
    $re .= BEGIN_TAIL_RE if $label eq MSDOS;
    # The new partition starts where the previous one ends, except
    # if the previous one is an extended and the new one a logical
    # partition. Then, the new logical partition starts where the
    # extended one starts.
    foreach my $line (@lines) {
        last unless $line =~ m!$re!;
        my ($n, $begin, $end, $type) = ($1, $2, $3, $4);
        if ($npart > $n) {
            if ($label eq MSDOS) {
                # msdos (and dvh too) 
                if ($self->{type} ne 'logical' || $type eq 'logical') {
                    $st = $end;
                }
                else {
                    $st = $begin if $type eq 'extended';
                }
            } else {
                # type-field is used as name field in mkpart
                $st = $end;
            }
        }
        else {
            last;
        }
    }

    $self->{begin} = $st;
    if (exists $self->{offset}) {
        $self->{begin} += $self->{offset};
        $this_app->debug (5, "Partition $self->{devname} offset $self->{offset}",
                             " shifts start from $st to $self->{begin}");
    }
    $this_app->debug (5, "Partition ",$self->{devname}," begins at ", $self->{begin});
    return $self->{begin};
}

# Returns the end point of a partition.
sub end
{
    my $self = shift;
    return exists $self->{size}? $self->{begin} + $self->{size} : '-0';
}

# Returns the number of the partition.
sub partition_number
{
    my $self = shift;
    $self->{devname} =~ m!.*\D(\d+)!;
    return $1;
}

=pod

=head2 devexists

Returns true if the partition exists on the system and false
otherwise.

=cut

sub devexists
{
    my $self = shift;

    local $ENV{LANG} = 'C';
    my $line = CAF::Process->new([PARTED, PARTEDARGS, $self->{holding_dev}->devpath,
                                  PARTEDEXTRA, PARTEDP],
                                  log => $this_app)->output();
    my $n = $self->partition_number;
    return $line =~ m/^\s*$n\s/m &&
        $line !~ m/^(?:Disk label type|Partition Table): loop/m;
}

=pod

=head1 Methods exposed to AII

=head2 should_print_ks

Returns whether the Partition should be printed on the Kickstart. A
partition can be printed only if it is on a disk that an be printed.

=cut

sub should_print_ks
{
    my $self = shift;
    return $self->{holding_dev}->should_print_ks;
}

=pod

=pod

=head2 should_create_ks

Returns whether the Partition should be printed on the %pre script. A
partition can be printed only if it is on a disk that an be printed.

=cut

sub should_create_ks
{
    my $self = shift;
    return $self->{holding_dev}->should_create_ks;
}

=head2 print_ks

If the partition must be printed, it prints the related Kickstart
commands.

Partitions must be printed only if they have a mountpoint associated
with them. Physical volumes and RAID members are defined in the %pre
section.

=cut

sub print_ks
{
    my ($self, $fs) = @_;

    print join (" ",
                "part", $fs->{mountpoint}, "--onpart",
                $self->{devname},
                $self->ksfsformat($fs),
                "\n") if $fs;
}

=pod

=head2 del_pre_ks

Generates the Bash code for removing the partition from the system, if
that's needed.

=cut

sub del_pre_ks
{
    my $self = shift;

    my $n = $self->partition_number;
    my $devpath = $self->{holding_dev}->devpath;

    # Partitions are deleted only if they exist. This will make
    # the partitioning phase much faster.
    print <<EOF;
if grep -q $self->{devname} /proc/partitions
then
    parted $devpath -s rm $n
fi
EOF
}

sub align_ks
{
    my $self = shift;

    return unless $self->should_create_ks;

    my $n = $self->partition_number;
    my $path = $self->devpath;
    my $disk = $self->{holding_dev}->devpath;
    my $align_sect = int($self->{holding_dev}->{alignment} / 512);
    # TODO: add support for alignment_offset

    if ($align_sect > 1) {
        print join(" ", "grep", "-q", "'" . $path . "\$'", PART_FILE, "&&",
                   "align", $disk, $path, $n, $align_sect, "\n");
    }
}

sub create_pre_ks
{
    my $self = shift;

    return unless $self->should_create_ks;

    my $n = $self->partition_number;
    #my $type = substr ($self->{type}, 0, 1);
    my $size = exists $self->{size}? "$self->{size}":'100%';
    my $offset = exists $self->{offset}? $self->{offset} : 0;
    my $path = $self->devpath;
    my $disk = $self->{holding_dev}->devpath;

    # Clear two times the alignment, but at least 1M
    my $align_sect = int($self->{holding_dev}->{alignment} / 512);
    my $clear_mb = int($align_sect / 2 / 1024) * 2;
    $clear_mb = 1 if $clear_mb < 1;

    print <<EOF;
if ! grep -q '$self->{devname}\$' /proc/partitions
then
    echo "Creating partition $self->{devname}"
   
    prev=\`parted $disk -s u MiB p |awk '\$1 == $n-1 {print \$5=="extended" ? \$2:\$3}'\`

    if [ -z \$prev ]
    then
        if [ $offset = 0 ]
        then 
            # The first partition must be aligned to the first MiB (0%)
            begin=1
        else
            begin=$offset
        fi            
    else
        let begin=\${prev/MiB}+$offset
    fi

    if [ $size = '100%'  ] || [ $size = -1 ]
    then
        end=$size
    else
        let end=\${prev/MiB}+$size
    fi
    parted $disk -s  -- u MiB mkpart $self->{type} \$begin \$end

    rereadpt $disk
    if [ $self->{type} != "extended" ]
    then
        wipe_metadata $path $clear_mb
    fi

    echo $path >> @{[PART_FILE]}
fi
EOF

}

1;
