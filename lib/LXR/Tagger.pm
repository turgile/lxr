# -*- tab-width: 4 -*- ###############################################
#
# $Id: Tagger.pm,v 1.12 1999/12/25 21:58:28 pergj Exp $

package LXR::Tagger;

$CVSID = '$Id: Tagger.pm,v 1.12 1999/12/25 21:58:28 pergj Exp $ ';

use strict;
use FileHandle;
use LXR::Lang;

sub processfile {
	my ($pathname, $release, $config, $files, $index) = @_;

	my $lang = new LXR::Lang($pathname, $release);

	return unless $lang;
	
	my $revision = $files->filerev($pathname, $release);

	return unless $revision;

	print(STDERR "--- $pathname $release $revision\n");
	
	my $fileid = $index->fileid($pathname, $revision);

	$index->release($fileid, $release);

	if ($index->toindex($fileid)) {
		$index->empty_cache();
		print(STDERR "--- $pathname $fileid\n");

		my $path = $files->tmpfile($pathname, $release);

		$lang->indexfile($pathname, $path, $fileid, $index, $config);
		unlink($path);
	}
}


sub processrefs {
	my ($pathname, $release, $config, $files, $index) = @_;

	my $lang = new LXR::Lang($pathname, $release);

	return unless $lang;
	
	my $revision = $files->filerev($pathname, $release);

	return unless $revision;

	print(STDERR "--- $pathname $release $revision\n");
	
	my $fileid = $index->fileid($pathname, $revision);

	if ($index->toreference($fileid)) {
		$index->empty_cache();
		print(STDERR "--- $pathname $fileid\n");

		my $path = $files->tmpfile($pathname, $release);

		$lang->referencefile($pathname, $path, $fileid, $index, $config);
		unlink($path);
	} else {
		print STDERR "$pathname was already referenced\n";
	}
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
