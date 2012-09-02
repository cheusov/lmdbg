COPTS +=	-O0 -g # gcc's -O2 is not allowed!

LIB    =	stacktrace
SRCS   =	stacktrace.c

INCS   =	stacktrace.h

MKPICLIB =	yes

WARNS    =	4

MKINSTALL ?=	no # internal library, do not install it

MKC_REQD =	0.15.0

.include "backtrace.mk"
.include <mkc.lib.mk>
