PATH.test3 :=	${.PARSEDIR}

CPPFLAGS +=	-I${PATH.test3}
LDFLAGS  +=	-L${OBJDIR_libtest3}
