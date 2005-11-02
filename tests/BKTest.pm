# Test cases for the LXR::Files::BK module
# Uses the associated lxr.conf file

package BKTest;
use strict;

use Test::Unit;
use Cwd;
use Time::Local;
use lib "..";
use lib "../lib";

use LXR::Files;

use base qw(Test::Unit::TestCase);

use vars qw($bkpath $bkrefdir $bkcache	);

$bkpath   = getcwd() . "/bk-test-repository";
$bkrefdir = getcwd() . "/bk-reference-files/";
$bkcache  = getcwd() . "/bk-cache-dir";

sub new {
	my $self = shift()->SUPER::new(@_);

	#	$self->{config} = {};
	return $self;
}

# define tests

# test that a bk files object can be created
sub test_creation {
	my $self = shift;
	$self->assert(defined($self->{'bk'}), "Failed to create Files::BK");
	$self->assert($self->{'bk'}->isa("LXR::Files::BK"), "Not a BK object");
	$self->assert($self->{'bk'}->{'cache'} eq $bkcache);
}

# Access some of the values to check what is found
sub test_root {
	my $self = shift;
	$self->assert(
		$self->{'bk'}->{rootpath} eq $self->{'config'}->{'dir'},
		"rootpath failed $self->{bk}->{rootpath} $self->{'config'}->{'dir'}"
	);
}

# Test the getdir function

package LXR::Files::BK::Test;
use LXR::Files::BK;

use vars qw(@ISA);

@ISA = ("LXR::Files::BK");

sub new {
	my ($proto, $rootpath) = @_;
	my $class = ref($proto) || $proto;
	my $self  = $class->SUPER::new($rootpath, {'cachepath' => ''});

	bless($self, $class);
	return $self;
}

sub set_tree {
	my ($self) = shift;
	$self->{tree} = \@_;
}

sub get_tree {
	my ($self) = shift;
	return @{ $self->{'tree'} };
}

1;

package BKTest;

# Test the tree building & caching for the getdir function.
#  Uses the BK::Test module to stub out real BK commands
#  so entire operation carried out on virtual trees

