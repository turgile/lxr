# -*- tab-width: 4 -*- ###############################################
#
# $Id: Files.pm,v 1.4 1999/05/22 10:52:01 argggh Exp $

package LXR::Files;

$CVSID = '$Id: Files.pm,v 1.4 1999/05/22 10:52:01 argggh Exp $ ';

use strict;

sub new {
	my ($self, $srcroot) = @_;
	my $files;

	if (($srcroot) = $srcroot =~ /^CVS:(.*)/i) {
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
