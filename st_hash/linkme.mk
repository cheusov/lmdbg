PATH.st_hash :=	${.PARSEDIR}

CPPFLAGS +=	-I${PATH.st_hash}
LDFLAGS  +=	-L${PATH.st_hash}
