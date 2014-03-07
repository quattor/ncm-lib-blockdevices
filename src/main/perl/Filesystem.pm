# ${license-info}
# ${developer-info}
# ${author-info}
# ${build-info}
################################################################################

package NCM::Filesystem;

use strict;
use warnings;

use EDG::WP4::CCM::Element;
use EDG::WP4::CCM::Configuration;
use CAF::Process;
use CAF::FileEditor;
use NCM::Blockdevices qw ($this_app PART_FILE);
use NCM::BlockdevFactory qw (build build_from_dev);
use FileHandle;
use File::Basename;
use File::Path;
use Fcntl qw(SEEK_END);
use Cwd qw(abs_path);

use constant MOUNTPOINTPERMS => 0755;
use constant BASEPATH	=> "/system/blockdevices/";
use constant DISK	=> "physical_devs/";
use constant UMOUNT	=> "/bin/umount";
use constant MOUNT	=> "/bin/mount";
use constant REMOUNT	=> qw (/bin/mount -o remount);
use constant FSTAB	=> "/etc/fstab";
use constant MTAB	=> "/etc/mtab";
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
                 swap	=> '/sbin/mkswap',
                 tmpfs	=> '/bin/true',
               };
# Use this instead of Perl's built-in mkdir to create everything in
# one go.
#use constant MKDIR	=> qw (/bin/mkdir -p);

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
    my $p = CAF::Process->new ([MOUNT, $mountp],
                               log => $this_app)->run();

    if ($dev =~ m/^(LABEL|UUID)=/) {
        my $fh = CAF::FileEditor->new(MTAB, log => $this_app);
        my @mtd = grep (m{^\S+\s+$mountp/?\s}, split("\n", "$fh"));
        $fh->close();
        $dev = $mtd[0];
        $dev =~ s{^(\S+)\s.*}{$1};
    }
    my $bd = build_from_dev ($dev, $config);
    my $self = {preserve    => 0,
                format        => 1,
                block_device    => $bd,
                mountpoint    => $mountp
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
    my $fh = CAF::FileEditor->new(MTAB, log => $this_app);
    return $fh =~ m!^\S+\s+$self->{mountpoint}/?\s!m;
}

=pod

=head2 remove_if_needed

If the filesystems' preserve tag is false, unmount it and destroy the
block device it uses. Do nothing if preserve is true.

=cut

sub remove_if_needed
{
    my $self = shift;

    if ($self->{preserve} || !$self->{format}) {
        $this_app->debug (5, "Filesystem ", $self->{mountpoint},
              " shouldn't be destroyed according to profile.");
        return 0;
    }
    $this_app->info ("Destroying filesystem on $self->{mountpoint}");
    if ($self->mounted) {
        CAF::Process->new ([UMOUNT, $self->{mountpoint}],
                  log => $this_app)->run();
        return $? if $?;
    }
    $self->{block_device}->remove==0 or return $?;
    my $fh = CAF::FileEditor->new (FSTAB, log => $this_app);
    $fh->remove_lines(qr/\s$self->{mountpoint}\s/, qr/^$/); # goodre ^$ (empty string) should never match  
    $fh->close();
    $this_app->debug (5, "Removing filesystem mountpoint", $self->{mountpoint});
    rmdir ($self->{mountpoint});
    return $?;
}

