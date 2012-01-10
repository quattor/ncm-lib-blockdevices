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
use NCM::Blockdevices qw ($this_app PART_FILE);
our @ISA = qw (NCM::Blockdevices);

use constant BASEPATH	=> "/system/blockdevices/";
use constant VGS	=> "volume_groups/";

use constant { LVCREATE	=> '/usr/sbin/lvcreate',
	       LVSIZE	=> '-L',
	       LVEXTENTS=> '-l',
	       LVNAME	=> '-n',
	       LVREMOVE	=> '/usr/sbin/lvremove',
	       LVRMARGS	=> '-f',
	       LVDISP	=> '/usr/sbin/lvdisplay',
	       LVSTRIPESZ	=> '--stripesize',
	       LVSTRIPEN=> '--stripes'
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
	$self->{stripe_size} = $st->{stripe_size} if exists $st->{stripe_size};
	# TODO: consider the stripe size when computing the alignment
	$self->_set_alignment($st, $self->{volume_group}->{alignment}, 0);
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

	if ($self->devexists) {
		$this_app->debug (5, "Logical volume ", $self->devpath,
				  " already exists. Leaving");
		return 0;
	}
	$self->{volume_group}->create==0 or return $?;
	if ($self->{size}) {
		$szflag = LVSIZE;
		$sz = $self->{size}
	} else {
		$szflag = LVEXTENTS;
		$sz = $self->{volume_group}->free_extents;
	}
	my @stopt = ();
	if (exists $self->{stripe_size}) {
	    @stopt = (LVSTRIPESZ, $self->{stripe_size},
		      LVSTRIPEN,
		      scalar (@{$self->{volume_group}->{device_list}}));
	}
	execute ([LVCREATE, $szflag, $sz, LVNAME, $self->{devname},
		  $self->{volume_group}->{devname}, @stopt]);
	$this_app->error ("Failed to create logical volume", $self->devpath)
	    if $?;
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
		if ($?) {
			$this_app->error ("Failed to remove logical volume ",
					  $self->devpath);
			return $?;
		}
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

=head2 should_create_ks

Returns whether the logical volume should be defined in the
%pre script.

=cut

sub should_create_ks
{
	my $self = shift;
	return $self->{volume_group}->should_create_ks;
}

=pod

=head2 print_ks

If the logical volume must be printed, it prints the appropriate
kickstart commands.

=cut

sub print_ks
{
	my ($self, $fs, $format, $fstype) = @_;

	return unless $self->should_print_ks;

	$self->{volume_group}->print_ks;

	print join (" ", "\nlogvol", $fs->{mountpoint},
		    "--vgname=$self->{volume_group}->{devname}",
		    "--name=$self->{devname}",
		    "--noformat",
		    "\n");
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
	my $self = shift;
	my $path = $self->devpath;

	return unless $self->should_create_ks;

	my @stopts = ();
	if (exists $self->{stripe_size}) {
	    @stopts = (LVSTRIPESZ, $self->{stripe_size},
		       LVSTRIPEN,
		       scalar (@{$self->{volume_group}->{device_list}}));
	}
	print <<EOC;
if ! lvm lvdisplay $self->{volume_group}->{devname}/$self->{devname} > /dev/null
then
EOC

	$self->{volume_group}->create_ks;
	print <<EOF;
	sed -i '\\:@{[$self->{volume_group}->devpath]}\$:d' @{[PART_FILE]}
EOF
    my $size="-l 95%FREE";
    $size="-L $self->{size}M" if (exists($self->{size})
				  && defined($self->{size})
				  && "$self->{size}" =~ m/\d+/);

	print <<EOC;
	lvm lvcreate -n $self->{devname} \\
	    $self->{volume_group}->{devname} \\
	    $size \\
	    @stopts
        echo @{[$self->devpath]} >> @{[PART_FILE]}

EOC
	print "fi\n";
}

1;
