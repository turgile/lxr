# -*- tab-width: 4 -*- ###############################################
#
# $Id: C.pm,v 1.1 1999/09/17 09:37:45 argggh Exp $

package LXR::Lang::C;

$CVSID = '$Id: C.pm,v 1.1 1999/09/17 09:37:45 argggh Exp $ ';

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
						 "--lang=c++",
						 "--c-types=cdefgmnpstuvx",
						 "-f", "-",
						 $path, "|"));

		while (<CTAGS>) {
			chomp;
				
			@_ = split(/\t/, $_);
			$_[2] =~ s/;\"$//;
				
			if ($_[4] =~ /^(struct|union|class):(.*)/) {
				$_[4] = $2;
				$_[4] =~ s/::<anonymous>//g;
			}
			else {
				$_[4] = undef;
			}

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

	require SimpleParse;
	&SimpleParse::init(new FileHandle($path), $self->parsespec);

	my $linenum = 1;
	my ($btype, $frag) = &SimpleParse::nextfrag;
	my @lines;
	my $ls;

	while (defined($frag)) {
		@lines = ($frag =~ /(.*?\n)/g, $frag =~ /[^\n]*$/);

		if ($btype eq 'comment' or $btype eq 'string' or $btype eq 'include') {
			$linenum += @lines - 1;
		}
		else {
			my $l;
			foreach $l (@lines) {
				foreach ($l =~ /(?:^|[^a-zA-Z_\#]) # Non-symbol chars.
						 (\~?_*[a-zA-Z][a-zA-Z0-9_]*) # The symbol.
						 \b/ogx)
				{
					$index->reference($_, $fileid, $linenum)
						if $index->issymbol($_);
                }

				$linenum++;
			}
			$linenum--;
		}
		($btype, $frag) = &SimpleParse::nextfrag;
	}
	print("+++ $linenum\n");

	exit if rand(50) < 1;
}


1;
