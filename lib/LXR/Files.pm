# -*- tab-width: 4 -*- ###############################################
#
# $Id: Files.pm,v 1.1 1999/05/14 20:27:09 argggh Exp $

package LXR::Files;

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