# Updates the fstab entry for the $self filesystem. Optionally, the
# handle to the fstab CAF::FileEditor handle can be passed as an
# argument
sub update_fstab
{
    my ($self, $fh) = @_;
    $fh = CAF::FileEditor->new (FSTAB, log => $this_app) unless $fh;
    my $re = qr!^\s*[^#]\S+\s+$self->{mountpoint}/?\s!m;
    my $entry = join ("\t",
                        (exists $self->{label}?
                            "LABEL=$self->{label}":
                            $self->{block_device}->devpath),
                        $self->{mountpoint},
                        $self->{type},
                        $self->{mountopts} .
                            (!$self->{mount} ? ",noauto":""),
                            $self->{freq},
                        $self->{pass});
    $fh->add_or_replace_lines ($re,
                               $entry,
                               $entry,
                               ENDING_OF_FILE);
}

=pod

=head2 format

Formats the filesystem, if the blockdevice has no supported filesystem or 
if force_filesystem is true.

=cut

sub formatfs
{
    my $self = shift;
    my $tunecmd;
    my @opts = exists $self->{label} ? (MKFSLABEL, $self->{label}):();
    push (@opts, split ('\s+', $self->{mkfsopts})) if exists $self->{mkfsopts};
    push (@opts, MKFSFORCE) if ($self->{type} eq 'xfs');

    $tunecmd =  TUNECMDS()->{$self->{type}};

    $? = 0;

    # Format only if there must be a filesystem. After a
    # re-install, it can happen that $self->{format} is false and
    # the block device has a filesystem. Don't destroy the data.
    my $has_filesystem = 1;
    if ($self->{type} eq 'none') {
        $this_app->debug(3, "type 'none', no format.");
        $has_filesystem = 1;
    } elsif(defined($self->{force_filesystemtype}) && $self->{force_filesystemtype}) {
        $has_filesystem = $self->{block_device}->has_filesystem($self->{type});
        $this_app->debug(3, "force_filesystemtype with type $self->{type}",
                            " has_filesystem $has_filesystem");
    } else {
        $has_filesystem = $self->{block_device}->has_filesystem;
        $this_app->debug(3, "any supported filesystem",
                            " has_filesystem $has_filesystem");
    };
    
    if (!$has_filesystem) {
        $this_app->debug (5, "Formatting to get $self->{mountpoint}");
        CAF::Process->new ([MKFSCMDS->{$self->{type}}, @opts,
                            $self->{block_device}->devpath],
                            log => $this_app)->run();
        return $? if $?;
        CAF::Process->new ([$tunecmd, split ('\s+', $self->{tuneopts}),
                            $self->{block_device}->devpath],
                            log => $this_app)->run()
                if exists $self->{tuneopts} && defined $tunecmd;
    }
    return $?;
}

=pod

=head2 mkmountpoint

Creates the directory given as an argument. Return 0 in case of
success, -1 in case of error.

=cut

sub mkmountpoint
{
    my $mp = shift;
    eval { mkpath ([$mp], 0, MOUNTPOINTPERMS) };
    if ($@) {
        $this_app->error ("Failed to create mount point $mp: $@");
        return -1;
    }
    return 0;
}

=pod

=head2 mountpoint_in_fstab

Returns the number of valid (i.e. mountable) entries in /etc/fstab 

=cut

sub mountpoint_in_fstab
{
    my $self = shift;

    my $fh = CAF::FileEditor->new(FSTAB, log => $this_app);
    return $fh =~ m!^\s*[^#]\S+\s+$self->{mountpoint}/?\s!m;
}

=pod

=head2 is_create_needed

Test if fs->blockdev->create is needed 

=cut

sub is_create_needed
{
    my $self = shift;

    my $ret=1; # default: create is needed
    my $msg = 'Default create is needed.';
    
    if($self->mounted()) {
        $msg="Filesystem MOUNTED";
        $ret=0;
    } elsif(defined($self->{force_filesystemtype}) && $self->{force_filesystemtype}) {
        # fstab might contain previous and possibly different filesystem type
        $msg="force_filesystemtype: ingore if mountpoint exists in ".FSTAB;
    } elsif ($self->mountpoint_in_fstab) {
        # this only checks presence of mountpoint in fstab file, not filesystemtype
        $msg="Mountpoint $self->{mountpoint} already exists in ".FSTAB;
        $ret=0;
    }

    $this_app->debug (5, "Filesystem mountpoint $self->{mountpoint}",
                      " is_create_needed $ret: $msg");
    
    return $ret;
}

=pod

=head2 create_if_needed

Creates the filesystem, if it doesn't exist yet.

It does nothing if the filesystem already exists.

=cut

sub create_if_needed
{
    my $self = shift;

    $this_app->debug (5, "Filesystem mountpoint $self->{mountpoint}",
                      " blockdev ", $self->{block_device}->devpath);

    if($self->is_create_needed) {
        $self->{block_device}->create && return $?;
        $self->formatfs && return $?;
        $this_app->info("Filesystem on $self->{mountpoint} successfully created");
    };
    return 0;
}

=pod

=head2 can_be_formatted

Returns true if the filesystem can be formatted. Currently, an
existing filesystem cannot be re-formatted. We never had the real need
to re-format anything from inside the component, and some users kept
making mistakes with this.

=cut

sub can_be_formatted
{
    return 0;
}

=pod

=head2 format_if_needed

If the filesystem's format tag is true, it formats (mkfs.) it
appropiately.

It accepts a hash with the protected mounts that shouldn't be
formatted in case they exist already. The keys should be the canonical
form of the mount points, otherwise it may be unsafe. I assume this
piece will be called by ncm-filesystems, and thus it is safe.

=cut

sub format_if_needed
{
    my ($self, %protected) = @_;
    $self->can_be_formatted(%protected) or return 0;
    my $r;
    CAF::Process->new ([UMOUNT, $self->{mountpoint}], log => $this_app)->run();
    $r = $self->formatfs;
    CAF::Process->new ([MOUNT, $self->{mountpoint}], log => $this_app)->run()
        if $self->{mount};
    return $r;
}

=pod

=head2 should_print_ks

Returns whether the filesystem should be defined at the Kickstart.

=cut

sub should_print_ks
{
    my $self = shift;

    $self->{should_print_ks} = $self->{block_device}->should_print_ks ? 1 : 0
    unless exists ($self->{should_print_ks});

    return $self->{should_print_ks};
}

=pod

=head2 should_create_ks

Returns whether the filesystem should be defined at the %pre script.

=cut

sub should_create_ks
{
    my $self = shift;

    $self->{should_create_ks} = $self->{block_device}->should_create_ks ? 1 : 0
    unless exists ($self->{should_create_ks});

    return $self->{should_create_ks};
}

=pod

=head2 print_ks

Prints the Anaconda directives on the Kickstart so that the file
system is mounted on the correct place.

=cut

sub print_ks
{
    my $self = shift;

    $self->{block_device}->print_ks ($self)
        if $self->{mount} && $self->should_print_ks;
}

=pod

=head2 del_pre_ks

If the FS is not marked to be kept, it prints the Bash code for
destroying it as well as its underlying block devices. To be used
during the %pre phase of the KS.

=cut

sub del_pre_ks
{
    my $self = shift;

    $self->{block_device}->del_pre_ks
        unless $self->{preserve} || !$self->{format};
}

=pod

=head2 create_ks

Prints the Bash code so that the block devices associated with the FS
get created. To be used during the %pre phase of the KS.

=cut

sub create_ks
{
    my $self = shift;

    return unless $self->should_create_ks;

    $self->{block_device}->create_ks;
}

=pod

=head2 format_ks

If the file system is to be listed on the KS and formatted, prints the
Bash code so that the block device on which the FS resides gets
formatted. To be used during the %pre phase.

=cut

sub format_ks
{
    my $self = shift;

    return unless $self->should_create_ks;
    print join (" ", "grep", "-q", "'" . $self->{block_device}->devpath . "\$'",
            PART_FILE, "&&", "")
        unless $self->{format};
    $self->do_format_ks;

    if (exists $self->{tuneopts}) {
        my $h = TUNECMDS;
        print "$h->{$self->{type}} $self->{tuneopts}\n";
    }
}

=pod

head2 do_format_ks

Prints, unconditionally, the bash code to format the block device on
which the FS resides. To be used B<only> by ncm-lib-blockdevices,
calling code should use format_fs. To be used during the %pre phase.

=cut

sub do_format_ks
{
    my $self = shift;

    # Extract the absolute path to make it work on different SL versions.
    if (exists (MKFSCMDS->{$self->{type}})) {
    my $mkfs = basename (MKFSCMDS->{$self->{type}});
    print join (' ', $mkfs,
                $self->{block_device}->devpath,
                exists ($self->{label}) ? (MKFSLABEL, $self->{label}) : (),
                exists ($self->{mkfsopts})? $self->{mkfsopts}:())
          , "\n";
    }
}

1;
