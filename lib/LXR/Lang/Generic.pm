# -*- tab-width: 4 -*- ###############################################
#
# $Id: Generic.pm,v 1.2 2001/07/03 14:46:12 mbox Exp $
#
# Implements generic support for any language that ectags can parse.
# This may not be ideal support, but it should at least work until 
# someone writes better support.
#

package LXR::Lang::Generic;

$CVSID = '$Id: Generic.pm,v 1.2 2001/07/03 14:46:12 mbox Exp $ ';

use strict;
use LXR::Common;
use LXR::Lang;
require Exporter;


use vars qw(@ISA $AUTOLOAD $langconf);

@ISA = ('LXR::Lang');

$langconf = "/home/malcolm/lxr/lib/LXR/Lang/generic.conf";


sub new {
  my ($proto, $pathname, $release, $lang) = @_;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $$self{'release'} = $release;
  $$self{'language'} = $lang;

  open (X, $langconf) || die "Can't open $langconf, $!";

  local($/) = undef;

  my $cfg = eval ("\n#line 1 \"generic.conf\"\n".
				  <X>);
  die ($@) if $@;

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
# Basically, look for anything that looks like # an identifier, and if
# it is then make it a hyperlink
# Parameters:
#   $code - reference to the code to markup
#   @itag - ???
# TODO : Make the handling of identifier recognition language dependant

sub processcode {
  my ($self, $code) = @_;
  $$code =~ s!(^|[^a-zA-Z_\#0-9])([a-zA-Z_~][a-zA-Z0-9_]*)\b!
	$1.
	  {if(!grep(/$2/, $self->langinfo('reserved')) {
		if($index->issymbol($2, $$self{'release'})) {
		  join($2, @{$$self{'itag'}});
		}
		else {
		  $2;
		}}
		!gxe;

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
  if (exists $$map{$self->language}) {
	$val = $$map{$self->language};
  } else {
	$val = undef;
  }

  if (defined $val) {
	return wantarray ? @{$$val{$item}} : $$val{$item};
  } else {
	return undef;
  }
}

1;
