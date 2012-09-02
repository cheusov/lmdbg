all:
	@echo 'running tests...'; \
	set -e; cd ${.CURDIR}; \
	LMDBG_LIB=${OBJDIR_liblmdbg}/liblmdbg.so; \
	PATH=${OBJDIR_scripts}:$$PATH; \
	PATH=${OBJDIR_s2m}:$$PATH; \
	PATH=${OBJDIR_m2s}:$$PATH; \
	PATH=${OBJDIR_stat}:$$PATH; \
	OBJDIR=${.CURDIR}/..; \
	SRCDIR=${.CURDIR}; \
	CC='${CC}'; \
	with_glibc=${HAVE_DEFINE.__GLIBC__.string_h}; \
	with_posix_memalign=${HAVE_FUNC3.posix_memalign.stdlib_h}; \
	export PATH LMDBG_LIB OBJDIR SRCDIR CC with_glibc with_posix_memalign; \
	./test.sh

.include <mkc.files.mk>
