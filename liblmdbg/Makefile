######################################################################
# Autoconfiguration part. Stop using GNU autoconf! :-)

# for Interix
MKC_COMMON_DEFINES+=	-D_ALL_SOURCE

# For Linux
MKC_COMMON_DEFINES+=	-D_GNU_SOURCE -D_FILE_OFFSET_BITS=64

# Ex.: CFLAGS += -DHAVE_FUNC2_MEMALIGN_MALLOC_H=1 on GNU libc
MKC_CHECK_FUNCS2+=	memalign:malloc.h

# Ex.: CFLAGS += -DHAVE_VAR___MALLOC_HOOK_MALLOC_H=1 on GNU libc
MKC_CHECK_VARS+=	__malloc_hook:malloc.h

# Ex.: CFLAGS += -DHAVE_FUNCLIB_DLOPEN_DL=1 on Linux and Solaris
MKC_CHECK_FUNCLIBS+=	dlopen:dl

######################################################################

LIB=		lmdbg
SRCS=		lmdbg.c

CFLAGS+=	-O0 -g # gcc's -O2 is not allowed!
CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

LMDBGFN=	liblmdbg.so.0.0

FILES=		liblmdbg.so
FILESNAME=	liblmdbg.so.0.0
FILESDIR=	${LIBDIR}
FILESOWN=	${LIBOWN}
FILESGRP=	${LIBGRP}
FILESMODE=	${LIBMODE}

SYMLINKS=	liblmdbg.so.0.0 ${LIBDIR}/liblmdbg.so.0
SYMLINKS+=	liblmdbg.so.0   ${LIBDIR}/liblmdbg.so

# Unfortunately default bsd.*.mk rule doesn't work with
# __attribute__((constructor)) construct used in lmdbg.c.
# This is why I define the following rule here.
.PHONY: all
all: liblmdbg.so
liblmdbg.so: lmdbg.so
	${CC} -shared -o ${.TARGET} lmdbg.so ${LDFLAGS} ${LDADD}

.include <mkc.configure.mk>

.include "../libstacktrace/linkme.mk"
DPLIBS+=	-lstacktrace_pic

.include <mkc.lib.mk>
