# Autoconfiguration part. Stop GNU autoconf! :-)

# Ex.: CFLAGS += -DHAVE_HEADER_EXECINFO_H=1 on GNU libc
MKC_CHECK_HEADERS+=	execinfo.h

######################################################################

LIB=	stacktrace
SRCS=	stacktrace.c

MKPIC=	yes

.include <mkc.configure.mk>
.include <mkc.lib.mk>
