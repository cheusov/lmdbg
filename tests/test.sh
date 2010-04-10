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
    awk '/^ 0x/ && !/prog|test/ {$0 = " " $1} {print}' "$@"
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
	$0 ~ /^[^ ]/ || $2 ~ /lmdbg[.]c|prog.[.]c/
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
# completely stupid tests
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

lmdbg-stat --help | head -1 |
cmp "lmdbg-stat --help" \
'Given an output of lmdbg-run or other lmdbg-* utilities on input
'

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

lmdbg-stat -h | head -1 |
cmp "lmdbg-stat -h" \
'Given an output of lmdbg-run or other lmdbg-* utilities on input
'

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

lmdbg-stat --version       | head -1 | version2XXX |
cmp 'lmdbg-stat --version' \
'lmdbg-stat XXX
'

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

lmdbg-stat -V              | head -1 | version2XXX |
cmp 'lmdbg-stat -V' \
'lmdbg-stat XXX
'

####################
# normal tests

# test1.c
if test -d "$OBJDIR/tests"; then
    execname1="$OBJDIR"/tests/prog1/prog1
    execname2="$OBJDIR"/tests/prog2/prog2
    execname4="$OBJDIR"/tests/prog4/prog4
    execname5="$OBJDIR"/tests/prog5/prog5

    logname="$OBJDIR"/_log

    libname="$OBJDIR"/libtest3/libtest3.so

    exec3name="$OBJDIR"/tests/prog3/prog3

    LD_LIBRARY_PATH=$OBJDIR/tests/libtest3
else
    execname1="$OBJDIR"/prog1
    execname2="$OBJDIR"/prog2
    execname4="$OBJDIR"/prog4
    execname5="$OBJDIR"/prog5

    logname="$OBJDIR"/_log

    libname="$OBJDIR"/libtest3.so

    exec3name="$OBJDIR"/prog3

    LD_LIBRARY_PATH=$OBJDIR
fi

#
export LD_LIBRARY_PATH

# -o
lmdbg-run -o "$logname" "$execname1"

