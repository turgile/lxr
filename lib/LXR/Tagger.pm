# -*- tab-width: 4 -*- ###############################################
#
# $Id: Tagger.pm,v 1.2 1999/05/14 12:45:30 argggh Exp $

use strict;

package LXR::Tagger;

my %typemap = ('.c' => 'c',
			   '.h' => 'c',
			   '.java' => 'java');
			   
sub processfile {
	my ($pathname, $release, $config, $files, $index) = @_;
	my $filetype = $typemap{$1} if $pathname =~ /([^\.]+)$/;

	print(STDERR "Foo: $pathname, $filetype\n");
}



# Ctags
package LXR::Tagger::ctags;

# Excuberant ctags
package LXR::Tagger::ectags;

#  			open(TMP, "> /tmp/lxrref");
#  			print(TMP $files->getfile($pathname, $release));
#  			close(TMP);
			
#  			open(CTAGS, $Conf->ctagsbin." --excmd=number --lang=c++ --c-types=cdefgmnpstuvx -f - /tmp/lxrref |") 
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
