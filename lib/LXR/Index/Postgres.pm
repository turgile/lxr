# -*- tab-width: 4 -*- ###############################################
#
# $Id: Postgres.pm,v 1.2 2000/07/26 07:50:21 pergj Exp $

package LXR::Index::Postgres;

$CVSID = '$Id: Postgres.pm,v 1.2 2000/07/26 07:50:21 pergj Exp $ ';

use strict;
use DBI;

use vars qw($dbh $transactions %files %symcache 
			$files_select $filenum_nextval $files_insert
			$symbols_byname $symbols_byid $symnum_nextval
			$symbols_insert $indexes_select $indexes_insert
			$releases_select $releases_insert $status_insert
			$status_update $usage_insert $usage_select);


sub new {
	my ($self, $dbname) = @_;

	$self = bless({}, $self);
	$dbh = DBI->connect($dbname);
	$$dbh{'AutoCommit'} = 0;
#	$dbh->trace(1);
	
	$transactions = 0;
	%files = ();
	%symcache = ();

	$files_select = $dbh->prepare
		("select fileid from files where filename = ? and revision = ?");
	$filenum_nextval = $dbh->prepare
		("select nextval('filenum')");
	$files_insert = $dbh->prepare
		("insert into files values (?, ?, ?)");

	$symbols_byname = $dbh->prepare
		("select symid from symbols where symname = ?");
	$symbols_byid = $dbh->prepare
		("select symname from symbols where symid = ?");
	$symnum_nextval = $dbh->prepare
		("select nextval('symnum')");
	$symbols_insert = $dbh->prepare
		("insert into symbols values (?, ?)");

	$indexes_select = $dbh->prepare
		("select f.filename, i.line, i.type, i.relsym ".
		 "from symbols s, indexes i, files f, releases r ".
		 "where s.symid = i.symid and i.fileid = f.fileid ".
		 "and f.fileid = r.fileid ".
		 "and s.symname = ? and r.release = ?");
	$indexes_insert = $dbh->prepare
		("insert into indexes values (?, ?, ?, ?, ?)");

	$releases_select = $dbh->prepare
		("select * from releases where fileid = ? and release = ?");
	$releases_insert = $dbh->prepare
		("insert into releases values (?, ?)");

	$status_insert = $dbh->prepare
#		("insert into status select ?, 0 except select fileid, 0 from status");
		("insert into status select ?, 0 where not exists ".
		 "(select * from status where fileid = ?)");

	$status_update = $dbh->prepare
		("update status set status = ? where fileid = ? and status <= ?");

	$usage_insert = $dbh->prepare
		("insert into usage values (?, ?, ?)");
	$usage_select = $dbh->prepare
		("select f.filename, u.line ".
		 "from symbols s, files f, releases r, usage u ".
		 "where s.symid = u.symid ".
		 "and f.fileid = u.fileid ".
		 "and f.fileid = r.fileid and ".
		 "s.symname = ? and r.release = ?");

	return $self;
}

sub empty_cache {
  %symcache = ();
}

sub index {
	my ($self, $symname, $fileid, $line, $type, $relsym) = @_;

	$indexes_insert->execute($self->symid($symname),
							 $fileid,
							 $line,
							 $type,
							 $relsym ? $self->symid($relsym) : undef);
	unless (++$transactions % 500) {
		$dbh->commit();
	}
}

sub reference {
	my ($self, $symname, $fileid, $line) = @_;

	$usage_insert->execute($fileid,
						   $line,
						   $self->symid($symname));

	unless (++$transactions % 500) {
		$dbh->commit();
	}
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
			$filenum_nextval->execute();
			($fileid) = $filenum_nextval->fetchrow_array();
			$files_insert->execute($filename, $revision, $fileid);
		}
		$files{"$filename\t$revision"} = $fileid;
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
	}
}

sub symid {
	my ($self, $symname) = @_;
	my ($symid);

	unless (defined($symid = $symcache{$symname})) {
		$symbols_byname->execute($symname);
		($symid) = $symbols_byname->fetchrow_array();
		unless ($symid) {
			$symnum_nextval->execute();
			($symid) = $symnum_nextval->fetchrow_array();
			$symbols_insert->execute($symname, $symid);
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

	return $symname;
}

sub issymbol {
	my ($self, $symname) = @_;

	unless (exists($symcache{$symname})) {
		$symbols_byname->execute($symname);
		($symcache{$symname}) = $symbols_byname->fetchrow_array();
	}
	
	return $symcache{$symname};
}

# If this file has not been indexed earlier, mark it as being indexed
# now and return true.  Return false if already indexed.
sub toindex {
	my ($self, $fileid) = @_;

	$status_insert->execute($fileid+0, $fileid+0);
	return $status_update->execute(1, $fileid, 0) > 0;
}

sub toreference {
	my ($self, $fileid) = @_;

	return $status_update->execute(2, $fileid, 1) > 0;
}

sub END {
	$files_select = undef;
	$filenum_nextval = undef;
	$files_insert = undef;
	$symbols_byname = undef;
	$symbols_byid = undef;
	$symnum_nextval = undef;
	$symbols_insert = undef;
	$indexes_insert = undef;
	$releases_insert = undef;
	$status_insert = undef;
	$status_update = undef;
	$usage_insert = undef;
	$usage_select = undef;

	$dbh->commit();
	$dbh->disconnect();
	$dbh = undef;
}


1;
