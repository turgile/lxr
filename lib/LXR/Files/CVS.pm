# -*- tab-width: 4 -*- ###############################################
#
# $Id $

package LXR::Files::CVS;

$CVSID = '$Id: CVS.pm,v 1.3 1999/05/22 10:52:03 argggh Exp $ ';

use strict;
use FileHandle;
use LXR::Common;

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

	my $cvs = $self->parsecvs($filename, $release);

	(my $rel = $release) =~ s/\./_/g; # Configurable?
	$rel = 'v'.$rel;

	my $rev = $$cvs{'header'}{'symbols'}{$rel};
	return undef unless defined($rev);

	my $hrev = $$cvs{'header'}{'head'};
	my @head = $$cvs{'history'}{$hrev}{'text'} =~ /([^\n]*\n)/gs;

	while ($hrev ne $rev && $$cvs{'branch'}{$hrev}{'branches'} ne $rev) {
		$hrev = $$cvs{'branch'}{$hrev}{'next'};
		my @diff = $$cvs{'history'}{$hrev}{'text'} =~ /([^\n]*\n)/gs;
		my $off = 0;

		while (@diff) {
			my $dir = shift(@diff);

			if ($dir =~ /^a(\d+)\s+(\d+)/) {
				splice(@head, $1-$off, 0, splice(@diff, 0, $2));
				$off -= $2;
			}
			elsif ($dir =~ /^d(\d+)\s+(\d+)/) {
				splice(@head, $1-$off-1, $2);
				$off += $2;
			}
			else {
				warning("Oops!  Out of sync!");
			}
		}
	}

	return join('', @head);
}

sub getfilehandle {
	my ($self, $filename, $release) = @_;
	my ($fileh);

#	$release =~ s/\./_/g;
#	$fileh = new FileHandle("co -q -pv$release ".
#							$self->toreal($filename, $release).
#							" |"); # FIXME: Exploitable?


	my $buffer = $self->getfile($filename, $release);
	fflush;
	my ($readh, $writeh) = FileHandle::pipe;
	unless (fork) {
		$writeh->autoflush(1);
		$writeh->print($buffer);
		exec("/bin/true");		# Exit without cleanup.
		exit;
	}

	return $readh;
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
			if ($node eq 'Attic') {
				push(@files, $self->getdir($pathname.$node.'/', $release));
			}
			else {
				push(@dirs, $node.'/') 
					if ($self->getdir($pathname.$node.'/', $release))[0];
			}
		}
		elsif ($node =~ /(.*),v$/) {
			push(@files, $1); # if release.
		}
	}
	closedir($DIR);

	return (sort(@dirs), sort(@files));
}

sub toreal {
	my ($self, $pathname, $release) = @_;
	my $real = $self->{'rootpath'}.$pathname;

	return $real if -d $real;
	return $real.',v' if -f $real.',v';
	
	$real =~ s|(/[^/]+/?)$|/Attic$1|;

	return $real if -d $real;
	return $real.',v' if -f $real.',v';

	return undef;
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


sub parsecvs {
	my ($self, $filename, $release) = @_;

	open(CVS, $self->toreal($filename, $release));
	my @cvs = join('', <CVS>) =~ /((?:(?:[^\n@]+|@[^@]*@)\n?)+)/gs;
	close(CVS);

	my %ret;

	$ret{'header'} = { map { s/^@|@($|@)/$1/gs; $_ }
					   shift(@cvs) =~ /(\w+)\s*((?:[^;@]+|@[^@]*@)*);/gs };
	$ret{'header'}{'symbols'}
	= { $ret{'header'}{'symbols'} =~ /(\S+?):(\S+)/g };

	while (@cvs && $cvs[0] !~ /\s*desc/s) {
		my ($r, $v) = shift(@cvs) =~ /\s*(\S+)\s*(.*)/s;
		$ret{'branch'}{$r} = { # map { s/^@|@($|@)/$1/gs; $_ }
							   $v =~ /(\w+)\s*((?:[^;@]+|@[^@]*@)*);/gs };
	}
	
	$ret{'desc'} = shift(@cvs) =~ /\s*desc\s+((?:[^\n@]+|@[^@]*@)*)\n/s;
	$ret{'desc'} =~ s/^@|@($|@)/$1/gs;

	while (@cvs) {
		my ($r, $v) = shift(@cvs) =~ /\s*(\S+)\s*(.*)/s;
		$ret{'history'}{$r} = { # map { s/^@|@($|@)/$1/gs; $_ }
								$v =~ /(\w+)\s*((?:[^\n@]+|@[^@]*@)*)\n/gs };
	}

	return \%ret;
}


1;
