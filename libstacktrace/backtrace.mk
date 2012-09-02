MKC_CHECK_HEADERS +=	execinfo.h
MKC_CHECK_FUNCLIBS +=	backtrace:execinfo

.include <mkc.configure.mk>

.if ${HAVE_HEADER.execinfo_h:U0}
.if ${HAVE_FUNCLIB.backtrace:U0} || ${HAVE_FUNCLIB.backtrace.execinfo:U0}
CFLAGS +=	-DEXTERNAL_BACKTRACE
.endif
.endif
