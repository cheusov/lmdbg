INSCRIPTS+=	lmdbg-run lmdbg-leaks lmdbg-sysleaks
INSCRIPTS+=	lmdbg-sym lmdbg lmdbg-stat lmdbg-grep lmdbg-sort

INFILES+=	lmdbg-run.1 lmdbg-leaks.1 lmdbg-sysleaks.1
INFILES+=	lmdbg-sym.1 lmdbg.1 lmdbg-stat.1

.ifndef AWK
.if exists(/usr/xpg4/bin/awk)
# Under Solaris /usr/bin/awk is a dead body, we need POSIX awk!
AWK?=		/usr/xpg4/bin/awk
.else
AWK?=		/usr/bin/awk
.endif # /usr/xpg4/bin/awk
.endif # AWK

GDB?=		gdb

MAN=		${INFILES}

SCRIPTS=	${INSCRIPTS}
SCRIPTS+=	lmdbg-sort.awk

#FILESDIR_lmdbg-sort.awk=	${DATADIR}/runawk

INTEXTS_SED+=	-e 's,@LMDBG_VERSION@,${VERSION},g'
INTEXTS_SED+=	-e 's,@AWK@,${AWK},g'
INTEXTS_SED+=	-e 's,@GDB@,${GDB},g'

.include "../version.mk"

.include <mkc.intexts.mk>
.include <mkc.prog.mk>
