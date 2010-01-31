.PHONY: test
test: all
	@echo 'running tests...'; \
	cd ${.CURDIR}/liblmdbg; \
	    LMDBG_LIB=`${MAKE} mkc_printobjdir`/liblmdbg.so; \
	cd ${.CURDIR}/scripts; \
	    PATH=`${MAKE} mkc_printobjdir`:$$PATH; \
	cd ${.CURDIR}/s2m; \
	    PATH=`${MAKE} mkc_printobjdir`:$$PATH; \
	cd ${.CURDIR}/m2s; \
	    PATH=`${MAKE} mkc_printobjdir`:$$PATH; \
	cd ${.CURDIR}/stat; \
	    PATH=`${MAKE} mkc_printobjdir`:$$PATH; \
	OBJDIR=${.OBJDIR}; \
	SRCDIR=${.CURDIR}; \
	CC='${CC}'; \
	export PATH LMDBG_LIB OBJDIR SRCDIR CC; \
	cd ${.CURDIR}/tests; \
	./test.sh
