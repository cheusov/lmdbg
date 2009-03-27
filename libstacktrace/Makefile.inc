LDFLAGS+=       -L../libstacktrace
LDADD+=         -lstacktrace_pic
#DPADD+=         ../stacktrace/libstacktrace_pic.a
CPPFLAGS+=	-I../libstacktrace
