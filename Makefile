# Makefile for lmdbg
# Copyright 2003-2009 Aleksey Cheusov <vle@gmx.net>
##################################################

PROJECTNAME=	lmdbg

BIRTHDATE=	2008-04-28

CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

CLEANFILES=	ChangeLog _*

###########################

SUBPRJ+=	libstacktrace:liblmdbg
SUBPRJ+=	scripts
SUBPRJ+=	s2m m2s
SUBPRJ+=	liblmdbg:tests s2m:tests m2s:tests scripts:tests

SUBPRJ_DFLT=	s2m m2s scripts liblmdbg

MKC_CHECK_DEFINES+=		__GLIBC__:string.h

MKC_REQD=	0.20.0

clean: clean-tests
cleandir: cleandir-tests

###########################
.include "version.mk"
.include "test.mk"

.include <mkc.subprj.mk>
