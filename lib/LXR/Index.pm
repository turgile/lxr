# -*- tab-width: 4 -*- ###############################################
#
# $Id: Index.pm,v 1.8 2001/08/04 17:42:16 mbox Exp $

package LXR::Index;

$CVSID = '$Id: Index.pm,v 1.8 2001/08/04 17:42:16 mbox Exp $ ';

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
	  die "Can't find database, $dbname";
	}
	return $index;
}

# TODO: Add skeleton code here to define the Index interface

1;
