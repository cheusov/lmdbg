# Autoconfiguration part. Stop GNU autoconf! :-)

MKC_COMMON_DEFINES+=	-D_ALL_SOURCE
MKC_COMMON_DEFINES+=	-D_GNU_SOURCE -D_FILE_OFFSET_BITS=64

# Ex.: CFLAGS += -DHAVE_FUNC2_MEMALIGN_MALLOC_H=1 on GNU libc
MKC_CHECK_FUNCS2+=	memalign:malloc.h

# Ex.: CFLAGS += -DHAVE_VAR___MALLOC_HOOK_MALLOC_H=1 on GNU libc
MKC_CHECK_VARS+=	__malloc_hook:malloc.h

# Ex.: CFLAGS += -DHAVE_FUNCLIB_DLOPEN_DL=1 on Linux and Solaris
MKC_CHECK_FUNCLIBS+=	dlopen:dl

##################################################

LIB=		lmdbg
SRCS=		lmdbg.c

SHLIB_MAJOR=	0
SHLIB_MINOR=	0

lib${LIB}.so.${SHLIB_MAJOR}.${SHLIB_MINOR}:
	${CC} -shared -soname liblmdbg.so.0.0 -o ${.TARGET} ${.ALLSRC} ${LDFLAGS} ${LDADD}

MKCDPLIBS=	stacktrace ${.CURDIR}/../libstacktrace

CPPFLAGS+=	-I${.CURDIR}/../libstacktrace

.include <mkc.configure.mk>
.include <mkc.lib.mk>
