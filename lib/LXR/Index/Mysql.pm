# -*- tab-width: 4 perl-indent-level: 4-*- ###############################
#
# $Id: Mysql.pm,v 1.5 2001/05/31 14:45:09 mbox Exp $

package LXR::Index::Mysql;

$CVSID = '$Id: Mysql.pm,v 1.5 2001/05/31 14:45:09 mbox Exp $ ';

use strict;
use DBI;
use LXR::Common;

use vars qw($dbh $transactions %files %symcache
			$files_select $files_insert
			$symbols_byname $symbols_byid
			$symbols_insert $symbols_remove $indexes_select 
			$indexes_insert $releases_select $releases_insert $status_insert
			$status_update $status_get $usage_insert $usage_select);


sub new {
	my ($self, $dbname) = @_;

	$self = bless({}, $self);
	$dbh = DBI->connect($dbname, "lxr") || fatal "Can't open connection to database\n";
#	$$dbh{'AutoCommit'} = 0;
#	$dbh->trace(1);

	$transactions = 0;
	%files = ();
	%symcache = ();

	$files_select = $dbh->prepare
		("select fileid from files where  filename = ? and  revision = ?");
	$files_insert = $dbh->prepare
		("insert into files values (?, ?, NULL)");

	$symbols_byname = $dbh->prepare
		("select symid from symbols where  symname = ?");
	$symbols_byid = $dbh->prepare
		("select symname from symbols where symid = ?");
	$symbols_insert = $dbh->prepare
		("insert into symbols values ( ?, NULL)");
	$symbols_remove = $dbh->prepare
		("delete from symbols where symname = ?");

	$indexes_select = $dbh->prepare
		("select f.filename, i.line, i.type, i.relsym ".
		 "from symbols s, indexes i, files f, releases r ".
		 "where s.symid = i.symid and i.fileid = f.fileid ".
		 "and f.fileid = r.fileid ".
		 "and  s.symname = ? and  r.release = ?");
	$indexes_insert = $dbh->prepare
		("insert into indexes values (?, ?, ?, ?, ?)");

	$releases_select = $dbh->prepare
		("select * from releases where fileid = ? and  release = ?");
	$releases_insert = $dbh->prepare
		("insert into releases values (?, ?)");

	$status_get = $dbh->prepare
		("select status from status where fileid = ?");

	$status_insert = $dbh->prepare
#		("insert into status select ?, 0 except select fileid, 0 from status");
		("insert into status values (?, ?)");

	$status_update = $dbh->prepare
		("update status set status = ? where fileid = ? and status <= ?");

	$usage_insert = $dbh->prepare
		("insert into useage values (?, ?, ?)");
	$usage_select = $dbh->prepare
		("select f.filename, u.line ".
		 "from symbols s, files f, releases r, useage u ".
		 "where s.symid = u.symid ".
		 "and f.fileid = u.fileid ".
		 "and u.fileid = r.fileid and ".
		 "s.symname = ? and  r.release = ? ".
		 "order by f.filename");

	return $self;
}

sub index {
	my ($self, $symname, $fileid, $line, $type, $relsym) = @_;

	$indexes_insert->execute($self->symid($symname),
							 $fileid,
							 $line,
							 $type,
							 $relsym ? $self->symid($relsym) : undef);
#	unless (++$transactions % 500) {
#		$dbh->commit();
#	}
}

sub reference {
	my ($self, $symname, $fileid, $line) = @_;

	$usage_insert->execute($fileid,
						   $line,
						   $self->symid($symname));

#	unless (++$transactions % 500) {
#		$dbh->commit();
#	}
}

sub getindex {
	my ($self, $symname, $release) = @_;
	my ($rows, @ret);

	$rows = $indexes_select->execute("$symname", "$release");

	while ($rows-- > 0) {
		push(@ret, [ $indexes_select->fetchrow_array ]);
	}

	$indexes_select->finish();

	map { $$_[3] &&= $self->symname($$_[3]) } @ret;

	return @ret;
}

