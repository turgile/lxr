# -*- tab-width: 4 -*- ###############################################
#
# $Id: DBI.pm,v 1.5 1999/05/17 23:43:52 argggh Exp $

package LXR::Index::DBI;

$CVSID = '$Id: DBI.pm,v 1.5 1999/05/17 23:43:52 argggh Exp $ ';

use strict;
use DBI;


sub new {
	my ($self, $dbname) = @_;

	$self = bless({}, $self);
	$$self{'dbh'} = DBI->connect($dbname);
	$$self{'dbh'}{'AutoCommit'} = 0;
	
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
		("select release from releases where fileid = ?");
	$$self{'rup'} = $$self{'dbh'}->prepare
		("insert into releases values (?, ?)");

	return $self;
}

sub index {
	my ($self, $symname, $release, $filename, $line, $type) = @_;

	$$self{'iup'}->execute($self->symid($symname, $release),
						   $self->fileid($filename, $release),
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
	my ($self, $filename, $release) = @_;
	my ($fileid);

	# FIXME: There's some release/revision mixup here.  Has to be fixed.
	# Ask the Files object which revision the file has in this release.
	# Remember to update releases table.

	unless (defined($fileid = $$self{'files'}{"$filename\t$release"})) {
		$$self{'fst'}->execute($filename, $release);
		($fileid) = $$self{'fst'}->fetchrow_array();
		unless ($fileid) {
			$$self{'fsq'}->execute();
			($fileid) = $$self{'fsq'}->fetchrow_array();
			$$self{'fup'}->execute($filename, $release, $fileid);
		}
		$$self{'files'}{"$filename\t$release"} = $fileid;
	}
	return $fileid;
}


# Convert from fileid to filename
sub filename {
	my ($self, $fileid) = @_;
}

# Convert from fileid to release
sub release {
	my ($self, $fileid) = @_;
}

sub symid {
	my ($self, $symname, $release) = @_;
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

sub DESTROY {
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
