######################################################################
# Autoconfiguration part. Stop using GNU autoconf! :-)

MKC_COMMON_DEFINES.Interix+=	-D_ALL_SOURCE
MKC_COMMON_DEFINES.Linux+=	-D_GNU_SOURCE -D_FILE_OFFSET_BITS=64

# Ex.: CFLAGS += -DHAVE_FUNC2_MEMALIGN_MALLOC_H=1 on GNU libc
MKC_CHECK_FUNCS2+=	memalign:malloc.h

# Ex.: CFLAGS += -DHAVE_VAR___MALLOC_HOOK_MALLOC_H=1 on GNU libc
MKC_CHECK_VARS+=	__malloc_hook:malloc.h

# Ex.: CFLAGS += -DHAVE_FUNCLIB_DLOPEN_DL=1 on Linux and Solaris
MKC_CHECK_FUNCLIBS+=	dlopen:dl

######################################################################

LIB=		lmdbg
SRCS=		lmdbg.c

SHLIB_MAJOR=	0
SHLIB_MINOR=	0

CFLAGS+=	-O0 -g # gcc`s -O2 is not allowed!
CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

WARNS=		4

.include <mkc.own.mk>

# Unfortunately default bsd.*.mk rule doesn't work with
# __attribute__((constructor)) construct used in lmdbg.c.
# The following rule overrides the default one..
.PHONY: all
all: liblmdbg${SHLIB_EXTFULL}
liblmdbg${SHLIB_EXTFULL}: lmdbg.so
	${CC} ${LDFLAGS_SHARED} -o ${.TARGET} lmdbg.so ${LDFLAGS} ${LDADD}

.include "../version.mk"

.include <mkc.configure.mk>

.include "../libstacktrace/linkme.mk"
DPLIBS+=	-lstacktrace_pic

.include <mkc.lib.mk>
