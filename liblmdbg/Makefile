.PHONY: all
all : liblmdbg.la

#LIB?=		lmdbg
#SRCS=		lmdbg.c stacktrace.c
SHLIB_MAJOR=	0
SHLIB_MINOR=	0

.for f in lmdbg
${f}.o: ${f}.c
	libtool --tag=CC --mode=compile $(CC) -o ${.TARGET} -c -D_GNU_SOURCE \
		$(CPPFLAGS) $(CFLAGS) -g -O0 $<
.endfor

liblmdbg.la : lmdbg.o

.for f in liblmdbg
${f}.la:
	libtool --tag=CC --mode=link $(CC) -o ${.TARGET} -rpath $(LIBDIR) \
	   -version-info ${SHLIB_MAJOR}:${SHLIB_MINOR} \
	   -g ${.ALLSRC:S/.o/.lo/g} $(LDFLAGS) $(LDADD)
.endfor

.PHONY: install-lmdbg
install-lmdbg : all
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)
	libtool --mode=install $(INSTALL) -m 0755 liblmdbg.la $(DESTDIR)$(LIBDIR)

.PHONY: install
install : install-lmdbg

CLEANFILES+=	*.a *.lo *.la *.o #.libs

.include "../libstacktrace/Makefile.inc"
.include <mkc.prog.mk>
