# -*- tab-width: 4 -*- ###############################################
#
# $Id $

package LXR::Files::CVS;

$CVSID = '$Id: CVS.pm,v 1.1 1999/05/20 22:37:53 argggh Exp $ ';

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

#	return $release;
	return join("-", $self->getfiletime($filename, $release),
				$self->getfilesize($filename, $release));
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

	my $fh = $self->getfilehandle($filename, $release);
	$buffer = join('', $fh->getlines);
	$fh->close();

	return $buffer;
}

sub getfilehandle {
	my ($self, $filename, $release) = @_;
	my ($fileh);

	$release =~ s/\./_/g;
	$fileh = new FileHandle("co -q -pv$release ".
							$self->toreal($filename, $release).
							" |"); # FIXME: Exploitable?
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
	my ($DIR);

	print(STDERR "Foo: $pathname $release\n");

	$DIR = new IO::Handle;

	$dir = $self->toreal($pathname, $release);
	opendir($DIR, $dir) || return ();
	while (defined($node = readdir($DIR))) {
		next if $node =~ /^\.|~$|\.orig$/;
		next if $node eq 'CVS';

		if (-d $dir.$node) {
			push(@dirs, $node.'/') 
				if ($self->getdir($pathname.$node.'/', $release))[0];
		}
		elsif ($node =~ /(.*),v$/) {
			push(@files, $1); # if release.
		}
	}
	closedir($DIR);

	return (sort(@dirs), sort(@files));
}

# This function should not be used outside this module
# except for printing error messages
# (I'm not sure even that is legitimate use, considering
# other possible File classes.)

sub toreal {
	my ($self, $pathname, $release) = @_;
	my $real = $self->{'rootpath'}.$pathname;

	$real .= ',v' unless -d $real;

	return $real;
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

# co -pv1_0_6 Makefile,v

