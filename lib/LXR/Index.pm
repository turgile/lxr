# -*- tab-width: 4 -*- ###############################################
#
# $Id: Index.pm,v 1.3 1999/05/14 12:45:30 argggh Exp $

package LXR::Index;

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
