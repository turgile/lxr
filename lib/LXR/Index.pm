# -*- tab-width: 4 -*- ###############################################
#
# $Id: Index.pm,v 1.12 2009/04/21 20:03:04 adrianissott Exp $

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

package LXR::Index;

$CVSID = '$Id: Index.pm,v 1.12 2009/04/21 20:03:04 adrianissott Exp $ ';

use LXR::Common;
use strict;

sub new {
	my ($self, $dbname, @args) = @_;
	my $index;

	if ($dbname =~ /^DBI:/i) {
		require LXR::Index::DBI;
		$index = new LXR::Index::DBI($dbname, @args);
	} elsif ($dbname =~ /^DBM:/i) {
		require LXR::Index::DB;
		$index = new LXR::Index::DB($dbname, @args);
	} else {
		die "Can't find database, $dbname";
	}
	return $index;
}

#
# Stub implementations of this interface
#

sub getindex {
  my ($self, $symname, $release) = @_;
  my @indexes;
	warn  __PACKAGE__."::getindex not implemented. Parameters @_";
  return @indexes;
}

sub index {
  my ($self, $symname, $fileid, $line, $langid, $type, $relsym) = @_;
	warn  __PACKAGE__."::index not implemented. Parameters @_";
  return;
}

sub toindex {
  my ($self, $fileid) = @_;
  my $filefoundboolean;
	warn  __PACKAGE__."::toindex not implemented. Parameters @_";
  return $filefoundboolean;
}

sub setindexed {
  my ($self, $fileid) = @_;
	warn  __PACKAGE__."::setindexed not implemented. Parameters @_";
  return;
}

sub fileid {
  my ($self, $filename, $revision) = @_;
  my $fileid;
	warn  __PACKAGE__."::fileid not implemented. Parameters @_";
  return $fileid;
}

sub getreference {
  my ($self, $symname, $release) = @_;
  my @references;
	warn  __PACKAGE__."::getreference not implemented. Parameters @_";
  return @references;
}

sub reference {
  my ($self, $symname, $fileid, $line) = @_;
	warn  __PACKAGE__."::reference not implemented. Parameters @_";
  return;
}

sub toreference {
  my ($self, $fileid) = @_;
  my $referencefoundboolean;
	warn  __PACKAGE__."::toreference not implemented. Parameters @_";
  return $referencefoundboolean;
}

sub setreferenced {
  my ($self, $fileid) = @_;
	warn  __PACKAGE__."::setreferenced not implemented. Parameters @_";
  return;
}

sub release {
  my ($self, $fileid, $release) = @_;
	warn  __PACKAGE__."::release not implemented. Parameters @_";
  return;
}

sub symid {
  my ($self, $symname) = @_;
  my $symid;
	warn  __PACKAGE__."::symid not implemented. Parameters @_";
  return $symid;
}

sub symname {
  my ($self, $symid) = @_;
  my $symname;
	warn  __PACKAGE__."::symname not implemented. Parameters @_";
  return $symname;
}

sub issymbol {
	my ($self, $symname, $release) = @_;
  my $symbolfoundboolean;
	warn  __PACKAGE__."::issymbol not implemented. Parameters @_";
  return $symbolfoundboolean;
}

sub getdecid {
  my ($self, $lang, $string) = @_;
  my $decid;
	warn  __PACKAGE__."::getdecid not implemented. Parameters @_";
  return $decid;
}

sub empty_cache {
  my ($self) = @_;
	warn  __PACKAGE__."::empty_cache not implemented. Parameters @_";
  return;
}

sub purge {
  my ($self, $version) = @_;
	warn  __PACKAGE__."::purge not implemented. Parameters @_";
  return;
}

1;
