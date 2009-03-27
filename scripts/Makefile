SCRIPTS+=	lmdbg-run lmdbg-leaks lmdbg-sysleaks
SCRIPTS+=	lmdbg-sym lmdbg-leak-check

CLEANFILES+=	${SCRIPTS}

.SUFFIXES:	.in

.PHONY: all
all : ${SCRIPTS}

.in:
	sed -e 's,@sysconfdir@,${SYSCONFDIR},g' \
	    -e 's,@libdir@,${LIBDIR},g' \
	    -e 's,@prefix@,${PREFIX},g' \
	    -e 's,@bindir@,${BINDIR},g' \
	    -e 's,@sbindir@,${SBINDIR},g' \
	    -e 's,@datadir@,${DATADIR},g' \
	    -e 's,@LMDBG_VERSION@,${VERSION},g' \
	    ${.ALLSRC} > ${.TARGET} && chmod +x ${.TARGET}

.include <mkc.prog.mk>
