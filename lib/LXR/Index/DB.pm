# -*- tab-width: 4 -*- ###############################################
#
# $Id: DB.pm,v 1.10 2000/10/31 12:52:12 argggh Exp $

package LXR::Index::DB;

$CVSID = '$Id: DB.pm,v 1.10 2000/10/31 12:52:12 argggh Exp $ ';

use strict;
use DB_File;
use NDBM_File;


sub new {
	my ($self, $dbpath, $mode) = @_;
	my ($foo);

	$self = bless({}, $self);
	$$self{'dbpath'} = $dbpath;
	$$self{'dbpath'} =~ s@/*$@/@;

	foreach ('releases', 'files', 'symbols', 'indexes', 'status') {
		$foo = {};
		tie (%$foo, 'NDBM_File' , $$self{'dbpath'}.$_, 
			 $mode||O_RDONLY, 0664) ||
				 die "Can't open database ".$$self{'dbpath'}.$_. "\n";
		$$self{$_} = $foo;
	}
	
	return $self;
}

sub index {
	my ($self, $symname, $fileid, $line, $type, $rel) = @_;
	my $symid = $self->symid($symname);

	$self->{'indexes'}{$symid} .= join("\t", $fileid, $line, $type, $rel)."\0";
#	$$self{'index'}{$self->symid($symname, $release)} =
#		join("\t", $filename, $line, $type, '');
}

# Returns array of (fileid, line, type)
sub getindex {
	my ($self, $symname, $release) = @_;

	my (@d, $f);
	foreach $f (split(/\0/,
					  $$self{'indexes'}{$self->symid($symname, $release)})) {
		my ($fi, $l, $t, $s) = split(/\t/, $f);

		my %r = map { ($_ => 1) } split(/;/, $self->{'releases'}{$fi});
		next unless $r{$release};

		push(@d, [ $self->filename($fi), $l, $t, $s ]);
	}
	return @d;
}

sub getreference {
	return ();
}

sub relate {
	my ($self, $symname, $release, $rsymname, $reltype) = @_;
	my $symid = $self->symid($symname, $release);

	$$self{''}{$symid} = join("", $$self{'relation'}{$self->symid($symname, $release)}, 	join("\t", $self->symid($rsymname, $release), $reltype, ''));
}

sub getrelations {
	my ($self, $symname, $release) = @_;
}

sub fileid {
	my ($self , $filename, $release) = @_;
	
	return $filename.';'.$release;
}

# Convert from fileid to filename
sub filename {
	my ($self, $fileid) = @_;
	my ($filename) = split(/;/, $fileid);

	return $filename;
}

# If this file has not been indexed earlier, mark it as being indexed
# now and return true.  Return false if already indexed.
sub toindex {
	my ($self, $fileid) = @_;

	return undef if $self->{'status'}{$fileid} >= 1;

	$self->{'status'}{$fileid} = 1;
	return 1;
}

# Indicate that this filerevision is part of this release
sub release {
	my ($self, $fileid, $release) = @_;

	$self->{'releases'}{$fileid} .= $release.";";
}

sub symid {
	my ($self, $symname, $release) = @_;
	my ($symid);

	return $symname;
}

sub issymbol {
	my ($self, $symname, $release) = @_;

	return $$self{'indexes'}{$self->symid($symname, $release)};
}

sub empty_cache {
}


1;
