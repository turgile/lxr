# -*- tab-width: 4; cperl-indent-level: 4 -*- ###############################################
#
# $Id: Lang.pm,v 1.21 2001/08/04 17:45:32 mbox Exp $

package LXR::Lang;

$CVSID = '$Id: Lang.pm,v 1.21 2001/08/04 17:45:32 mbox Exp $ ';

use strict;
use LXR::Common;

sub new {
	my ($self, $pathname, $release, @itag) = @_;
	my ($lang, $type);

    foreach $type ($config->filetype) {
		if ($pathname =~ /$$type[1]/) {
			eval "require $$type[2]";
			my $create = "new $$type[2]".'($pathname, $release, $$type[0])';
			$lang = eval($create);
			die "Unable to create $$type[2] Lang object, $@" unless defined $lang;
			last;
        }
    }

	if (!defined $lang) {
        # Try to see if it's a script
		$files->getfile($pathname, $release) =~ /^#!\s*(\S+)/s;

		my $shebang = $1;
		
		if ($shebang =~ /perl/) {
			require LXR::Lang::Generic;
			$lang = new LXR::Lang::Generic($pathname, $release, 'Perl');
		} else {
			$lang = undef;
		}
	}

	$$lang{'itag'} = \@itag if $lang;

	return $lang;
}

sub processinclude {
	my ($self, $frag, $dir) = @_;

	$$frag =~ s#(\")(.*?)(\")#	 
	  $1.&LXR::Common::incref($2, $2, $dir).$3 #e;
		$$frag =~ s#(\0<)(.*?)(\0>)#  
		  $1.&LXR::Common::incref($2, $2).$3 #e;
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
