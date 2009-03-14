# Makefile for lmdbg
# Copyright 2003-2009 Aleksey Cheusov <vle@gmx.net>

##################################################

MKC_COMMON_DEFINES=	-D_ALL_SOURCE -D_GNU_SOURCE -D_FILE_OFFSET_BITS=64

MKC_CHECK_HEADERS+=	execinfo.h
MKC_CHECK_FUNCS2+=	memalign:malloc.h
MKC_CHECK_VARS+=	__malloc_hook:malloc.h
MKC_CHECK_FUNCLIBS+=	dlopen:dl

##################################################

PREFIX?=		/usr/local
BINDIR?=		${PREFIX}/bin
LIBDIR?=		${PREFIX}/lib
INCLUDEDIR?=		${PREFIX}/include
MANDIR?=		${PREFIX}/man
SYSCONFDIR?=		${PREFIX}/etc

MKHTML=			no
MKMAN=			no

INST_DIR?=		${INSTALL} -d

##################################################

VERSION=	0.10.0

PROJECTNAME=	lmdbg

BIRTHDATE=	2008-04-28

CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

SCRIPTS+=	lmdbg-run lmdbg-leaks lmdbg-sysleaks
SCRIPTS+=	lmdbg-sym lmdbg-leak-check

CLEANFILES=	ChangeLog *.lo *.la *.o _* ${SCRIPTS} .libs _mkc_*

##################################################

.PHONY: all
all : liblmdbg.la ${SCRIPTS}

.PHONY: stacktrace
stacktrace : libstacktrace.la

.for f in lmdbg stacktrace
${f}.o: ${f}.c
	libtool --tag=CC --mode=compile $(CC) -o ${.TARGET} -c -D_GNU_SOURCE \
		$(CFLAGS) -g -O0 $<
.endfor

liblmdbg.la : lmdbg.o stacktrace.o
libstacktrace.la : stacktrace.o

.for f in liblmdbg libstacktrace
	libtool --tag=CC --mode=link $(CC) -o ${.TARGET} -rpath $(LIBDIR) \
	   -version-info 0:0 -g ${.ALLSRC:S/.o/.lo/g} $(LDFLAGS) $(LDADD)
.endfor

.SUFFIXES:	.in

.in:
	sed -e 's,@sysconfdir@,${SYSCONFDIR},g' \
	    -e 's,@libdir@,${LIBDIR},g' \
	    -e 's,@prefix@,${PREFIX},g' \
	    -e 's,@bindir@,${BINDIR},g' \
	    -e 's,@sbindir@,${SBINDIR},g' \
	    -e 's,@datadir@,${DATADIR},g' \
	    -e 's,@LMDBG_VERSION@,${VERSION},g' \
	    ${.ALLSRC} > ${.TARGET} && chmod +x ${.TARGET}

.PHONY: install.stacktrace
install.stacktrace : libstacktrace.la
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)
	$(INSTALL) -d $(DESTDIR)$(INCLUDEDIR)
	libtool --mode=install $(INSTALL) -m 0644 libstacktrace.la \
		$(DESTDIR)$(LIBDIR)
	$(INSTALL) -m 0644 stacktrace.h $(DESTDIR)$(INCLUDEDIR)

.PHONY: install-lmdbg
install-lmdbg : all
	$(INSTALL) -d $(DESTDIR)$(libdir)
	libtool --mode=install $(INSTALL) -m 0755 liblmdbg.la $(DESTDIR)$(LIBDIR)

.PHONY: install
install : install-lmdbg

##################################################

.PHONY: install-dirs
install-dirs:
	$(INST_DIR) ${DESTDIR}${BINDIR}
	$(INST_DIR) ${DESTDIR}${LIBDIR}
.if !defined(MKMAN) || empty(MKMAN:M[Nn][Oo])
	$(INST_DIR) ${DESTDIR}${MANDIR}/man1
.if !defined(MKCATPAGES) || empty(MKCATPAGES:M[Nn][Oo])
	$(INST_DIR) ${DESTDIR}${MANDIR}/cat1
.endif
.endif

###########################

.include <bsd.own.mk>

.PHONY: test
test: liblmdbg.la lmdbg-sym lmdbg-leaks lmdbg-run
	@echo 'running tests...'; \
	OBJDIR=${.OBJDIR} SRCDIR=${.CURDIR} CC='${CC}'; \
	export OBJDIR SRCDIR CC; \
	if ( cd ${.CURDIR}/tests || exit 0; \
	    ./test.sh > ${.OBJDIR}/_test.res || exit 0; \
	    diff -u test.out ${.OBJDIR}/_test.res > ${.OBJDIR}/_test2.res; \
	    grep -Ev '^[-+] ([?][?]:NNN|0xF00DBEAF)$$' \
		${.OBJDIR}/_test2.res > ${.OBJDIR}/_test3.res; \
	    grep '^[-+][^+-]' ${.OBJDIR}/_test3.res > /dev/null; \
	    ); \
	then \
	    echo '   failed'; \
	    grep -Ev '^[-+] ([?][?]:NNN|0xF00DBEAF)$$' ./_test2.res; \
	    false; \
	else \
	    echo '   succeeded'; \
	fi

###########################

.include "configure.mk"
.include <bsd.prog.mk>
