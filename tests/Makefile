MKC_COMMON_DEFINES.Linux=	-D_GNU_SOURCE
MKC_CHECK_FUNCS3+=		posix_memalign:stdlib.h
MKC_CHECK_DEFINES+=		__GLIBC__

.include <mkc.configure.mk>

SUBDIR+=	prog1    
SUBDIR+=	prog2
SUBDIR+=	libtest3
SUBDIR+=	prog3
SUBDIR+=	prog4

.if ${HAVE_FUNC3.posix_memalign.stdlib_h:U1}
SUBDIR+=	prog5
.endif

MKINSTALL=	no

.PHONY: all test
test : all
	set -e; cd ${.CURDIR}; \
	env with_glibc=${HAVE_DEFINE.__GNUC__} ./test.sh

.include <mkc.subdir.mk>
