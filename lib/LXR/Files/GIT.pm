# -*- tab-width: 4 -*- ###############################################
#
# $Id: GIT.pm,v 1.1 2006/04/08 13:37:58 mbox Exp $

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

package LXR::Files::GIT;

$CVSID = '$Id: GIT.pm,v 1.1 2006/04/08 13:37:58 mbox Exp $';

use strict;
use FileHandle;
use LXR::Common;
use LXR::Author;

#
# We're adding ".git" to the path since we're only dealing with
# low-level stuff and _never_ ever deal with checked-out files.
#
sub new {
	my ($self, $rootpath, $params) = @_;

	$self = bless({}, $self);
	$self->{'rootpath'} = $rootpath;

	$ENV{'GIT_DIR'} = $self->{'rootpath'};
	return $self;
}

sub filerev {
	my ($self, $filename, $release) = @_;

	$filename = $self->sanitizePath ($filename);
	$release = $self->get_treehash_for_branchhead_or_tag ($release);

	my $pid = open(my $F, '-|');
	die $! unless defined $pid;
	if (!$pid) {
		exec ("git-ls-tree", $release, $filename)
			or die "filerev: Cannot exec git-ls-tree"; 
	}

	my $git_line=<$F>;
	chomp $git_line;
	close($F);

	if ($git_line =~ m/(\d+)\s(\w+)\s([[:xdigit:]]+)\t(.*)/ ) {
		return $3;
		
	} else {
		die "filerev( $filename, $release ): No entry found.\n";
	}
}

sub getfiletime {
	my ($self, $filename, $release) = @_;
	$filename = $self->sanitizePath ($filename);

	if ($filename =~ m/\/\.\.$/ )
		return undef;
#	if ($filename =~ /\/\.\.\$/)
#		return undef;

	my $pid1 = open(my $R, '-|' );
	die $! unless defined $pid1;
	if(!$pid1) {
		exec("git-rev-list", "--max-count=1", "$release", "--", $filename ) or die "getfiletime ($filename, $release): Cannot exec git-rev-list\n";
	}
	my $commit = <$R>;
	chomp $commit;
	close($R);
	
	my $pid = open(my $F, '-|');
	die $! unless defined $pid;
	if(!$pid) {
		exec("git-cat-file", "commit", $commit) or die "getfiletime ($filename, $release): Cannot exec git-cat-file\n";
	}

	while(<$F>) {
		chomp;
		if ( m/^author .*<.*> (\d+)\s.*$/ ) {
			close($F);
			return $1;
		}
	}
	
	close($F);

	die "getfiletime ($filename, $release) : Did not find GIT entry.\n";
}

sub getfilesize {
	my ($self, $filename, $release) = @_;

	$filename = $self->sanitizePath ($filename);
	my $object_hash = $self->filerev ($filename, $release);

	print STDERR "getfilesize ($filename, $release)\n";

	# return `git-cat-file -s $blobhash`;
	my $pid = open (my $F, '-|');
	die $! unless defined $pid;
	if(!$pid) {	
		exec ("git-cat-file", "-s", $object_hash) or die "getfilesize ($filename, $release): Cannot exec git-cat-file\n";
	}

	my $size = <$F>;
	close ($F);
	chomp $size;
	if ( $size ) {
		return $size;
	} else {
		return undef;
	}

	close ($F);
	return undef;
}

sub getfile {
	my ($self, $filename, $release) = @_;
	my ($buffer);

#	my $blobhash = open( "git-ls-tree $release $filename | cut -f 3 -d ' ' | cut -f 1 -d \$'\t' |") or die "Cannot open git-ls-tree $release $filename in getfile\n";
	my $blobhash = $self->filerev( $filename, $release );
#	local ($/) = undef;

	open(FILE, "git-cat-file blob $blobhash|") || return undef;
	$buffer = <FILE>;
	close(FILE);
	return $buffer;
}

sub getfilehandle {
	my ($self, $filename, $release) = @_;
	my ($fileh);
	$filename = $self->sanitizePath ($filename);

	my $treeid = $self->get_treehash_for_branchhead_or_tag ($release);

	$filename = $self->sanitizePath ($filename);
	my $objectid = $self->getBlobOrTreeOfPathAndTree ($filename, $treeid);

	$fileh = new IO::File;
	$fileh->open ("git-cat-file blob $objectid |") or die "Cannot execute git-cat-file blob $objectid";

	return $fileh;
}

