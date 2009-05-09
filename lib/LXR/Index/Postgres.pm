# -*- tab-width: 4 perl-indent-level: 4-*- ###############################
#
# $Id: Postgres.pm,v 1.28 2009/05/09 15:39:00 adrianissott Exp $

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

package LXR::Index::Postgres;

$CVSID = '$Id: Postgres.pm,v 1.28 2009/05/09 15:39:00 adrianissott Exp $ ';

use strict;
use DBI;
use LXR::Common;

use vars qw($dbh $transactions %files %symcache $commitlimit
  $files_select $filenum_nextval $files_insert
  $symbols_byname $symbols_byid $symnum_nextval
  $symbols_remove $symbols_insert $indexes_select $indexes_insert
  $releases_select $releases_insert $status_select $status_insert
  $status_update $usage_insert $usage_select $decl_select
  $declid_nextnum $decl_insert $delete_indexes $delete_usage
  $delete_status $delete_releases $delete_files $prefix);

sub new {
    my ($self, $dbname) = @_;

    $self = bless({}, $self);
    $dbh ||= DBI->connect($dbname, $config->{'dbuser'}, $config->{'dbpass'});
    die($DBI::errstr) unless $dbh;

    $$dbh{'AutoCommit'} = 0;

    #    $dbh->trace(1);

    if (defined($config->{'dbprefix'})) {
        $prefix = $config->{'dbprefix'};
    } else {
        $prefix = "lxr_";
    }

    $commitlimit  = 100;
    $transactions = 0;
    %files        = ();
    %symcache     = ();

    $files_select =
      $dbh->prepare("select fileid from ${prefix}files where filename = ? and revision = ?");
    $filenum_nextval = $dbh->prepare("select nextval('${prefix}filenum')");
    $files_insert    = $dbh->prepare("insert into ${prefix}files values (?, ?, ?)");

    $symbols_byname = $dbh->prepare("select symid from ${prefix}symbols where symname = ?");
    $symbols_byid   = $dbh->prepare("select symname from ${prefix}symbols where symid = ?");
    $symnum_nextval = $dbh->prepare("select nextval('${prefix}symnum')");
    $symbols_insert = $dbh->prepare("insert into ${prefix}symbols values (?, ?)");
    $symbols_remove = $dbh->prepare("delete from ${prefix}symbols where symname = ?");

    $indexes_select =
      $dbh->prepare("select f.filename, i.line, d.declaration, i.relsym "
          . "from ${prefix}symbols s, ${prefix}indexes i, ${prefix}files f, ${prefix}releases r, ${prefix}declarations d "
          . "where s.symid = i.symid and i.fileid = f.fileid "
          . "and f.fileid = r.fileid "
          . "and i.langid = d.langid and i.type = d.declid "
          . "and s.symname = ? and r.release = ? "
          . "order by f.filename, i.line, d.declaration");
    $indexes_insert =
      $dbh->prepare("insert into ${prefix}indexes (symid, fileid, line, langid, type, relsym) "
          . "values (?, ?, ?, ?, ?, ?)");

    $releases_select =
      $dbh->prepare("select * from ${prefix}releases where fileid = ? and release = ?");
    $releases_insert = $dbh->prepare("insert into ${prefix}releases values (?, ?)");
    $status_select = $dbh->prepare("select status from ${prefix}status where fileid = ?");
    $status_insert = $dbh->prepare
      ("insert into ${prefix}status (fileid, status) values (?, ?)");
    
    $status_update =
      $dbh->prepare("update ${prefix}status set status = ? where fileid = ? and status <= ?");

    $usage_insert = $dbh->prepare("insert into ${prefix}usage values (?, ?, ?)");
    $usage_select =
      $dbh->prepare("select f.filename, u.line "
          . "from ${prefix}symbols s, ${prefix}files f, ${prefix}releases r, ${prefix}usage u "
          . "where s.symid = u.symid "
          . "and f.fileid = u.fileid "
          . "and f.fileid = r.fileid and "
          . "s.symname = ? and r.release = ? "
          . "order by f.filename, u.line");

    $declid_nextnum = $dbh->prepare("select nextval('${prefix}declnum')");

    $decl_select =
      $dbh->prepare(
        "select declid from ${prefix}declarations where langid = ? and " . "declaration = ?");
    $decl_insert =
      $dbh->prepare(
        "insert into ${prefix}declarations (declid, langid, declaration) values (?, ?, ?)");

    $delete_indexes =
      $dbh->prepare("delete from ${prefix}indexes "
          . "where fileid in "
          . "  (select fileid from ${prefix}releases where release = ?)");
    $delete_usage =
      $dbh->prepare("delete from ${prefix}usage "
          . "where fileid in "
          . "  (select fileid from ${prefix}releases where release = ?)");
    $delete_status =
      $dbh->prepare("delete from ${prefix}status "
          . "where fileid in "
          . "  (select fileid from ${prefix}releases where release = ?)");
    $delete_releases = $dbh->prepare("delete from ${prefix}releases " . "where release = ?");
    $delete_files    =
      $dbh->prepare("delete from ${prefix}files "
          . "where fileid in "
          . "  (select fileid from ${prefix}releases where release = ?)");

    return $self;
}

