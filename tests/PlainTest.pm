# Test cases for the LXR::Files::Plain module
# Uses the associated lxr.conf file

package PlainTest;
use strict;

use FindBin;

use Test::Unit;
use lib "..";
use lib "../lib";

use LXR::Files;
use LXR::Config;
use LXR::Common;

use base qw(Test::Unit::TestCase);

use vars qw($root);

$root = "$FindBin::Bin/test-src/";

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
	$self->assert(defined($self->{'plain'}), "Failed to create Files::Plain");
	$self->assert($self->{'plain'}->isa("LXR::Files::Plain"), "Not a Plain object");
}

# Access some of the values to check what is found
sub test_root {
	my $self = shift;
	$self->assert($self->{'plain'}->{rootpath} eq $self->{'config'}->{'dir'},
		   "rootpath failed $self->{plain}->{rootpath} $self->{'config'}->{'dir'}");
}

# Test the get_dir function.  Depends on the ctags 5.5.4 release being in place

sub test_getdir {
	my $self = shift;
	my $f = $self->{'plain'};
	
	my @files = sort($f->getdir("/",'5.5.4'));  # use different releases to disambiguate
	my @files2 = sort($f->getdir("", '5.5.4')); # should now produce same result
	$self->assert_deep_equals(\@files, \@files2);
	
	# Check for invalid behaviours
	@files = $f->getdir("/aFile.txt", '5.5.4');
	$self->assert($#files == -1);
	@files = $f->getdir("tests", '5.5.4');
	$self->assert($#files == -1);
	@files = $f->getdir("notthere/", '5.5.4');
	$self->assert($#files == -1);
}

# Test the get_file method.

sub test_getfile {
	my $self = shift;
	my $f = $self->{'plain'};
	
	my $file = $f->getfile("/aFile.txt", '5.5.4');
	local ($/) = undef;
	open FILE, "<". "$root/5.5.4/aFile.txt" || die "Can't open file";
	my $ref = <FILE>;
	$self->assert($file eq $ref, "Files not matching");
}

# set_up and tear_down are used to
# prepare and release resources need for testing

# Prepare a config object
 sub set_up {
	my $self = shift;
	$self->{'plain'} = new LXR::Files("$root");
 	$self->{'config'}->{'dir'} = "$root";
 	}

 sub tear_down {
	my $self = shift;
#	$self->{config} = undef;
 }




1;
