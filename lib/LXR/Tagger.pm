# -*- tab-width: 4 -*- ###############################################
#
#

use strict;


package LXR::Tagger;

sub new {
    my ($name, index);

    if ($main::Conf->dbtype eq "dbi") {
	$index = new LXR::Index::DBI($main::Conf->dbname);
    } elsif ($main::Conf->dbtype eq "db") {
	$index = new LXR::Index::DB($main::Conf->dbname);
    }
    $index;
}



# Ctags
package LXR::Tagger::ctags;

# Excuberant ctags
package LXR::Tagger::ectags;


1;
