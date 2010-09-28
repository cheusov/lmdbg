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
	with_glibc=${HAVE_DEFINE.__GLIBC__}; \
	export PATH LMDBG_LIB OBJDIR SRCDIR CC with_glibc; \
	echo with_glibc=${HAVE_DEFINE.__GLIBC__}; \
	cd ${.CURDIR}/tests; \
	./test.sh
