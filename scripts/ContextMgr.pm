# -*- tab-width: 4 -*-
###############################################
#
# $Id: ContextMgr.pm,v 1.1 2013/01/11 11:53:13 ajlittoz Exp $
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

package ContextMgr;

use strict;
use lib do { $0 =~ m{(.*)/}; "$1" };
use QuestionAnswer;
use VTescape;


##############################################################
#
#				Define global parameters
#
##############################################################

require Exporter;
our @ISA = qw(Exporter);

our @EXPORT = qw(
	$cardinality $dbengine $dbenginechanged
	$dbpolicy    $dbname   $dbuser
	$dbpass      $dbprefix $nodbuser
	$nodbprefix
	&contextReload
	&contextSave
	&contextDB
);

our $cardinality;
our $dbengine;
our $dbenginechanged = 0;
our $dbpolicy;
our $dbname;
our $dbuser;
our $dbpass;
our $dbprefix;
our $nodbuser;
our $nodbprefix;

# WARNING:	remember to increment this number when changing the
#			set of state variables and/or their meaning.
my $context_version = 1;


##############################################################
#
#				Reload context file
#
##############################################################

sub contextReload {
	my ($verbose, $ctxtfile) = @_;
	my $reloadstatus = 0;

	if (my $c=open(SOURCE, '<', $ctxtfile)) {
		print "Initial context $ctxtfile is reloaded\n" if $verbose;
		#	Default record separator
		#	changed to read full file content at once and restored afterwards
		my $oldsep = $/;
		$/ = undef;
		my $context = <SOURCE>;
		$/ = $oldsep;
		close(SOURCE);
		my ($confout) =~ m/\n# Context .* with (.*?)\n/g;
		my $context_created;
		eval($context);
		if (!defined($context_created)) {
			print "${VTred}ERROR:${VTnorm} saved context file probably damaged!\n";
			print "Check variable not found\n";
			print "Delete or rename file $ctxtfile to remove lock.\n";
			exit 1;
		}
		if ($context_created != $context_version) {
			print "${VTred}ERROR:${VTnorm} saved context file probably too old!\n";
			print "Recorded state version = $context_created while expecting version = $context_version\n";
			print "It is wise to 'quit' now and add manually the new tree or reconfigure from scratch.\n";
			print "You can however try to restore the initial context at your own risk.\n";
			print "\n";
			print "${VTyellow}WARNING:${VTnorm} inconsistent answers can lead to LXR malfunction.\n";
			print "\n";
			if ('q' eq get_user_choice
				( 'Do you want to quit or manually restore context?'
				, 1
				, [ 'quit', 'restore' ]
				, [ 'q', 'r' ]
				) ) {
				exit 1;
			}
			$reloadstatus = 1;
		};

		if ($dbpolicy eq 't') {
			print "Your DB engine was: ${VTbold}";
			if ("m" eq $dbengine) {
				print "MySQL";
			} elsif ("o" eq $dbengine) {
				print "Oracle";
			} elsif ("p" eq $dbengine) {
				print "PostgreSQL";
			} elsif ("s" eq $dbengine) {
				print "SQLite";
			} else {
				print "???${VTnorm}\n";
				print "${VTred}ERROR:${VTnorm} saved context file damaged or tampered with!\n";
				print "Unknown database code '$dbengine'\n";
				print "Delete or rename file $ctxtfile to remove lock.\n";
				if ('q' eq get_user_choice
					( 'Do you want to quit or manually restore context?'
					, 1
					, [ 'quit', 'restore' ]
					, [ 'q', 'r' ]
					) ) {
					exit 1;
				}
				$reloadstatus = 1;
			};
		}
	} else {
		print "${VTyellow}WARNING:${VTnorm} could not reload context file ${VTbold}$ctxtfile${VTnorm}!\n";
		print "You may have deleted the context file or you moved the configuration\n";
		print "file out of the user-configuration directory without the\n";
		print "context companion file ${VTyellow}$ctxtfile${VTnorm}.\n";
		print "\n";
		print "You can now 'quit' to think about the situation or try to restore\n";
		print "the parameters by answering the following questions\n";
		print "(some clues can be gathered from reading configuration file).\n";
		print "\n";
		print "${VTyellow}WARNING:${VTnorm} inconsistent answers can lead to LXR malfunction.\n";
		print "\n";
		if ('q' eq get_user_choice
			( 'Do you want to quit or manually restore context?'
			, 1
			, [ 'quit', 'restore' ]
			, [ 'q', 'r' ]
			) ) {
			exit 1;
		};
		$reloadstatus = 1;
	}
	return $reloadstatus;
}


##############################################################
#
#			Save context for future additions
#
##############################################################

