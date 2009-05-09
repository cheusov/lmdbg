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

SHLIB_MAJOR=	0
SHLIB_MINOR=	0

CFLAGS+=	-O0 -g # gcc's -O2 is not allowed!
CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

# Unfortunately default bsd.*.mk rule doesn't work with
# __attribute__((constructor)) used in lmdbg.c.
# This is why I define this rule here.
# USE_LIBTOOLS=yes|no is needed in bsd.*.mk
# or full functional replacement.
lib${LIB}.so.${SHLIB_MAJOR}.${SHLIB_MINOR}:
	${CC} -shared -o ${.TARGET} lmdbg.so ${LDFLAGS} ${LDADD}; \
	ln -f -s ${.TARGET} lib${LIB}.so.${SHLIB_MAJOR}; \
	ln -f -s ${.TARGET} lib${LIB}.so

.include <mkc.configure.mk>

#
LDADD+=	-lstacktrace_pic

.include "../libstacktrace/linkme.mk"

.include <mkc.lib.mk>
