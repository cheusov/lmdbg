PROG=		lmdbg-stat

LIB_Judy?=	Judy

MKC_REQUIRE_FUNCLIBS+=	JudyHSIns:${LIB_Judy}
MKC_REQUIRE_HEADERS+=	Judy.h

.include <mkc.configure.mk>

CPPFLAGS+=	-DVERSION='"${VERSION}"'

LDADD+=		-l${LIB_Judy}

WARNS=		4

.include "../version.mk"
.include <mkc.prog.mk>
