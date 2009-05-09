######################################################################
# Autoconfiguration part. Stop using GNU autoconf! :-)

# Ex.: CFLAGS += -DHAVE_HEADER_EXECINFO_H=1 on GNU libc
MKC_CHECK_HEADERS+=	execinfo.h

######################################################################

CFLAGS+=	-O0 -g # gcc's -O2 is not allowed!

LIB=		stacktrace
SRCS=		stacktrace.c

INCS=		stacktrace.h

MKPIC=		yes

.include <mkc.configure.mk>
.include <mkc.lib.mk>
