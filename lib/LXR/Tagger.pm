# -*- tab-width: 4 -*- ###############################################
#
# $Id: Tagger.pm,v 1.8 1999/06/01 06:44:22 pergj Exp $

package LXR::Tagger;

$CVSID = '$Id: Tagger.pm,v 1.8 1999/06/01 06:44:22 pergj Exp $ ';

use strict;
use FileHandle;
use LXR::Lang;

sub processfile {
	my ($pathname, $release, $config, $files, $index) = @_;
#	my $filetype = $typemap{$1} if $pathname =~ /([^\.]+)$/;

	my $lang = new LXR::Lang($pathname);
#	print(STDERR "Foo: $pathname, $lang\n");

	return unless $lang;
	
	my $revision = $files->filerev($pathname, $release);

	return unless $revision;

	print(STDERR "--- $pathname $release $revision\n");
	
	my $fileid = $index->fileid($pathname, $revision);

	if ($fileid) {
		$index->release($pathname, $revision, $release);
		return;			# Already indexed.
	}

	$fileid = $index->fileid($pathname, $revision, 1);
	$index->release($pathname, $revision, $release);

	print(STDERR "--- $pathname $fileid\n");

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
			
			$index->index($_[0], $pathname, $revision, $_[2], $_[3]);
				
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
	# Python
	elsif (ref($lang) =~ /LXR::Lang::Python/) {
		
		my (@ptag_lines, @single_ptag, $module_name);
		
		if ($pathname =~ m|/(\w+)\.py$|) {
			$module_name = $1;
		}
		
		open(PYTAG, $path);
		while (<PYTAG>) {
			chomp;

			# Function definitions
			if ( $_ =~ /^\s*def\s+([^\(]+)/ ) {
				$index->index($module_name."\.$1", $pathname, $revision, $., "f");
			}
			# Class definitions 
			elsif ( $_ =~ /^\s*class\s+([^\(:]+)/ ) {
				$index->index($module_name."\.$1", $pathname, $revision, $., "c");
			}
			# Targets that are identifiers if occurring in an assignment..
			elsif ( $_ =~ /^(\w+) *=.*/ ) {
				$index->index($module_name."\.$1", $pathname, $revision, $., "v");
			}
			# ..for loop header.
			elsif ( $_ =~ /^for\s+(\w+)\s+in.*/ ) {
				$index->index($module_name."\.$1", $pathname, $revision, $., "v");
			}
		}
		close(PYTAG);
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
