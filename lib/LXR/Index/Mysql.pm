# -*- tab-width: 4 perl-indent-level: 4-*-
###############################
#
# $Id: Mysql.pm,v 1.37 2013/11/07 19:39:22 ajlittoz Exp $
#
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
#
###############################

package LXR::Index::Mysql;

$CVSID = '$Id: Mysql.pm,v 1.37 2013/11/07 19:39:22 ajlittoz Exp $ ';

use strict;
use DBI;
use LXR::Common;

our @ISA = ('LXR::Index');

sub new {
	my ($self, $config) = @_;

	$self = bless({}, $self);
	$self->{dbh} = DBI->connect	( $config->{'dbname'}
								, $config->{'dbuser'}
								, $config->{'dbpass'}
								, {'AutoCommit' => 0}
								)
#	MySQL seems to be neutral vis-à-vis auto commit mode, though
#	a tiny improvement may show up with explicit commit (the
#	difference on the medium-sized test cases is difficult to
#	appreciate since it is within the measurement error).
		or die "Can't open connection to database: $DBI::errstr\n";

	my $prefix = $config->{'dbprefix'};

	$self->{'last_auto_val'} = 
		$self->{dbh}->prepare('select last_insert_id()');

	$self->{'files_insert'} =
		$self->{dbh}->prepare
			( "insert into ${prefix}files"
			. ' (filename, revision, fileid)'
			. ' values (?, ?, NULL)'
			);

	$self->{'symbols_insert'} =
		$self->{dbh}->prepare
			( "insert into ${prefix}symbols"
			. ' (symname, symid, symcount)'
			. ' values ( ?, NULL, 0)'
			);

	$self->{'langtypes_insert'} =
		$self->{dbh}->prepare
			( "insert into ${prefix}langtypes"
			. ' (typeid, langid, declaration)'
			. ' values (NULL, ?, ?)'
			);

	$self->{'purge_all'} = $self->{dbh}->prepare
		( "call ${prefix}purgeall()"
		);

	return $self;
}

sub fileid {
# 	my ($self, $filename, $revision) = @_;
	my $self = shift @_;
	my $fileid;

	$fileid = $self->fileidifexists(@_);
	unless ($fileid) {
		$self->{'files_insert'}->execute(@_);
		$self->{'last_auto_val'}->execute();
		($fileid) = $self->{'last_auto_val'}->fetchrow_array();
		$self->{'status_insert'}->execute($fileid, 0);
# opt	$self->{'last_auto_val'}->finish();
# 		$files{"$filename\t$revision"} = $fileid;
	}
	return $fileid;
}

sub symid {
	my ($self, $symname) = @_;
	my $symid;
	my $symcount;

	$symid = $LXR::Index::symcache{$symname};
	unless (defined($symid)) {
		$self->{'symbols_byname'}->execute($symname);
		($symid, $symcount) = $self->{'symbols_byname'}->fetchrow_array();
		unless ($symid) {
			$self->{'symbols_insert'}->execute($symname);
            # Get the id of the new symbol
			$self->{'last_auto_val'}->execute();
			($symid) = $self->{'last_auto_val'}->fetchrow_array();
			$symcount = 0;
		}
		$LXR::Index::symcache{$symname} = $symid;
		$LXR::Index::cntcache{$symname} = -$symcount;
	}
	return $symid;
}

sub decid {
# 	my ($self, $lang, $string) = @_;
	my $self = shift @_;
	my $id;

	$self->{'langtypes_select'}->execute(@_);
	($id) = $self->{'langtypes_select'}->fetchrow_array();
	unless (defined($id)) {
		$self->{'langtypes_insert'}->execute(@_);
		$self->{'last_auto_val'}->execute();
		($id) = $self->{'last_auto_val'}->fetchrow_array();
	}
# opt	$self->{'last_auto_val'}->finish();
	return $id;
}

sub final_cleanup {
	my ($self) = @_;

	$self->commit();
	$self->{'last_auto_val'} = undef;
	$self->{'files_select'} = undef;
	$self->{'releases_select'} = undef;
	$self->{'status_select'} = undef;
	$self->{'langtypes_select'} = undef;
	$self->{'symbols_byname'} = undef;
	$self->{dbh}->disconnect() or die "Disconnect failed: $DBI::errstr";
}

1;
