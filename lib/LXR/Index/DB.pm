# -*- tab-width: 4 -*- ###############################################
#
#

package LXR::Index::DB;

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
#		tie (%$foo, 'DB_File' , $$self{'dbpath'}.$_, 
#			 O_RDWR|O_CREAT, 0664, $DB_HASH);
		$$self{$_} = $foo;
	}
	
	return $self;
}

sub index {
	my ($self, $symname, $release, $filename, $line, $type) = @_;

	$$self{'files'}{$self->symid($symname, $release)} .=
		join("\t", $filename, $line, $type, '');
}

sub getindex {
	my ($self, $symname, $release) = @_;
}

sub relate {
	my ($self, $symname, $release, $rsymname, $reltype) = @_;

	$$self{'relation'}{$self->symid($symname, $release)} .=
		join("\t", $self->symid($rsymname, $release), $reltype, '');
}

sub getrelations {
	my ($self, $symname, $release) = @_;
}

sub symid {
	my ($self, $symname, $release) = @_;
	my ($symid);

	return $symname;
}

1;
