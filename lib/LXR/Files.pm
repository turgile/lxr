# -*- tab-width: 4 -*- ###############################################
#
# $Id: Files.pm,v 1.11 2009/03/26 17:15:28 mbox Exp $

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

package LXR::Files;

$CVSID = '$Id: Files.pm,v 1.11 2009/03/26 17:15:28 mbox Exp $ ';

use strict;

sub new {
	my ( $self, $srcroot, $params ) = @_;
	my $files;

	if ( $srcroot =~ /^CVS:(.*)/i ) {
		require LXR::Files::CVS;
		$srcroot = $1;
		$files   = new LXR::Files::CVS($srcroot);
	}
	elsif ( $srcroot =~ /^bk:(.*)/i ) {
		require LXR::Files::BK;
		$srcroot = $1;
		$files   = new LXR::Files::BK($srcroot, $params);
	}
	elsif ( $srcroot =~ /^git:(.*)/i ) {
		require LXR::Files::GIT;
		$srcroot = $1;
		$files   = new LXR::Files::GIT($srcroot, $params);
	}
	else {
		require LXR::Files::Plain;
		$files = new LXR::Files::Plain($srcroot);
	}
	return $files;
}

# Stub implementations of the Files interface

sub getdir {
	my $self = shift;
	warn  "::getdir not implemented. Parameters @_";
}

sub getfile {
	my $self = shift;
	warn  "::getfile not implemented. Parameters @_";
}

sub getannotations {
	my $self = shift;
	warn  "::getannotations not implemented. Parameters @_";
}

sub getauthor {
	my $self = shift;
	warn  "::getauthor not implemented. Parameters @_";
}

sub filerev {
	my $self = shift;
	warn  "::filerev not implemented. Parameters @_";
}

sub getfilehandle {
	my $self = shift;
	warn  "::getfilehandle not implemented. Parameters @_";
}

sub getfilesize {
	my $self = shift;
	warn  "::getfilesize not implemented. Parameters @_";
}

sub getfiletime {
	my $self = shift;
	warn  "::getfiletime not implemented. Parameters @_";
}

sub getindex {
	my $self = shift;
	warn  "::getindex not implemented. Parameters @_";
}

sub isdir {
	my $self = shift;
	warn  "::isdir not implemented. Parameters: @_";
}

sub isfile {
	my $self = shift;
	warn  "::isfile not implemented. Parameters: @_";
}

sub tmpfile {
	my $self = shift;
	# FIXME: This function really sucks and should be removed :)
	warn  "::tmpfile not implemented. Parameters: @_";
}

sub toreal {
	# FIXME: this function should probably not exist, since it doesn't make sense for 
	# all file access methods
	warn "toreal called - obsolete";
	return undef;
}

1;
