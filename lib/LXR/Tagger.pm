# -*- tab-width: 4 -*- ###############################################
#
# $Id: Tagger.pm,v 1.4 1999/05/16 23:48:28 argggh Exp $

use strict;
use FileHandle;
use LXR::Lang;

package LXR::Tagger;

$CVSID = '$Id: Tagger.pm,v 1.4 1999/05/16 23:48:28 argggh Exp $ ';


sub processfile {
	my ($pathname, $release, $config, $files, $index) = @_;
#	my $filetype = $typemap{$1} if $pathname =~ /([^\.]+)$/;

	my $lang = new LXR::Lang($pathname);
#	print(STDERR "Foo: $pathname, $lang\n");

	return unless $lang;
	
	my $path = $files->tmpfile($pathname, $release);

	if (ref($lang) =~ /LXR::Lang::(C|Eiffel|Fortran|Java)/
		&& $config->ectagsbin) {

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
			
			$index->index($_[0], $release, $pathname, $_[2], $_[3]);
				
			if ($_[4] eq '') {
			}
			elsif ($_[4] =~ /^file:/) {
			}
			elsif ($_[4] =~ /^struct:(.*)/) {
				$index->relate($_[0], $release, $1, 'struct member');
			}
			elsif ($_[4] =~ /^union:(.*)/) {
				$index->relate($_[0], $release, $1, 'union member');
			}
			elsif ($_[4] =~ /^class:(.*)/) {
				$index->relate($_[0], $release, $1, 'class member');
			}
			else {
				print(STDERR "** Unknown : $_\n");
			}
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
	unlink($path);
}



# Ctags
package LXR::Tagger::ctags;

# Excuberant ctags
package LXR::Tagger::ectags;

#  			open(TMP, "> /tmp/lxrref");
#  			print(TMP $files->getfile($pathname, $release));
#  			close(TMP);
			
#  				|| die "Can't run ctags";
#  #		open(CTAGS, "ctags-3.2/ctags --excmd=number --sort=no --lang=c++ --c-types=cdefgmnpstuvx -f - ".$$files{'rootpath'}.$release.$pathname." |");
#  			while (<CTAGS>) {
#  				chomp;
#  				@_ = split(/\t/, $_);
#  				$_[2] =~ s/;\"$//;
				
#  				$index->index($_[0], $release, $pathname, $_[2], $_[3]);
				
#  				if ($_[4] eq '') {
#  				}
#  				elsif ($_[4] =~ /^file:/) {
#  				}
#  				elsif ($_[4] =~ /^struct:(.*)/) {
#  					$index->relate($_[0], $release, $1, 'struct member');
#  				}
#  				elsif ($_[4] =~ /^union:(.*)/) {
#  					$index->relate($_[0], $release, $1, 'union member');
#  				}
#  				elsif ($_[4] =~ /^class:(.*)/) {
#  					$index->relate($_[0], $release, $1, 'class member');
#  				}
#  				else {
#  					print(STDERR "** Unknown : $_\n");
#  				}
#  			}
#  			close(CTAGS);


1;
