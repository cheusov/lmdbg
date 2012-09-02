PROG =		lmdbg-stat
SRCS =		lmdbg-stat.c stat.c

MKC_REQUIRE_FUNCLIBS +=	JudyHSIns:${LIB_Judy}
MKC_REQUIRE_HEADERS  +=	Judy.h

.include <mkc.configure.mk>

CPPFLAGS +=	-DVERSION='"${VERSION}"'

WARNS =		4

.include "../st_hash/linkme.mk"

DPLIBS +=	-lst_hash

.include "../version.mk"
.include <mkc.prog.mk>
