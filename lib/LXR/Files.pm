# -*- tab-width: 4 -*- ###############################################
#
# $Id: Files.pm,v 1.3 1999/05/20 22:37:52 argggh Exp $

package LXR::Files;

$CVSID = '$Id: Files.pm,v 1.3 1999/05/20 22:37:52 argggh Exp $ ';

use strict;

sub new {
	my ($self, $srcroot) = @_;
	my $files;

	if ($srcroot =~ /^CVS:(.*)/i) {
		require LXR::Files::CVS;
		$files = new LXR::Files::CVS($1);
	}
	else {
		require LXR::Files::Plain;
		$files = new LXR::Files::Plain($srcroot);
	}
	return $files;
}


1;
