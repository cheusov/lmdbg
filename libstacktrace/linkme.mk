PATH.stacktrace :=	${.PARSEDIR}

CPPFLAGS  +=	-I${PATH.stacktrace}
LDFLAGS   +=	-L${PATH.stacktrace}
