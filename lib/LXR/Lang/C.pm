# -*- tab-width: 4 -*- ###############################################
#
# $Id: C.pm,v 1.10 2001/08/15 15:50:27 mbox Exp $

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

package LXR::Lang::C;

$CVSID = '$Id: C.pm,v 1.10 2001/08/15 15:50:27 mbox Exp $ ';

use strict;
use LXR::Common;
use LXR::Lang;

use vars qw(@ISA);
@ISA = ('LXR::Lang');

my @spec = ('atom'		=> ('\\\\.',	''),
			'comment'	=> ('/\*',		'\*/'),
			'comment'	=> ('//',		"\$"),
			'string'	=> ('"',		'"'),
			'string'	=> ("'",		"'"),
			'include'	=> ('#include',	"\$"));

my @reserved = ('asm',' auto', 'break', 'case', 'char', 
				'continue', 'default', 'do', 'double', 
				'else', 'enum', 'extern', 'float', 'for', 
				'fortran', 'goto', 'if', 'int', 'long', 
				'register', 'return', 'short');

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

	$$code =~ s#(^|[^a-zA-Z_\#0-9])([a-zA-Z_~][a-zA-Z0-9_]*)\b#
		$1.($index->issymbol($2, $$self{'release'}) 
			? join($2, @{$$self{'itag'}})
			: $2)#ge;
}

sub indexfile {
	my ($self, $name, $path, $fileid, $index, $config) = @_;

	if ($config->ectagsbin) {
		open(CTAGS, join(" ", $config->ectagsbin,
						 "--excmd=number",
						 "--language-force=c++",
						 "--c-types=cdefgmnpstuvx",
						 "-f", "-",
						 $path, "|"));

		while (<CTAGS>) {
			chomp;
				
			@_ = split(/\t/, $_);
			$_[2] =~ s/;\"$//;
				
			if (defined($_[4]) && $_[4] =~ /^(struct|union|class|enum):(.*)/) {
				$_[4] = $2;
				$_[4] =~ s/::<anonymous>//g;
			}
			else {
				$_[4] = undef;
			}

			next if grep { $_[0] eq $_ } @reserved;

			$index->index($_[0], $fileid, $_[2], $_[3], $_[4]);
		}
		close(CTAGS);
	}
	else {
		system($config->ctagsbin, 
			   "-x",
#			   "--no-warn",
			   "--members", 
			   "--typedefs-and-c++",
			   "--language=c++", 
			   "--output=-",
			   $path);
	}
}


sub referencefile {
	my ($self, $name, $path, $fileid, $index, $config) = @_;

	require LXR::SimpleParse;
	&LXR::SimpleParse::init(new FileHandle($path), $self->parsespec);

	my $linenum = 1;
	my ($btype, $frag) = &LXR::SimpleParse::nextfrag;
	my @lines;
	my $ls;

	while (defined($frag)) {
		@lines = ($frag =~ /(.*?\n)/g, $frag =~ /[^\n]*$/);

		if(defined($btype)) {
			if($btype eq 'comment' or $btype eq 'string' or $btype eq 'include') {
				$linenum += @lines - 1;
			} else {
				print "BTYPE was: $btype\n";
			}
		}
		else {
			my $l;
			foreach $l (@lines) {
				foreach ($l =~ /(?:^|[^a-zA-Z_\#]) # Non-symbol chars.
  						 (\~?_*[a-zA-Z][a-zA-Z0-9_]*) # The symbol.
  						 \b/ogx)
  				{
#					print "considering $_\n";
					if($index->issymbol($_)) {
#						print "adding $_ to references\n";
						$index->reference($_, $fileid, $linenum);
					}

				}
				
  				$linenum++;
  			}
  			$linenum--;
  		}
  		($btype, $frag) = &LXR::SimpleParse::nextfrag;
  	}
	print("+++ $linenum\n");
}


1;
