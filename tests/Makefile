MKC_CHECK_FUNCS3+=	posix_memalign:stdlib.h

.include <mkc.configure.mk>

SUBDIR+=	prog1    
SUBDIR+=	prog2
SUBDIR+=	libtest3
SUBDIR+=	prog3
SUBDIR+=	prog4

.if ${HAVE_FUNC3.memalign:U1}
SUBDIR+=	prog5
.endif

.PHONY: all test
test : all
	set -e; cd ${.CURDIR}; ./test.sh

.include <mkc.subdir.mk>
