# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
################################################################################

package NCM::Filesystem;

use strict;
use warnings;

use EDG::WP4::CCM::Element;
use EDG::WP4::CCM::Configuration;
use LC::Process qw (execute output);
use NCM::BlockdevFactory qw (build build_from_dev);
use FileHandle;

use constant BASEPATH	=> "/software/components/filesystems/blockdevices/";
use constant DISK	=> "physical_devs/";
use constant SED	=> qw (/bin/sed -i);
use constant UMOUNT	=> "/bin/umount";
use constant MOUNT	=> "/bin/mount";
use constant REMOUNT	=> qw (/bin/mount -o remount);
use constant FSTAB	=> "/etc/fstab";
use constant MTAB	=> "/etc/mtab";
use constant GREP	=> qw (/bin/grep -q);
use constant MKFSLABEL	=> '-L';
use constant MKFSFORCE	=> '-f';
use constant SWAPON	=> '/sbin/swapon';
use constant TUNE2FS	=> '/sbin/tune2fs';
use constant TUNEXFS	=> '/usr/sbin/xfs_admin';
use constant REISERTUNE	=> '/usr/sbin/reiserfstune';
use constant TUNECMDS	=> { xfs	=> TUNEXFS,
			     ext2	=> TUNE2FS,
			     ext3	=> TUNE2FS,
			     reiserfs	=> REISERTUNE
			   };
use constant MKFSCMDS	=> { xfs	=> '/sbin/mkfs.xfs',
			     ext2	=> '/sbin/mkfs.ext2',
			     ext3	=> '/sbin/mkfs.ext3',
			     ext4	=> '/sbin/mkfs.ext4',
			     reiserfs	=> '/sbin/mkfs.reiserfs',
			     reiser4	=> '/sbin/mkfs.reiser4',
			     jfs	=> '/sbin/mkfs.jfs',
			     swap	=> '/sbin/mkswap'
			   };
# Use this instead of Perl's built-in mkdir to create everything in
# one go.
use constant MKDIR	=> qw (/bin/mkdir -p);

our @ISA = qw(CAF::Object);

=pod

=head2 new_from_fstab

Creates a filesystem object from its /etc/fstab entry. The filesystem
object is created to remove the filesystem and its block device, so it
is created with "preserve" = 0 and "format = 1. It's a lightweight
version of _initialize.

Arguments: $_[1] the line on /etc/fstab specifying the filesystem.

=cut

sub new_from_fstab
{
    my ($class, $line, $config) = @_;

    $line =~ m{^(\S+)\s+(\S+)\s};
    my ($dev, $mountp) = ($1, $2);
    execute ([MOUNT, $mountp]);

    if ($dev =~ m/^LABEL=/) {
	    open (FH, MTAB);
	    my @mtd = <FH>;
	    close (FH);
	    @mtd = grep (m{^\S+\s+$mountp/?\s}, @mtd);
	    $dev = $mtd[0];
	    $dev =~ s{^(\S+)\s.*}{$1};
    }
    my $bd = build_from_dev ($dev, $config);
    my $self = { preserve	=> 0,
		 format		=> 1,
		 block_device	=> $bd,
		 mountpoint	=> $mountp
	       };
    return bless ($self, $class);
}

sub _initialize
{
	my ($self, $path, $config) = @_;
	my $st = $config->getElement($path)->getTree;

	while (my ($key, $val) = each (%$st)) {
		$self->{$key} = $val;
	}

	$self->{block_device} = build ($config, $self->{block_device});
	return $self;
}

=pod

=head2 mounted

Returns whether the filesystem is mounted

=cut

sub mounted
{
	my $self = shift;
	execute ([GREP, $self->{mountpoint}, MTAB]);
	return !$?;
}

=pod

=head2 remove_if_needed

If the filesystems' preserve tag is false, unmount it and destroy the
block device it uses. Do nothing if preserve is true.

=cut


sub remove_if_needed
{
	my $self = shift;

	return 0 if $self->{preserve} || !$self->{format};
	if ($self->mounted) {
		execute ([UMOUNT, $self->{mountpoint}]);
		return $? if $?;
	}
	$self->{block_device}->remove==0 or return $?;
	execute ([SED, "\\:$self->{mountpoint}\\s:d", FSTAB]);
	return $?;
}

