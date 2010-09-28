# Makefile for lmdbg
# Copyright 2003-2009 Aleksey Cheusov <vle@gmx.net>
##################################################

MKC_REQD=	0.14.0

PROJECTNAME=	lmdbg

BIRTHDATE=	2008-04-28

CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

CLEANFILES=	ChangeLog _*

###########################

SUBPRJ+=	libstacktrace:liblmdbg
SUBPRJ+=	scripts
SUBPRJ+=	s2m m2s
SUBPRJ+=	scripts tests

MKC_CHECK_DEFINES+=		__GLIBC__:string.h

###########################
.include <mkc.configure.mk>

.include "version.mk"
.include "test.mk"

.include <mkc.subprj.mk>
