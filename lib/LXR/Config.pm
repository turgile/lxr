# $Id: Config.pm,v 1.7 1999/05/15 14:12:01 argggh Exp $

package LXR::Config;

use LXR::Common;

use vars qw($AUTOLOAD);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw($Conf);

$confname = 'lxr.conf-new';


sub new {
    my ($class, @parms) = @_;
    my $self = {};
    bless($self);
    $self->_initialize(@parms);
    $Conf = $self;
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
    my ($self, $conf) = @_;
    my ($dir, $arg);

    unless ($conf) {
	($conf = $0) =~ s#/[^/]+$#/#;
	$conf .= $confname;
    }
    
    unless (open(CONFIG, $conf)) {
	&fatal("Couldn't open configuration file \"$conf\".");
    }
    
    local($SIG{'__DIE__'}) = 'IGNORE';
    local($/) = undef;
	
    my @config = eval(<CONFIG>);
    &fatal("Error in configuration file: ".$@) if $@;

#    %$self = (%$self,
#	      %{eval(<CONFIG>)});

    my $url = 'http://'.$ENV{'SERVER_NAME'}.':'.$ENV{'SERVER_PORT'};
    $url =~ s/:80$//;
    $url .= $ENV{'SCRIPT_NAME'};

    my $config;
    foreach $config (@config) {
	print(STDERR Dumper($config));
	if ($config->{baseurl}) {
	    my $root = quotemeta($config->{baseurl});
	    next unless $url =~ /^$root/;
	}
	
	%$self = (%$self, %$config);
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


sub AUTOLOAD {
    my $self = shift;
    (my $var = $AUTOLOAD) =~ s/.*:://;

    if (exists($self->{$var})) {
	my $val = $self->{$var};
	
	if (ref($val) eq 'ARRAY') {
	    return map { $self->varexpand($_) } @$val;
	}
	else {
	    return $self->varexpand($val);
	}
    }
    else {
	return undef;
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

#sub mappath {
#    my ($self, $path) = @_;
#    my ($m);
#    
#    foreach $m (@{$self->{maplist}}) {
#	$path =~ s/$m->[0]/$self->varexpand($m->[1])/e;
#    }
#    return($path);
#}

1;
