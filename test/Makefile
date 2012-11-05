all:
	@echo 'running tests...'; \
	set -e; cd ${.CURDIR}; \
	LMDBG_LIB=${OBJDIR_liblmdbg}/liblmdbg.so; \
	PATH=${OBJDIR_scripts}:$$PATH; \
	PATH=${OBJDIR_s2m}:$$PATH; \
	PATH=${OBJDIR_m2s}:$$PATH; \
	PATH=${OBJDIR_stat}:$$PATH; \
	PATH=${OBJDIR_prog1}:$$PATH; \
	PATH=${OBJDIR_prog2}:$$PATH; \
	PATH=${OBJDIR_prog3}:$$PATH; \
	PATH=${OBJDIR_prog4}:$$PATH; \
	PATH=${OBJDIR_prog5}:$$PATH; \
	PATH=${OBJDIR_prog6}:$$PATH; \
	LD_LIBRARY_PATH=${OBJDIR_libtest3}; \
	OBJDIR=${.CURDIR}/..; \
	SRCDIR=${.CURDIR}; \
	CC='${CC}'; \
	export PATH LD_LIBRARY_PATH LMDBG_LIB OBJDIR SRCDIR CC; \
	./test.sh

.include <mkc.files.mk>
