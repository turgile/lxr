# Test cases for the LXR::Files::CVS module
# Uses the associated lxr.conf file

package CVSTest;
use strict;

use Test::Unit;
use lib "..";
use lib "../lib";

use LXR::Files;
use LXR::Config;
use LXR::Common;
use Cwd;
use File::Spec;

use base qw(Test::Unit::TestCase);

use vars qw($root);

$config = new LXR::Config("http://test/lxr", "./lxr.conf");

sub new {
	my $self = shift()->SUPER::new(@_);
#	$self->{config} = {};
	return $self;
}

# define tests

# test that a files object can be created
sub test_creation {
	my $self = shift;
	$self->assert(defined($self->{'cvs'}), "Failed to create Files::CVS");
	$self->assert($self->{'cvs'}->isa("LXR::Files::CVS"), "Not a CVS object");
}

# Access some of the values to check what is found
sub test_root {
	my $self = shift;
	$self->assert($self->{'cvs'}->{rootpath} eq $self->{'config'}->{'dir'},
		   "rootpath failed $self->{cvs}->{rootpath} $self->{'config'}->{'dir'}");
}

# Test for failure when co is not found on path
# Bug [ 1111786 ] Failure to open file not detected

sub test_no_co_bug_1111786 {
	my $self =shift;
	
	$self->{'cvs'}->{'path'} = '';
	my $t;
	my $ret = eval($t = $self->{'cvs'}->getfilehandle('tests/CVSTest.pm','release'));
	$self->assert(!defined($ret) or !defined($t), 'Getfilehandle should die');
	
}

# set_up and tear_down are used to
# prepare and release resources need for testing

# Prepare a CVS object
 sub set_up {
	my $self = shift;
	my $dir = getcwd;
	$dir = File::Spec->updir($dir);
	
	$self->{'cvs'} = new LXR::Files("cvs:$dir");
 	$self->{'config'}->{'dir'} = "$dir/";
 	}

 sub tear_down {
	my $self = shift;
#	$self->{config} = undef;
 }




1;
