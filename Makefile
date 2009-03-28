# Makefile for lmdbg
# Copyright 2003-2009 Aleksey Cheusov <vle@gmx.net>

##################################################

MKHTML=			no
MKMAN=			no

INST_DIR?=		${INSTALL} -d

##################################################

VERSION=	0.10.0

PROJECTNAME=	lmdbg

BIRTHDATE=	2008-04-28

CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

CLEANFILES=	ChangeLog *.lo *.la *.o _* .libs _mkc_*

##################################################


##################################################

.PHONY: install-dirs
install-dirs:
	$(INST_DIR) ${DESTDIR}${BINDIR}
	$(INST_DIR) ${DESTDIR}${LIBDIR}
	$(INST_DIR) ${DESTDIR}${INCSDIR}
.if !defined(MKMAN) || empty(MKMAN:M[Nn][Oo])
	$(INST_DIR) ${DESTDIR}${MANDIR}/man1
.if !defined(MKCATPAGES) || empty(MKCATPAGES:M[Nn][Oo])
	$(INST_DIR) ${DESTDIR}${MANDIR}/cat1
.endif
.endif

###########################

.PHONY: test
test: all
	@echo 'running tests...'; \
	OBJDIR=${.OBJDIR} SRCDIR=${.CURDIR} CC='${CC}'; \
	export OBJDIR SRCDIR CC; \
	if ( cd ${.CURDIR}/tests || exit 0; \
	    ./test.sh > ${.OBJDIR}/_test.res || exit 0; \
	    diff -u test.out ${.OBJDIR}/_test.res > ${.OBJDIR}/_test2.res; \
	    grep -Ev '^[-+] ([?][?]:NNN|0xF00DBEAF)$$' \
		${.OBJDIR}/_test2.res > ${.OBJDIR}/_test3.res; \
	    grep -E '^[-+]([^+-]|$$)' ${.OBJDIR}/_test3.res > /dev/null; \
	    ); \
	then \
	    echo '   failed'; \
	    grep -Ev '^[-+] ([?][?]:NNN|0xF00DBEAF)$$' ./_test2.res; \
	    false; \
	else \
	    echo '   succeeded'; \
	fi

###########################

SUBDIR+=	libstacktrace
SUBDIR+=	scripts
SUBDIR+=	.WAIT
SUBDIR+=	liblmdbg

.include <mkc.subdir.mk>
