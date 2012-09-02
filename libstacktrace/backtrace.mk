MKC_NOAUTO_FUNCLIBS =	1

MKC_CHECK_HEADERS +=	execinfo.h
MKC_CHECK_FUNCLIBS +=	backtrace:execinfo

.include <mkc.configure.mk>

.if ${HAVE_HEADER.execinfo_h:U0}
CFLAGS +=	-DEXTERNAL_BACKTRACE
.if ${HAVE_FUNCLIB.backtrace.execinfo:U0}
LDADD  +=	-lexecinfo
.endif
.endif

.undef MKC_NOAUTO_FUNCLIBS
