# -*- tab-width: 4 perl-indent-level: 4-*- ###############################
#
# $Id: DBI.pm,v 1.24 2009/05/14 21:13:07 mbox Exp $

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

# This is an abstract package as it doesn't redefine any of the 
# subroutines defined by LXR::Index and instead relies on 
# there being derived classes that provide a concrete implementation 
package LXR::Index::DBI;

$CVSID = '$Id: DBI.pm,v 1.24 2009/05/14 21:13:07 mbox Exp $ ';

use strict;

sub new {
	my ($self, $dbname) = @_;
	my ($index);

	if ($dbname =~ /^dbi:mysql:/i) {
		require LXR::Index::Mysql;
		$index = new LXR::Index::Mysql($dbname);
	} elsif ($dbname =~ /^dbi:Pg:/i) {
		require LXR::Index::Postgres;
		$index = new LXR::Index::Postgres($dbname);
	} elsif ($dbname =~ /^dbi:oracle:/i) {
		require LXR::Index::Oracle;
		$index = new LXR::Index::Oracle($dbname);
	}
	return $index;
}


1;
