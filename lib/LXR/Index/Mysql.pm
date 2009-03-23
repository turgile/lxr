# -*- tab-width: 4 perl-indent-level: 4-*- ###############################
#
# $Id: Mysql.pm,v 1.21 2009/03/23 12:27:18 mbox Exp $

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

package LXR::Index::Mysql;

$CVSID = '$Id: Mysql.pm,v 1.21 2009/03/23 12:27:18 mbox Exp $ ';

use strict;
use DBI;
use LXR::Common;

use vars qw(%files %symcache @ISA $prefix);

@ISA = ("LXR::Index");

sub new {
	my ($self, $dbname) = @_;

	$self = bless({}, $self);
	if (defined($config->{dbpass})) {
		$self->{dbh} = DBI->connect($dbname, $config->{dbuser}, $config->{dbpass})
		  || fatal "Can't open connection to database\n";
	} else {
		$self->{dbh} = DBI->connect($dbname, "lxr", $config->{dbpass})
		  || fatal "Can't open connection to database\n";
	}

	if (defined($config->{'dbprefix'})) {
		$prefix = $config->{'dbprefix'};
	} else {
		$prefix = "lxr_";
	}

	%files    = ();
	%symcache = ();

	$self->{files_select} =
	  $self->{dbh}
	  ->prepare("select fileid from ${prefix}files where  filename = ? and  revision = ?");
	$self->{files_insert} =
	  $self->{dbh}
	  ->prepare("insert into ${prefix}files (filename, revision, fileid) values (?, ?, NULL)");

	$self->{symbols_byname} =
	  $self->{dbh}->prepare("select symid from ${prefix}symbols where  symname = ?");
	$self->{symbols_byid} =
	  $self->{dbh}->prepare("select symname from ${prefix}symbols where symid = ?");
	$self->{symbols_insert} =
	  $self->{dbh}->prepare("insert into ${prefix}symbols (symname, symid) values ( ?, NULL)");
	$self->{symbols_remove} =
	  $self->{dbh}->prepare("delete from ${prefix}symbols where symname = ?");

	$self->{indexes_select} =
	  $self->{dbh}->prepare("select f.filename, i.line, d.declaration, i.relsym "
		  . "from ${prefix}symbols s, ${prefix}indexes i, ${prefix}files f, ${prefix}releases r, ${prefix}declarations d "
		  . "where s.symid = i.symid and i.fileid = f.fileid "
		  . "and f.fileid = r.fileid "
		  . "and i.langid = d.langid and i.type = d.declid "
		  . "and  s.symname = ? and  r.rel = ?");
	$self->{indexes_insert} =
	  $self->{dbh}->prepare(
		"insert into ${prefix}indexes (symid, fileid, line, langid, type, relsym) values (?, ?, ?, ?, ?, ?)"
	  );

	$self->{releases_select} =
	  $self->{dbh}->prepare("select * from ${prefix}releases where fileid = ? and  rel = ?");
	$self->{releases_insert} =
	  $self->{dbh}->prepare("insert into ${prefix}releases (fileid, rel) values (?, ?)");

	$self->{status_get} =
	  $self->{dbh}->prepare("select status from ${prefix}status where fileid = ?");

	$self->{status_insert} = $self->{dbh}->prepare

	  #		("insert into status select ?, 0 except select fileid, 0 from status");
	  ("insert into ${prefix}status (fileid, status) values (?, ?)");

	$self->{status_update} =
	  $self->{dbh}
	  ->prepare("update ${prefix}status set status = ? where fileid = ? and status <= ?");

	$self->{usage_insert} =
	  $self->{dbh}->prepare("insert into ${prefix}useage (fileid, line, symid) values (?, ?, ?)");
	$self->{usage_select} =
	  $self->{dbh}->prepare("select f.filename, u.line "
		  . "from ${prefix}symbols s, ${prefix}files f, ${prefix}releases r, ${prefix}useage u "
		  . "where s.symid = u.symid "
		  . "and f.fileid = u.fileid "
		  . "and u.fileid = r.fileid "
		  . "and s.symname = ? and  r.rel = ? "
		  . "order by f.filename");
	$self->{decl_select} =
	  $self->{dbh}->prepare(
		"select declid from ${prefix}declarations where langid = ? and " . "declaration = ?");
	$self->{decl_insert} =
	  $self->{dbh}->prepare(
		"insert into ${prefix}declarations (declid, langid, declaration) values (NULL, ?, ?)");

	$self->{delete_indexes} =
	  $self->{dbh}->prepare("delete from ${prefix}indexes "
		  . "using ${prefix}indexes i, ${prefix}releases r "
		  . "where i.fileid = r.fileid "
		  . "and r.rel = ?");
	$self->{delete_useage} =
	  $self->{dbh}->prepare("delete from ${prefix}useage "
		  . "using ${prefix}useage u, ${prefix}releases r "
		  . "where u.fileid = r.fileid "
		  . "and r.rel = ?");
	$self->{delete_status} =
	  $self->{dbh}->prepare("delete from ${prefix}status "
		  . "using ${prefix}status s, ${prefix}releases r "
		  . "where s.fileid = r.fileid "
		  . "and r.rel = ?");
	$self->{delete_releases} =
	  $self->{dbh}->prepare("delete from ${prefix}releases " . "where rel = ?");
	$self->{delete_files} =
	  $self->{dbh}->prepare("delete from ${prefix}files "
		  . "using ${prefix}files f, ${prefix}releases r "
		  . "where f.fileid = r.fileid "
		  . "and r.rel = ?");

	return $self;
}

