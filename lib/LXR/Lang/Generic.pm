# -*- tab-width: 4 -*- ###############################################
#
# $Id: Generic.pm,v 1.5 2001/08/15 15:50:27 mbox Exp $
#
# Implements generic support for any language that ectags can parse.
# This may not be ideal support, but it should at least work until 
# someone writes better support.
#
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

package LXR::Lang::Generic;

$CVSID = '$Id: Generic.pm,v 1.5 2001/08/15 15:50:27 mbox Exp $ ';

use strict;
use LXR::Common;
use LXR::Lang;
require Exporter;


use vars qw(@ISA $AUTOLOAD $langconf);

@ISA = ('LXR::Lang');

sub new {
  my ($proto, $pathname, $release, $lang) = @_;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $$self{'release'} = $release;
  $$self{'language'} = $lang;

  open (X, $config->genericconf) || die "Can't open $config->genericconf, $!";

  local($/) = undef;

  my $cfg = eval ("\n#line 1 \"generic.conf\"\n".
				  <X>);
  die ($@) if $@;
  close X;
  %$self= (%$self, %$cfg);

  return $self;
}

sub indexfile {
  my ($self, $name, $path, $fileid, $index, $config) = @_;
  my $langforce = $ {$self->eclangnamemapping}{$self->language};
  if (!defined $langforce) {
	$langforce = $self->language;
  }
	
  if ($config->ectagsbin) {
	open(CTAGS, join(" ", $config->ectagsbin,
					 $self->ectagsopts,
					 "--excmd=number",
					 "--language-force=$langforce",
					 "-f", "-", 
					 $path, "|")) or die "Can't run ectags, $!";
	
	while (<CTAGS>) {
	  chomp;
		
	  my ($sym, $file, $line, $type,$ext) = split(/\t/, $_);
	  $line =~ s/;\"$//;
	  $ext =~ /language:(\w+)/;
		
	  # TODO: can we make it more generic in parsing the extension fields?
	  if (defined($ext) && $ext =~ /^(struct|union|class|enum):(.*)/) {
		$ext = $2;
		$ext =~ s/::<anonymous>//g;
	  } else {
		$ext = undef;
	  }
		
	  $index->index($sym, $fileid, $line, $type, $ext);
	}
	close(CTAGS);
	
  }
}

# This method returns the regexps used by SimpleParse to break the
# code into different blocks such as code, string, include, comment etc.
# Since this depends on the language, it's configured via generic.conf

sub parsespec {
  my ($self) = @_;
  my @spec = $self->langinfo('spec');
  return @spec;
}

# Process a chunk of code
# Basically, look for anything that looks like an identifier, and if
# it is then make it a hyperlink, unless it's a reserved word in this
# language.
# Parameters:
#   $code - reference to the code to markup
#   @itag - ???
# TODO : Make the handling of identifier recognition language dependant

sub processcode {
  my ($self, $code) = @_;
  my ($start, $id);
  $$code =~ s {(^|[^\w\#])([\w~][\w]*)\b}
	# Replace identifier by link unless it's a reserved word
	{
	  $1.
		((!grep(/$2/, $self->langinfo('reserved')) &&
		  $index->issymbol($2, $$self{'release'})) ?
		 join($2, @{$$self{'itag'}}) :
		 $2);
	}ge;
}

#
# Find references to symbols in the file
#

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

	if (defined($btype)) {
	  if ($btype eq 'comment' or $btype eq 'string' or $btype eq 'include') {
		$linenum += @lines - 1;
	  } else {
		print "BTYPE was: $btype\n";
	  }
	} else {
	  my $l;
	  my $string;
	  foreach $l (@lines) {
		foreach ($l =~ /(?:^|[^a-zA-Z_\#]) 	# Non-symbol chars.
				 (\~?_*[a-zA-Z][a-zA-Z0-9_]*) # The symbol.
				 \b/ogx) {
		  $string = $_;
#		  print "considering $string\n";
		  if (!grep(/$string/, $self->langinfo('reserved')) &&
			  $index->issymbol($string)) {
#			print "adding $string to references\n";
			$index->reference($string, $fileid, $linenum);
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




# Autoload magic to allow access using $generic->variable syntax
# blatently ripped from Config.pm - I still don't fully understand how
# this works.

sub variable {
  my ($self, $var, $val) = @_;

  $self->{variables}{$var}{value} = $val if defined($val);
  return $self->{variables}{$var}{value} ||
	$self->vardefault($var);
}

sub varexpand {
  my ($self, $exp) = @_;
  $exp =~ s/\$\{?(\w+)\}?/$self->variable($1)/ge;

  return $exp;
}


sub value {
  my ($self, $var) = @_;

  if (exists($self->{$var})) {
	my $val = $self->{$var};
		
	if (ref($val) eq 'ARRAY') {
	  return map { $self->varexpand($_) } @$val;
	} elsif (ref($val) eq 'CODE') {
	  return $val;
	} else {
	  return $self->varexpand($val);
	}
  } else {
	return undef;
  }
}


sub AUTOLOAD {
  my $self = shift;
  (my $var = $AUTOLOAD) =~ s/.*:://;

  my @val = $self->value($var);
	
  if (ref($val[0]) eq 'CODE') {
	return $val[0]->(@_);
  } else {
	return wantarray ? @val : $val[0];
  }
}

sub langinfo {
  my ($self, $item) = @_;
	
  my $val;
  my $map = $self->langmap;
  die if !defined $map;
  if (exists $$map{$self->language}) {
	$val = $$map{$self->language};
  } else {
	$val = undef;
  }

  if (defined $val && defined $$val{$item}) {
	return wantarray ? @{$$val{$item}} : $$val{$item};
  } else {
	return undef;
  }
}

1;