sub test_getdir_part1 {
	my $self = shift;
	my $bk   = new LXR::Files::BK::Test("/");
	$bk->set_tree("README|README|1.1", "src/file1|src/file1|1.1",
		"src/file2|src/file2|1.1",
		"src/tests/newtest/test1|src/tests/newtest/test1|1.3");

	my @files =
	  sort($bk->getdir("/", 'test1'));  # use different releases to disambiguate
	$self->assert_deep_equals(\@files, [ sort "README", "src/" ]);
	@files = sort ($bk->getdir("", 'test1'));  # Check that interprets "" as "/"
	$self->assert_deep_equals(\@files, [ sort "README", "src/" ]);
	@files = sort($bk->getdir("src/", 'test1'));
	$self->assert_deep_equals(\@files, [ sort "file1", "file2", "tests/" ]);
	@files = sort($bk->getdir("src/tests/newtest/", 'test1'));
	$self->assert_deep_equals(\@files, [ sort "test1" ]);
	@files = sort($bk->getdir("src/tests/", 'test1'));
	$self->assert_deep_equals(\@files, [ sort "newtest/" ]);
	@files = sort($bk->getdir("src/tests/newtest/", 'test1'));
	$self->assert_deep_equals(\@files, [ sort "test1" ]);

	$bk->set_tree(
		"BitKeeper/deleted/.del-README-34243232432|README|1.2",
		"src/file1|src/file1|1.2",
		"src/file2|src/file2|1.2",
		"src/tests/newtest/test1|src/tests/newtest/test1|1.2",
		"src/tests/newtest/test2|src/tests/newtest/test2|1.2",
		"Config|Config|1.2"
	);
	@files =
	  sort($bk->getdir("src/tests/newtest/", 'test1')); # Check cache is working
	$self->assert_deep_equals(\@files, ["test1"]);
	@files =
	  sort($bk->getdir("src/tests/newtest/", 'test2'))
	  ;    # Should pick up new entry
	$self->assert_deep_equals(\@files, [ "test1", "test2" ]);
	@files =
	  sort($bk->getdir("src/tests/", 'test2'))
	  ;    # Should still only see one copy of dir
	$self->assert_deep_equals(\@files, ["newtest/"]);
	@files =
	  sort($bk->getdir("src/tests/newtest/", 'test1'))
	  ;    # Check cache is still ok
	$self->assert_deep_equals(\@files, ["test1"]);

	# Now tests with invalid paths on entry
	@files = sort($bk->getdir("src/tests", 'test2'));
	$self->assert($#files == -1);
}

# Test the get_tree function and ensure it is giving the right answers
sub test_get_tree {
	my $self = shift;
	my $bk   = $self->{'bk'};

	my @versions = (1.5, 1.7, 1.6, 1.8);
	foreach (@versions) {
		my @tree = sort $bk->get_tree('@' . $_);
		open(X, "${bkrefdir}bk-file-tree-$_")
		  || die "Can't read ${bkrefdir}bk-file-tree-$_";
		my @answer = sort <X>;
		close X;
		chomp @answer;
		$self->assert_deep_equals(\@tree, \@answer, "Failed for version $_");
	}
}

# Now test the getdir function with the full tree
sub test_getdir_part2 {
	my $self = shift;
	my $bk   = $self->{'bk'};

	# A revision with no deletions
	my @entries = sort $bk->getdir('/firstdir/', '@1.3');
	$self->assert(scalar(@entries) == 2, "entries is $#entries");
	$self->assert_deep_equals(\@entries, [ sort ("file2", "file3") ]);
	@entries = sort($bk->getdir('/seconddir/', '@1.6'));
	$self->assert_deep_equals(\@entries, [ sort ("file4", "thirddir/") ]);

	# Check the full recursive tree
	@entries = sort $bk->getdir('/', '@1.11');
	$self->assert_deep_equals(\@entries, [sort ("file1", "firstdir/", "seconddir/", "sourcedir/")]);
	@entries = sort $bk->getdir('/sourcedir/', '@1.11');
	$self->assert_deep_equals(\@entries, [sort ("cobol.c", "main.c", "subdir1/")]);
	
	# Now a revision after some files have been deleted
	@entries = sort $bk->getdir('firstdir/', '@1.6');
	$self->assert(scalar(@entries) == 0);
	@entries = sort $bk->getdir('seconddir/', '@1.6');
	$self->assert_deep_equals(\@entries, [ sort ('thirddir/', 'file4') ]);
	@entries = sort $bk->getdir('seconddir/thirddir/', '@1.6');
	$self->assert_deep_equals(\@entries, [ sort ('file5') ]);

	# Now after a file in firstdir has been recreated
	@entries = sort $bk->getdir('firstdir/', '@1.8');
	$self->assert_deep_equals(\@entries, [ sort ('file2') ]);
}

# test getdir() ordering - dirs before files, all alphabetical
sub test_getdir_part3 {
	my $self = shift;
	my $bk   = $self->{'bk'};

	my @nodes = $bk->getdir('/', '@1.13');
	$self->assert($nodes[0] =~ m!/$!);
	my @expected = ('firstdir/', 'seconddir/', 'sourcedir/', 'file1');
	$self->assert_deep_equals(\@nodes, \@expected);
}

# Test the cache of bitkeeper trees

sub test_cache_creation {
	my $self = shift;
	my $bk   = $self->{'bk'};

	# First nuke the cache directory & the memory cache
	$self->clear_disk_cache();
	
	# Now ask for a specific tree
	$bk->getdir('/', '@1.10');
	$self->assert(-r $bk->cachename('@1.10'));
	$bk->getdir('/sourcedir', '@1.3');
	$self->assert(-r $bk->cachename('@1.3'));
	
	$self->clear_disk_cache();
}	

# Test the disk cache usage

sub test_cache_usage {
	my $self = shift;
	my $bk = $self->{'bk'};
	
	# Test strategy is to clear the cache, create a cache file for a version
	# that is known not to exist, then check that the info from that cached
	# version is returned.
	# First nuke the cache directory & the memory cache
	$self->clear_disk_cache();

	# Create the new information
	open(X, ">", $bk->cachename('testversion')) or die "Can't create test cache entry";
	print X "foobar|foobar|1.1\n";
	print X "another|another|1.2\n";
	print X "somewhere/other|somewhere/new|1.3\n";
	close X;
	
	my @entries = sort $bk->getdir('/', 'testversion');
	$self->assert_deep_equals(\@entries, [sort ("foobar", "another", "somewhere/")]);
	
	$self->clear_disk_cache();
}

sub clear_disk_cache {
	my $self = shift;
	
	system('rm -rf '.$bkcache);
	$self->assert(!-d $bkcache);	
	system('mkdir '.$bkcache);
	$self->assert(-d $bkcache);
	%LXR::Files::BK::tree_cache = ('' => '');
}

# Tests for the cache manipulation commands
sub test_fileexists {
	my $self = shift;
	my $bk   = $self->{'bk'};

	# These all exist
	$self->assert($bk->file_exists('/file1',                    '@1.2'));
	$self->assert($bk->file_exists('/file1',                    '@1.6'));
	$self->assert($bk->file_exists('/file1',                    '@1.8'));
	$self->assert($bk->file_exists('/firstdir/file2',           '@1.3'));
	$self->assert($bk->file_exists('/firstdir/file3',           '@1.5'));
	$self->assert($bk->file_exists('/seconddir/thirddir/file5', '@1.6'));

	# And these don't
	$self->assert(!$bk->file_exists('/file1',                    '@1.1'));
	$self->assert(!$bk->file_exists('/file2',                    '@1.3'));
	$self->assert(!$bk->file_exists('/firstdir/',                '@1.8'));
	$self->assert(!$bk->file_exists('/firstdir/file2',           '@1.2'));
	$self->assert(!$bk->file_exists('/firstdir/file3',           '@1.6'));
	$self->assert(!$bk->file_exists('/seconddir/thirddir/file4', '@1.6'));
}

sub test_getfileinfo {
	my $self = shift;
	my $bk   = $self->{'bk'};

	# These all exist
	$self->assert(defined($bk->getfileinfo('/file1', '@1.2')));
	$self->assert($bk->getfileinfo('/file1', '@1.6')->{'revision'} == 1.1);
	$self->assert($bk->getfileinfo('/file1', '@1.8')->{'curpath'} eq 'file1');
	my $info = $bk->getfileinfo('/firstdir/file2', '@1.3');
	$self->assert($info->{'revision'} == 1.1);
	$self->assert(
		$info->{'curpath'} eq 'BitKeeper/deleted/.del-file2~7a40a14b3cb5ac42');

	# And these don't
	$self->assert(!defined($bk->getfileinfo('/file1', '@1.1')));
	$self->assert(!defined($bk->getfileinfo('/file2', '@1.3')));
}

# Some basic getfile tests
# Check for correct & incorrect pathnames and versions
sub test_getfile {
	my $self = shift;
	my $bk   = $self->{'bk'};

	my $data = $bk->getfile("/firstdir/file2", '@1.3');
	open(FILE, '<', $bkrefdir . 'firstdir^file2^@1.3')
	  || die "Can't open file to check contents firstdir^file2^\@1.3";
	local ($/) = undef;
	my $check = <FILE>;
	close FILE;
	$self->assert($check eq $data, "File read didn't match");

# Pathnames must start with a "/" for CVS/Plain but we'll accept without - for now!
	$data = $bk->getfile("firstdir/file2", '@1.3');
	$self->assert($check eq $data, "File read didn't match");
	$data = $bk->getfile("/an/impossible/path/that/doesn/t/exist", '@131');
	$self->assert(!defined($data));
	$data = '';
	$data = $bk->getfile("include/linux/jffs.h", '@1345');
	$self->assert(!defined($data));
}

# Detailed getfile tests
# Checking here that we can correctly recover:
#  - the same file at two different revisions
#  - a file that has been deleted
#  - a file that has been deleted and then reconstructed
#      (i.e. the new dir/file is different to dir/file at a previous revision
#  - a file that has been moved
sub test_getfile2 {
	my $self = shift;
	my $bk   = $self->{'bk'};

	# These are all valid versions with contents
	my @versions = (
		'/seconddir/file4',          '@1.4',     # rev 1
		'/seconddir/file4',          '@1.7',     # rev 2
		'/firstdir/file2',           '@1.4',     # before delete
		'/firstdir/file2',           '@1.8',     # after reconstruction
		'/seconddir/thirddir/file5', '@1.6',     # before move
		'/seconddir/thirddir/file6', '@1.9',     # after move
		'/seconddir/file7',          '@1.10',    # after move to new dir
	);

	while (scalar(@versions)) {
		my $file      = shift @versions;
		my $ver       = shift @versions;
		my $data      = $bk->getfile($file, $ver);
		my $checkfile = substr($file, 1);
		$checkfile =~ s{/}{^}g;
		$checkfile = $bkrefdir . $checkfile . '^' . $ver;
		open(X, '<', $checkfile) or die "Can't open file $checkfile";
		local ($/) = undef;
		my $check = <X>;
		close X;
		$self->assert_equals($data, $check, "Failed for $file, $ver");
	}
}

sub test_getfilehandle {
	my ($self) = shift;
	my $bk = $self->{'bk'};

	$self->assert(defined($bk->getfilehandle("/firstdir/file2",  '@1.3')));
	$self->assert(defined($bk->getfilehandle("/seconddir/file4", '@1.6')));
	$self->assert(defined($bk->getfilehandle('file1',            '@1.2')));
	$self->assert(
		!defined($bk->getfilehandle("/random/path/to/nowhere", '@1.1449')));
	$self->assert(!defined($bk->getfilehandle("/file1",          '1.1')));
	$self->assert(!defined($bk->getfilehandle("/firstdir/file3", '@1.8')));
	$self->assert(!defined($bk->getfilehandle("/seconddir/file7", '@1.8')));
	$self->assert(!defined($bk->getfilehandle("/seconddir/thirddir/file5", '@1.10')));
}

# Test filerev
#  Need to ensure that the filerevs are < 255 chars & sensible!
#  Oh, and they change when the file changes!
sub test_filerev {
	my ($self) = shift;
	my $bk = $self->{'bk'};
	
	# A file that has changed contents
	my $rev = $bk->filerev('/file1', '@1.3');
	$self->assert($rev);
	$self->assert_not_equals($rev, $bk->filerev('/file1', '@1.12'));
	
	# A file that hasn't changed
	$rev = $bk->filerev('/firstdir/file2', '@1.3');
	$self->assert_equals($rev, $bk->filerev('/firstdir/file2', '@1.5'));
	$self->assert(length($rev) < 255);
	
	# A file that has been deleted & recreated
	$rev = $bk->filerev('/firstdir/file2', '@1.5');
	$self->assert_not_equals($rev, $bk->filerev('/firstdir/file2', '@1.9'));
}

# Test isdir
#  Assuming that pathname will always end in / if it's a dir
#  - this may not be correct!
sub test_isdir {
	my ($self) = shift;
	my $bk = $self->{'bk'};
	
	$self->assert($bk->isdir('/firstdir/', '@1.3'));
	$self->assert($bk->isdir('/seconddir/thirddir/','@1.6'));
	$self->assert(!$bk->isdir('/not/a/dir/', '@1.3'));
	$self->assert(!$bk->isdir('/seconddir/file2/', '@1.4'));
	$self->assert(!$bk->isdir('/file1','@1.11'));
	$self->assert(!$bk->isdir('/sourcedir/main.c', '@1.12'));
	$self->assert(!$bk->isdir('/sourcedir/', '@1.10')); 
}

sub test_isfile {
	my ($self) = shift;
	my $bk = $self->{'bk'};
	
	$self->assert($bk->isfile('/file1', '@1.12'));
	$self->assert($bk->isfile('/sourcedir/main.c', '@1.12'));
	$self->assert(!$bk->isfile('/sourcedir/main.c', '@1.9'));
	$self->assert(!$bk->isfile('/seconddir/thirddir/', '@1.9'));
}

# Test the getfiletime function
#  tests are assuming that undef is OK for a directory
sub test_getfiletime {
	my ($self) = shift;
	my $bk = $self->{'bk'};
	
	$self->assert_equals($bk->getfiletime('/file1', '@1.3'), timegm(30,20,14,13,01,2005)); # Note months is 0..11
	$self->assert_equals($bk->getfiletime('/file1', '@1.3'), $bk->getfiletime('file1', '@1.11'));
	$self->assert(!defined($bk->getfiletime('/sourcedir/', '@1.12')));
}

# Test the getfilesize
sub test_getfilesize {
	my ($self) = shift;
	my $bk = $self->{'bk'};
	
	$self->assert_equals($bk->getfilesize('/file1', '@1.3'), 60);
	$self->assert_equals($bk->getfilesize('/file1', '@1.3'), $bk->getfilesize('file1', '@1.11'));
	$self->assert(!defined($bk->getfilesize('/sourcedir/main.c', '@1.9')));
}

# Test getauthor

sub test_getauthor {
	my ($self) = shift;
	my $bk = $self->{'bk'};

	$self->assert_equals('malcolm', $bk->getauthor('/file1', '@1.3'));
	$self->assert_equals('malcolm', $bk->getauthor('/sourcedir/cobol.c', '@1.13'));
	$self->assert_null($bk->getauthor('/sourcedir/cobol.c', '@1.3'));
}

# Test getannotations
#  Only problem is that I don't have a clue what this function should return - so
#  for now we're stubbing it out a la Plain.pm

sub test_getannotations {
	my ($self) = shift;
	my $bk = $self->{'bk'};

	$self->assert_deep_equals([], [ $bk->getannotations('/file1', '@1.3') ]);
}

# Tests of helper functions in BK.pm
sub test_canonise {
	my ($self) = shift;
	my $bk = $self->{'bk'};
	$self->assert(
		LXR::Files::BK::canonise('/path/to/somewhere') eq 'path/to/somewhere');
	$self->assert(LXR::Files::BK::canonise('/') eq '');
}

# set_up and tear_down are used to
# prepare and release resources need for testing

# Prepare a config object
sub set_up {
	my $self = shift;
	$self->{'bk'} = new LXR::Files("bk:$bkpath", {'cachepath' => $bkcache});
	$self->{'config'}->{'dir'} = "$bkpath";
}

sub tear_down {
	my $self = shift;

	#	$self->{config} = undef;
}

1;