sub contextSave {
	my ($ctxtfile, $confout) = @_;

	if (open(DEST, '>', $ctxtfile)) {
		print DEST "# -*- mode: perl -*-\n";
		print DEST "# Context file associated with $confout\n";
		my @t = gmtime(time());
		my ($sec, $min, $hour, $mday, $mon, $year) = @t;
		my $date_time = sprintf	( "%04d-%02d-%02d %02d:%02d:%02d"
								, $year + 1900, $mon + 1, $mday
								, $hour, $min, $sec
								);
		print DEST "# Created $date_time UTC\n";
		print DEST "# Strictly internal, do not play with content\n";
		print DEST "\$context_created = $context_version;\n";
		print DEST "\n";
		print DEST "\$cardinality = '$cardinality';\n";
		print DEST "\$dbpolicy = '$dbpolicy';\n";
		print DEST "\$dbengine = '$dbengine';\n";
		if ("g" eq $dbpolicy) {
			print DEST "\$dbname = '$dbname';\n";
		}
		if ($nodbuser) {
			print DEST "\$nodbuser = 1;\n";
		} else {
			print DEST "\$dbuser = '$dbuser';\n";
			print DEST "\$dbpass = '$dbpass';\n";
		}
		if ($nodbprefix) {
			print DEST "\$nodbprefix = 1;\n";
		} else {
			print DEST "\$dbprefix = '$dbprefix'\n";
		}
		close(DEST)
		or print "${VTyellow}WARNING:${VTnorm} error $! when closing context file ${VTbold}$confout${VTnorm}!\n";
	} else {
		print "${VTyellow}WARNING:${VTnorm} could not create context file ${VTbold}$confout${VTnorm}, autoreload disabled!\n";
	}
}


##############################################################
#
#				Describe database context
#
##############################################################

sub contextDB {
	my ($verbose) = @_;

	$dbengine =  get_user_choice
			( 'Database engine?'
			, 1
			, [ 'mysql', 'oracle', 'postgres', 'sqlite' ]
			, [ 'm', 'o', 'p', 's' ]
			);

	#	Are we configuring for single tree or multiple trees?
	$cardinality = get_user_choice
			( 'Configure for single/multiple trees?'
			, 1
			, [ 's', 'm' ]
			, [ 's', 'm' ]
			);

	if ($cardinality eq 's') { 
		if ('y' eq get_user_choice
				( 'Do you intend to add other trees later?'
				, 2
				, [ 'yes', 'no' ]
				, [ 'y', 'n']
				)
			) {
			$cardinality = 'm';
			print "${VTyellow}NOTE:${VTnorm} installation switched to ${VTbold}multiple${VTnorm} mode\n";
			print "      but describe just a single tree.\n";
		} else {
			$dbpolicy   = 't';
			$nodbuser   = 1;
			$nodbprefix = 1;
		}
	}

	if ($cardinality eq 'm') {
		if ('o' ne $dbengine) {
			if ($verbose > 1) {
				print "The safest option is to create one database per tree.\n";
				print "You can however create a single database for all your trees with a specific set of\n";
				print "tables for each tree (though this is not recommended).\n";
			}
			$dbpolicy = get_user_choice
					( 'How do you setup the databases?'
					, 1
					, [ 'per tree', 'global' ]
					, [ 't', 'g' ]
					);
			if ($dbpolicy eq 'g') {	# Single global database
				if ('s' eq $dbengine) {
					$dbname = get_user_choice
						( 'Name of global SQLite database file? (e.g. /home/myself/SQL-databases/lxr'
						, -2
						, []
						, []
						);
				} else {
					$dbname = get_user_choice
						( 'Name of global database?'
						, -1
						, []
						, [ 'lxr' ]
						);
				}
				$nodbprefix = 1;
			}
		} else {
			if ($verbose > 1) {
				print "There is only one global database under Oracle.\n";
				print "The tables for each tree are identified by a unique prefix.\n";
			}
			$dbpolicy   = 'g';
			$nodbprefix = 1;
		}
		if ($verbose > 1) {
			print "All databases can be accessed with the same username and\n";
			print "can also be described under the same names.\n";
		}
		if ('n' eq get_user_choice
				( 'Will you share database characteristics?'
				, 1
				, [ 'yes', 'no' ]
				, [ 'y', 'n']
				)
			) {
			$nodbuser   = 1;
			$nodbprefix = 1;
		}
	} elsif ('o' eq $dbengine) {
		$dbpolicy = 'g';
		$nodbuser = undef;
	}

	if (!defined($nodbuser)) {
		if	(  $dbpolicy eq 'g'
			|| 'y' eq get_user_choice
				( 'Will you use the same username and password for all DBs?'
				, 1
				, [ 'yes', 'no' ]
				, [ 'y', 'n']
				)
			) {
			$dbuser = get_user_choice
				( '--- DB user name?'
				, -1
				, []
				, [ 'lxr' ]
				);
			$dbpass = get_user_choice
				( '--- DB password ?'
				, -1
				, []
				, [ 'lxrpw' ]
				);
		} else {
			$nodbuser = 1;
		}
	}

	if (!defined($nodbprefix)) {
		if ('y' eq get_user_choice
				( 'Will you give the same prefix to all tables?'
				, 1
				, [ 'yes', 'no' ]
				, [ 'y', 'n']
				)
			) {
			$dbprefix = get_user_choice
					( '--- Common table prefix?'
					, -1
					, []
					, [ 'lxr_' ]
					);
		}else {
			$nodbprefix = 1;
		}
	}
}


1;
