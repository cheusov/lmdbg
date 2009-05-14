# Makefile for lmdbg
# Copyright 2003-2009 Aleksey Cheusov <vle@gmx.net>
##################################################

PROJECTNAME=	lmdbg

BIRTHDATE=	2008-04-28

CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

CLEANFILES=	ChangeLog _*

###########################

.PHONY: test
test: all
	@echo 'running tests...'; \
	cd ${.CURDIR}/liblmdbg; \
	    LMDBG_LIB=`${MAKE} mkc_printobjdir`/liblmdbg.so; \
	cd ${.CURDIR}/scripts; \
	    PATH=`${MAKE} mkc_printobjdir`:$$PATH; \
	OBJDIR=${.OBJDIR}; \
	SRCDIR=${.CURDIR}; \
	CC='${CC}'; \
	export PATH LMDBG_LIB OBJDIR SRCDIR CC; \
	if ( cd ${.CURDIR}/tests || exit 0; \
	    ./test.sh > ${.OBJDIR}/_test.res || exit 0; \
	    diff -u test.out ${.OBJDIR}/_test.res > ${.OBJDIR}/_test2.res; \
	    grep -Ev '^[-+] ([?][?]:NNN|0xF00DBEAF)$$' \
		${.OBJDIR}/_test2.res > ${.OBJDIR}/_test3.res; \
	    grep -E '^[-+]([^+-]|$$)' ${.OBJDIR}/_test3.res > /dev/null; \
	    ); \
	then \
	    echo '   failed'; \
	    grep -Ev '^[-+] ([?][?]:NNN|0xF00DBEAF)$$' ${.OBJDIR}/_test2.res; \
	    false; \
	else \
	    echo '   succeeded'; \
	fi

###########################

SUBDIR+=	libstacktrace
SUBDIR+=	scripts
SUBDIR+=	.WAIT
SUBDIR+=	liblmdbg

.include "./Makefile.version"

.include <mkc.subdir.mk>
