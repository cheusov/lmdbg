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
	export PATH LMDBG_LIB OBJDIR SRCDIR CC; \
	./test.sh

.include <mkc.files.mk>
