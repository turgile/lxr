# -*- tab-width: 4 perl-indent-level: 4-*- ###############################
#
# $Id: DBI.pm,v 1.15 1999/12/25 21:58:28 pergj Exp $

package LXR::Index::DBI;

$CVSID = '$Id: DBI.pm,v 1.15 1999/12/25 21:58:28 pergj Exp $ ';

use strict;

sub new {
	my ($self, $dbname) = @_;
	my ($index);

	if($dbname =~ /^dbi:mysql:/) {
		require LXR::Index::Mysql;
		$index = new LXR::Index::Mysql($dbname);
	} elsif($dbname =~ /^dbi:postgres:/) {
		require LXR::Index::Postgres;
		$index = LXR::Index::Posgres($dbname);
	} elsif($dbname =~ /^dbi:sybase:/) {
		require LXR::Index::Sybase;
		$index = LXR::Index::Sybase($dbname);
	}
	return $index;
}


1;
