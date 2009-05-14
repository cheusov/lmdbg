# Makefile for lmdbg
# Copyright 2003-2009 Aleksey Cheusov <vle@gmx.net>
##################################################

PROJECTNAME=	lmdbg

BIRTHDATE=	2008-04-28

CFLAGS+=	-DLMDBG_VERSION=\"$(VERSION)\" -I.

CLEANFILES=	ChangeLog _*

###########################

SUBDIR+=	libstacktrace
SUBDIR+=	scripts
SUBDIR+=	.WAIT
SUBDIR+=	liblmdbg

###########################

.include "./Makefile.version"
.include "./Makefile.test"

.include <mkc.subdir.mk>
