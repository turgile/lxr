# -*- tab-width: 4 perl-indent-level: 4-*- ###############################
#
# $Id: DBI.pm,v 1.16 2000/07/26 07:50:21 pergj Exp $

package LXR::Index::DBI;

$CVSID = '$Id: DBI.pm,v 1.16 2000/07/26 07:50:21 pergj Exp $ ';

use strict;

sub new {
	my ($self, $dbname) = @_;
	my ($index);

	if($dbname =~ /^dbi:mysql:/) {
		require LXR::Index::Mysql;
		$index = new LXR::Index::Mysql($dbname);
	} elsif($dbname =~ /^dbi:Pg:/) {
		require LXR::Index::Postgres;
		$index = new LXR::Index::Posgres($dbname);
	} elsif($dbname =~ /^dbi:sybase:/) {
		require LXR::Index::Sybase;
		$index = new LXR::Index::Sybase($dbname);
	}
	return $index;
}


1;
