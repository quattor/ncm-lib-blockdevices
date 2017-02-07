#${PMpre} NCM::HWRaid${PMpost}

=pod

=head1 NAME

NCM::HWRaid

This class defines a hardware RAID set. It is part of the blockdevices
framework.

It operates by parsing hwraidman's output and feeding to it. Please
refer to hwraidtools' documentation for more help.

=head1 LIMITATIONS

This class doesn't support a RAID array spanned on several RAID
controllers.

Only global spares are supported.

=cut

use NCM::Blockdevices qw ($reporter);

use CAF::Process;
use LC::Exception;


use constant VENDOR	=> 0;
use constant CONTROLLER	=> 1;
use constant UNIT	=> 2;
use constant RAIDLEVEL	=> 3;
use constant STRIPESIZE	=> 4;
use constant RAIDSIZE	=> 5;
use constant DISKLIST	=> 6;
use constant OSDISK	=> 7;
use constant RAIDSTATUS	=> 8;
use constant EMPTY	=> '-';
use constant HWRAIDINFO	=> qw (/usr/bin/hwraidman info);
use constant HWRAIDDESTROY => qw (/usr/bin/hwraidman destroy);
use constant HWRAIDCREATE  => qw (/usr/bin/hwraidman create);
use constant HWPATH	=> "/hardware/cards/raid/";
use constant VENDORSTRING => "/vendor";
use constant RAIDPATH	=> "/system/blockdevices/hwraid/";
use constant NODISK	=> EMPTY;
use constant DISKSEP	=> ':';
use constant JOINER	=> ',';

use parent qw(NCM::Blockdevices);
my $ec = LC::Exception::Context->new->will_store_all;

=head2 _initialize ($path, $config, $parent)

Where the object is actually created. This object is expected to be
created only by the Disk class.

It accepts 3 arguments:

=over

=item * C<$path>

The Pan path to the Hardware RAID description

=item * C<$config>

The configuration object.

=item * C<$parent>

The disk object on top of this RAID array.

=back

=cut

sub _initialize
{
    my ($self, $path, $config, $parent, %opts) = @_;

    $self->{log} = $opts{log} || $reporter;

    $path =~ m{^([^/]*)};
    $self->{unit} = $1;
    $self->{unit} =~ tr/_/u/;
    $path = RAIDPATH . $path;

    unless ($config->elementExists ($path)) {
        $self->error ("RAID array on $path doesn't exist");
        return;
    }

    my $t = $config->getElement ($path)->getTree;

    $self->{parent} = $parent;
    my @dl;

    foreach my $dev (@{$t->{device_list}}) {
        unless ($dev =~ m{^raid/_\d+/ports/_(\d+).*}) {
            $self->error ("This device is not a RAID port, leaving");
            return;
        }
        push (@dl, $1);
    }
    @dl = sort (@dl);
    $self->{device_list} = \@dl;
    $self->{level} = $t->{raid_level};
    $self->{level} =~ s{(RAID)(\d+)}{$1-$2};
    $self->{stripe_size} = $t->{stripe_size}? "$t->{stripe_size}K":EMPTY;

    $t->{device_list}->[0] =~ m{^raid/_(\d+)};
    $self->{controller} = "c$1";
    unless ($config->elementExists (HWPATH . "_$1" . VENDORSTRING)) {
        $self->error ("No vendor defined for the RAID controller on ",
                      HWPATH, "_$1", VENDORSTRING, " Leaving");
        return;
    }

    $self->{vendor} = $config->getElement (HWPATH . "_$1" .
                                           VENDORSTRING)->getValue;

    # TODO: compute the alignment from the RAID parameters
    $self->_set_alignment($t, 0, 0);
    return $self;
}

=head2 remove

Public method to remove a RAID array. Actually, it does nothing. Array
destruction is delegated to creation methods, which will destroy the
array in case of mismatch.

=cut

sub remove
{
}

=head2 create

Creates a RAID array on the desired controller. It performs basic
checks the controller is the expected one. If the controller is not
the expected one, the method will fail.

Returns 0 on success, a different value on failure.

=cut

sub create
{
    my $self = shift;

    unless ($self->is_consistent) {
        $self->error ("The RAID status and the profile are inconsistent. ",
                      "Fix your profile or manually adjust your RAID.");
        return -1;
    }

    if ($self->destroy_if_needed == -1) {
        return -1;
    }

    return $self->create_if_needed;
}

=head2 is_consistent

Returns whether the RAID status is the specified on the profile, or
something that can be corrected.

Returns false if the RAID array is fatally different from that on the
profile (i.e: there are no disks for it, or it's on a different
controller).

