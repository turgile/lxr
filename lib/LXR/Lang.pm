# -*- tab-width: 4 -*- ###############################################
#
# $Id: Lang.pm,v 1.2 1999/05/16 23:48:27 argggh Exp $

package LXR::Lang;

$CVSID = '$Id: Lang.pm,v 1.2 1999/05/16 23:48:27 argggh Exp $ ';

use strict;

sub new {
	my ($self, $fname, @itag) = @_;
	my $lang;

	if ($fname =~ /\.([ch]|cpp?|cc)$/i) {
#		require LXR::Lang::C;
		$lang = new LXR::Lang::C($fname);
	}
	elsif ($fname =~ /\.java$/i) {
#		require LXR::Lang::Java;
		$lang = new LXR::Lang::Java($fname);
	}
	else {
		$lang = undef;
	}

	$$lang{'itag'} = \@itag if $lang;

	return $lang;
}


# C
package LXR::Lang::C;

sub new {
	my ($self, $fname) = @_;

	$self = bless({}, $self);

	return $self;
}

sub processcode {
	my ($self, $code, @itag) = @_;

	$$code =~ s#(^|[^a-zA-Z_\#0-9])([a-zA-Z_~][a-zA-Z0-9_]*)\b#
		$1.($main::index->issymbol($2, $main::release) 
			? join($2, @{$$self{'itag'}})
			: $2)#ge;
}


# Java
package LXR::Lang::Java;

# May  8 1998 jmason java keywords
my @java_reserved = ('break', 'case', 'continue', 'default', 'do', 'else',
					 'for', 'goto', 'if', 'return', 'static',
					 'switch', 'void', 'volatile', 'while', 'public',
					 'class', 'final', 'private', 'protected',
					 'synchronized', 'package', 'import', 'boolean',
					 'byte', 'new', 'abstract', 'extends',
					 'implements', 'interface', 'throws',
					 'instanceof', 'super', 'this', 'native', 'null');

# Some of these should probably be object-local, not class-wide.  I
# don't have the time too look into that just now, and it works as it
# is.
my %java_reserved;
my %import_specifics = ();
my @import_stars = ();
my $java_package = '';
my $java_class = '';
my $ident = '[a-zA-Z_][a-zA-Z0-9_]*';
my $identdot = '[a-zA-Z_][a-zA-Z0-9_\.]*';


sub new {
	my ($self, $fname) = @_;

	require LXR::JavaClassList;

	$self = bless({}, $self);
	foreach $_ (@java_reserved) { $java_reserved{$_} = 1; }

	return $self;
}

sub processcode {
	my ($self, $code, @itag) = @_;
	
	$$code =~ s/(?:\A|\b)import\s+($identdot\.)\*\s*\;/
		push (@import_stars, $1); $&;
	/goexs;

	$$code =~ s/(?:\A|\b)import\s+($identdot\.)($ident)\s*\;/
		$import_specifics{$2} = $1.$2; $&;
	/goexs;

	$$code =~ s/(?:\A|\b)package\s+($identdot)\s*\;/
		$java_package = "$1."; push (@import_stars, $java_package); $&;
	/goexs;

	$$code =~ s/(?:\A|\b)(?:class|interface)\s+($ident)
		(?:\s+extends\s+$identdot|\s+implements\s+$identdot)*\s+\{/
			$java_class = $import_specifics{$1} = $java_package.$1; $&;
	/goexs;

#	#fix vi % command: }
	
	$$code =~ s#(^|[^a-zA-Z\#0-9_])([a-zA-Z_][a-zA-Z0-9_\.]*)(\b)#
		$1.find_java_xrefs($2).$3;#ge;
}

# not exported to genxref as it uses lots of vars arrays etc. defined in
# this module; maybe some perl expert out there could fix it so it can
# be shared between the two modules.
#
sub get_java_fqpn {
	local ($_) = @_;

	if (defined ($java_reserved{$_})) { return undef; }

	if ($_ eq 'this' && $main::index->issymbol($java_class, $main::release)) {
		return $java_class;		# the "this" object's type.
	} 

	elsif ($main::index->issymbol($_, $main::release)) {
		return $_;				# already fully-packaged?
	}

	elsif (defined ($import_specifics{$_}) 
		   && $main::index->issymbol($import_specifics{$_}, $main::release)) {
		return $import_specifics{$_}; # the fully-packaged name.
	}

	my $imported;
	foreach $imported (@import_stars) {
		# maybe it was imported using a star?
		if ($main::index->issymbol($imported.$_, $main::release)) {
			return $imported.$_;
		}
	}

	if (&JavaClassList::is_java_class ($_, @import_stars)) {
		return $_;				# a java system class
	}

	# maybe it's a variable or method on this class
	if ($main::index->issymbol("$java_class.$_", $main::release)) {
		return "$java_class.$_";
	}

	undef;						# I give up
}

sub find_java_xref_bit {
	my ($check, $ret) = @_;
	my ($full);

	$full = get_java_fqpn($check);
	if (defined ($full)) {
		$check = $full; 
		$ret = &LXR::Common::idref ($ret, $check);

		# Avoid accidentally nesting links
		$ret =~ s!^(<a href=[^>]+>)(<a href=[^>]+>)(.+)</a>\.([^<]+)</a>$!
			"$2$3</a>.$1$4</a>"
				!ge;
	}
	return ($check, $ret);
}

sub find_java_xrefs {
	local ($_) = @_;
	my ($full, $check, @bits, $bit, $ret);

	$full = get_java_fqpn($_);
	if (defined ($full)) { 
		return &LXR::Common::idref ($_, $full); 
	}

	($check, @bits) = split (/\./, $_);
	if ($#bits >= 0) {
		$ret = $check;
		foreach $bit (@bits) {
			($check, $ret) = find_java_xref_bit ($check, $ret);
			# FIXME.
#			if (defined ($member_type{$check})) { $check = $member_type{$check}; }
			$check .= '.'.$bit;
			$ret .= '.'.$bit;
		}
		($check, $ret) = find_java_xref_bit ($check, $ret);
		return $ret;
	}

	$_;
}


1;