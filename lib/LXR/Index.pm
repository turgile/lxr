# -*- tab-width: 4 -*- ###############################################
#
# $Id: Index.pm,v 1.4 1999/05/16 23:48:27 argggh Exp $

package LXR::Index;

$CVSID = '$Id: Index.pm,v 1.4 1999/05/16 23:48:27 argggh Exp $ ';

use strict;

sub new {
	my ($self, $dbname) = @_;
	my $index;

	if ($dbname =~ /^DBI:/i) {
		require LXR::Index::DBI;
		$index = new LXR::Index::DBI($dbname);
	}
#	elsif ($dbname =~ /^DBM:/i) {
	else {
		print(STDERR "Bar: Fnord!", caller, "\n");
		require LXR::Index::DB;
		$index = new LXR::Index::DB($dbname);
	}
	return $index;
}


1;
