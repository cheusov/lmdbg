PATH.st_hash :=	${.PARSEDIR}

CPPFLAGS +=	-I${PATH.st_hash}
LDFLAGS  +=	-L${OBJDIR_st_hash}
