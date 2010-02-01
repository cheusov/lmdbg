# Makefile for lmdbg
# Copyright 2003-2009 Aleksey Cheusov <vle@gmx.net>
##################################################

MKC_REQD=	0.14.0

PROJECTNAME=	lmdbg

BIRTHDATE=	2008-04-28

CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

CLEANFILES=	ChangeLog _*

###########################

SUBDIR+=	libstacktrace
SUBDIR+=	scripts
SUBDIR+=	m2s
SUBDIR+=	s2m
# lmdbg-stat is not finished yet
SUBDIR+=	stat
SUBDIR+=	.WAIT
SUBDIR+=	liblmdbg
SUBDIR+=	tests

###########################

.include "version.mk"
.include "test.mk"

.include <mkc.subdir.mk>
