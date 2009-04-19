# -*- tab-width: 4 perl-indent-level: 4-*- ###############################
#
# $Id: DBI.pm,v 1.22 2009/04/19 16:52:40 adrianissott Exp $

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

package LXR::Index::DBI;

$CVSID = '$Id: DBI.pm,v 1.22 2009/04/19 16:52:40 adrianissott Exp $ ';

use strict;

sub new {
	my ($self, $dbname) = @_;
	my ($index);

	if ($dbname =~ /^dbi:mysql:/i) {
		require LXR::Index::Mysql;
		$index = new LXR::Index::Mysql($dbname);
	} elsif ($dbname =~ /^dbi:Pg:/i) {
		require LXR::Index::Postgres;
		$index = new LXR::Index::Postgres($dbname);
	} elsif ($dbname =~ /^dbi:oracle:/i) {
		require LXR::Index::Oracle;
		$index = new LXR::Index::Oracle($dbname);
	}
	return $index;
}

sub getindex {
  my ($self, $symname, $release) = @_;
  my @indexes;
  return @indexes;
}

sub index {
  my ($self, $symname, $fileid, $line, $langid, $type, $relsym) = @_;
  return;
}

sub toindex {
  my ($self, $fileid) = @_;
  my $filefoundboolean;
  return $filefoundboolean;
}

sub setindexed {
  my ($self, $fileid) = @_;
  return;
}

sub fileid {
  my ($self, $filename, $revision) = @_;
  my $fileid;
  return $fileid;
}

sub getreference {
  my ($self, $symname, $release) = @_;
  my @references;
  return @references;
}

sub reference {
  my ($self, $symname, $fileid, $line) = @_;
  return;
}

sub toreference {
  my ($self, $fileid) = @_;
  my $referencefoundboolean;
  return $referencefoundboolean;
}

sub setreferenced {
  my ($self, $fileid) = @_;
  return;
}

sub release {
  my ($self, $fileid, $release) = @_;
  return;
}

sub symid {
  my ($self, $symname) = @_;
  my $symid;
  return $symid;
}

sub symname {
  my ($self, $symid) = @_;
  my $symname;
  return $symname;
}

sub issymbol {
	my ($self, $symname, $release) = @_;
  my $symbolfoundboolean;
  return $symbolfoundboolean;
}

sub getdecid {
  my ($self, $lang, $string) = @_;
  my $decid;
  return $decid;
}

sub empty_cache {
  return;
}

sub purge {
  my ($self, $version) = @_;
  return;
}

1;
