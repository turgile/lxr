# -*- tab-width: 4 -*- ###############################################
#
# $Id: Oracle.pm,v 1.4 2004/07/15 20:42:41 brondsem Exp $

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

package LXR::Index::Oracle;

$CVSID = '$Id: Oracle.pm,v 1.4 2004/07/15 20:42:41 brondsem Exp $ ';

use strict;
use DBI;
use LXR::Common;

use vars qw(%files %symcache @ISA);

@ISA = ("LXR::Index");

sub new {
	my ($self, $dbname) = @_;

	$self = bless({}, $self);
	
	$self->{dbh} = DBI->connect($dbname, $config->{dbuser}, $config->{dbpass}, { RaiseError => 1, AutoCommit => 1 })
			|| fatal "Can't open connection to database\n";

	%files = ();
	%symcache = ();

	$self->{files_select} = $self->{dbh}->prepare
		("select fileid from files where  filename = ? and  revision = ?");		
	$self->{files_insert} = $self->{dbh}->prepare
		("insert into files values (?, ?, filenum.nextval)");

	$self->{symbols_byname} = $self->{dbh}->prepare
		("select symid from symbols where  symname = ?");
	$self->{symbols_byid} = $self->{dbh}->prepare
		("select symname from symbols where symid = ?");
	$self->{symbols_insert} = $self->{dbh}->prepare
		("insert into symbols values ( ?, symnum.nextval)");
	$self->{symbols_remove} = $self->{dbh}->prepare
		("delete from symbols where symname = ?");

	$self->{indexes_select} = $self->{dbh}->prepare
		("select f.filename, i.line, i.type, i.relsym ".
		 "from symbols s, indexes i, files f, releases r ".
		 "where s.symid = i.symid and i.fileid = f.fileid ".
		 "and f.fileid = r.fileid ".
		 "and  s.symname = ? and  r.release = ? ");
	$self->{indexes_insert} = $self->{dbh}->prepare
		("insert into indexes values (?, ?, ?, ?, ?)");

	$self->{releases_select} = $self->{dbh}->prepare
		("select * from releases where fileid = ? and  release = ?");
		
	$self->{releases_insert} = $self->{dbh}->prepare
		("insert into releases values (?, ?)");

	$self->{status_get} = $self->{dbh}->prepare
		("select status from status where fileid = ?");

	$self->{status_insert} = $self->{dbh}->prepare
#		("insert into status select ?, 0 except select fileid, 0 from status");
		("insert into status values (?, ?)");

	$self->{status_update} = $self->{dbh}->prepare
		("update status set status = ? where fileid = ? and status <= ?");

	$self->{usage_insert} = $self->{dbh}->prepare
		("insert into usage values (?, ?, ?)");
	$self->{usage_select} = $self->{dbh}->prepare
		("select f.filename, u.line ".
		 "from symbols s, files f, releases r, usage u ".
		 "where s.symid = u.symid ".
		 "and f.fileid = u.fileid ".
		 "and u.fileid = r.fileid and ".
		 "s.symname = ? and  r.release = ? ".
		 "order by f.filename");

	$self->{delete_indexes} = $self->{dbh}->prepare
	  ("delete from indexes ".
		 "where fileid in ".
		 "  (select fileid from releases where release = ?)");
	$self->{delete_usage} = $self->{dbh}->prepare
	  ("delete from usage ".
		 "where fileid in ".
		 "  (select fileid from releases where release = ?)");
	$self->{delete_status} = $self->{dbh}->prepare
		("delete from status ".
		 "where fileid in ".
		 "  (select fileid from releases where release = ?)");
	$self->{delete_releases} = $self->{dbh}->prepare
		("delete from releases ".
		 "where release = ?");
	$self->{delete_files} = $self->{dbh}->prepare
		("delete from files ".
		 "where fileid in ".
		 "  (select fileid from releases where release = ?)");

	
	return $self;
}

