# -*- tab-width: 4 -*- ###############################################
#
# $Id: Config.pm,v 1.14 1999/06/01 06:44:22 pergj Exp $

package LXR::Config;

$CVSID = '$Id: Config.pm,v 1.14 1999/06/01 06:44:22 pergj Exp $ ';

use strict;

use LXR::Common;

require Exporter;

use vars qw($AUTOLOAD $confname);

$confname = 'lxr.conf';

sub new {
    my ($class, @parms) = @_;
    my $self = {};
    bless($self);
    $self->_initialize(@parms);
    return($self);
}



sub readfile {
    local($/) = undef;		# Just in case; probably redundant.
    my $file  = shift;
    my @data;

    open(INPUT, $file);
    $file = <INPUT>;
    close(INPUT);

    @data = $file =~ /([^\s]+)/gs;

    return wantarray ? @data : $data[0];
}


sub _initialize {
    my ($self, $url, $conf) = @_;
    my ($dir, $arg);

    unless ($url) {
		$url = 'http://'.$ENV{'SERVER_NAME'}.':'.$ENV{'SERVER_PORT'};
		$url =~ s/:80$//;
		$url .= $ENV{'SCRIPT_NAME'};
    }
    
    unless ($conf) {
		($conf = $0) =~ s#/[^/]+$#/#;
		$conf .= $confname;
    }
    
    unless (open(CONFIG, $conf)) {
		fatal("Couldn't open configuration file \"$conf\".");
    }
    
#    local($SIG{'__DIE__'}) = 'IGNORE';
    local($/) = undef;
    my @config = eval("\n#line 1 \"configuration file\"\n".
					  <CONFIG>);
    fatal($@) if $@;

    my $config;
    foreach $config (@config) {
		if ($config->{baseurl}) {
			my $root = quotemeta($config->{baseurl});
			next unless $url =~ /^$root/;
		}
		
		%$self = (%$self, %$config);
    }
    print (STDERR Dumper($self));
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


sub vardefault {
    my ($self, $var) = @_;

    return $self->{variables}{$var}{default} || 
		$self->{variables}{$var}{range}[0];
}


sub vardescription {
    my ($self, $var, $val) = @_;

    $self->{variables}{$var}{name} = $val if defined($val);

    return $self->{variables}{$var}{name};
}


sub varrange {
    my ($self, $var) = @_;

    return @{$self->{variables}{$var}{range} || []};
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
		}
		elsif (ref($val) eq 'CODE') {
			return $val;
		}
		else {
			return $self->varexpand($val);
		}
    }
    else {
		return undef;
    }
}


sub AUTOLOAD {
    my $self = shift;
    (my $var = $AUTOLOAD) =~ s/.*:://;

	my $val = $self->value($var);
	
	if (ref($val) eq 'CODE') {
		return &$val(@_);
	}
	else {
		return $val;
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


1;