sub tmpfile {
	my ($self, $filename, $release) = @_;
	my ($tmp, $fileh);
	local ($/) = undef;

	$tmp = $config->tmpdir . '/lxrtmp.' . time . '.' . $$ . '.' . &LXR::Common::tmpcounter;
	open(TMP, "> $tmp") || return undef;
	$fileh = $self->getfilehandle( $filename, $release );
	print(TMP <$fileh>);
	close($fileh);
	close(TMP);

	return $tmp;
}

sub getannotations {

	return ();
	my ($self, $pathname, $release) = @_;
	my @authors = ();

	if ( $pathname =~ m#^/(.*)$# ) {
		$pathname = $1;
	}
	
	open( BLAME, "git-blame -l $pathname $release |");
	while( <BLAME> ) {
		if (  m/(^[[:xdigit:]]+)\s.*$/ ) {
			my $linehash = $1;
			my $authorline = `git-cat-file commit $linehash`;
			if ($authorline =~ m/^author ([^<]+)<(([^@])\@[^>]+)>.*$/ ) {
				my ($authorname, $authoruser, $authoremail) = ($1, $2, $3);
				push(@authors, LXR::Author->new(chomp $authorname,
						$authoruser, $authoremail));
			} else {
				push(@authors, LXR::Author->new("", "", ""));
			}
		} else {	
			print STDERR "getannotations: JB HAT DOOFE OHREN: $_\n";
		}
	}
	close(BLAME);

	print STDERR "authors: " . join(" ", @authors) . "\n";
	
	return @authors;
}

sub getauthor {

	return ();

	my ($self, $filename, $release) = @_;
	$filename = $self->sanitizePath ($filename);
	print STDERR "getauthr( $filename, $release )\n";
	my $commit = `git-rev-list --max-count=1 $release -- $filename | tr -d \$'\n'`;
	my $authorline = `git-cat-file commit $commit | grep '^author' | head -n1 | tr -d \$'\n'`;

	if ($authorline =~ m/^author ([^<]+)<(([^@])\@[^>]+)>.*$/ ) {
		my ($authorname, $authoruser, $authoremail) = ($1, $2, $3);
		return LXR::Author->new(chomp $authorname, $authoruser, $authoremail);
	} else {
		return LXR::Author->new("", "", "");
	}
}

sub getdir {
	my ($self, $pathname, $release) = @_;
	my ($dir, $node, @dirs, @files);
	
	my $treeid = $self->get_treehash_for_branchhead_or_tag ($release);
	
	$pathname = $self->sanitizePath( $pathname );
	if ( $pathname !~ m#..*/# ) {
		$pathname = $pathname . '/';
	}

	open(DIRLIST, "git-ls-tree $treeid $pathname |") or die "Cannot open git-ls-tree $treeid $pathname";
	while( <DIRLIST> ) {
		if (  m/(\d+)\s(\w+)\s([[:xdigit:]]+)\t(.*)/ ) {
			my ($entrymode, $entrytype, $objectid, $entryname) = ($1,$2,$3,$4);

			# Weed out things to ignore
			foreach my $ignoredir ($config->{ignoredirs}) {
				next if $entryname eq $ignoredir;
			}

			next if $entryname =~ /^\.$/;
			next if $entryname =~ /^\.\.$/;

			if ($entrytype eq "blob") {
				push(@files, $entryname);
				
			} elsif ($entrytype eq "tree") {
				push(@dirs, "$entryname/");
				#push(@dirs, "$entryname");
			}
		}
	}
	close(DIRLIST);
	
	return sort(@dirs), sort(@files);
}

# This function should not be used outside this module
# except for printing error messages
# (I'm not sure even that is legitimate use, considering
# other possible File classes.)

##sub toreal {
##	my ($self, $pathname, $release) = @_;
##
## nearly all (if not all) method calls eventually call toreal(), so this is a good place to block file access
##	foreach my $ignoredir ($config->ignoredirs) {
##		return undef if $pathname =~ m|/$ignoredir/|;
##	}
##
##	return ($self->{'rootpath'} . $release . $pathname);
##}

sub isdir {
	my ($self, $pathname, $release) = @_;

	$pathname = $self->sanitizePath ($pathname);
	$release = $self->get_newest_commit_from_branchhead_or_tag ($release);

	print STDERR "isdir ($pathname, $release)\n";

	my $treeid = $self->get_treehash_for_branchhead_or_tag ($release);

	return $self->getObjectType ($pathname, $treeid) eq "tree";
}