unify_address "$logname" | skip_useless_addr |
cmp "prog1.c: lmdbg-run -o" \
"malloc ( 555 ) --> 0xF00DBEAF
realloc ( NULL , 666 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
free ( 0xF00DBEAF )
"

# --log
lmdbg-run --log "$logname" "$execname1"

unify_address "$logname" | skip_useless_addr |
cmp "prog1.c: lmdbg-run --log" \
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
cmp "prog1.c: lmdbg-leaks" \
"realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
"

# lmdbg-sym --with-gdb
lmdbg-sym --with-gdb "$execname1" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers |
canonize_paths | skip_useless_addr |
cmp "prog1.c: lmdbg-sym" \
"malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN	main
free ( 0xF00DBEAF )
 0xF00DBEAF	prog1.c:NNN	main
"

# lmdbg-sym -g
lmdbg-sym -g "$execname1" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers |
canonize_paths | skip_useless_addr |
cmp "prog1.c: lmdbg-sym -g" \
"malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN	main
free ( 0xF00DBEAF )
 0xF00DBEAF	prog1.c:NNN	main
"

# lmdbg-sym -a
lmdbg-sym -a "$execname1" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers |
canonize_paths | skip_useless_addr |
cmp "prog1.c: lmdbg-sym -a" \
"malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	prog1.c:NNN
free ( 0xF00DBEAF )
 0xF00DBEAF	prog1.c:NNN
"

# lmdbg-run --pipe lmdbg-leaks
lmdbg-run -o "$logname" --pipe lmdbg-leaks "$execname1"

unify_address "$logname" | hide_lmdbg_code |
hide_line_numbers |
canonize_paths | skip_useless_addr |
cmp "prog1.c: lmdbg-run --pipe lmdbg-leaks" \
"realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
"

# lmdbg-run -p lmdbg-leaks
lmdbg-run -o "$logname" -p lmdbg-leaks "$execname1"

unify_address "$logname" | hide_lmdbg_code |
hide_line_numbers |
canonize_paths | skip_useless_addr |
cmp "prog1.c: lmdbg-run -p lmdbg-leaks" \
"realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
"

# prog1.c
logname="$OBJDIR"/_log

# lmdbg-run -o with two leaks
lmdbg-run -o "$logname" -p "lmdbg-sym $execname2" "$execname2"

unify_address "$logname" | skip_useless_addr |
hide_line_numbers |
canonize_paths | skip_useless_addr | hide_foreign_code |
cmp "prog2.c: lmdbg-run -p" \
"malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	malloc
 0xF00DBEAF	prog2.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	prog2.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	prog2.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	prog2.c:NNN	main
"

# lmdbg-leaks with two leaks
logname2="$OBJDIR"/_log2
lmdbg-leaks "$logname" > "$logname2"

unify_paths_inplace "$logname"

unify_paths "$logname2" | unify_address | skip_useless_addr |
hide_line_numbers | hide_foreign_code | sort |
cmp "prog2.c: lmdbg-run -p again" \
" 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	malloc
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	prog2.c:NNN	main
 0xF00DBEAF	prog2.c:NNN	main
malloc ( 555 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
"

# lmdbg-leaks with lmdbg-leak1.conf
cat > "$logname" <<EOF
malloc ( 555 ) --> 0xbb907400
 0xbbbe2b38	lmdbg.c:98	log_stacktrace
 0xbbbe3258	lmdbg.c:405	malloc
 0x8048738	/lmdbg/dir/prog2.c:8	main
 0x8048584
 0x80484e7
realloc ( NULL , 666 ) --> 0xbb907800
 0xbbbe2b38	lmdbg.c:98	log_stacktrace
 0xbbbe3333	lmdbg.c:430	realloc
 0x804874e	/lmdbg/dir/prog2.c:9	main
 0x8048584
 0x80484e7
realloc ( 0xbb907800 , 777 ) --> 0xbb907c00
 0xbbbe2b38	lmdbg.c:98	log_stacktrace
 0xbbbe3333	lmdbg.c:430	realloc
 0x8048764	/lmdbg/dir/prog2.c:10	main
 0x8048584
 0x80484e7
realloc ( 0xbb907c00 , 888 ) --> 0xbb907800
 0xbbbe2b38	lmdbg.c:98	log_stacktrace
 0xbbbe3333	lmdbg.c:430	realloc
 0x804877a	/lmdbg/dir/prog2.c:11	main
 0x8048584
 0x80484e7
EOF

lmdbg-sysleaks -c ./lmdbg1.conf -s > "$logname2" < "$logname"

unify_address "$logname2" | skip_useless_addr |
hide_line_numbers | hide_foreign_code |
cmp "prog2.c: lmdbg-sysleaks -c ./lmdbg1.conf" \
"malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	malloc
 0xF00DBEAF	/lmdbg/dir/prog2.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/prog2.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/prog2.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/prog2.c:NNN	main
"

# lmdbg-leaks with lmdbg-leak2.conf
lmdbg-sysleaks -c ./lmdbg2.conf -s \
    "$logname" > "$logname2"

unify_address "$logname2" | skip_useless_addr |
hide_line_numbers |
canonize_paths |
cmp "prog2.c: lmdbg-sysleaks -c ./lmdbg2.conf -s" ''

# lmdbg-leaks with lmdbg-leak3.conf
lmdbg-sysleaks -c ./lmdbg3.conf -s \
    "$logname" > "$logname2"

unify_address "$logname2" | skip_useless_addr |
hide_line_numbers | hide_foreign_code |
cmp "prog2.c: lmdbg-sysleaks -c ./lmdbg3.conf -s" \
'malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	malloc
 0xF00DBEAF	/lmdbg/dir/prog2.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/prog2.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/prog2.c:NNN	main
'

# lmdbg-leaks with lmdbg-leak3.conf
lmdbg-sysleaks -c ./lmdbg3.conf \
    "$logname" > "$logname2"

unify_address "$logname2" | skip_useless_addr |
hide_line_numbers | hide_foreign_code |
cmp "prog2.c: lmdbg-sysleaks -c ./lmdbg3.conf" \
'realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/prog2.c:NNN	main
'

# lmdbg!
lmdbg -c ./lmdbg3.conf -o "$logname" "$execname1" || true

unify_paths "$logname" | skip_useless_addr |
hide_line_numbers | unify_address | hide_foreign_code |
cmp "prog1.c: lmdbg -c ./lmdbg3.conf" \
'realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	prog1.c:NNN	main
'

# lmdbg!
lmdbg -v -c ./lmdbg5.conf -o "$logname" "$execname1" 2>"$logname2" || true

cat "$logname2" |
cmp "prog1.c: lmdbg -v -c lmdbg5.conf" \
'No memory leaks detected
'

# lmdbg!
lmdbg -c ./lmdbg6.conf -o "$logname" "$execname2" || true

unify_address "$logname" | skip_useless_addr |
hide_line_numbers | unify_paths | hide_foreign_code |
cmp "prog1.c: lmdbg -o" \
'malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	malloc
 0xF00DBEAF	prog2.c:NNN	main
'

# lmdbg-run -o and shared libraries
lmdbg-run -o "$logname" "$exec3name"

unify_address "$logname" | skip_useless_addr |
hide_line_numbers | unify_paths |
cmp "prog3.c: lmdbg-run -o" \
'malloc ( 555 ) --> 0xF00DBEAF
malloc ( 666 ) --> 0xF00DBEAF
'

# lmdbg-sym -g and shared libraries
lmdbg-sym --with-gdb "$exec3name" "$logname" |
unify_paths | unify_address | hide_lmdbg_code | hide_line_numbers |
skip_useless_addr | 
cmp "prog3.c: lmdbg-sym -g" \
'malloc ( 555 ) --> 0xF00DBEAF
 0xF00DBEAF	test3.c:NNN	allocate_memory
 0xF00DBEAF	prog3.c:NNN	main
malloc ( 666 ) --> 0xF00DBEAF
 0xF00DBEAF	prog3.c:NNN	main
'

# lmdbg-run + prog4.c
logname="$OBJDIR"/_log

lmdbg-run -o "$logname" "$execname4"

unify_address "$logname" |
skip_useless_addr |
cmp "prog4.c: lmdbg-run -o" \
'calloc ( 555 , 16 ) --> 0xF00DBEAF
calloc ( 5 , 256 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF
calloc ( 1 , 10240 ) --> 0xF00DBEAF
free ( 0xF00DBEAF )
'

# lmdbg-leaks + prog4.c
lmdbg-leaks "$logname" |
unify_address | skip_useless_addr | sort |
cmp "prog4.c: lmdbg-leaks + calloc" \
'calloc ( 1 , 10240 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF
'

# lmdbg-run + prog5.c
logname="$OBJDIR"/_log

lmdbg-run -o "$logname" "$execname5"

unify_address "$logname" |
skip_useless_addr |
cmp "prog5.c: lmdbg-run -o" \
'posix_memalign ( 16 , 200 ) --> 0xF00DBEAF
posix_memalign ( 8 , 256 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF
posix_memalign ( 256 , 10240 ) --> 0xF00DBEAF
free ( 0xF00DBEAF )
'

# lmdbg-leaks + prog5.c
lmdbg-leaks "$logname" | lmdbg-sym "$execname5" |
unify_paths | hide_line_numbers |
unify_address | skip_useless_addr |
hide_foreign_code | sort |
cmp "prog5.c: lmdbg-leaks + lmdbg-sym" \
' 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	posix_memalign
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	prog5.c:NNN	main
 0xF00DBEAF	prog5.c:NNN	main
posix_memalign ( 256 , 10240 ) --> 0xF00DBEAF
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF
'

# lmdbg-m2s: malloc
ctrl2norm (){
    awk '{
	gsub(/\032/, "\\{032}")
	gsub(/\033/, "\\{033}")
	gsub(/\034/, "\\{034}")
	print}' "$@"
}

test_fn="$OBJDIR/_tst"

lmdbg-m2s ./input2.txt | ctrl2norm |
cmp "lmdbg-m2s:" \
'info lalala
malloc ( 123 ) -> 0x1234 0x234\{034}0x456
calloc ( 16 , 124 ) -> 0x1235 0x235\{034}0x457\{034}0x678
memalign ( 16 , 123 ) -> 0x1235000 0x1\{034}0x2\{034}0x3
realloc ( 0x1235000 , 12300 ) -> 0x2236000 0x2\{034}0x3\{034}0x4
posix_memalign ( 16 , 123 ) -> 0x3235000 0x1\{033}foo\{034}0x2\{033}bar\{032}baz\{034}0x3\{033}foobar
stacktrace peak: 123 max: 234 allocs: 456 0x111\{034}0x222\{034}0x333
'

# lmdbg-s2m: malloc
ctrl2norm (){
    awk '{
	gsub(/\\[{]032[}]/, "\032")
	gsub(/\\[{]033[}]/, "\033")
	gsub(/\\[{]034[}]/, "\034")
	print}' "$@"
}

lmdbg-m2s ./input2.txt | lmdbg-s2m > $test_fn.tmp
printf 'lmdbg-s2m:... ' 1>&2
if diff ./input2.txt "$test_fn.tmp" > "$test_fn.tmp2"; then
    echo ok
else
    echo FAILED
    awk '{print "   " $0}' "$test_fn.tmp2"
    ex=1
fi

# lmdbg-stat: malloc
lmdbg-stat ./input3.txt | lmdbg-m2s | sort | lmdbg-s2m |
cmp "lmdbg-stat (input3.txt):" \
'info stat total_allocs: 4
info stat total_free_cnt: 2
info stat total_leaks: 50
stacktrace peak: 100 max: 100 allocs: 1
 0xbbbe2bc3
 0xbbbe33bd
 0x8048757
 0x80485b4
 0x8048517
stacktrace peak: 120 max: 70 allocs: 3 leaks: 50
 0xbbbe2bc3
 0xbbbe3498
 0x8048788
 0x80485b4
 0x8048517
'

stat_fn="$OBJDIR/_stat"

lmdbg-stat ./input1.txt | lmdbg-m2s | sort | lmdbg-s2m | tee "$stat_fn" |
cmp "lmdbg-stat (input1.txt):" \
'info lalala
info stat total_allocs: 13
info stat total_free_cnt: 2
info stat total_leaks: 793
stacktrace peak: 130 max: 130 allocs: 1 leaks: 130
 0x2
 0x3
stacktrace peak: 200 max: 200 allocs: 1
 0x7
stacktrace peak: 223 max: 123 allocs: 2 leaks: 123
 0x1
 0x2
stacktrace peak: 230 max: 120 allocs: 2 leaks: 230
 0x3
 0x4
 0x5
stacktrace peak: 248 max: 248 allocs: 1
 0x2
 0x3
 0x4
stacktrace peak: 300 max: 300 allocs: 1
 0x5
stacktrace peak: 310 max: 180 allocs: 5 leaks: 310
 0x6
'

# lmdbg-grep
lmdbg-grep 'addrline ~ /bar/' ./input2.txt |
cmp 'lmdbg-grep + addrline' \
'info lalala
posix_memalign ( 16 , 123 ) -> 0x3235000
 0x1	foo
 0x2	bar baz
 0x3	foobar
'

lmdbg-grep -v 'addrline ~ /bar/' ./input2.txt |
cmp 'lmdbg-grep -v + addrline' \
'info lalala
malloc ( 123 ) -> 0x1234
 0x234
 0x456
calloc ( 16 , 124 ) -> 0x1235
 0x235
 0x457
 0x678
memalign ( 16 , 123 ) -> 0x1235000
 0x1
 0x2
 0x3
realloc ( 0x1235000 , 12300 ) -> 0x2236000
 0x2
 0x3
 0x4
stacktrace peak: 123 max: 234 allocs: 456
 0x111
 0x222
 0x333
'

# lmdbg-grep
lmdbg-grep 'allocs > 400' ./input2.txt |
cmp 'lmdbg-grep + allocs' \
'info lalala
stacktrace peak: 123 max: 234 allocs: 456
 0x111
 0x222
 0x333
'

# lmdbg-grep
lmdbg-grep 'max > 100 && max < 200' "$stat_fn" |
cmp 'lmdbg-grep + max' \
'info lalala
info stat total_allocs: 13
info stat total_free_cnt: 2
info stat total_leaks: 793
stacktrace peak: 130 max: 130 allocs: 1 leaks: 130
 0x2
 0x3
stacktrace peak: 223 max: 123 allocs: 2 leaks: 123
 0x1
 0x2
stacktrace peak: 230 max: 120 allocs: 2 leaks: 230
 0x3
 0x4
 0x5
stacktrace peak: 310 max: 180 allocs: 5 leaks: 310
 0x6
'

# lmdbg-grep
lmdbg-grep -v 'peak < 200' "$stat_fn" |
cmp 'lmdbg-grep -v + peak' \
'info lalala
info stat total_allocs: 13
info stat total_free_cnt: 2
info stat total_leaks: 793
stacktrace peak: 200 max: 200 allocs: 1
 0x7
stacktrace peak: 223 max: 123 allocs: 2 leaks: 123
 0x1
 0x2
stacktrace peak: 230 max: 120 allocs: 2 leaks: 230
 0x3
 0x4
 0x5
stacktrace peak: 248 max: 248 allocs: 1
 0x2
 0x3
 0x4
stacktrace peak: 300 max: 300 allocs: 1
 0x5
stacktrace peak: 310 max: 180 allocs: 5 leaks: 310
 0x6
'

#
exit "$ex"
