SUBDIR+=	prog1    
SUBDIR+=	prog2
SUBDIR+=	libtest3
SUBDIR+=	prog3
SUBDIR+=	prog4
SUBDIR+=	prog5

.PHONY: all test
test : all
	set -e; cd ${.CURDIR}; ./test.sh

.include <mkc.subdir.mk>
