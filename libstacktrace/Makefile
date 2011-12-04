######################################################################
# Autoconfiguration part. Stop using GNU autoconf! :-)

# Ex.: CFLAGS += -DHAVE_HEADER_EXECINFO_H=1 on GNU libc
MKC_CHECK_HEADERS+=	execinfo.h
#MKC_CHECK_FUNCLIBS+=	backtrace:execinfo

######################################################################

COPTS+=	-O0 -g # gcc's -O2 is not allowed!

LIB=		stacktrace
SRCS=		stacktrace.c

INCS=		stacktrace.h

MKPICLIB=	yes

WARNS=		4

MKINSTALL?=	no # internal library, do not install it

MKC_REQD=	0.15.0

.include <mkc.configure.mk>
.include <mkc.lib.mk>
