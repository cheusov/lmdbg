#!/bin/sh

set -e

CC=${CC:=cc}
SRCDIR=${SRCDIR:=.}

test -n "$OBJDIR"
test -n "$LMDBG_LIB"

LC_ALL=C
export LC_ALL

unify_paths (){
    # /home/cheusov/prjs/lmdbg/ ---> /lmdbg/dir/
    sed 's,/[^ ]*lmdbg[^ ]*/,/lmdbg/dir/,g' "$@"
}

unify_paths_inplace (){
    unify_paths "$1" > "$1"_
    mv "$1"_ "$1"
}

####################

unify_address (){
    # input:  malloc ( <size> ) --> 0x81234567
    # output: malloc ( <size> ) --> 0xF00DBEAF
    awk '
	$1 == "info" {next}
	$1 == "malloc"         {$6 = "0xF00DBEAF"}
	$1 == "calloc"         {$8 = "0xF00DBEAF"}
	$1 == "posix_memalign" && $8 != "NULL" {$8 = "0xF00DBEAF"}
	$1 == "free"           {$3 = "0xF00DBEAF"}
	$1 == "realloc"        {$8 = "0xF00DBEAF"}
	$1 == "realloc" && $3 != "NULL" {$3 = "0xF00DBEAF"}
	match($0, /^ [^ \t]+/) {$0 = " 0xF00DBEAF" substr($0, RSTART+RLENGTH)}
	{ print }
    ' "$@"
}

skip_useless_addr (){
    awk 'NF != 1 || $1 != "0xF00DBEAF"' "$@"
}

hide_lmdbg_code (){
    # cut off line like the following
    #   0xF00DBEAF  /GNU/libc/code/source.c     some_func
    awk '/^ 0x/ && !/test/ {$0 = " " $1} {print}' "$@"
}

hide_line_numbers (){
    # ....source.c:67     ---> source.c:NNN
    sed 's,:[0-9][0-9]*,:NNN,' "$@"
}

canonize_paths (){
    # ..../dir/to/source.c:67     ---> source.c:67
    awk '/^ / {sub(/[^ \t]*\//, "")} {print}' "$@"
}

version2XXX (){
    awk '{$2 = "XXX"; print}'
}

hide_foreign_code (){
    awk -F'\t' '
	{ sub(/wrap_/, "") }
	$0 ~ /^[^ ]/ || $2 ~ /lmdbg[.]c|test.[.]c/
    ' "$@"
}

tmpfn1=/tmp/lmdbg.1.$$
tmpfn2=/tmp/lmdbg.2.$$
tmpfn3=/tmp/lmdbg.3.$$

ex=0

cmp (){
    # $1 - progress message
    # $2 - expected text
    printf '%s... ' "$1" 1>&2

    cat > "$tmpfn2"
    printf '%s' "$2" > "$tmpfn1"

    if diff -u "$tmpfn1" "$tmpfn2" > "$tmpfn3"; then
	echo ok
    else
	echo FAILED
	awk '{print "   " $0}' "$tmpfn3"
	ex=1
    fi
}

####################
# stupid tests
lmdbg-run --help | head -1 |
cmp "lmdbg-run --help" \
'lmdbg-run is intended to run your program with
'

lmdbg-sym --help | head -1 |
cmp "lmdbg-sym --help" \
"lmdbg-sym analyses lmdbg-run's output and converts
"

lmdbg-leaks --help | head -1 |
cmp "lmdbg-leaks --help" \
"This program analyses lmdbg-run's or lmdbg-sym's output and
"

lmdbg-sysleaks --help   | head -1 |
cmp "lmdbg-sysleaks --help" \
"This program analyses lmdbg-run's output and
"

lmdbg-run -h            | head -1 |
cmp "lmdbg-run --help" \
'lmdbg-run is intended to run your program with
'

lmdbg-sym -h            | head -1 |
cmp "lmdbg-sym --help" \
"lmdbg-sym analyses lmdbg-run's output and converts
"

lmdbg-leaks -h          | head -1 |
cmp "lmdbg-leaks --help" \
"This program analyses lmdbg-run's or lmdbg-sym's output and
"

lmdbg-sysleaks -h       | head -1 |
cmp "lmdbg-sysleaks --help" \
"This program analyses lmdbg-run's output and
"

lmdbg-run --version        | head -1 | version2XXX |
cmp "lmdbg-run --version" \
"lmdbg-run XXX
"

lmdbg-sym --version        | head -1 | version2XXX |
cmp "lmdbg-sym --version" \
"lmdbg-sym XXX
"

lmdbg-leaks --version      | head -1 | version2XXX |
cmp "lmdbg-leaks --version" \
"lmdbg-leaks XXX
"
lmdbg-sysleaks --version   | head -1 | version2XXX |
cmp "lmdbg-sysleaks --version" \
"lmdbg-sysleaks XXX
"

lmdbg-run -V               | head -1 | version2XXX |
cmp "lmdbg-run -V" \
"lmdbg-run XXX
"

lmdbg-sym -V               | head -1 | version2XXX |
cmp "lmdbg-sym -V" \
"lmdbg-sym XXX
"

