# -*- tab-width: 4 -*- ###############################################
#
#

package LXR::Files::Plain;

use strict;


sub new {
	my ($self, $rootpath) = @_;

	$self = bless({}, $self);
	$$self{'rootpath'} = $rootpath;
	$$self{'rootpath'} =~ s@/*$@/@;

	return $self;
}

sub filerev {
	my ($self, $filename, $release) = @_;

	return $release;
}

sub getfile {
	my ($self, $filename, $release) = @_;
	my ($buffer);
	local ($/) = undef;

	open(FILE, $$self{'rootpath'}.$release.$filename) || return undef;
	$buffer = <FILE>;
	close(FILE);
	return $buffer;
}

sub getdir {
	my ($self, $pathname, $release) = @_;
	my ($dir, $node, @files);

	$dir = $$self{'rootpath'}.$release.$pathname;
	opendir(DIR, $dir) || return ();
	while (defined($node = readdir(DIR))) {
		next if $node =~ /^\.|~$|\.orig$/;

		$node .= '/' if -d $dir.$node;
		push(@files, $node);
	}
	closedir(DIR);

	return @files;
}

sub isdir {
	my ($self, $pathname, $release) = @_;

	return -d $$self{'rootpath'}.$release.$pathname;
}

1;
