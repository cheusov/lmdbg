INSCRIPTS +=	lmdbg-run lmdbg-leaks lmdbg-sysleaks
INSCRIPTS +=	lmdbg-sym lmdbg lmdbg-grep lmdbg-sort
INSCRIPTS +=	lmdbg-head lmdbg-modules lmdbg-strip

INFILES +=	lmdbg-run.1 lmdbg-leaks.1 lmdbg-sysleaks.1
INFILES +=	lmdbg-sym.1 lmdbg.1 lmdbg-grep.1 lmdbg-sort.1
INFILES +=	lmdbg-head.1 #lmdbg-modules.1 lmdbg-strip.1 

.ifndef AWK
.if exists(/usr/xpg4/bin/awk)
# On Solaris /usr/bin/awk is a dead body, we need POSIX awk!
AWK      =	/usr/xpg4/bin/awk
.else
MKC_REQUIRE_PROGS +=	awk
AWK      =	${PROG.awk}
.endif # /usr/xpg4/bin/awk
.endif # AWK

GDB     ?=	gdb

MAN      =	${INFILES}

SCRIPTS  =	${INSCRIPTS}

INTEXTS_SED +=	-e 's,@LMDBG_VERSION@,${VERSION},g'
INTEXTS_SED +=	-e 's,@AWK@,${AWK},g'
INTEXTS_SED +=	-e 's,@GDB@,${GDB},g'

.include "../version.mk"
.include <mkc.prog.mk>