sub getreference {
	my ($self, $symname, $release) = @_;
	my ($rows, @ret);

	$rows = $usage_select->execute("$symname", "$release");

	while ($rows-- > 0) {
		push(@ret, [ $usage_select->fetchrow_array ]);
	}

	$usage_select->finish();

	return @ret;
}

sub relate {
	my ($self, $symname, $release, $rsymname, $reltype) = @_;

#	$relation{$self->symid($symname, $release)} .=
#		join("\t", $self->symid($rsymname, $release), $reltype, '');
}

sub getrelations {
	my ($self, $symname, $release) = @_;
}

sub fileid {
	my ($self, $filename, $revision) = @_;
	my ($fileid);

	# CAUTION: $revision is not $release!
	unless (defined($fileid = $files{"$filename\t$revision"})) {
		$files_select->execute($filename, $revision);
		($fileid) = $files_select->fetchrow_array();
		unless ($fileid) {
			$files_insert->execute($filename, $revision);
			$files_select->execute($filename, $revision);
			($fileid) = $files_select->fetchrow_array();
		}
		$files{"$filename\t$revision"} = $fileid;
		$files_select->finish();
	}
	return $fileid;
}

# Indicate that this filerevision is part of this release
sub release {
	my ($self, $fileid, $release) = @_;

	my $rows = $releases_select->execute($fileid+0, $release);
	$releases_select->finish();

	unless ($rows > 0) {
		$releases_insert->execute($fileid, $release);
		$releases_insert->finish();
	}
}

sub symid {
	my ($self, $symname) = @_;
	my ($symid);

	$symid = $symcache{$symname};
	unless (defined($symid)) {
		$symbols_byname->execute($symname);
		($symid) = $symbols_byname->fetchrow_array();
		$symbols_byname->finish();
		unless ($symid) {
			$symbols_insert->execute($symname);
			# Get the id of the new symbol
			$symbols_byname->execute($symname);
			($symid) = $symbols_byname->fetchrow_array();
			$symbols_byname->finish();
		}
		$symcache{$symname} = $symid;
	}

	return $symid;
}

sub symname {
	my ($self, $symid) = @_;
	my ($symname);

	$symbols_byid->execute($symid+0);
	($symname) = $symbols_byid->fetchrow_array();
	$symbols_byid->finish();

	return $symname;
}

sub issymbol {
	my ($self, $symname) = @_;
	my ($symid);

	$symid = $symcache{$symname};
	unless (defined($symid)) {
		$symbols_byname->execute($symname);
		($symid) = $symbols_byname->fetchrow_array();
		$symbols_byname->finish();
		$symcache{$symname} = $symid;
	}

	return $symid;
}

sub removesymbol {
	my ($self, $symname) = @_;

	delete $symcache{$symname};
	$symbols_remove->execute($symname);
}

# If this file has not been indexed earlier, mark it as being indexed
# now and return true.  Return false if already indexed.
sub toindex {
	my ($self, $fileid) = @_;
	my ($status);

	$status_get->execute($fileid);
	$status = $status_get->fetchrow_array();
	$status_get->finish();

	if(!defined($status)) {
		$status_insert->execute($fileid+0, 0);
	}
	return $status_update->execute(1, $fileid, 0) > 0;
}

sub toreference {
	my ($self, $fileid) = @_;
	my ($rv);

	return $status_update->execute(2, $fileid, 1) > 0;
}

# This function should be called before parsing each new file, 
# if this is not done the too much memory will be used and
# tings will become very slow. 
sub empty_cache {
	%symcache = ();
}

sub END {
	$files_select = undef;
	$files_insert = undef;
	$symbols_byname = undef;
	$symbols_byid = undef;
	$symbols_insert = undef;
	$indexes_insert = undef;
	$releases_insert = undef;
	$status_insert = undef;
	$status_update = undef;
	$usage_insert = undef;
	$usage_select = undef;

#	$dbh->commit();
	if($dbh) {
		$dbh->disconnect();
		$dbh = undef;
	}
}


1;
