# -*- tab-width: 4 -*- ###############################################
#
# $Id: Generic.pm,v 1.1 2001/06/17 08:35:10 mbox Exp $
#
# Implements generic support for any language that ectags can parse.
# This may not be ideal support, but it should at least work until 
# someone writes better support.
#

package LXR::Lang::Generic;

$CVSID = '$Id: Generic.pm,v 1.1 2001/06/17 08:35:10 mbox Exp $ ';

my $langconf = "generic.conf";

use strict;
use LXR::Common;
use LXR::Lang;
require Exporter;


use vars qw(@ISA $AUTOLOAD);
@ISA = ('LXR::Lang');

sub new {
  my ($proto, $pathname, $release) = @_;
  my $class = ref($proto) || $proto;
  my $self  = {};
  bless ($self, $class);
  $$self{'release'} = $release;
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
  my $lang;

  if ($config->ectagsbin) {
    # We let ctags figure out the language and then snarf the result
    open(CTAGS, join(" ", $config->ectagsbin,
					 $self->ectagsopts,
					 "--excmd=number", 
					 "--fields=+l",	# print the language
					 "-f", "-", 
					 $path, "|"));
	
    while (<CTAGS>) {
	  chomp;
		
	  my ($sym, $file, $line, $type,$ext) = split(/\t/, $_);
	  $line =~ s/;\"$//;
	  $ext =~ /language:(\w+)/;
	  $lang=$1;
		
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


sub allvariables {
  my $self = shift;
  
  return keys(%{$self->{variables} || {}});
}


sub variable {
  my ($self, $var, $val) = @_;

  $self->{variables}{$var}{value} = $val if defined($val);
  return $self->{variables}{$var}{value} ||
	$self->vardefault($var);
}

# Autoload magic to allow access using $generic->variable syntax
# blatently ripped from Config.pm - I still don't fully understand how
# this works.

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


sub mappath {
  my ($self, $path, @args) = @_;
  my %oldvars;
  my ($m, $n);
    
  foreach $m (@args) {
	if ($m =~ /(.*?)=(.*)/) {
	  $oldvars{$1} = $self->variable($1);
	  $self->variable($1, $2);
	}
  }

  while (($m, $n) = each %{$self->{maps} || {}}) {
	$path =~ s/$m/$self->varexpand($n)/e;
  }
	
  while (($m, $n) = each %oldvars) {
	$self->variable($m, $n);
  }
	
  return $path;
}

sub langinfo {
  my ($self, $lang, $item) = @_;
	
  my $val;
  my $map = $self->langmap;
  if (exists $$map{$lang}) {
	$val = $$map{$lang};
  } else {
	$val = undef;
  }

  if (defined $val) {
	return wantarray ? @{$$val{$item}} : $$val{$item};
  } else {
	return undef;
  }
}
