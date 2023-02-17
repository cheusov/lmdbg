all:
	@echo 'running tests...'; \
	set -e; cd ${.CURDIR}; \
	LMDBG_S2M_DIR=${OBJDIR_s2m}; \
	LMDBG_M2S_DIR=${OBJDIR_m2s}; \
	LMDBG_LIB=${OBJDIR_liblmdbg}/liblmdbg.so; \
	PATH=${OBJDIR_scripts}:${OBJDIR_stat}:$$PATH; \
	PATH=${OBJDIR_prog1}:${OBJDIR_prog2}:${OBJDIR_prog3}:$$PATH; \
	PATH=${OBJDIR_prog4}:${OBJDIR_prog5}:${OBJDIR_prog6}:$$PATH; \
	PATH=${OBJDIR_prog7}:${OBJDIR_prog8}:${OBJDIR_prog9}:$$PATH; \
	PATH=${OBJDIR_prog10}:$$PATH; \
	LD_LIBRARY_PATH=${OBJDIR_libtest3}; \
	OBJDIR=${.CURDIR}/..; \
	SRCDIR=${.CURDIR}; \
	export PATH LD_LIBRARY_PATH LMDBG_LIB OBJDIR SRCDIR \
	   LMDBG_S2M_DIR LMDBG_M2S_DIR; \
	./test.sh

.include <mkc.files.mk>
