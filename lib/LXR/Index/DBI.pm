# -*- tab-width: 4 -*- ###############################################
#
# $Id: DBI.pm,v 1.6 1999/05/22 14:41:05 argggh Exp $

package LXR::Index::DBI;

$CVSID = '$Id: DBI.pm,v 1.6 1999/05/22 14:41:05 argggh Exp $ ';

use strict;
use DBI;


sub new {
	my ($self, $dbname) = @_;

	$self = bless({}, $self);
	$$self{'dbh'} = DBI->connect($dbname);
	$$self{'dbh'}{'AutoCommit'} = 0;
#	$$self{'dbh'}->trace(2);
	
	$$self{'transactions'} = 0;
	$$self{'filecache'} = [];
	$$self{'symcache'} = {};

	$$self{'fst'} = $$self{'dbh'}->prepare
		("select fileid from files where filename = ? and revision = ?");
	$$self{'fsq'} = $$self{'dbh'}->prepare
		("select nextval('filenum')");
	$$self{'fup'} = $$self{'dbh'}->prepare
		("insert into files values (?, ?, ?)");

	$$self{'sst'} = $$self{'dbh'}->prepare
		("select symid from symbols where symname = ?");
	$$self{'ssq'} = $$self{'dbh'}->prepare
		("select nextval('symnum')");
	$$self{'sup'} = $$self{'dbh'}->prepare
		("insert into symbols values (?, ?)");

	$$self{'iup'} = $$self{'dbh'}->prepare
		("insert into indexes values (?, ?, ?, ?)");

	$$self{'rst'} = $$self{'dbh'}->prepare
		("select * from releases where fileid = ? and release = ?");
	$$self{'rup'} = $$self{'dbh'}->prepare
		("insert into releases values (?, ?)");

	return $self;
}

sub index {
	my ($self, $symname, $fileid, $line, $type) = @_;

	$$self{'iup'}->execute($self->symid($symname),
						   $fileid,
						   $line, $type);
	unless (++$$self{'transactions'} % 500) {
		$$self{'dbh'}->commit();
	}
}

sub getindex {
	my ($self, $symname, $release) = @_;
}

sub relate {
	my ($self, $symname, $release, $rsymname, $reltype) = @_;

#	$$self{'relation'}{$self->symid($symname, $release)} .=
#		join("\t", $self->symid($rsymname, $release), $reltype, '');
}

sub getrelations {
	my ($self, $symname, $release) = @_;
}

sub fileid {
	my ($self, $filename, $revision, $update) = @_;
	my ($fileid);

	# CAUTION: $revision is not $release!

	unless (defined($fileid = $$self{'files'}{"$filename\t$revision"})) {
		$$self{'fst'}->execute($filename, $revision);
		($fileid) = $$self{'fst'}->fetchrow_array();
		unless ($fileid) {
			return undef unless $update;

			$$self{'fsq'}->execute();
			($fileid) = $$self{'fsq'}->fetchrow_array();
			$$self{'fup'}->execute($filename, $revision, $fileid);
		}
		$$self{'files'}{"$filename\t$revision"} = $fileid;
	}
	return $fileid;
}

# Indicate that this filerevision is part of this release
sub release {
	my ($self, $fileid, $release) = @_;

	my $rows = $$self{'rst'}->execute($fileid+0, $release);
	$$self{'rst'}->finish();

	unless ($rows > 0) {
		$$self{'rup'}->execute($fileid, $release);
	}
}

# Convert from fileid to filename
sub filename {
	my ($self, $fileid) = @_;
}

sub symid {
	my ($self, $symname) = @_;
	my ($symid);

	unless (defined($symid = $$self{'symbols'}{$symname})) {
		$$self{'sst'}->execute($symname);
		($symid) = $$self{'sst'}->fetchrow_array();
		unless ($symid) {
			$$self{'ssq'}->execute();
			($symid) = $$self{'ssq'}->fetchrow_array();
			$$self{'sup'}->execute($symname, $symid);
		}
		$$self{'symbols'}{$symname} = $symid;
	}

	return $symid;
}

sub issymbol {
	my ($self, $symname, $release) = @_;

	unless (exists($$self{'symcache'}{$symname})) {
		$$self{'sst'}->execute($symname);
		($$self{'symcache'}{$symname}) = $$self{'sst'}->fetchrow_array();
	}
	
	return $$self{'symcache'}{$symname};
}

sub commit {
	my ($self) = @_;

	$$self{'fst'} = undef;
	$$self{'fsq'} = undef;
	$$self{'fup'} = undef;
	$$self{'sst'} = undef;
	$$self{'ssq'} = undef;
	$$self{'sup'} = undef;
	$$self{'iup'} = undef;

	$$self{'dbh'}->commit();
	$$self{'dbh'}->disconnect();
}


1;
