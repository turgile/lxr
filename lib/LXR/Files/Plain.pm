# -*- tab-width: 4 -*- ###############################################
#
#

package LXR::Files::Plain;

use strict;


sub new {
	my ($self, $rootpath) = @_;

	$self = bless({}, $self);
	$self->{'rootpath'} = $rootpath;
	$self->{'rootpath'} =~ s@/*$@/@;

	return $self;
}

sub filerev {
	my ($self, $filename, $release) = @_;

	return $release;
}

sub getfiletime {
	my ($self, $filename, $release) = @_;

	return (stat($self->toreal($release, $filename)))[9];
}


sub getfile {
	my ($self, $filename, $release) = @_;
	my ($buffer);
	local ($/) = undef;

	open(FILE, $self->toreal($filename, $release)) || return undef;
	$buffer = <FILE>;
	close(FILE);
	return $buffer;
}

sub getdir {
	my ($self, $pathname, $release) = @_;
	my ($dir, $node, @files);

	$dir = $self->toreal($release,$pathname);
	opendir(DIR, $dir) || return ();
	while (defined($node = readdir(DIR))) {
		next if $node =~ /^\.|~$|\.orig$/;

		$node .= '/' if -d $dir.$node;
		if (!($node eq "CVS")) {
			push(@files, $node);
		}
	}
	closedir(DIR);

	return @files;
}

# This function should not be used outside this module
# except for printing error messages
sub toreal {
	my ($self, $pathname, $release) = @_;
	return ($self->{'rootpath'}.$release.$pathname);
}

sub isdir {
	my ($self, $pathname, $release) = @_;
	return -d $self->toreal($release,$pathname);
}

sub isfile {
	my ($self, $pathname, $release) = @_;

	return -f $self->toreal($release,$pathname);
}

sub getindex {
	my ($self, $pathname, $release) = @_;
	my ($save, $index, %index);
	my $indexname = $self->toreal($release, $pathname)."00-INDEX";

	if (-f $indexname) {
		open(INDEX, $indexname) || &warning("Existing $indexname could not be opened.");
		$save = $/; undef($/);
		$index = <INDEX>;
		$/ = $save;

		%index = $index =~ /\n(\S*)\s*\n\t-\s*([^\n]*)/gs;
	}
	return %index;
}


1;
