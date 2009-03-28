INSCRIPTS+=	lmdbg-run lmdbg-leaks lmdbg-sysleaks
INSCRIPTS+=	lmdbg-sym lmdbg-leak-check

SCRIPTS=	${INSCRIPTS}

INTEXTS_SED+=	-e 's,@LMDBG_VERSION@,${VERSION},g'

.include "../Makefile.version"

.include <mkc.intexts.mk>
.include <mkc.prog.mk>