sub index {
	my ($self, $symname, $fileid, $line, $type, $relsym) = @_;

	$self->{indexes_insert}->execute($self->symid($symname),
							 $fileid,
							 $line,
							 $type,
							 $relsym ? $self->symid($relsym) : undef);
}

sub reference {
	my ($self, $symname, $fileid, $line) = @_;

	$self->{usage_insert}->execute($fileid,
						   $line,
						   $self->symid($symname));

}

sub getindex {	# Hinzugef�gt von Variable @row, While-Schleife
	my ($self, $symname, $release) = @_;
	my ($rows, @ret, @row);

	$rows = $self->{indexes_select}->execute("$symname", "$release");
	
	while (@row = $self->{indexes_select}->fetchrow_array){
	    push (@ret,[@row]);
	}
	
	#while ($rows-- > 0) {
	#	push(@ret, [ $self->{indexes_select}->fetchrow_array ]);
	#}

	$self->{indexes_select}->finish();

	map { $$_[3] &&= $self->symname($$_[3]) } @ret;

	return @ret;
}

sub getreference {
	my ($self, $symname, $release) = @_;
	my ($rows, @ret, @row);
	
	$rows = $self->{usage_select}->execute("$symname", "$release");	

	while (@row = $self->{usage_select}->fetchrow_array){
	    push (@ret,[@row]);
	}
	
	#while ($rows-- > 0) {
	#	push(@ret, [ $self->{usage_select}->fetchrow_array ]);
	#}

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
	my (@row);
	my $rows = $self->{releases_select}->execute($fileid+0, $release);
	while (@row = $self->{releases_select}->fetchrow_array){
		    $rows=1;
	}	
	$self->{releases_select}->finish();

	unless ($rows > 0) {
		$self->{releases_insert}->execute($fileid+0, $release);
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

	$self->{symbols_byid}->execute($symid+0);
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

# If this file has not been indexed earlier, mark it as being indexed
# now and return true.  Return false if already indexed.
sub toindex {
	my ($self, $fileid) = @_;
	my ($status);

	$self->{status_get}->execute($fileid);
	$status = $self->{status_get}->fetchrow_array();
	$self->{status_get}->finish();

	if(!defined($status)) {
		$self->{status_insert}->execute($fileid+0, 0);
	}
	return $self->{status_update}->execute(1, $fileid, 0) > 0;
}

sub toreference {
	my ($self, $fileid) = @_;
	my ($rv);

	return $self->{status_update}->execute(2, $fileid, 1) > 0;
}

# This function should be called before parsing each new file, 
# if this is not done the too much memory will be used and
# tings will become very slow. 
sub empty_cache {
	%symcache = ();
}

sub purge {
	my ($self, $version) = @_;
	# we don't delete symbols, because they might be used by other versions
    # so we can end up with unused symbols, but that doesn't cause any problems
	$self ->{delete_indexes}->execute($version);
	$self ->{$delete_usage}->execute($version);
	$self ->{$delete_status}->execute($version);
	$self ->{$delete_releases}->execute($version);
	$self ->{$delete_files}->execute($version);
	}

sub DESTROY {
	my ($self) = @_;
	$self->{files_select} = undef;
	$self->{files_insert} = undef;
	$self->{symbols_byname} = undef;
	$self->{symbols_byid} = undef;
	$self->{symbols_insert} = undef;
	$self->{indexes_insert} = undef;
	$self->{releases_insert} = undef;
	$self->{status_insert} = undef;
	$self->{status_update} = undef;
	$self->{usage_insert} = undef;
	$self->{usage_select} = undef;
	$self->{delete_indexes} = undef;
	$self->{delete_useage} = undef;
	$self->{delete_status} = undef;
	$self->{delete_releases} = undef;
	$self->{delete_files} = undef;

	if($self->{dbh}) {
		$self->{dbh}->disconnect();
		$self->{dbh} = undef;
	}
}


1;
