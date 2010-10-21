PROG=		lmdbg-stat

SRCS=		lmdbg-stat.c stat.c

LIB_Judy?=	Judy

MKC_REQUIRE_FUNCLIBS+=	JudyHSIns:${LIB_Judy}
MKC_REQUIRE_HEADERS+=	Judy.h

.include <mkc.configure.mk>

CPPFLAGS+=	-DVERSION='"${VERSION}"'

LDADD+=		-l${LIB_Judy}

WARNS=		4

.include "../st_hash/linkme.mk"

DPLIBS+=	-lst_hash

.include "../version.mk"
.include <mkc.prog.mk>