sub index {
	my ($self, $symname, $fileid, $line, $langid, $type, $relsym) = @_;

	$self->{indexes_insert}->execute($self->symid($symname),
		$fileid, $line, $langid, $type, $relsym ? $self->symid($relsym) : undef);
}

sub reference {
	my ($self, $symname, $fileid, $line) = @_;

	$self->{usage_insert}->execute($fileid, $line, $self->symid($symname));

}

sub getindex {
	my ($self, $symname, $release) = @_;
	my ($rows, @ret);

	$rows = $self->{indexes_select}->execute("$symname", "$release");

	while ($rows-- > 0) {
		push(@ret, [ $self->{indexes_select}->fetchrow_array ]);
	}

	$self->{indexes_select}->finish();

	map { $$_[3] &&= $self->symname($$_[3]) } @ret;

	return @ret;
}

sub getreference {
	my ($self, $symname, $release) = @_;
	my ($rows, @ret);

	$rows = $self->{usage_select}->execute("$symname", "$release");

	while ($rows-- > 0) {
		push(@ret, [ $self->{usage_select}->fetchrow_array ]);
	}

	$self->{usage_select}->finish();

	return @ret;
}

sub fileid {
	my ($self, $filename, $revision) = @_;
	my ($fileid);

	# CAUTION: $revision is not $release!
	unless (defined($fileid = $files{"$filename\t$revision"})) {
		$self->{files_select}->execute($filename, $revision);
		($fileid) = $self->{files_select}->fetchrow_array();
		unless ($fileid) {
			$self->{files_insert}->execute($filename, $revision);
			$self->{files_select}->execute($filename, $revision);
			($fileid) = $self->{files_select}->fetchrow_array();
		}
		$files{"$filename\t$revision"} = $fileid;
		$self->{files_select}->finish();
	}
	return $fileid;
}

# Indicate that this filerevision is part of this release
sub release {
	my ($self, $fileid, $release) = @_;

	my $rows = $self->{releases_select}->execute($fileid + 0, $release);
	$self->{releases_select}->finish();

	unless ($rows > 0) {
		$self->{releases_insert}->execute($fileid, $release);
		$self->{releases_insert}->finish();
	}
}

