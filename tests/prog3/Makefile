PROG=		prog3

# ${.CURDIR}/ is for test only
SRCS=		${.CURDIR}/prog3.c

COPTS+=		-O0 -g

.include "../libtest3/linkme.mk"

DPLIBS+=	-ltest3

.include <mkc.prog.mk>
