# -*- tab-width: 4 -*- ###############################################
#
# $Id: Index.pm,v 1.7 2001/05/31 14:45:09 mbox Exp $

package LXR::Index;

$CVSID = '$Id: Index.pm,v 1.7 2001/05/31 14:45:09 mbox Exp $ ';

use LXR::Common;
use strict;

sub new {
	my ($self, $dbname, @args) = @_;
	my $index;

	if ($dbname =~ /^DBI:/i) {
		require LXR::Index::DBI;
		$index = new LXR::Index::DBI($dbname, @args);
	}
	elsif ($dbname =~ /^DBM:/i) {
	  require LXR::Index::DB;
	  $index = new LXR::Index::DB($dbname, @args);
	}
	else {
	  die "Can't find database";
	}
	return $index;
}


1;
