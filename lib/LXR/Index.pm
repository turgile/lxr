# -*- tab-width: 4 -*- ###############################################
#
# $Id: Index.pm,v 1.6 2000/10/31 12:52:11 argggh Exp $

package LXR::Index;

$CVSID = '$Id: Index.pm,v 1.6 2000/10/31 12:52:11 argggh Exp $ ';

use strict;

sub new {
	my ($self, $dbname, @args) = @_;
	my $index;

	if ($dbname =~ /^DBI:/i) {
		require LXR::Index::DBI;
		$index = new LXR::Index::DBI($dbname, @args);
	}
#	elsif ($dbname =~ /^DBM:/i) {
	else {
#		print(STDERR "Bar: Fnord!", caller, "\n");
		require LXR::Index::DB;
		$index = new LXR::Index::DB($dbname, @args);
	}
	return $index;
}


1;
