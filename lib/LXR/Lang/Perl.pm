# -*- tab-width: 4 -*- ###############################################
#
# $Id: Perl.pm,v 1.1 1999/09/17 09:37:45 argggh Exp $

package LXR::Lang::Perl;

$CVSID = '$Id: Perl.pm,v 1.1 1999/09/17 09:37:45 argggh Exp $ ';

=head1 LXR::Lang::Perl

Da Perl package, man!

=cut

use strict;
use LXR::Common;
use LXR::Lang;

use vars qw(@ISA);
@ISA = ('LXR::Lang');

my @spec = (
			'atom'		=> ('\$\W?',	''),
			'atom'		=> ('\\\\.',	''),
			'include'	=> ('\buse\s+',	';'),
			'string'	=> ('"',		'"'),
			'comment'	=> ('#',		"\$"),
			'comment'	=> ("^=\\w+",	"^=cut"),
			'string'	=> ("'",		"'"));


sub new {
	my ($self, $pathname, $release) = @_;

	$self = bless({}, $self);

	$$self{'release'} = $release;

   	return $self;
}

sub parsespec {
	return @spec;
}

sub processcode {
	my ($self, $code, @itag) = @_;
	my $sym;

#	$$code =~ s#([\@\$\%\&\*])([a-z0-9_]+)|\b([a-z0-9_]+)(\s*\()#
#		$sym = $2 || $3;
#		$1.($index->issymbol($sym, $$self{'release'})
#			? join($sym, @{$$self{'itag'}})
#			: $sym).$4#geis;
	
	$$code =~ s#\b([a-z][a-z0-9_:]*)\b#
		($index->issymbol($1, $$self{'release'})
		 ? join($1, @{$$self{'itag'}})
		 : $1)#geis;
}

sub processinclude {
	my ($self, $frag, $dir) = @_;
	
	$$frag =~ s/(use\s*)(\w+)/$1.&LXR::Common::incref($2, ".pm")/e;
}

sub processcomment {
	my ($self, $comm) = @_;

	if ($$comm =~ /^=/s) {
		# Pod text

		$$comm = join('', map {
			if (/^=head(\d)\s*(.*)/s) {
				"<span class=pod><font size=\"+".(4-$1)."\">$2<\/font></span>";
			}
			elsif (/^=item\s*(.*)/s) {
				"<span class=podhead>* $1 ".
					("-" x (67 - length($1)))."<\/span>";
			}
			elsif (/^=(pod|cut)/s) {
				"<span class=podhead>".
					("-" x 70)."<\/span>";
			}
			elsif (/^=.*/s) {
				"";
			}
			else {
				if (/^\s/s) {	# Verbatim paragraph
					s|^(.*)$|<span class=pod><code>$1</code></span>|gm;
				}
				else {			# Normal paragraph
					s|^(.*)$|<span class=pod>$1</span>|gm;
					s/C\0\<(.*?)\0\>/<code>$1<\/code>/g;
				}
				$_;
			}
		} split(/((?:\n[ \t]*)*\n)/, $$comm));
	}
	else {
		$$comm =~ s|^(.*)$|<b><i>$1</i></b>|gm;
	}
}


sub indexfile {
	my ($self, $name, $path, $fileid, $index, $config) = @_;

	open(PLTAG, $path);
		
	while (<PLTAG>) {
		if (/^sub\s+(\w+)/) {
			print(STDERR "Sub: $1\n");
			$index->index($1, $fileid, $., 'f');
		}
		elsif (/^package\s+([\w:]+)/) {
			print(STDERR "Class: $1\n");
			$index->index($1, $fileid, $., 'c');
		}
		elsif (/^=item\s+[\@\$\%\&\*]?(\w+)/) {
			print(STDERR "Doc: $1\n");
			$index->index($1, $fileid, $., 'i');
		}
	}
	close(PLTAG);
}

