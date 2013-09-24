# -*- tab-width: 4 -*-
###############################################
#
# $Id: VTescape.pm,v 1.2 2013/09/24 15:24:07 ajlittoz Exp $
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
#
###############################################

# $Id: VTescape.pm,v 1.2 2013/09/24 15:24:07 ajlittoz Exp $

package VTescape;

use strict;

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
	$CSI    $VTbold   $VTfast  $VTinvert $VTnorm
	$VTslow $VTunder
	$VTred  $VTyellow $VTgreen $VTcyan $VTblue $VTmagenta
	$VTblack          $VTwhite
	VTCUU VTCUD VTCUF VTCUB VTCNL VTCPL VTCHA VTCUP
	VTDL  VTDSR VTED  VTEL  VTHVP VTICH VTIL  VTRCP
	VTSCP VTSD  VTSSR VTSU
);

# Some ANSI escape sequences to highlight error messages in output
our $CSI      = "\x1b[";	# CSI = esc [
our $VTnorm   = "${CSI}0m";
our $VTbold   = "${CSI}1m";
our $VTunder  = "${CSI}4m";
our $VTslow   = "${CSI}5m";
our $VTfast   = "${CSI}6m";
our $VTinvert = "${CSI}7m";
our $VTred    = "${VTbold}${CSI}31m";
our $VTyellow = "${VTbold}${CSI}33m";
our $VTgreen  = "${VTbold}${CSI}32m";
our $VTcyan   = "${VTbold}${CSI}36m";
our $VTblue   = "${VTbold}${CSI}34m";
our $VTmagenta= "${VTbold}${CSI}35m";
our $VTblack  = "${VTbold}${CSI}30m";
our $VTwhite  = "${VTbold}${CSI}37m";

# ICH = Insert blank CHaracters
sub VTICH {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. '@';
}

# CUU = CUrsor Up
sub VTCUU {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'A';
}

# CUD = CUrsor Down
sub VTCUD {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'B';
}

# CUF = CUrsor Forward
sub VTCUF {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'C';
}

# CUB = CUrsor Backward
sub VTCUB {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'D';
}

# CNL = Cursor beginning of Next Line
sub VTCNL {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'E';
}

# CPL = Cursor beginning of Previous Line
sub VTCPL {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'F';
}

# CHA = Cursor Horizontal Absolute
sub VTCHA {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'G';
}

# CUP = CUrsor Position
sub VTCUP {
	my ($row, $col) = @_;
	return $CSI . $row . ';' . $col . 'H';
}

# ED = Erase Data (0->EOS, BOS->1, 2:screen)
sub VTED {
	my $n = shift;
	$n = 0 if $n > 2;
	return $CSI
		. ($n>0 ? $n : '')
		. 'J';
}

# EL = Erase Line (0->EOL, BOL->1, 2:line)
sub VTEL {
	my $n = shift;
	$n = 0 if $n > 2;
	return $CSI
		. ($n>0 ? $n : '')
		. 'K';
}

# IL = Insert Lines
sub VTIL {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'L';
}

# DL = Delete Lines
sub VTDL {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'M';
}

# SU = Scroll Up
sub VTSU {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'S';
}

# SD = Scroll Down
sub VTSD {
	my $n = shift;
	return $CSI
		. ($n>1 ? $n : '')
		. 'T';
}

# HVP = Horizontal and Vertical Position (= CUP)
sub VTHVP {
	my ($row, $col) = @_;
	return $CSI . $row . ';' . $col . 'f';
}

# DSR = Device Status Report
#	Returns: (row, column) of cursor current position
#
# CAUTION! may be very Linux specific, portability not tested
# NOTE: to be used as a function outside any print statement
sub VTDSR {
	# Put terminal in transparent mode (otherwise a manual
	# <return> is necessary to report back the string.
	# Suppress echo, so that status report is not displayed
	system('stty -icanon min 1 time 0 -echo');
	# Cause transmission on last character of status report
	my $oldinpsep = $/;
	$/ = 'R';
	# Better be that STDOUT and STDERR point to the same device!!!
	print STDERR $CSI, '6n';
	my $status = <STDIN>;
	# Revert everything
	$/ = $oldinpsep;
	system ('stty icanon echo');
	$status =~ m/\[(\d+);(\d+)R/;
	return ($1, $2);
}

# SSR (non-standardized name) = Set Scrolling Region
# CAUTION! $top <= $bottom not checked!
sub VTSSR {
	my ($top, $bottom) = @_;
	return $CSI
		. $top . ';' . $bottom
		. 'r';
}


# SCP = Save Cursor Position
sub VTSCP {
	return $CSI . 's';
}

# RCP = Restore Cursor Position
sub VTRCP {
	return $CSI . 'u';
}

# SGR = Select Graphic Rendition, see $VTxxx


1;
