# -*- tab-width: 4 -*- ###############################################
#
# $Id: DB.pm,v 1.6 1999/05/17 23:43:51 argggh Exp $

package LXR::Index::DB;

$CVSID = '$Id ';

use strict;
use DB_File;


sub new {
	my ($self, $dbpath) = @_;
	my ($foo);

	$self = bless({}, $self);
	$$self{'dbpath'} = $dbpath;
	$$self{'dbpath'} =~ s@/*$@/@;

	foreach ('files', 'symbols', 'index', 'relation') {
		$foo = {};
		tie (%$foo, 'DB_File' , $$self{'dbpath'}.$_, 
			 O_RDWR|O_CREAT, 0664, $DB_HASH) || 
				 die "Can't open database ".$$self{'dbpath'}.$_. "\n";
		$$self{$_} = $foo;
	}
	
	return $self;
}

sub index {
	my ($self, $symname, $release, $filename, $line, $type) = @_;
	my $symid = $self->symid($symname, $release);

	$self->{'index'}{$symid} = 
		join("", $$self{'index'}{$symid}, join("\t", $filename, $line, $type, ''));
#	$$self{'index'}{$self->symid($symname, $release)} =
#		join("\t", $filename, $line, $type, '');
}

# Returns array of (fileid, line, type)
sub getindex {
	my ($self, $symname, $release) = @_;
	my ($foobar);

	$foobar = $$self{'index'}{$self->symid($symname, $release)};
	return split /\t/, $foobar;
}

sub relate {
	my ($self, $symname, $release, $rsymname, $reltype) = @_;
	my $symid = $self->symid($symname, $release);

#	join("", $$self{'relation'}{$self->symid($symname, $release)},
#		join("\t", $self->symid($rsymname, $release), $reltype, ''));
	$$self{'relation'}{$symid} =
		join("\t", $self->$symid, $reltype, '');
}

sub getrelations {
	my ($self, $symname, $release) = @_;
}

sub fileid {
	my ($self , $filename, $release) = @_;
	
	return $filename;
}

# Convert from fileid to filename
sub filename {
	my ($self, $fileid) = @_;
	
	return ($fileid);
}

sub symid {
	my ($self, $symname, $release) = @_;
	my ($symid);

	return $symname;
}

sub issymbol {
	my ($self, $symname, $release) = @_;

	return $$self{'index'}{$self->symid($symname, $release)};
}


1;
