# -*- tab-width: 4 -*- ###############################################
#
# $Id: CVS.pm,v 1.7 1999/05/29 23:35:03 argggh Exp $

package LXR::Files::CVS;

$CVSID = '$Id: CVS.pm,v 1.7 1999/05/29 23:35:03 argggh Exp $ ';

use strict;
use FileHandle;
use Time::Local;
use LXR::Common;

use vars qw(%cvs $cache_filename);

sub new {
	my ($self, $rootpath) = @_;

	$self = bless({}, $self);
	$self->{'rootpath'} = $rootpath;
	$self->{'rootpath'} =~ s@/*$@/@;

	return $self;
}

sub filerev {
	my ($self, $filename, $release) = @_;

	$self->parsecvs($filename, $release);

	return $cvs{'header'}{'symbols'}{$release};
}								

sub getfiletime {
	my ($self, $filename, $release) = @_;

	return undef if $self->isdir($filename, $release);

	$self->parsecvs($filename, $release);

	my $rev = $cvs{'header'}{'symbols'}{$release};

	return undef unless defined($rev);

	my @t = reverse(split(/\./, $cvs{'branch'}{$rev}{'date'}));
	$t[4]--;

	return timegm(@t);
}

sub getfilesize {
	my ($self, $filename, $release) = @_;

	return length($self->getfile($filename, $release));
}

sub getfile {
	my ($self, $filename, $release) = @_;

	$self->parsecvs($filename, $release);

	my $rev = $cvs{'header'}{'symbols'}{$release};
	return undef unless defined($rev);

	my $hrev = $cvs{'header'}{'head'};
	my @head = $cvs{'history'}{$hrev}{'text'} =~ /([^\n]*\n)/gs;

	while ($hrev ne $rev && $cvs{'branch'}{$hrev}{'branches'} ne $rev) {
		$hrev = $cvs{'branch'}{$hrev}{'next'};
		my @diff = $cvs{'history'}{$hrev}{'text'} =~ /([^\n]*\n)/gs;
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
				warning("Oops! Out of sync!");
			}
		}
	}

	return join('', @head);
}

sub getfilehandle {
	my ($self, $filename, $release) = @_;
	my ($fileh);

#	$fileh = new FileHandle("co -q -pv$release ".
#							$self->toreal($filename, $release).
#							" |"); # FIXME: Exploitable?

	my $buffer = $self->getfile($filename, $release);

	&LXR::Common::fflush;
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
	my ($tmp, $buf);

	$buf = $self->getfile($filename, $release);
	return undef unless defined($buf);
	
	$tmp = '/tmp/lxrtmp.'.time.'.'.$$.'.'.&LXR::Common::tmpcounter;
	open(TMP, "> $tmp") || return undef;
	print(TMP $buf);
	close(TMP);
	
	return $tmp;
}

sub dirempty {
	my ($self, $pathname, $release) = @_;
	my ($node, @dirs, @files);
	my $DIRH = new IO::Handle;
	my $real = $self->toreal($pathname, $release);

	opendir($DIRH, $real) || return 1;
	while (defined($node = readdir($DIRH))) {
		next if $node =~ /^\.|~$|\.orig$/;
		next if $node eq 'CVS';

		if (-d $real.$node) {
			push(@dirs, $node.'/'); 
		}
		elsif ($node =~ /(.*),v$/) {
			push(@files, $1);
		}
	}
	closedir($DIRH);

	foreach $node (@files) {
		$self->parsecvs($pathname.$node, $release);
		return 0 if $cvs{'header'}{'symbols'}{$release};
	}

	foreach $node (@dirs) {
		return 0 unless $self->dirempty($pathname.$node, $release);
	}
	return 1;
}

sub getdir {
	my ($self, $pathname, $release) = @_;
	my ($node, @dirs, @files);
	my $DIRH = new IO::Handle;
	my $real = $self->toreal($pathname, $release);

	opendir($DIRH, $real) || return ();
	while (defined($node = readdir($DIRH))) {
		next if $node =~ /^\.|~$|\.orig$/;
		next if $node eq 'CVS';

		if (-d $real.$node) {
			if ($node eq 'Attic') {
				push(@files, $self->getdir($pathname.$node.'/', $release));
			}
			else {
				push(@dirs, $node.'/') 
					unless defined($release) 
						&& $self->dirempty($pathname.$node.'/', $release);
			}
		}
		elsif ($node =~ /(.*),v$/) {
			push(@files, $1) 
				if ! defined($release) 
					|| $self->getfiletime($pathname.$1, $release);
		}
	}
	closedir($DIRH);

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

	my $index = $self->getfile($pathname, $release);

	return $index =~ /\n(\S*)\s*\n\t-\s*([^\n]*)/gs;
}

sub allreleases {
	my ($self, $filename) = @_;

	$self->parsecvs($filename, undef);

	return sort(keys(%{$cvs{'header'}{'symbols'}}));
}

sub parsecvs {
	my ($self, $filename, $release) = @_;

	return if $cache_filename eq $filename;
	$cache_filename = $filename;

	open(CVS, $self->toreal($filename, $release));
	my @cvs = join('', <CVS>) =~ /((?:(?:[^\n@]+|@[^@]*@)\n?)+)/gs;
	close(CVS);

	$cvs{'header'} = { map { s/@@/@/gs;
							 /^@/s && substr($_, 1, -1) || $_ }
					   shift(@cvs) =~ /(\w+)\s*((?:[^;@]+|@[^@]*@)*);/gs };
	$cvs{'header'}{'symbols'}
	= { $cvs{'header'}{'symbols'} =~ /(\S+?):(\S+)/g };

	my ($orel, $nrel, $rev);
	while (($orel, $rev) = each %{$cvs{'header'}{'symbols'}}) {
		$nrel = $config->cvsversion($orel);
		next unless defined($nrel);

		if ($nrel ne $orel) {
			delete($cvs{'header'}{'symbols'}{$orel});
			$cvs{'header'}{'symbols'}{$nrel} = $rev if $nrel;
		}
	}

	while (@cvs && $cvs[0] !~ /\s*desc/s) {
		my ($r, $v) = shift(@cvs) =~ /\s*(\S+)\s*(.*)/s;
		$cvs{'branch'}{$r} = { map { s/@@/@/gs;
									 /^@/s && substr($_, 1, -1) || $_ }
							   $v =~ /(\w+)\s*((?:[^;@]+|@[^@]*@)*);/gs };
	}
	
	$cvs{'desc'} = shift(@cvs) =~ /\s*desc\s+((?:[^\n@]+|@[^@]*@)*)\n/s;
	$cvs{'desc'} =~ s/^@|@($|@)/$1/gs;

	while (@cvs) {
		my ($r, $v) = shift(@cvs) =~ /\s*(\S+)\s*(.*)/s;
		$cvs{'history'}{$r} = { map { s/@@/@/gs; 
									  /^@/s && substr($_, 1, -1) || $_ }
								$v =~ /(\w+)\s*((?:[^\n@]+|@[^@]*@)*)\n/gs };
	}
}


1;