sub symid {
	my ($self, $symname) = @_;
	my ($symid);

	$symid = $symcache{$symname};
	unless (defined($symid)) {
		$self->{symbols_byname}->execute($symname);
		($symid) = $self->{symbols_byname}->fetchrow_array();
		$self->{symbols_byname}->finish();
		unless ($symid) {
			$self->{symbols_insert}->execute($symname);

			# Get the id of the new symbol
			$self->{symbols_byname}->execute($symname);
			($symid) = $self->{symbols_byname}->fetchrow_array();
			$self->{symbols_byname}->finish();
		}
		$symcache{$symname} = $symid;
	}

	return $symid;
}

sub symname {
	my ($self, $symid) = @_;
	my ($symname);

	$self->{symbols_byid}->execute($symid + 0);
	($symname) = $self->{symbols_byid}->fetchrow_array();
	$self->{symbols_byid}->finish();

	return $symname;
}

sub issymbol {
	my ($self, $symname) = @_;
	my ($symid);

	$symid = $symcache{$symname};
	unless (defined($symid)) {
		$self->{symbols_byname}->execute($symname);
		($symid) = $self->{symbols_byname}->fetchrow_array();
		$self->{symbols_byname}->finish();
		$symcache{$symname} = $symid;
	}

	return $symid;
}

# If this file has not been indexed earlier return true.  Return false
# if already indexed.
sub toindex {
	my ($self, $fileid) = @_;
	my ($status);

	$self->{status_get}->execute($fileid);
	$status = $self->{status_get}->fetchrow_array();
	$self->{status_get}->finish();

	if (!defined($status)) {
		$self->{status_insert}->execute($fileid + 0, 0);
	}

	return $status == 0;
}

sub setindexed {
	my ($self, $fileid) = @_;
	$self->{status_update}->execute(1, $fileid, 0);
}

sub toreference {
	my ($self, $fileid) = @_;
	my ($status);

	$self->{status_get}->execute($fileid);
	$status = $self->{status_get}->fetchrow_array();
	$self->{status_get}->finish();

	return $status < 2;
}

sub setreferenced {
	my ($self, $fileid) = @_;
	$self->{status_update}->execute(2, $fileid, 1);
}

# This function should be called before parsing each new file,
# if this is not done the too much memory will be used and
# tings will become very slow.
sub empty_cache {
	%symcache = ();
}

sub getdecid {
	my ($self, $lang, $string) = @_;

	my $rows = $self->{decl_select}->execute($lang, $string);
	$self->{decl_select}->finish();

	unless ($rows > 0) {
		$self->{decl_insert}->execute($lang, $string);
	}

	$self->{decl_select}->execute($lang, $string);
	my $id = $self->{decl_select}->fetchrow_array();
	$self->{decl_select}->finish();

	return $id;
}

sub purge {
	my ($self, $version) = @_;

	# we don't delete symbols, because they might be used by other versions
	# so we can end up with unused symbols, but that doesn't cause any problems
	$self->{delete_indexes}->execute($version);
	$self->{delete_useage}->execute($version);
	$self->{delete_status}->execute($version);
	$self->{delete_releases}->execute($version);
	$self->{delete_files}->execute($version);
}

sub DESTROY {
	my ($self) = @_;
	$self->{files_select}    = undef;
	$self->{files_insert}    = undef;
	$self->{symbols_byname}  = undef;
	$self->{symbols_byid}    = undef;
	$self->{symbols_insert}  = undef;
	$self->{indexes_insert}  = undef;
	$self->{releases_insert} = undef;
	$self->{status_insert}   = undef;
	$self->{status_update}   = undef;
	$self->{usage_insert}    = undef;
	$self->{usage_select}    = undef;
	$self->{decl_select}     = undef;
	$self->{decl_insert}     = undef;
	$self->{delete_indexes}  = undef;
	$self->{delete_useage}   = undef;
	$self->{delete_status}   = undef;
	$self->{delete_releases} = undef;
	$self->{delete_files}    = undef;

	if ($self->{dbh}) {
		$self->{dbh}->disconnect();
		$self->{dbh} = undef;
	}
}

1;