# Updates the fstab entry for a filesystem.
sub update_fstab
{
	my $self = shift;
	execute ([SED, "\\:$self->{mountpoint}\\s:d", FSTAB]);
	my $fh = FileHandle->new ("/etc/fstab", "a");
	print $fh join (" ",
			(exists $self->{label}?
			 "LABEL=$self->{label}":
			 $self->{block_device}->devpath),
			$self->{mountpoint},
			$self->{type},
			$self->{mountopts} .
			((!$self->{mount} || $self->{type} eq 'none')?",noauto":""),
			$self->{freq},
			$self->{pass}), "\n";
	$fh->close;
}

=pod

=head2 format

Formats the filesystem, unconditionatlly.

=cut

sub formatfs
{
	my $self = shift;
	my $tunecmd;
	my @opts = exists $self->{label} ? (MKFSLABEL, $self->{label}):();
	push (@opts, split ('\s+', $self->{mkfsopts})) if exists $self->{mkfsopts};
	push (@opts, MKFSFORCE) if ($self->{type} eq 'xfs');

	my $tcms = TUNECMDS;
	$tunecmd = $$tcms{$self->{type}};

	$? = 0;
	if ($self->{type} ne 'none') {
		execute ([MKFSCMDS->{$self->{type}}, @opts,
			  $self->{block_device}->devpath]);
		return $? if $?;
		execute ([$tunecmd, split ('\s+', $self->{tuneopts}),
			  $self->{block_device}->devpath])
		    if exists $self->{tuneopts} && defined $tunecmd;
	}
	return $?;
}

=pod

=head2 create_if_needed

Creates the filesystem, if it doesn't exist yet.

It does nothing if the filesystem already exists.

=cut

sub create_if_needed
{
	my $self = shift;

	# The filesystem already exists. Update its fstab.
	execute ([GREP, "[^#]*$self->{mountpoint}"."[[:space:]]", FSTAB]);
	if (!$?) {
		$self->update_fstab;
		execute ([REMOUNT, $self->{mountpoint}])
		    if $self->{type} ne 'none' && $self->{mount};
		return 0;
	}

	# The filesystem doesn't exist. Create it and add it to fstab.
	$self->{block_device}->create && return $?;
	$self->formatfs && return $?;
	execute ([MKDIR, $self->{mountpoint}]);
	return $? if $?;
	$self->update_fstab;
	if ($self->{mount}) {
		if ($self->{type} eq 'swap') {
			execute ([SWAPON, $self->{block_device}->devpath]);
		} else {
			execute ([MOUNT, $self->{mountpoint}]);
		}
	}
	return 0;
}

=pod

=head2 format_if_needed

If the filesystem's format tag is true, it formats (mkfs.) it
appropiately.

=cut

sub format_if_needed
{
	my $self = shift;
	$self->{format} && $self->{type} ne 'none' or return 0;
	my $r;
	execute ([UMOUNT, $self->{mountpoint}]);

	$r = $self->formatfs;
	execute ([MOUNT, $self->{mountpoint}]) if $self->{mount};
	return $r;
}

=pod

=head2 should_print_ks

Returns whether the filesystem should be defined at the Kickstart.

=cut

sub should_print_ks
{
	my $self = shift;
	
	$self->{should_print_ks} = $self->{block_device}->should_print_ks?1:0
	    unless exists ($self->{should_print_ks});

	return $self->{should_print_ks};
}

sub print_ks
{
	my $self = shift;

	$self->{block_device}->print_ks ($self->{mountpoint})
	    if $self->should_print_ks;
}

sub del_pre_ks
{
	my $self = shift;
	
	$self->{block_device}->del_pre_ks
	    unless $self->{preserve};
}

sub create_ks
{
	my $self = shift;

	return unless $self->should_print_ks;

	$self->{block_device}->create_ks ($self->{type});
}

sub format_ks
{
	my $self = shift;

	return unless $self->should_print_ks;
	if ($self->{format}) {
		if ($self->{type} eq 'swap') {
			print "mkswap ",
			    $self->{block_device}->devpath, "\n";
		} else {
			print MKFSCMDS->{$self->{type}},
			    $self->{block_device}->devpath, "\n";
			if (exists $self->{tuneopts}) {
				my $h = TUNECMDS;
				print "$h->{$self->{type}} $self->{tuneopts}\n";
			}
		}
	}
}


1;
