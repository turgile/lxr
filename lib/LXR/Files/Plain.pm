# -*- tab-width: 4 -*- ###############################################
#
# $Id: Plain.pm,v 1.8 1999/05/16 23:48:29 argggh Exp $

package LXR::Files::Plain;

$CVSID = '$Id: Plain.pm,v 1.8 1999/05/16 23:48:29 argggh Exp $ ';

use strict;
use FileHandle;

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

	return (stat($self->toreal($filename, $release)))[9];
}

sub getfilesize {
	my ($self, $filename, $release) = @_;

	return -s $self->toreal($filename, $release);
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

sub getfilehandle {
	my ($self, $filename, $release) = @_;
	my ($fileh);

	$fileh = new FileHandle($self->toreal($filename, $release));
	return $fileh;
}

sub tmpfile {
	my ($self, $filename, $release) = @_;
	my ($tmp);
	local ($/) = undef;

	$tmp = '/tmp/lxrtmp.'.time.'.'.$$;
	open(TMP, "> $tmp") || return undef;
	open(FILE, $self->toreal($filename, $release)) || return undef;
	print(TMP <FILE>);
	close(FILE);
	close(TMP);
	
	return $tmp;

}

sub getdir {
	my ($self, $pathname, $release) = @_;
	my ($dir, $node, @dirs, @files);

	$dir = $self->toreal($pathname, $release);
	opendir(DIR, $dir) || return ();
	while (defined($node = readdir(DIR))) {
		next if $node =~ /^\.|~$|\.orig$/;
		next if $node eq 'CVS';

		if (-d $dir.$node) {
			push(@dirs, $node.'/');
		}
		else {
			push(@files, $node);
		}
	}
	closedir(DIR);

	return sort(@dirs), sort(@files);
}

# This function should not be used outside this module
# except for printing error messages
# (I'm not sure even that is legitimate use, considering
# other possible File classes.)

sub toreal {
	my ($self, $pathname, $release) = @_;

	return ($self->{'rootpath'}.$release.$pathname);
}

sub isdir {
	my ($self, $pathname, $release) = @_;

	return -d $self->toreal($pathname, $release);
}

sub isfile {
	my ($self, $pathname, $release) = @_;

	return -f $self->toreal($pathname, $release);
}

sub getindex {
	my ($self, $pathname, $release) = @_;
	my ($save, $index, %index);
	my $indexname = $self->toreal($pathname, $release)."00-INDEX";

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
