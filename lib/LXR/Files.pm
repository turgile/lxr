# -*- tab-width: 4 -*- ###############################################
#
# $Id: Files.pm,v 1.2 1999/05/16 23:48:27 argggh Exp $

package LXR::Files;

$CVSID = '$Id: Files.pm,v 1.2 1999/05/16 23:48:27 argggh Exp $ ';

use strict;

sub new {
	my ($self, $srcroot) = @_;
	my $files;

	if ($srcroot =~ /^CVS:/i) {
		require LXR::Files::CVS;
		$files = new LXR::Files::CVS($srcroot);
	}
	else {
		require LXR::Files::Plain;
		$files = new LXR::Files::Plain($srcroot);
	}
	return $files;
}


1;
