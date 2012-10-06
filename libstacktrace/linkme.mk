PATH.stacktrace :=	${.PARSEDIR}

CPPFLAGS  +=	-I${PATH.stacktrace}
LDFLAGS   +=	-L${OBJDIR_libstacktrace}
