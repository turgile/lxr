# -*- tab-width: 4 -*- ###############################################
#
# $Id: Local.pm,v 1.21 2009/05/10 11:54:29 adrianissott Exp $
#
# Local.pm -- Subroutines that need to be customized for each installation
#
#	Dawn Endico <dawn@cannibal.mi.org>

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

######################################################################
# This package is for placing subroutines that are likely to need
# to be customized for each installation. In particular, the file
# and directory description snarfing mechanism is likely to be
# different for each project.

package Local;

$CVSID = '$Id: Local.pm,v 1.21 2009/05/10 11:54:29 adrianissott Exp $ ';

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(&fdescexpand &descexpand &dirdesc &convertwhitespace);

use LXR::Common qw(:html);

# dme: Create descriptions for a file in a directory listing
# If no description, return the string "\&nbsp\;" to keep the
# table looking pretty.
#
# In mozilla search the beginning of a source file for a short
# description. Not all files have them and the ones that do use
# many different formats. Try to find as many of these without
# printing gobbeldygook or something silly like a file name or a date.
#
# Read in the beginning of the file into a string. I chose 60 because the
# Berkeley copyright notice is around 40 lines long so we need a bit more
# than this.
#
# Its common for file descriptions to be delimited by the file name or
# the word "Description" which preceeds the description. Search the entire
# string for these. Sometimes they're put in odd places such as inside
# the copyright notice or after the code begins. The file name should be
# followed by a colon or some pattern of dashes.
#
# If no such description is found then use the contents of the "first"
# comment as the description. First, strip off the copyright notice plus
# anything before it. Remove rcs comments. Search for the first bit of
# code (usually #include) and remove it plus anything after it. In what's
# left, find the contents of the first comment, and get the first paragraph.
# If that's too long, use only the first sentence up to a period. If that's
# still too long then we probably have a list or something that will look
# strange if we print it out so give up and return null.
#
# Yes, this is a lot of trouble to go through but its easier than getting
# people to use the same format and re-writing thousands of comments. Not
# everything printed will really be a summary of the file, but still the
# signal/noise ratio seems pretty high.
#
# Yea, though I walk through the valley of the shadow of pattern
# matching, I shall fear no regex.
sub fdescexpand {
	my $filename  = shift;
	my $dir       = shift;
	my $releaseid   = shift;
	my $linecount = 0;
	my $copy      = "";
	local $desc = "";
	my $maxlines = 40;    #only look at the beginning of the file

	#ignore files that aren't source code
	if (
		!(
			($filename =~ /\.c$/) |  ($filename =~ /\.h$/) |   ($filename =~ /\.cc$/) |
			($filename =~ /\.cp$/) | ($filename =~ /\.cpp$/) | ($filename =~ /\.java$/)
		)
	  )
	{
		return ("\&nbsp\;");
	}

	if ($fh = $files->getfilehandle($dir . $filename, $releaseid)) {
		while (<$fh>) {
			$desc = $desc . $_;
			if ($linecount++ > 60) {
				last;
			}
		}
		close($file);
	}

	# sanity check: if there's no description then stop
	if (!($desc =~ /\w/)) {
		return ("\&nbsp\;");
	}

	# if a java file, only consider class-level javadoc comments
	if ($filename =~ /\.java$/) {

		# last /** ... */ before 'public class' or 'public interface'

		# find declaration
		$desc =~ m/public\s((abstract|static|final|strictfp)\s)*(class|interface)/g;
		$declPos = pos $desc;
		return "\&nbsp\;" if !$declPos;

		# last comment start before declaration
		pos $desc = 0;
		$commentStart = -1;
		while ($desc =~ m#/\*\*#g) {
			last if $declPos < pos $desc;
			$commentStart = pos $desc;
		}
		return "\&nbsp\;" if $commentStart == -1;

		# find comment end, and extract
		pos $desc = $commentStart;
		$desc =~ m#\*/#g;
		$commentEnd = pos $desc;
		$desc       = substr($desc, $commentStart + 3, $commentEnd - $commentStart - 5);

		return "\&nbsp\;" if !$desc;

		# strip off any leading * s
		$desc =~ s/^\s*\*\s?//mg;

		# Strip off @parameter lines
		$desc =~ s/^\s*@\w+.*$//mg;

		# strip html tags (probably a way to do this all in one, but it's beyond my skill)
		$desc =~ s#<[/\w]+(\s*\w+="[\w\s]*"\s*)*>##g;    # double quoted attributes
		$desc =~ s#<[/\w]+(\s*\w+='[\w\s]*'\s*)*>##g;    # single quoted attributes
		$desc =~ s#<[/\w]+(\s*\w+=[\w]*\s*)*>##g;        # no quotes on attributes

		# strip off some CVS keyword lines
		foreach $keyword ('Workfile', 'Revision', 'Modtime', 'Author', 'Id', 'Date', 'Source',
			'RCSfile')
		{
			$desc =~ s/^\s*\$$keyword[\$:].*$//mg;
		}

	}

	# save a copy for later
	$copy = $desc;

	# Look for well behaved <filename><seperator> formatted
	# descriptions before we go to the trouble of looking for
	# one in the first comment. The whitespace between the
	# delimeter and the description may include a newline.
	if (   ($desc =~ s/(?:.*?$filename\s*?- ?-*\s*)([^\n]*)(?:.*)/$1/sgi)
		|| ($desc =~ s/(?:.*?$filename\s*?:\s*)([^\n]*)(?:.*)/$1/sgi)
		|| ($desc =~ s/(?:.*?Description:\s*)([^\n]*)(?:.*)/$1/sgi))
	{

		# if the description is non-empty then clean it up and return it
		if ($desc =~ /\w/) {

			#strip trailing asterisks and "*/"
			$desc =~ s#\*/?\s*$##;
			$desc =~ s#^[^\S]*\**[^\S]*#\n#gs;

			# Strip beginning and trailing whitespace
			$desc =~ s/^\s+//;
			$desc =~ s/\s+$//;

			# Strip junk from the beginning
			$desc =~ s#[^\w]*##ms;

			#htmlify the comments making links to symbols and files
			$desc = markupstring($desc, $Path->{'virt'});
			return ($desc);
		}
	}

	# if java and the <filename><seperator> check above didn't work, just dump the whole javadoc
	if ($filename =~ /\.java$/) {
		return $desc;
	}

	# we didn't find any well behaved descriptions above so start over
	# and look for one in the first comment
	$desc = $copy;

	# Strip off code from the end, starting at the first cpp directive
	$desc =~ s/\n#.*//s;

	# Strip off code from the end, starting at typedef
	$desc =~ s/\ntypedef.*//s;

	# Strip off license
	$desc =~ s#(?:/\*.*license.*?\*/)(.*)#$1#is;

	# Strip off copyright notice
	$desc =~ s#(?:/\*.*copyright.*?\*/)(.*)#$1#is;

	# Strip off emacs line
	$desc =~ s#(/\*.*tab-width.*?\*/)(.*)#$2#isg;

	# excise rcs crud
	$desc =~ s#Id: $filename.*?Exp \$##g;

	# Yuck, nuke these silly comments in js/jsj /* ** */
	$desc =~ s#\n\s*/\*+[\s\*]+\*/\n#\n#sg;

	# Don't bother to continue if there aren't any comments here
	if (!($desc =~ m#/\*#)) {
		return ("&nbsp;");
	}

	# Remove lines generated by jmc
	$desc =~ s#\n.*?Source date:.*\n#\n#;
	$desc =~ s#\n.*?Generated by jmc.*\n#\n#;

	# Extract the first comment
	$desc =~ s#(?:.*?/\*+)(.*?)(?:(?:\*+/.*)|(?:$))#$1#s;

	# Strip silly borders
	$desc =~ s#\n\s*[\*\=\-\s]+#\n#sg;

	# Strip beginning and trailing whitespace
	$desc =~ s/^\s+//;
	$desc =~ s/\s+$//;

	# Strip out file name
	$desc =~ s#$filename##i;

	# Strip By line
	$desc =~ s#By [^\n]*##;

	# Strip out dates
	$desc =~ s#\d{1,2}/\d{1,2}/\d\d\d\d##;
	$desc =~ s#\d{1,2}/\d{1,2}/\d\d##;
	$desc =~ s#\d{1,2} \w\w\w \d\d\d\d##;

	# Strip junk from the beginning
	$desc =~ s#[^\w]*##;

	# Extract the first paragraph
	$desc =~ s#(\n\s*?\n.*)##s;

	# If the description is too long then just use the first sentence
	# this will fail if no period was used.
	if (length($desc) > 200) {
		$desc =~ s#([^\.]+\.)\s.*#$1#s;
	}

	# If the description is still too long then assume it will look
	# like gobbeldygook and give up
	if (length($desc) > 200) {
		return ("&nbsp;");
	}

	# htmlify the comments, making links to symbols and files
	$desc = markupstring($desc, $Path->{'virt'});

	if ($desc) {
		return ($desc);
	} else {
		return ("\&nbsp\;");
	}
}

# dme: create a short description for a subdirectory in a directory listing
# If no description, return the string "\&nbsp\;" to keep the
# table looking pretty.
#
# In Mozilla, if the directory has a README file look in it for lines
# like the ones used in source code: "directoryname --- A short description"
sub descexpand {
	my ($templ, $node, $dir, $releaseid) = @_;
	if ($files->isdir($dir . $node, $releaseid)) {
		return LXR::Common::expandtemplate($templ,
			('desctext' => sub { return dirdesc($dir . $node, $releaseid); }));
	} else {
		return LXR::Common::expandtemplate($templ,
			('desctext' => sub { return fdescexpand($node, $dir, $releaseid); }));
	}
}

# dme: Print a descriptive blurb in directory listings between
# the document heading and the table containing the actual listing.
#
# For Mozilla, we extract this information from the README file if
# it exists. If the file is short then just print the whole thing.
# For longer files print the first paragraph or so. As much as
# possible make this work for randomly formatted files rather than
# inventing strict rules which create gobbeldygook when they're broken.
sub dirdesc {
	my ($path, $releaseid) = @_;
	if ($files->isfile($path . "README.txt", $releaseid)) {
		descreadme($path . "README.txt", $releaseid);
	} elsif ($files->isfile($path . "README", $releaseid)) {
		descreadme($path . "README", $releaseid);
	} elsif ($files->isfile($path . "README.html", $releaseid)) {
		descreadmehtml($path . "README.html", $releaseid);
	}
}

sub descreadmehtml {
	my ($file, $releaseid) = @_;

	my $string = "";
	return if !($desc = $files->getfilehandle($file, $releaseid));

	#    undef $/;
	$string = <$desc>;

	#    $/ = "\n";
	close($desc);

	# if the README is 0 length then give up
	if (!$string) {
		return;
	}

	# check if there's a short desc nested inside the long desc. If not, do
	# a non-greedy search for a long desc. assume there are no other stray
	# spans within the description.
	if ($string =~
		/<span class=["']?lxrlongdesc['"]?>(.*?<span class=["']?lxrshortdesc['"]?>.*?<\/span>.*?)<\/span>/is
	  )
	{
		$long = $1;
		if (!($long =~ /<span.*?\<span/is)) {
			return ($long . "<p>\nSEE ALSO: <a href=\"README.html\">README</a></p>\n");
		}
	} elsif ($string =~ /<span class=["']?lxrlongdesc['"]?>(.*?)<\/span>/is) {
		$long = $1;
		if (!($long =~ /\<span/is)) {
			return ($long . "<p>\nSEE ALSO: <a href=\"README.html\">README</a></p>\n");
		}
	}
}

sub descreadme {
	my ($file, $releaseid) = @_;

	my $string = "";

	#    $string =~ s#(</?([^>^\s]+[^>]*)>.*$)#($2~/B|A|IMG|FONT|BR|EM|I|TT/i)?$1:""#sg;
	my $n;
	my $count;
	my $temp;

	my $maxlines = 20;    # If file is less than this then just print it all
	my $minlines = 5;     # Too small. Go back and add another paragraph.
	my $chopto   = 10;    # Truncate long READMEs to this length

	return if !($desc = $files->getfilehandle($file, $releaseid));

	#    undef $/;
	$string = <$desc>;

	#    $/ = "\n";
	close($desc);

	# if the README is 0 length then give up
	if (!$string) {
		return;
	}

	# strip the emacs tab line
	$string =~ s/.*tab-width:[ \t]*([0-9]+).*\n//;

	# strip the npl
	$string =~ s/.*The contents of this .* All Rights.*Reserved\.//s;

	# strip the short description from the beginning
	$path   =~ s#/(.+)/#$1#;
	$string =~ s/.*$path\/*\s+--- .*//;

	# strip away junk
	$string =~ s/#+\s*\n/\n/;
	$string =~ s/---+\s*\n/\n/g;
	$string =~ s/===+\s*\n/\n/g;

	# strip blank lines at beginning and end of file.
	$string =~ s/^\s*\n//gs;
	$string =~ s/\s*\n$//gs;
	chomp($string);
	$_     = $string;
	$count = tr/\n//;

	# If the file is small there's not much use splitting it up.
	# Just print it all
	if ($count <= $maxlines) {
		$string = markupstring($string, $Path->{'virt'});
		$string = convertwhitespace($string);
		return ($string);
	} else {

		# grab the first n paragraphs, with n decreasing until the
		# string is 10 lines or shorter or until we're down to
		# one paragraph.
		$n    = 6;
		$temp = $string;
		while (($count > $chopto) && ($n-- > 1)) {
			$string =~ s/^((?:(?:[\S\t ]*?\n)+?[\t ]*\n){$n}?)(.*)/$1/s;
			$_ = $string;
			$string =~ s/\s*\n$//gs;
			$count = tr/\n//;
		}

		# if we have too few lines then back up and grab another paragraph
		$_     = $string;
		$count = tr/\n//;
		if ($count < $minlines) {
			$n = $n + 1;
			$temp =~ s/^((?:(?:[\S\t ]*?\n)+?[\t ]*\n){$n}?)(.*)/$1/s;
			$string = $temp;
		}

		# if we have more than $maxlines then truncate to $chopto
		# and add an elipsis.
		if ($count > $maxlines) {
			$string =~ s/^((?:[\S \t]*\n){$chopto}?)(.*)/$1/s;
			chomp($string);
			$string = $string . "\n...";
		}

		# since not all of the README is displayed here,
		# add a link to it.
		chomp($string);
		if ($string =~ /SEE ALSO/) {
			$string = $string . ", README";
		} else {
			$string = $string . "\n\nSEE ALSO: README";
		}

		$string = markupstring($string, $Path->{'virt'});
		$string = convertwhitespace($string);

		# strip blank lines at beginning and end of file again
		$string =~ s/^\s*\n//gs;
		$string =~ s/\s*\n$//gs;
		chomp($string);

		return ($string);
	}
}

# dme: substitute carraige returns and spaces in original text
# for html equivalent so we don't need to use <pre> and can
# use variable width fonts but preserve the formatting
sub convertwhitespace {
	my ($string) = @_;

	# handle ascii bulleted lists
	$string =~ s/<p>\n\s+o\s/<p>\n\&nbsp\;\&nbsp\;o /sg;
	$string =~ s/\n\s+o\s/&nbsp\;\n<br>\&nbsp\;\&nbsp\;o /sg;

	#find paragraph breaks and replace with <p>
	$string =~ s/\n\s*\n/<p>\n/sg;

	return ($string);
}

1;
