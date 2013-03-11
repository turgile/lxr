# -*- tab-width: 4 -*-
###############################################
#
# $Id: Ruby.pm,v 1.3 2013/03/11 16:11:43 ajlittoz Exp $
#
# Enhances the support for the Ruby language over that provided by
# Generic.pm
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

package LXR::Lang::Ruby;

$CVSID = '$Id: Ruby.pm,v 1.3 2013/03/11 16:11:43 ajlittoz Exp $ ';

use strict;
use LXR::Common;
use LXR::Lang;
require LXR::Lang::Generic;

@LXR::Lang::Ruby::ISA = ('LXR::Lang::Generic');

# Process a Ruby include directive
sub processinclude {
	my ($self, $frag, $dir) = @_;

	my $source = $$frag;
	my $dirname;	# include directive name
	my $spacer;		# spacing
	my $file;		# language include file
	my $path;		# OS include file
	my $lsep;		# left separator
	my $rsep;		# right separator
	my $link;		# link to include file
	my $tail;		# lower-lever links after current $link
	my $identdef = $self->langinfo('identdef');

	if ($source =~ s/^				# Parse instruction
				([\w\#]\s*[\w]*)	# reserved keyword for include construct
				(\s+)				# space
				(?|	(\")(.+?)(\")	# double quoted string
				|	(\')(.+?)(\')	# single quoted string
				)
				//sx) {		# Parse directive
		# Guard against syntax error or unexpected variant
		# Advance past keyword, so that parsing may continue without loop.
		$source =~ s/^($identdef)//;	# Erase keyword
		$dirname = $1;
		$$frag =	"<span class='reserved'>$dirname</span>";
		&LXR::SimpleParse::requeuefrag($source);
		return;
	}
	$dirname = $1;
	$spacer  = $2;
	$lsep    = $3;
	$file    = $4;
	$path    = $file;
	$rsep    = $5;

	$path =~ s@(?<!\.rb)$@.rb@;
	$link = &LXR::Common::incref($file, "include" ,$path ,$dir);
	if (!defined($link)) {
		$tail = $file if $path !~ m!/!;
	}
	while	(	$file =~ m!/!
			&&	substr($link, 0, 1) ne '<'
			) {
		$file =~ s!(/[^/]*)$!!;
		$tail = $1 . $tail;
		$path =~ s!/[^/]+$!!;
		$link = &LXR::Common::incdirref($file, "include", $path, $dir);
	}
	if (substr($link, 0, 1) eq '<') {
		while ($path =~ m!/!) {
			$link =~ s!^([^>]+>)([^/]*/)+?!$1!;
			$tail = '/' . $link . $tail;
			$file =~ s!/[^/]*$!!;
			$path =~ s!/[^/]+$!!;
			$link = &LXR::Common::incdirref($file, "include", $path, $dir);
		}
	}
# 	if (defined($link)) {
# 		while ($file =~ m!/!) {
# 			$link =~ s!^([^>]+>)([^/]*/)+!$1!g;
# 			$file =~ s!/[^/]*$!!;
# 			$path =~ s!/[^/]+$!!;
# 			$link = &LXR::Common::incdirref($file, "include", $path, $dir)
# 					. "/"
# 					. $link ;
# 		}
# 	} else {
# 		$link = $file;
# 	}
	# Rescan the unused part of the source line
	&LXR::SimpleParse::requeuefrag($source);

	$$frag =	"<span class='reserved'>$dirname</span>"
			.	$spacer
			.	$lsep
			.	$link
			.	$tail
			.	$rsep;
}

1;
