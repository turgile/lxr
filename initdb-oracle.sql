drop sequence lxr_filenum;
drop sequence lxr_symnum;
drop table lxr_indexes;
drop table lxr_usage;
drop table lxr_symbols;
drop table lxr_releases;
drop table lxr_status;
drop table lxr_files;

commit;

create sequence lxr_filenum;
create sequence lxr_symnum;

commit;

create table lxr_files ( 			
	filename	varchar2(250),
	revision	varchar2(250),
	fileid		number,
	constraint lxr_pk_files primary key (fileid)
);
alter table lxr_files add unique (filename, revision);
create index lxr_i_files on lxr_files(filename);

commit;

create table lxr_symbols (				
	symname		varchar2(250),
	symid		number,
	constraint lxr_pk_symbols primary key (symid)
);
alter table lxr_symbols add unique(symname);

commit;

create table lxr_indexes (
	symid		number,
	fileid		number,
	line		number,
	type		varchar2(250),
	relsym		number,
	constraint lxr_fk_indexes_fileid foreign key (fileid) references lxr_files(fileid),
	constraint lxr_fk_indexes_symid foreign key (symid) references lxr_symbols(symid),
	constraint lxr_fk_indexes_relsym foreign key (relsym) references lxr_symbols(symid)
);
create index lxr_i_indexes on lxr_indexes(symid);

commit;

create table lxr_releases (	
	fileid		number,
	release		varchar2(250),
	constraint lxr_pk_releases primary key (fileid,release),
	constraint lxr_fk_releases_fileid foreign key (fileid) references lxr_files(fileid)
);

commit;

create table lxr_status (
	fileid		number,
	status		number,
	constraint lxr_pk_status primary key (fileid),
	constraint lxr_fk_status_fileid foreign key (fileid) references lxr_files(fileid)
);

commit;

create table lxr_usage (				
	fileid		number,
	line		number,
	symid		number,
	constraint lxr_fk_usage_fileid foreign key (fileid) references lxr_files(fileid),
	constraint lxr_fk_usage_symid foreign key (symid) references lxr_symbols(symid)
);
create index lxr_i_usage on lxr_usage(symid);

commit;