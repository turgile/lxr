# Test cases for the various security exploits.
# 
# Uses the associated lxr.conf file

package SecurityTest;
use strict;

use Test::Unit;
use lib "..";
use lib "../lib";

use LXR::Files;
use LXR::Config;
use LXR::Common qw(:html);
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
sub test_fixpaths {
	my $self = shift;

	$ENV{'SERVER_NAME'} = 'test';
	$ENV{'SERVER_PORT'} = 80;
	$ENV{'SCRIPT_NAME'} = '/lxr/source';
	$ENV{'PATH_INFO'} = '/a/test/path';

	# Need to preserve signal handlers round call to httpinit as
	# it sets up the LXR signal handlers.
	
	my $die = $SIG{'__DIE__'};
	my $warn = $SIG{'__WARN__'};
	
	httpinit;
	my $node = "/../test/..//abit/./../././../........././";
	$node = LXR::Common::fixpaths($node);
	
	$SIG{'__DIE__'} = $die;
	$SIG{'__WARN__'} = $warn;
	
	$self->assert($node eq '/abit/./........././', "fixpaths is $node");	
}

sub test_version_path_exploit {
	# Check that the version string is properly scrubbed
	# Should only be able to set version to the values
	# defined in lxr.conf
	my $self = shift;

	$ENV{'SERVER_NAME'} = 'test';
	$ENV{'SERVER_PORT'} = 80;
	$ENV{'SCRIPT_NAME'} = '/lxr/source';
	$ENV{'PATH_INFO'} = '/a/test/path';
	$ENV{'QUERY_STRING'} = 'v=../../;virtroot=testpath;dbname=notapath';

	# Need to preserve signal handlers round call to httpinit as
	# it sets up the LXR signal handlers.
	
	my $die = $SIG{'__DIE__'};
	my $warn = $SIG{'__WARN__'};
	
	httpinit;
	
	$SIG{'__DIE__'} = $die;
	$SIG{'__WARN__'} = $warn;

	$self->assert($release eq '1.0.6', '$release not washed');
	$self->assert($config->variable('v') eq '1.0.6', '$config->variable(v) not washed');	
	
	$ENV{'QUERY_STRING'} = '?v=hi%20hippy/../..;file=/some/path;version=../..';
	$die = $SIG{'__DIE__'};
	$warn = $SIG{'__WARN__'};
	
	httpinit;
	
	$SIG{'__DIE__'} = $die;
	$SIG{'__WARN__'} = $warn;
	$self->assert($release eq '1.0.6', '$release not washed');
	$self->assert($config->variable('v') eq $release, '$release not washed');

	$ENV{'QUERY_STRING'} = '?version=hi../..';
	$die = $SIG{'__DIE__'};
	$warn = $SIG{'__WARN__'};
	
	httpinit;
	
	$SIG{'__DIE__'} = $die;
	$SIG{'__WARN__'} = $warn;
	$self->assert($release eq '1.0.6', "release not washed, was $release");
	$self->assert($config->variable('v') eq $release, "release not washed, was $release");

}

sub test_filename_wash {
	# Check that filenames are washed
	my $self = shift;

	$ENV{'SERVER_NAME'} = 'test';
	$ENV{'SERVER_PORT'} = 80;
	$ENV{'SCRIPT_NAME'} = '/lxr/source';
	$ENV{'PATH_INFO'} = '/a/test/path/../../../';
	$ENV{'QUERY_STRING'} = 'v=../../;virtroot=testpath;dbname=notapath';

	# Need to preserve signal handlers round call to httpinit as
	# it sets up the LXR signal handlers.
	
	my $die = $SIG{'__DIE__'};
	my $warn = $SIG{'__WARN__'};
	
	httpinit;
	
	$SIG{'__DIE__'} = $die;
	$SIG{'__WARN__'} = $warn;

	$self->assert($pathname eq '/a/test/path/', "pathname not washed, got $pathname");
	
	$ENV{'PATH_INFO'} = '';
	$ENV{'QUERY_STRING'} = 'file=/a/test/path++many';
	$die = $SIG{'__DIE__'};
	$warn = $SIG{'__WARN__'};
	httpinit;
	$SIG{'__DIE__'} = $die;
	$SIG{'__WARN__'} = $warn;
	$self->assert($pathname eq '/a/test/path++many', "pathname not washed, got $pathname");

	$ENV{'PATH_INFO'} = '/../.././.././a/test/path+!/some/%chars,v';
	$ENV{'QUERY_STRING'} = '';
	$die = $SIG{'__DIE__'};
	$warn = $SIG{'__WARN__'};
	httpinit;
	$SIG{'__DIE__'} = $die;
	$SIG{'__WARN__'} = $warn;
	$self->assert($pathname eq '/a/test/path+!/some/%chars,v', "pathname not washed, got $pathname");
	
}

sub test_filename_compat {
	# Checking for ability to deal with ++ in the filename
	my $self = shift;

	$ENV{'SERVER_NAME'} = 'test';
	$ENV{'SERVER_PORT'} = 80;
	$ENV{'SCRIPT_NAME'} = '/lxr/source';
	$ENV{'PATH_INFO'} = '/a/test/file++name';
	$ENV{'QUERY_STRING'} = '';

	# Need to preserve signal handlers round call to httpinit as
	# it sets up the LXR signal handlers.
	
	my $die = $SIG{'__DIE__'};
	my $warn = $SIG{'__WARN__'};
	
	httpinit;
	
	$SIG{'__DIE__'} = $die;
	$SIG{'__WARN__'} = $warn;

	$self->assert($pathname eq '/a/test/file++name', "pathname corrupted, got $pathname");
}
	

sub test_config {
	# Check that parameters in URL cannot alter config variables
	
	my $self = shift;

	$ENV{'SERVER_NAME'} = 'test';
	$ENV{'SERVER_PORT'} = 80;
	$ENV{'SCRIPT_NAME'} = '/lxr/source';
	$ENV{'PATH_INFO'} = '/a/test/path';
	$ENV{'QUERY_STRING'} = 'v=../../;virtroot=testpath;dbname=notapath';

	# Need to preserve signal handlers round call to httpinit as
	# it sets up the LXR signal handlers.
	
	my $die = $SIG{'__DIE__'};
	my $warn = $SIG{'__WARN__'};
	
	httpinit;
	
	$SIG{'__DIE__'} = $die;
	$SIG{'__WARN__'} = $warn;
	$self->assert($config->{'dbname'} ne 'notapath', 'dbname messed');
	$self->assert($config->{'virtroot'} eq '/lxr', 'virtroot set');
}	
1;
