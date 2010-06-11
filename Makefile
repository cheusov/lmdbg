# Makefile for lmdbg
# Copyright 2003-2009 Aleksey Cheusov <vle@gmx.net>
##################################################

MKC_REQD=	0.14.0

PROJECTNAME=	lmdbg

BIRTHDATE=	2008-04-28

CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

CLEANFILES=	ChangeLog _*

###########################

SUBPRJS+=	libstacktrace:liblmdbg
SUBPRJS+=	scripts
SUBPRJS+=	s2m m2s
SUBPRJS+=	scripts tests

###########################

.include "version.mk"
.include "test.mk"

.include <mkc.subprj.mk>
