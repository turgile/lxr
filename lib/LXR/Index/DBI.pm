# -*- tab-width: 4 -*- ###############################################
#
# $Id: DBI.pm,v 1.11 1999/06/01 06:44:25 pergj Exp $

package LXR::Index::DBI;

$CVSID = '$Id: DBI.pm,v 1.11 1999/06/01 06:44:25 pergj Exp $ ';

use strict;
use DBI;

use vars qw($dbh $fst $fup $sst $ssq $sup $ist $iup $rup
			$transactions %files %symcache);

sub new {
	my ($self, $dbname) = @_;

	$self = bless({}, $self);
	$dbh = DBI->connect($dbname, "pergj", "foobar");
	$$dbh{'AutoCommit'} = 0;
#	$dbh->trace(1);
	$dbh->{RaiseError} = 1;
	
	$transactions = 0;
	%files = ();
	%symcache = ();

	$dbh->prepare("use lxr2")->execute();

	$fup = $dbh->prepare
		("insert into files values (?, ?)");

	$sup = $dbh->prepare
		("insert into symbols values ( ? )");

	$sst = $dbh->prepare
		("select * from symbols where symname = ?");

	$ist = $dbh->prepare
		("select f.filename, i.line, i.type ".
		 "from symbols s, indexes i, files f, releases r ".
		 "where s.symname = i.symname and ".
		 "i.filename = f.filename and i.revision = f.revision ".
		 "and f.filename = r.filename and f.revision = r.revision ".
		 "and s.symname = ? and r.release = ?");

	$iup = $dbh->prepare
		("insert into indexes values (?, ?, ?, ?, ?)");

	$rup = $dbh->prepare
		("insert into releases values (?, ?, ?)");
	
	$fst = $dbh->prepare
		("select * from files where filename = ? and revision = ?");
	
	return $self;
}

sub index {
	my ($self, $symname, $filename, $revision, $line, $type) = @_;

	if(!issymbol($self, $symname)) {
		$sup->execute($symname);
	}

	$iup->execute($symname,
				  $filename, $revision,
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

# Retrieve the file identifier for this file
sub fileid {
	my ($self, $filename, $revision, $update) = @_;
	my ($fileid);

	# CAUTION: $revision is not $release!
	unless (defined($fileid = $files{"$filename\t$revision"})) {
		$fst->execute($filename, $revision);
		($fileid) = $fst->fetchrow_array();
		unless ($fileid) {
			return undef unless $update;
			$fup->execute($filename, $revision);
		}
		$files{"$filename\t$revision"} = $fileid;
	}
	return $fileid;
}

# Indicate that this filerevision is part of this release
sub release {
	my ($self, $filename, $revision, $release) = @_;

	$rup->execute($filename, $revision, $release);
}

# Convert from fileid to filename
sub filename {
	my ($self, $fileid) = @_;
}

sub issymbol {
	my ($self, $symname) = @_;
	my ($foobar);

	if (!defined($symcache{$symname})) {
		$sst->execute($symname);
		while($foobar = $sst->fetchrow_array()) {
			$symcache{$symname} = $foobar;
		}
#		$sst->finish;
	}
	
	if(defined($symcache{$symname})) {
		return $symcache{$symname}
	} else {
		return ;
	}		
}

sub END {
	$fup = undef;
	$sst = undef;
	$ssq = undef;
	$sup = undef;
	$iup = undef;

	$dbh->commit();
	$dbh->disconnect();
	$dbh = undef;
}


1;
