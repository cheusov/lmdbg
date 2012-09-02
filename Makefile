# Makefile for lmdbg
# Copyright 2003-2012 Aleksey Cheusov <vle@gmx.net>
##################################################

PROJECTNAME=	lmdbg

BIRTHDATE=	2008-04-28

CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

CLEANFILES=	ChangeLog _*

###########################
MKC_COMMON_DEFINES.Linux  =	-D_GNU_SOURCE
MKC_CHECK_FUNCS3         +=	posix_memalign:stdlib.h

SUBPRJ+=	libstacktrace:liblmdbg
SUBPRJ+=	scripts s2m m2s doc
SUBPRJ+=	liblmdbg:test s2m:test m2s:test scripts:test

TESTS +=	prog1 prog2 libtest3 prog3 prog4 prog6
.if ${HAVE_FUNC3.posix_memalign.stdlib_h:U1}
TESTS +=	prog5
.endif
.for t in ${TESTS}
SUBPRJ +=	test/${t}:test
clean: clean-test/${t}
cleandir: cleandir-test/${t}
.endfor

SUBPRJ_DFLT=	s2m m2s scripts liblmdbg

.ifndef WITH_LMDBG_STAT_SCRIPT
SUBPRJ+=	st_hash:stat stat:test
SUBPRJ_DFLT+=	stat
.endif

MKC_CHECK_DEFINES+=	__GLIBC__:string.h

MKC_REQD=	0.23.0

###########################
.include "version.mk"
.include <mkc.subprj.mk>
