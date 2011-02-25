# ${license-info}
# ${developer-info
# ${author-info}
# ${build-info}
################################################################################

package NCM::Blockdevices;

use strict;
use warnings;

use EDG::WP4::CCM::Element;
use EDG::WP4::CCM::Configuration;
use CAF::Object;

our @ISA = qw/CAF::Object/;

sub _initialize
{
	return $_[0];
}

sub unescape
{
	my ($self,$str)=@_;
	$str =~ s!(_[0-9a-f]{2})!sprintf("%c",hex($1))!eg;
	return $str;
}


sub create
{
	my $self = shift;
	$self->error ("create method not defined for this class");
}

sub remove
{
	my $self = shift;
	$self->error ("remove method not defined for this class");

}

sub grow
{
	my $self = shift;
	$self->error ("grow method not defined for this class");

}

sub shrink
{
	my $self = shift;
	$self->error ("shrink method not defined for this class");

}

sub decide
{
	my $self = shift;
	$self->error ("decide method not defined for this class");
}

sub devexists
{
	my $self = shift;
	$self->error ("devexists method not defined for this class");
}

sub should_print_ks
{
	my $self = shift;
	$self->error ("should_print method not defined for this class");
}

sub print_ks
{}

sub print_pre_ks
{}

sub del_pre_ks
{}

sub create_ks
{
}

1;