=cut

sub is_consistent
{
    my $self = shift;
    my ($raid_status, @fields);

    $self->debug (5, "Checking consistency for RAID on controller: ",
                  "$self->{controller}, expected on device ",
                  $self->{parent}->devpath);
    my $proc = CAF::Process->new ([HWRAIDINFO], log => $self);

    $raid_status = $proc->output;
    return 0 if $?;

    if ($raid_status =~ m{$self->{vendor},
        $self->{controller},
        $self->{unit}, .*,
        $self->{parent}->{devname}}xmi) {
        return 1;
    }
    if ($raid_status =~ m{^(.*$self->{parent}->{devname})}m) {
        @fields = split (/,/, $1);
        $self->error ("Wrong vendor specified for unit $self->{unit}")
            if exists $self->{vendor} &&
            $fields[VENDOR] ne (lc $self->{vendor});

        $self->error ("Wrong controller specified for unit $self->{unit}")
            if $fields[CONTROLLER] ne $self->{controller};

        $self->error ("Disk ", $self->{parent}->devpath,
                      " exists, but is associated to a different ",
                      "RAID unit. Expected: $self->{unit}")
            if $fields[UNIT] ne $self->{unit};

        return 0;
    } elsif ($raid_status =~ m{^($self->{vendor},
             $self->{controller},
             $self->{unit}.*)}xmi) {
        @fields = split (/,/, $1);
        if ($fields[OSDISK] ne NODISK) {
            $self->error ("The selected RAID array holds ",
                          "a different device: $fields[OSDISK]");
            return 0;
        }
    }

    # If there are other differences, we can try to fix them.
    return 1;
}

=head2 destroy_if_needed

If the array exists, checks if it has the correct devices, and RAID
properties (level, stripe...). If it has, it does nothing. Otherwise,
the RAID array is destroyed. This method assumes C<is_consistent>
returned true!!!

Returns 0 if succeeds, -1 in case of errors.

=cut

sub destroy_if_needed
{
    my $self = shift;
    my $proc = CAF::Process->new ([HWRAIDINFO], log => $self);

    my $raid_status = $proc->output;
    my @candidates = grep (m{$self->{controller}}, split (/\n/, $raid_status));
    my @l = grep (m{$self->{unit}}, @candidates);
    if (@l) {
        my @fields = split (/,/, $l[0]);
        my @disks = split (/:/, $fields[DISKLIST]);
        if ($disks[0] eq "") {
            shift (@disks);
        }
        if (($fields[RAIDLEVEL] ne $self->{level}) or
            ($fields[STRIPESIZE] ne $self->{stripe_size}) or
            @disks != @{$self->{device_list}}) {
            return $self->do_destroy ($l[0]);
        }
    }
    $self->debug (5, "Didn't have to destroy array $self->{unit}");
    return 0;
}

=head2 do_destroy ($raidinfo)

Destroys an array, defined by the $raidinfo parameter. The $raidinfo
will be fed, as is, to hwraidman.

=cut

sub do_destroy
{
    my ($self, $raidinfo) = @_;
    $self->debug (5, "Must destroy array $self->{unit}");
    my $proc = CAF::Process->new ([HWRAIDDESTROY], log => $self,
                                  stdin => "$raidinfo\n");
    my $err = $proc->execute();
    return $?
}

=head2 create_if_needed

Creates the RAID array, if it doesn't exist. Otherwise, it does
nothing.

Returns 0 if it succeeds, something different in case of errors.

=cut

sub create_if_needed
{
    my $self = shift;
    my $proc = CAF::Process->new ([HWRAIDINFO], log => $self);
    my $raid_status = $proc->output;
    my @raidline;
    return 0 if $raid_status =~ m{$self->{unit}};
    $self->debug (5, "Array $self->{unit} doesn't exist. Creating it.");

    my $disklist = join (DISKSEP, "", @{$self->{device_list}});
    $raidline[VENDOR] = lc ($self->{vendor});
    $raidline[CONTROLLER] = $self->{controller};
    $raidline[UNIT] = $self->{unit};
    $raidline[RAIDLEVEL] = $self->{level};
    $raidline[STRIPESIZE] = $self->{stripe_size};
    $raidline[RAIDSIZE] = EMPTY;
    $raidline[DISKLIST] = $disklist;
    $raidline[OSDISK] = $self->{parent}->{devname};
    $raidline[RAIDSTATUS] = EMPTY;

    $proc = CAF::Process->new ([HWRAIDCREATE], log => $self,
                               stdin => join (JOINER, @raidline) . "\n");
    $proc->execute;
    return $?;
}


1;