sub isfile {
	my ($self, $pathname, $release) = @_;

	$pathname = $self->sanitizePath ($pathname);
	$release = $self->get_newest_commit_from_branchhead_or_tag ($release);
	
	print STDERR "isfile($pathname, $release)\n";

	my $treeid = $self->get_treehash_for_branchhead_or_tag ($release);
	
	return $self->getObjectType ($pathname, $treeid) eq "blob";
}

#
# For a given commit (that is, the latest commit on a named branch or
# a tag's name)  return the tree object's hash corresponding to it.
#
sub get_treehash_for_branchhead_or_tag () {
	my ($self, $release) = @_;
	$release = $self->get_newest_commit_from_branchhead_or_tag ($release);

	return `git-cat-file commit $release | grep '^tree' | head -n1 | cut -f 2 -d ' ' | tr -d \$'\n'`;
}

sub getObjectType() {
	my ($self, $pathname, $treeid) = @_;

	open (DIRLIST, "git-ls-tree $treeid $pathname |") or die "Cannot open git-ls-tree $treeid $pathname";
	while (<DIRLIST>) {
		if (m/(\d+)\s(\w+)\s([[:xdigit:]]+)\t(.*)/) {
			my ($entrymode, $entrytype, $objectid, $entryname) = ($1, $2, $3, $4);

			# Weed out things to ignore
#			# This should only be needed in the getdir function.
#			foreach my $ignoredir ($config->{ignoredirs}) {
#				next if $entryname eq $ignoredir;
#			}

			$entryname = $self->sanitizePath ($entryname);

#			print STDERR "getBlobOrTreeOfPathAndTree: pathname: \"$pathname\" :: entryname: \"$entryname\"\n";
			next if ( ! $pathname eq $entryname );

			close (DIRLIST);
#			print STDERR "Juhu, wir haben $pathname gefunden :: $objectid\n";
			return $entrytype;
		}
	}
	close (DIRLIST);

	return undef;
}

sub getBlobOrTreeOfPathAndTree() {
	my ($self, $pathname, $treeid ) = @_;

	open (DIRLIST, "git-ls-tree $treeid $pathname |") or die "Cannot open git-ls-tree $treeid $pathname";
	while (<DIRLIST>) {
		if (m/(\d+)\s(\w+)\s([[:xdigit:]]+)\t(.*)/) {
			my ($entrymode, $entrytype, $objectid, $entryname) = ($1, $2, $3, $4);

			# Weed out things to ignore
			foreach my $ignoredir ($config->{ignoredirs}) {
				next if $entryname eq $ignoredir;
			}

			$entryname = $self->sanitizePath( $entryname );
			next if (! $pathname eq $entryname );

			close (DIRLIST);
			return $objectid;
		}
	}
	close (DIRLIST);

	return undef;
}

#
# This function will take a branch name ("master") or a tag name
# (like "v2.6.15") and return either the branch commit object ID,
# or descend from the tag object into the referenced commit object
# and return its commit ID.  XXX
#
sub get_newest_commit_from_branchhead_or_tag ($$) {
	my ($self, $head_or_tag) = @_;
	my $objtype = `git-cat-file -t $head_or_tag | tr -d \$'\n'`;

	if ($objtype eq "commit") {
		return $head_or_tag;
	} elsif ($objtype eq "tag") {
		return `git-cat-file tag $head_or_tag | grep '^object' | head -n1 | cut -f 2 -d ' ' | tr -d \$'\n'`;
	} else {
		die ("get_newest_commit_from_branchhead_or_tag: Unrecognized object type $objtype for $head_or_tag\n");
	}
}

sub sanitizePath() {
	my ($self, $pathname) = @_;

	if ( $pathname eq "" ) {
		# Empty? Just beam the client to the root.
		$pathname = ".";
	} elsif ( $pathname =~ m#^/# ) {
		# Absolute? We want them to be relative!
		$pathname = ".$pathname";
	} else {
		# Filename incurrent directory? Add "./" to
		# make them truly relative.
		$pathname = "./$pathname";
	}

	# Don't let them exploit us easily.
#	if ( $pathname =~ m#/../# ) {
#		die("You are now dead because of $pathname\n");
#	}

	# Doubled slashes? We remove them.
	$pathname =~ s#//#/#g;

	# Delete leading slashes.
	$pathname =~ s#/*$##g;

	return $pathname;
}

1;
