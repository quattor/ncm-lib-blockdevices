# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
################################################################################

=pod

=head1 LV

This class defines a logical volume (LV) for LVM. It is part of the
blockdevices framework.

=cut

package NCM::LV;

use strict;
use warnings;

use EDG::WP4::CCM::Element;
use EDG::WP4::CCM::Configuration;
use LC::Process qw (execute output);
our @ISA = qw (NCM::Blockdevices);

use constant BASEPATH	=> "/software/components/filesystems/blockdevices/";
use constant VGS	=> "volume_groups/";

use constant { LVCREATE	=> '/usr/sbin/lvcreate',
	       LVSIZE	=> '-L',
	       LVEXTENTS=> '-l',
	       LVNAME	=> '-n',
	       LVREMOVE	=> '/usr/sbin/lvremove',
	       LVRMARGS	=> '-f',
	       LVDISP	=> '/usr/sbin/lvdisplay'
       };

=pod

head2 _initialize

Where the object creation is actually done.

=cut

sub _initialize
{
	my ($self, $path, $config) = @_;

	my $st = $config->getElement ($path)->getTree;
	$path =~ m!/([^/]+)$!;
	$self->{devname} = $1;
	$self->{volume_group} = NCM::LVM->new (BASEPATH . VGS .
						    $st->{volume_group},
						    $config);
	$self->{size} = $st->{size};
	return $self;
}

=pod

=head2 new_from_system

Creates a logical volume object from its path on the disk. The device
won't be in the convenient /dev/VG/LV form which is just a symbolik
link, but rather, on the actual /dev/entry, which is
/dev/mapper/VG-LV. This method converts the names to something the
rest of the class can understand.

=cut

sub new_from_system
{
	my ($class, $dev, $cfg) = @_;

	$dev =~ m{(/dev/.*[^-]+)-([^-].*)$};
	my ($vgname, $devname) = ($1, $2);
	$devname =~ s/-{2}/-/g;
	my $vg = NCM::LVM->new_from_system ($vgname, $cfg);
	my $self = { devname		=> $devname,
		     volume_group	=> $vg
		   };
	return bless ($self, $class);
}

=pod

=head2 create

Creates the logical volume on the system. Returns $? (0 if
success). If the logical volume already exists, it returns 0 without
doing anything.

=cut

sub create
{
	my $self = shift;
	my ($szflag, $sz);

	return 0 if $self->devexists;
	$self->{volume_group}->create==0 or return $?;
	$self->{devname}. " ". $self->{volume_group}->{devname};
	if ($self->{size}) {
		$szflag = LVSIZE;
		$sz = $self->{size}
	} else {
		$szflag = LVEXTENTS;
		$sz = $self->{volume_group}->free_extents;
	}
	execute ([LVCREATE, $szflag, $sz, LVNAME, $self->{devname},
		  $self->{volume_group}->{devname}]);
	return $?;
}


=pod

=head2 remove

Removes the logical volume from the system.

=cut

sub remove
{
	my $self = shift;
	if ($self->devexists) {
		execute ([LVREMOVE, LVRMARGS,
			  $self->{volume_group}->devpath."/$self->{devname}"]);
		return $? if $?;
	}
	$self->{volume_group}->remove;
	return 0;
}

=pod

=head2 devexists

Returns true if the device already exists in the system.

=cut

sub devexists
{
	my $self = shift;
	output (LVDISP, "$self->{volume_group}->{devname}/$self->{devname}");
	return !$?;
}

sub devpath
{
	my $self = shift;
	return $self->{volume_group}->devpath . "/" . $self->{devname};
}



=pod

=head1 Methods exposed to AII

=head2 should_print_ks

Returns whether the logical volume should be defined in the
Kickstart. This is, whether the volume group holding the logical
volume should be printed.

=cut

sub should_print_ks
{
	my $self = shift;
	return $self->{volume_group}->should_print_ks;
}

=pod

=head2 print_ks

If the logical volume must be printed, it prints the appropriate
kickstart commands.

=cut

sub print_ks
{
	my ($self, $mountpoint, $format, $fstype) = @_;

	return unless $self->should_print_ks;

	$self->{volume_group}->print_ks;

	print "\nlogvol $mountpoint --vgname=$self->{volume_group}->{devname} ",
	    "--name=$self->{devname} --noformat\n";
}

=pod

=head2 del_pre_ks

Generates teh Bash code for removing the logical volume from the
system, if that's needed.

=cut

sub del_pre_ks
{
	my $self = shift;

	print "lvm lvremove ", $self->{volume_group}->devpath, "/$self->{devname}\n";
	$self->{volume_group}->del_pre_ks;
}

sub create_ks
{
	my ($self, $fstype) = @_;
	my $path = $self->devpath;

	print <<EOC;
if ! lvm lvdisplay $self->{volume_group}->{devname}/$self->{devname} > /dev/null
then
EOC

	$self->{volume_group}->create_ks;

	print <<EOC;
	lvm lvcreate -n $self->{devname} \\
	    $self->{volume_group}->{devname} \\
	    -L $self->{size}M
    mkfs.$fstype $path
fi
EOC
	
}

1;
