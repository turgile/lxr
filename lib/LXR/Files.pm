# -*- tab-width: 4 -*- ###############################################
#
# $Id: Files.pm,v 1.5 1999/05/27 14:44:22 toffer Exp $

package LXR::Files;

$CVSID = '$Id: Files.pm,v 1.5 1999/05/27 14:44:22 toffer Exp $ ';

use strict;

sub new {
	my ($self, $srcroot) = @_;
	my $files;

	if ($srcroot =~ /^CVS:(.*)/i) {
		require LXR::Files::CVS;
		$srcroot = $1;
		$files = new LXR::Files::CVS($srcroot);
	}
	else {
		require LXR::Files::Plain;
		$files = new LXR::Files::Plain($srcroot);
	}
	return $files;
}


1;
