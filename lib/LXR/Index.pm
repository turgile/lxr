# -*- tab-width: 4 -*- ###############################################
#
#

package LXR::Index;

use strict;
use LXR::Index::DBI;
use LXR::Index::DB;

sub new {
    my ($index);

    if ($main::Conf->dbtype eq "dbi") {
	$index = new LXR::Index::DBI($main::Conf->dbname);
    } elsif ($main::Conf->dbtype eq "db") {
	$index = new LXR::Index::DB($main::Conf->dbname);
    }
    $index;
}

1;
