# Makefile for lmdbg
# Copyright 2003-2009 Aleksey Cheusov <vle@gmx.net>
##################################################

PROJECTNAME=	lmdbg

BIRTHDATE=	2008-04-28

CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

CLEANFILES=	ChangeLog _*

###########################

SUBPRJ+=	libstacktrace:liblmdbg
SUBPRJ+=	scripts s2m m2s doc
SUBPRJ+=	liblmdbg:tests s2m:tests m2s:tests scripts:tests

SUBPRJ_DFLT=	s2m m2s scripts liblmdbg

.ifndef WITH_LMDBG_STAT_SCRIPT
SUBPRJ+=	st_hash:stat
SUBPRJ_DFLT+=	stat
.endif

MKC_CHECK_DEFINES+=	__GLIBC__:string.h

MKC_REQD=	0.20.0

clean: clean-tests
cleandir: cleandir-tests

###########################
.include "version.mk"
.include "test.mk"
.include <mkc.subprj.mk>
