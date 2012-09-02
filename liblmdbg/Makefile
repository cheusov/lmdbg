######################################################################
# Autoconfiguration part. Stop using GNU autoconf! :-)

MKC_COMMON_DEFINES.Interix +=	-D_ALL_SOURCE
MKC_COMMON_DEFINES.Linux +=	-D_GNU_SOURCE -D_FILE_OFFSET_BITS=64

# Ex.: CFLAGS += -DHAVE_FUNC2_MEMALIGN_MALLOC_H=1 on GNU libc
MKC_CHECK_FUNCS2 +=	memalign:malloc.h

# Ex.: CFLAGS += -DHAVE_FUNC2_MEMALIGN_MALLOC_H=1 on GNU libc
MKC_CHECK_FUNCS3 +=	posix_memalign:stdlib.h

# Ex.: CFLAGS += -DHAVE_VAR___MALLOC_HOOK_MALLOC_H=1 on GNU libc
MKC_CHECK_VARS +=	__malloc_hook:malloc.h

# Ex.: CFLAGS += -DHAVE_FUNCLIB_DLOPEN_DL=1 on Linux and Solaris
MKC_CHECK_FUNCLIBS +=	dlopen:dl

######################################################################

LIB  =		lmdbg
SRCS =		lmdbg.c

SHLIB_MAJOR =	0
SHLIB_MINOR =	0

LDCOMPILER =	yes

COPTS  +=	-O0 -g # gcc`s -O2 is not allowed!
CFLAGS +=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

WARNS =		4

MKC_REQD =	0.13.0

.include <mkc.configure.mk>

.include "../version.mk"

.include "../libstacktrace/linkme.mk"
DPLIBS +=	-lstacktrace_pic

.include "../libstacktrace/backtrace.mk"
.include <mkc.lib.mk>
