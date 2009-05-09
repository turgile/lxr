# -*- tab-width: 4 -*- ###############################################
#
# $Id: DB.pm,v 1.17 2009/05/09 21:57:34 adrianissott Exp $

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

package LXR::Index::DB;

$CVSID = '$Id: DB.pm,v 1.17 2009/05/09 21:57:34 adrianissott Exp $ ';

use strict;
use DB_File;
use NDBM_File;

sub new {
	my ($self, $dbpath, $mode) = @_;
	my ($foo);

	$self = bless({}, $self);
	$$self{'dbpath'} = $dbpath;
	$$self{'dbpath'} =~ s@/*$@/@;

	foreach ('releases', 'files', 'symbols', 'indexes', 'status') {
		$foo = {};
		tie(%$foo, 'NDBM_File', $$self{'dbpath'} . $_, $mode || O_RDONLY, 0664)
		  || die "Can't open database " . $$self{'dbpath'} . $_ . "\n";
		$$self{$_} = $foo;
	}

	return $self;
}

sub setsymdeclaration {
	my ($self, $symname, $fileid, $line, $langid, $type, $relsym) = @_;
	my $symid = $self->symid($symname);

	$self->{'indexes'}{$symid} .= join("\t", $fileid, $line, $type, $relsym) . "\0";

	#	$$self{'symdeclaration'}{$self->symid($symname)} =
	#		join("\t", $filename, $line, $type, '');
}

# Returns array of (fileid, line, type)
sub symdeclarations {
	my ($self, $symname, $release) = @_;

	my (@d, $f);
	foreach $f (split(/\0/, $$self{'indexes'}{ $self->symid($symname) })) {
		my ($fi, $l, $t, $s) = split(/\t/, $f);

		my %r = map { ($_ => 1) } split(/;/, $self->{'releases'}{$fi});
		next unless $r{$release};

		push(@d, [ $self->filename($fi), $l, $t, $s ]);
	}
	return @d;
}

sub symreferences {
  my ($self, $symname, $release) = @_;
	return ();
}

sub fileid {
	my ($self, $filename, $revision) = @_;

	return $filename . ';' . $revision;
}

# Convert from fileid to filename
sub filename {
	my ($self, $fileid) = @_;
	my ($filename) = split(/;/, $fileid);

	return $filename;
}

# If this file has not been indexed earlier, mark it as being indexed
# now and return true.  Return false if already indexed.
sub fileindexed {
	my ($self, $fileid) = @_;

	return undef if $self->{'status'}{$fileid} >= 1;

	$self->{'status'}{$fileid} = 1;
	return 1;
}

# Indicate that this filerevision is part of this release
sub setfilerelease {
	my ($self, $fileid, $release) = @_;

	$self->{'releases'}{$fileid} .= $release . ";";
}

sub symid {
	my ($self, $symname) = @_;
	my ($symid);

	return $symname;
}

sub issymbol {
	my ($self, $symname, $release) = @_;

	return $$self{'indexes'}{ $self->symid($symname) };
}

sub emptycache {
}

sub DESTROY {
}

1;
