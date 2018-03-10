PROG =		lmdbg-stat
SRCS =		lmdbg-stat.c stat.c
MAN  =		lmdbg-stat.1

INFILES +=	lmdbg-stat.1

MKC_REQUIRE_FUNCLIBS +=	JudyHSIns:${LIB_Judy}
MKC_REQUIRE_HEADERS  +=	Judy.h

CPPFLAGS +=	-DVERSION='"${VERSION}"'

WARNS     =	4

.include "../version.mk"
.include <mkc.prog.mk>
