# Makefile for lmdbg
# Copyright 2003-2012 Aleksey Cheusov <vle@gmx.net>
##################################################

PROJECTNAME =	lmdbg

BIRTHDATE =	2008-04-28

CFLAGS +=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

CLEANFILES =	ChangeLog _*

###########################
MKC_COMMON_DEFINES.Linux  =	-D_GNU_SOURCE
MKC_CHECK_FUNCS3         +=	posix_memalign:stdlib.h
MKC_CHECK_DEFINES        +=	__GLIBC__:string.h

.include <mkc.configure.mk>

LIBDEPS =	libstacktrace:liblmdbg st_hash:stat test/libtest3:test/prog3

SUBPRJ +=	scripts s2m m2s doc
SUBPRJ +=	liblmdbg:test s2m:test m2s:test scripts:test
SUBPRJ +=	stat:test

TESTS +=	prog1 prog2 libtest3 prog3 prog4 prog6 prog7 prog8

.if ${HAVE_FUNC3.posix_memalign.stdlib_h:U1}
TESTS +=	prog5
with_posix_memalign =	1
EXPORT_VARNAMES +=	with_posix_memalign
.endif

with_glibc =	${HAVE_DEFINE.__GLIBC__.string_h}
EXPORT_VARNAMES +=	with_glibc

.for t in ${TESTS}
SUBPRJ +=	test/${t}:test
clean: clean-test/${t}
cleandir: cleandir-test/${t}
.endfor

test: all-test
	@:

SUBPRJ_DFLT =	s2m m2s scripts liblmdbg stat

MKC_REQD =	0.29.1

###########################
.include "version.mk"
.include <mkc.subprj.mk>
