# -*- tab-width: 4 -*- ###############################################
#
# $Id: SimpleParse.pm,v 1.7 1999/05/29 19:38:59 argggh Exp $

package SimpleParse;

$CVSID = '$Id: SimpleParse.pm,v 1.7 1999/05/29 19:38:59 argggh Exp $ ';

use strict;
use integer;

require Exporter;

use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);
@EXPORT = qw(&doparse &untabify &init &nextfrag);

my $fileh;			# File handle
my @frags;			# Fragments in queue
my @bodyid;			# Array of body type ids
my @open;			# Fragment opening delimiters
my @term;			# Fragment closing delimiters
my $split;			# Fragmentation regexp
my $open;			# Fragment opening regexp
my $tabwidth;		# Tab width

sub init {
    my @blksep;

    ($fileh, @blksep) = @_;

    while (@_ = splice(@blksep,0,3)) {
		push(@bodyid, $_[0]);
		push(@open, $_[1]);
		push(@term, $_[2]);
    }

    foreach (@open) {
		$open .= "($_)|";
		$split .= "$_|";
    }
    chop($open);
    
    foreach (@term) {
		next if $_ eq '';
		$split .= "$_|";
    }
    chop($split);

    $tabwidth = 8;
}


sub untabify {
    my $t = $_[1] || 8;

    $_[0] =~ s/^(\t+)/(' ' x ($t * length($1)))/ge; # Optimize for common case.
    $_[0] =~ s/([^\t]*)\t/$1.(' ' x ($t - (length($1) % $t)))/ge;
    return($_[0]);
}


sub nextfrag {
    my $btype = undef;
    my $frag = undef;
	my $line = '';

    while (1) {
		if ($#frags < 0) {
#	    my $line = $1 if $buffer =~ s/([^\n]*\n*)//;
			$line = $fileh->getline;
			
			if ($. == 1 &&
				$line =~ /^.*-[*]-.*?[ \t;]tab-width:[ \t]*([0-9]+).*-[*]-/) {
				$tabwidth = $1;
			}
			
#			&untabify($line, $tabwidth); # We inline this for performance.

			# Optimize for common case.
			$line =~ s/^(\t+)/' ' x ($tabwidth * length($1))/ge;
			$line =~ s/([^\t]*)\t/$1.(' ' x ($tabwidth - (length($1) % $tabwidth)))/ge;

			@frags = split(/($split)/o, $line);
		}

		last if $#frags < 0;
		
		unless ($frags[0]) {
			shift(@frags);

		}
		elsif (defined($frag)) {
			if (defined($btype)) {
				my $next = shift(@frags);
				
				$frag .= $next;
				last if $next =~ /^$term[$btype]$/;

			}
			else {
				last if $frags[0] =~ /^$open$/o;
				$frag .= shift(@frags);
			}
		}
		else {
			$frag = shift(@frags);
			if (defined($frag) && (@_ = $frag =~ /^$open$/o)) {
				# grep in a scalar context returns the number of times
				# EXPR evaluates to true, which is this case will be
				# the index of the first defined element in @_.

				my $i = 1;
				$btype = grep { $i &&= !defined($_) } @_;
			}
		}
    }
    $btype = $bodyid[$btype] if defined($btype);
    
    return($btype, $frag);
}


1;
