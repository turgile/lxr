# -*- tab-width: 4 -*- ###############################################
#
# $Id: DBI.pm,v 1.13 1999/08/19 22:13:36 argggh Exp $

package LXR::Index::DBI;

$CVSID = '$Id: DBI.pm,v 1.13 1999/08/19 22:13:36 argggh Exp $ ';

use strict;
use DBI;

use vars qw($dbh $fst $fsq $fup $sst $ssq $sup $ist $iup $rst $rup $tin $tip
			$transactions %files %symcache);

sub new {
	my ($self, $dbname) = @_;

	$self = bless({}, $self);
	$dbh = DBI->connect($dbname);
	$$dbh{'AutoCommit'} = 0;
#	$dbh->trace(2);
	
	$transactions = 0;
	%files = ();
	%symcache = ();

	$fst = $dbh->prepare
		("select fileid from files where filename = ? and revision = ?");
	$fsq = $dbh->prepare
		("select nextval('filenum')");
	$fup = $dbh->prepare
		("insert into files values (?, ?, ?)");

	$sst = $dbh->prepare
		("select symid from symbols where symname = ?");
	$ssq = $dbh->prepare
		("select nextval('symnum')");
	$sup = $dbh->prepare
		("insert into symbols values (?, ?)");

	$ist = $dbh->prepare
		("select f.filename, i.line, i.type ".
		 "from symbols s, indexes i, files f, releases r ".
		 "where s.symid = i.symid and i.fileid = f.fileid ".
		 "and f.fileid = r.fileid ".
		 "and s.symname = ? and r.release = ?");
	$iup = $dbh->prepare
		("insert into indexes values (?, ?, ?, ?)");

	$rst = $dbh->prepare
		("select * from releases where fileid = ? and release = ?");
	$rup = $dbh->prepare
		("insert into releases values (?, ?)");

	$tin = $dbh->prepare
		("insert into status select ?, 0 except select fileid, 0 from status");

	$tip = $dbh->prepare
		("update status set status = ? where fileid = ? and status <= ?");

	return $self;
}

sub index {
	my ($self, $symname, $fileid, $line, $type) = @_;

	$iup->execute($self->symid($symname),
						   $fileid,
						   $line, $type);
	unless (++$transactions % 500) {
		$dbh->commit();
	}
}

sub getindex {
	my ($self, $symname, $release) = @_;
	my ($rows, @ret);

	print(STDERR "$symname, $release\n");
	$rows = $ist->execute("$symname", "$release");

	while ($rows-- > 0) {
		push(@ret, [ $ist->fetchrow_array ]);
	}

	$ist->finish();

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
		$fst->execute($filename, $revision);
		($fileid) = $fst->fetchrow_array();
		unless ($fileid) {
#			return undef unless $update;

			$fsq->execute();
			($fileid) = $fsq->fetchrow_array();
			$fup->execute($filename, $revision, $fileid);
		}
		$files{"$filename\t$revision"} = $fileid;
	}
	return $fileid;
}

# Indicate that this filerevision is part of this release
sub release {
	my ($self, $fileid, $release) = @_;

	my $rows = $rst->execute($fileid+0, $release);
	$rst->finish();

	unless ($rows > 0) {
		$rup->execute($fileid, $release);
	}
}

# Convert from fileid to filename
sub filename {
	my ($self, $fileid) = @_;
}

sub symid {
	my ($self, $symname) = @_;
	my ($symid);

	unless (defined($symid = $symcache{$symname})) {
		$sst->execute($symname);
		($symid) = $sst->fetchrow_array();
		unless ($symid) {
			$ssq->execute();
			($symid) = $ssq->fetchrow_array();
			$sup->execute($symname, $symid);
		}
		$symcache{$symname} = $symid;
	}

	return $symid;
}

sub issymbol {
	my ($self, $symname) = @_;

	unless (exists($symcache{$symname})) {
		$sst->execute($symname);
		($symcache{$symname}) = $sst->fetchrow_array();
	}
	
	return $symcache{$symname};
}

# If this file has not been indexed earlier, mark it as being indexed
# now and return true.  Return false if already indexed.
sub toindex {
	my ($self, $fileid) = @_;

	$tin->execute($fileid);
	return $tip->execute(1, $fileid, 0) > 0;
}

sub END {
	$fst = undef;
	$fsq = undef;
	$fup = undef;
	$sst = undef;
	$ssq = undef;
	$sup = undef;
	$iup = undef;
	$tin = undef;
	$tip = undef;

	$dbh->commit();
	$dbh->disconnect();
	$dbh = undef;
}


1;