sub END {
    $files_select    = undef;
    $filenum_nextval = undef;
    $files_insert    = undef;
    $symbols_byname  = undef;
    $symbols_byid    = undef;
    $symnum_nextval  = undef;
    $symbols_remove  = undef;
    $symbols_insert  = undef;
    $indexes_select  = undef;
    $indexes_insert  = undef;
    $releases_select = undef;
    $releases_insert = undef;
    $status_insert   = undef;
    $status_update   = undef;
    $usage_insert    = undef;
    $usage_select    = undef;
    $decl_select     = undef;
    $declid_nextnum  = undef;
    $decl_insert     = undef;
    $delete_indexes  = undef;
    $delete_usage    = undef;
    $delete_status   = undef;
    $delete_releases = undef;
    $delete_files    = undef;

    $dbh->commit();
    $dbh->disconnect();
    $dbh = undef;
}

#
# LXR::Index API Implementation
#

sub fileid {
    my ($self, $filename, $revision) = @_;
    my ($fileid);

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
    _commitIfLimit();
    return $fileid;
}

sub setfilerelease {
    my ($self, $fileid, $release) = @_;

    $releases_select->execute($fileid + 0, $release);
    my $firstrow = $releases_select->fetchrow_array();

    #    $releases_select->finish();

    unless ($firstrow) {
        $releases_insert->execute($fileid + 0, $release);
    }
    _commitIfLimit();
}

sub fileindexed {
    my ($self, $fileid) = @_;
    my ($status);

    $status_select->execute($fileid);
    $status = $status_select->fetchrow_array();
    $status_select->finish();

    if (!defined($status)) {
        $status = 0;
    }
    return $status;
}

sub setfileindexed {
    my ($self, $fileid) = @_;
    my ($status);
    
    $status_select->execute($fileid);
    $status = $status_select->fetchrow_array();
    $status_select->finish();

    if (!defined($status)) {
        $status_insert->execute($fileid + 0, 1);
    } else {
        $status_update->execute(1, $fileid, 0);
    }
}

sub filereferenced {
    my ($self, $fileid) = @_;
    my ($status);

    $status_select->execute($fileid);
    $status = $status_select->fetchrow_array();
    $status_select->finish();

    return defined($status) && $status == 2;
}

sub setfilereferenced {
    my ($self, $fileid) = @_;
    my ($status);
    
    $status_select->execute($fileid);
    $status = $status_select->fetchrow_array();
    $status_select->finish();

    if (!defined($status)) {
        $status_insert->execute($fileid + 0, 2);
    } else {
        $status_update->execute(2, $fileid, 1);
    }
}

sub symdeclarations {
  my ($self, $symname, $release) = @_;
  my ($rows, @ret);

  $rows = $indexes_select->execute("$symname", "$release");

  while ($rows-- > 0) {
    my @row = $indexes_select->fetchrow_array;

    $row[3] = $self->symname($row[3]); # convert the symid

    # Also need to remove trailing whitespace erroneously added by the db 
    # interface that isn't actually stored in the underlying db
    $row[2] =~ s/^(.+?)\s+$/$1/;

    push(@ret, \@row);
  }

  $indexes_select->finish();

  return @ret;
}

sub setsymdeclaration {
    my ($self, $symname, $fileid, $line, $langid, $type, $relsym) = @_;

    $indexes_insert->execute($self->symid($symname),
    $fileid, $line, $langid, $type, $relsym ? $self->symid($relsym) : undef);
    _commitIfLimit();
}

sub symreferences {
    my ($self, $symname, $release) = @_;
    my ($rows, @ret);

    $rows = $usage_select->execute("$symname", "$release");

    while ($rows-- > 0) {
        push(@ret, [ $usage_select->fetchrow_array ]);
    }

    $usage_select->finish();

    return @ret;
}

sub setsymreference {
    my ($self, $symname, $fileid, $line) = @_;

    $usage_insert->execute($fileid, $line, $self->symid($symname));
    _commitIfLimit();
}

sub issymbol {
    my ($self, $symname, $release) = @_; # TODO make use of $release

    unless (exists($symcache{$symname})) {
        $symbols_byname->execute($symname);
        ($symcache{$symname}) = $symbols_byname->fetchrow_array();
    }

    return $symcache{$symname};
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
    _commitIfLimit();
    return $symid;
}

sub symname {
    my ($self, $symid) = @_;
    my ($symname);

    $symbols_byid->execute($symid + 0);
    ($symname) = $symbols_byid->fetchrow_array();

    return $symname;
}

sub decid {
    my ($self, $lang, $string) = @_;

    my $rows = $decl_select->execute($lang, $string);
    $decl_select->finish();

    unless ($rows > 0) {
        $declid_nextnum->execute();
        my ($declid) = $declid_nextnum->fetchrow_array();
        $decl_insert->execute($declid, $lang, $string);
    }

    $decl_select->execute($lang, $string);
    my $id = $decl_select->fetchrow_array();
    $decl_select->finish();

    _commitIfLimit();
    return $id;
}

sub emptycache {
    %symcache = ();
}

sub purge {
    my ($self, $version) = @_;

    # we don't delete symbols, because they might be used by other versions
    # so we can end up with unused symbols, but that doesn't cause any problems
    $delete_indexes->execute($version);
    $delete_usage->execute($version);
    $delete_status->execute($version);
    $delete_releases->execute($version);
    $delete_files->execute($version);
    _commitIfLimit();
}

#
# Internal subroutines
#

sub _commitIfLimit {
    unless (++$transactions % $commitlimit) {
        $dbh->commit();
    }
}

1;
