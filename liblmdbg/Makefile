######################################################################
# Autoconfiguration part. Stop using GNU autoconf!

MKC_COMMON_DEFINES.Interix +=	-D_ALL_SOURCE
MKC_COMMON_DEFINES.Linux   +=	-D_GNU_SOURCE

MKC_CHECK_FUNCS2 +=	memalign:malloc.h aligned_alloc:stdlib.h
MKC_CHECK_FUNCS3 +=	posix_memalign:stdlib.h

MKC_CHECK_FUNCLIBS +=	dlopen:dl

MKC_FEATURES       +=	strlcat errc

######################################################################

LIB  =		lmdbg
SRCS =		lmdbg.c

SHLIB_MAJOR =	0
SHLIB_MINOR =	0

LDCOMPILER =	yes

COPTS  +=	-O0 -g -U_FORTIFY_SOURCE # gcc`s -O2 is not allowed!
CFLAGS +=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

WARNS    =	4

MKC_REQD =	0.29.1

.include <mkc.configure.mk>

.include "../libstacktrace/backtrace.mk"

.include "../version.mk"
.include <mkc.lib.mk>