lmdbg-leaks -V             | head -1 | version2XXX |
cmp "lmdbg-leaks -V" \
"lmdbg-leaks XXX
"

lmdbg-sysleaks -V          | head -1 | version2XXX |
cmp "lmdbg-sysleaks -V" \
"lmdbg-sysleaks XXX
"

# test1.c
execname="$OBJDIR"/_test1
srcname="$SRCDIR"/tests/test1.c
logname="$OBJDIR"/_log

$CC -O0 -g -o "$execname" "$srcname"

# !FIX ME! Use mk-configure's mkc.lib.mk here!
libsrcname="$SRCDIR"/tests/libtest.c
libname="$OBJDIR"/libtest.so
$CC -O0 -g -shared -fPIC -DPIC -o "$libname" "$libsrcname"

exec3name="$OBJDIR"/_test3
src3name="$SRCDIR"/tests/test3.c
$CC -O0 -g -o $exec3name -L${OBJDIR} "$src3name" -ltest

#
LD_LIBRARY_PATH=$OBJDIR
export LD_LIBRARY_PATH

# -o
lmdbg-run -o "$logname" "$execname"

unify_address "$logname" | skip_useless_addr |
cmp "test1.c: lmdbg-run -o" \
"malloc ( 555 ) --> 0xF00DBEAF
realloc ( NULL , 666 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
free ( 0xF00DBEAF )
"

# --log
lmdbg-run --log "$logname" "$execname"

unify_address "$logname" | skip_useless_addr |
cmp "test1.c: lmdbg-run --log" \
"malloc ( 555 ) --> 0xF00DBEAF
realloc ( NULL , 666 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
free ( 0xF00DBEAF )
"

# lmdbg-leaks
logname2="$OBJDIR"/_log2
lmdbg-leaks "$logname" > "$logname2"

unify_address "$logname2" | skip_useless_addr |
cmp "test1.c: lmdbg-leaks" \
"realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
"

# lmdbg-sym --with-gdb
lmdbg-sym --with-gdb "$execname" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers |
canonize_paths | skip_useless_addr |
cmp "test1.c: lmdbg-sym" \
"malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN	main
free ( 0xF00DBEAF )
 0xF00DBEAF	test1.c:NNN	main
"

# lmdbg-sym -g
lmdbg-sym -g "$execname" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers |
canonize_paths | skip_useless_addr |
cmp "test1.c: lmdbg-sym -g" \
"malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN	main
free ( 0xF00DBEAF )
 0xF00DBEAF	test1.c:NNN	main
"

# lmdbg-sym -a
lmdbg-sym -a "$execname" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers |
canonize_paths | skip_useless_addr |
cmp "test1.c: lmdbg-sym -a" \
"malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	test1.c:NNN
free ( 0xF00DBEAF )
 0xF00DBEAF	test1.c:NNN
"

# lmdbg-run --pipe lmdbg-leaks
lmdbg-run -o "$logname" --pipe lmdbg-leaks "$execname"

unify_address "$logname" | hide_lmdbg_code |
hide_line_numbers |
canonize_paths | skip_useless_addr |
cmp "test1.c: lmdbg-run --pipe lmdbg-leaks" \
"realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
"

# lmdbg-run -p lmdbg-leaks
lmdbg-run -o "$logname" -p lmdbg-leaks "$execname"

unify_address "$logname" | hide_lmdbg_code |
hide_line_numbers |
canonize_paths | skip_useless_addr |
cmp "test1.c: lmdbg-run -p lmdbg-leaks" \
"realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
"

# test1.c
execname="$OBJDIR"/_test2
srcname="$SRCDIR"/tests/test2.c
logname="$OBJDIR"/_log

$CC -O0 -g -o "$execname" "$srcname"

# lmdbg-run -o with two leaks
lmdbg-run -o "$logname" -p "lmdbg-sym $execname" "$execname"

unify_address "$logname" | skip_useless_addr |
hide_line_numbers |
canonize_paths | skip_useless_addr | hide_foreign_code |
cmp "test2.c: lmdbg-run -p" \
"malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	malloc
 0xF00DBEAF	test2.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	test2.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	test2.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	test2.c:NNN	main
"

# lmdbg-leaks with two leaks
logname2="$OBJDIR"/_log2
lmdbg-leaks "$logname" > "$logname2"

unify_paths_inplace "$logname"

unify_paths "$logname2" | unify_address | skip_useless_addr |
hide_line_numbers | hide_foreign_code | sort |
cmp "test2.c: lmdbg-run -p again" \
" 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	malloc
 0xF00DBEAF	lmdbg.c:NNN	realloc
malloc ( 555 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
"

# lmdbg-leaks with lmdbg-leak1.conf
lmdbg-sysleaks -c ./lmdbg1.conf -s \
    "$logname" > "$logname2"

unify_address "$logname2" | skip_useless_addr |
hide_line_numbers | hide_foreign_code |
cmp "test2.c: lmdbg-sysleaks -c ./lmdbg1.conf" \
"malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	malloc
 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
"

# lmdbg-leaks with lmdbg-leak2.conf
lmdbg-sysleaks -c ./lmdbg2.conf -s \
    "$logname" > "$logname2"

unify_address "$logname2" | skip_useless_addr |
hide_line_numbers |
canonize_paths |
cmp "test2.c: lmdbg-sysleaks -c ./lmdbg2.conf -s" ''

# lmdbg-leaks with lmdbg-leak3.conf
lmdbg-sysleaks -c ./lmdbg3.conf -s \
    "$logname" > "$logname2"

unify_address "$logname2" | skip_useless_addr |
hide_line_numbers | hide_foreign_code |
cmp "test2.c: lmdbg-sysleaks -c ./lmdbg3.conf -s" \
'malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	malloc
 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
'

# lmdbg-leaks with lmdbg-leak3.conf
lmdbg-sysleaks -c ./lmdbg3.conf \
    "$logname" > "$logname2"

unify_address "$logname2" | skip_useless_addr |
hide_line_numbers | hide_foreign_code |
cmp "test2.c: lmdbg-sysleaks -c ./lmdbg3.conf" \
'realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
'

# lmdbg!
lmdbg -c ./lmdbg3.conf -o "$logname" "$OBJDIR"/_test1 || true

unify_paths "$logname" | skip_useless_addr |
hide_line_numbers | unify_address | hide_foreign_code |
cmp "test1.c: lmdbg -c ./lmdbg3.conf" \
'realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/test1.c:NNN	main
'

# lmdbg!
lmdbg -v -c ./lmdbg5.conf -o "$logname" "$OBJDIR"/_test1 2>"$logname2" || true

cat "$logname2" |
cmp "test1.c: lmdbg -v -c lmdbg5.conf" \
'No memory leaks detected
'

# lmdbg!
lmdbg -c ./lmdbg6.conf -o "$logname" "$OBJDIR"/_test2 || true

unify_address "$logname" | skip_useless_addr |
hide_line_numbers | unify_paths | hide_foreign_code |
cmp "test1.c: lmdbg -o" \
'malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	malloc
 0xF00DBEAF	/lmdbg/dir/test2.c:NNN	main
'

# lmdbg-run -o and shared libraries
lmdbg-run -o "$logname" "$exec3name"

unify_address "$logname" | skip_useless_addr |
hide_line_numbers | unify_paths |
cmp "test3.c: lmdbg-run -o" \
'malloc ( 555 ) --> 0xF00DBEAF
malloc ( 666 ) --> 0xF00DBEAF
'

# lmdbg-sym -g and shared libraries
lmdbg-sym --with-gdb "$exec3name" "$logname" |
unify_paths | unify_address | hide_lmdbg_code | hide_line_numbers |
skip_useless_addr |
cmp "test3.c: lmdbg-sym -g" \
'malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	/lmdbg/dir/libtest.c:NNN	allocate_memory
 0xF00DBEAF	/lmdbg/dir/test3.c:NNN	main
malloc ( 666 ) --> 0xF00DBEAF
 0xF00DBEAF	/lmdbg/dir/test3.c:NNN	main
'

# lmdbg-run + test4.c
execname="$OBJDIR"/_test4
srcname="$SRCDIR"/tests/test4.c
logname="$OBJDIR"/_log

$CC -O0 -g -o "$execname" "$srcname"
lmdbg-run -o "$logname" "$execname"

unify_address "$logname" |
skip_useless_addr |
cmp "test4.c: lmdbg-run -o" \
'calloc ( 555 , 16 ) --> 0xF00DBEAF
calloc ( 5 , 256 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF
calloc ( 1 , 10240 ) --> 0xF00DBEAF
free ( 0xF00DBEAF )
'

# lmdbg-leaks + test4.c
lmdbg-leaks "$logname" |
unify_address | skip_useless_addr | sort |
cmp "test4.c: lmdbg-leaks + calloc" \
'calloc ( 1 , 10240 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF
'

# lmdbg-run + test5.c
execname="$OBJDIR"/_test5
srcname="$SRCDIR"/tests/test5.c
logname="$OBJDIR"/_log

$CC -O0 -g -o "$execname" "$srcname"
lmdbg-run -o "$logname" "$execname"

unify_address "$logname" |
skip_useless_addr |
cmp "test5.c: lmdbg-run -o" \
'posix_memalign ( 16 , 200 ) --> 0xF00DBEAF
posix_memalign ( 8 , 256 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF
posix_memalign ( 256 , 10240 ) --> 0xF00DBEAF
free ( 0xF00DBEAF )
'

# lmdbg-leaks + test5.c
lmdbg-leaks "$logname" | lmdbg-sym "$execname" |
unify_paths | hide_line_numbers |
unify_address | skip_useless_addr |
hide_foreign_code | sort |
cmp "test5.c: lmdbg-leaks + lmdbg-sym" \
' 0xF00DBEAF	/lmdbg/dir/test5.c:NNN	main
 0xF00DBEAF	/lmdbg/dir/test5.c:NNN	main
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	posix_memalign
 0xF00DBEAF	lmdbg.c:NNN	realloc
posix_memalign ( 256 , 10240 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF
'

exit "$ex"
