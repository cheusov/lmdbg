INSCRIPTS+=	lmdbg-run lmdbg-leaks lmdbg-sysleaks
INSCRIPTS+=	lmdbg-sym lmdbg

INFILES+=	lmdbg-run.1 lmdbg-leaks.1 lmdbg-sysleaks.1
INFILES+=	lmdbg-sym.1 lmdbg.1

MAN=		${INFILES}

SCRIPTS=	${INSCRIPTS}
SCRIPTS+=	lmdbg-multi2single
SCRIPTS+=	lmdbg-single2multi

INTEXTS_SED+=	-e 's,@LMDBG_VERSION@,${VERSION},g'

.include "../version.mk"

.include <mkc.intexts.mk>
.include <mkc.prog.mk>
