# -*- tab-width: 4 -*- ###############################################
#
# $Id: Lang.pm,v 1.16 1999/09/17 09:37:41 argggh Exp $

package LXR::Lang;

$CVSID = '$Id: Lang.pm,v 1.16 1999/09/17 09:37:41 argggh Exp $ ';

use strict;
use LXR::Common;

sub new {
	my ($self, $pathname, $release, @itag) = @_;
	my $lang;

	if ($pathname =~ /\.([ch]|cpp?|cc)$/i) {
		require LXR::Lang::C;
		$lang = new LXR::Lang::C($pathname, $release);
	}
	elsif ($pathname =~ /\.java$/i) {
		require LXR::Lang::Java;
		$lang = new LXR::Lang::Java($pathname, $release);
	}
	elsif ($pathname =~ /\.py$/i) {
		require LXR::Lang::Python;
		$lang = new LXR::Lang::Python($pathname, $release);
	}
	elsif ($pathname =~ /\.p[lmh]$/i) {
		require LXR::Lang::Perl;
		$lang = new LXR::Lang::Perl($pathname, $release);
	}
	else {
		$lang = undef;
	}

	$$lang{'itag'} = \@itag if $lang;

	return $lang;
}

sub processinclude {
	my ($self, $frag, $dir) = @_;

	$$frag =~ s#(\")(.*?)(\")#
		$1.&LXR::Common::incref($2, '', $dir).$3#e;
	$$frag =~ s#(\0<)(.*?)(\0>)#
		$1.&LXR::Common::incref($2, '').$3#e;
}

sub processcomment {
	my ($self, $frag) = @_;

	$$frag = "<b><i>$$frag</i></b>";
	$$frag =~ s#\n#</i></b>\n<b><i>#g;
}

sub referencefile {
	my ($self) = @_;
		
	print(STDERR ref($self), "->referencefile not implemented.\n");
}


1;
