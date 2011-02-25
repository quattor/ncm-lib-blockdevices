# Dummy CAF::Application for use with the tests, so that the actual
# modules have $this_app and can call reporting methods.
package dummyapp;

use strict;
use warnings;
use CAF::Application;

our @ISA = qw (CAF::Application);

sub _initialize
{
	my $self = shift;

	return $self;
}

# No options.
sub app_options
{
	return [];
}
