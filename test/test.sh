#!/bin/sh

set -e

test -n "$OBJDIR"
test -n "$LMDBG_LIB"

LC_ALL=C
export LC_ALL

: ${LMDBG_PROCFS:=/proc}
if test -f "$LMDBG_PROCFS/$$/maps"; then
    procfs_exists=1
fi

unify_paths (){
    # /home/cheusov/prjs/lmdbg/ ---> /lmdbg/dir/
    sed -e 's,\([^[:space:]]*\)/prog,/path/to/prog,' \
	-e 's,'`dirname "$LMDBG_LIB"`',/lmdbg/dir,g' \
	-e 's,/[^ ]*lmdbg[^ ]*/,/lmdbg/dir/,g' \
	-e 's,[^[:space:]]*/\([^ /]*[.]c\),\1,' "$@"
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
	$1 == "malloc"         {$6 = "0xF00DBEAF"}
	$1 == "calloc"         {$8 = "0xF00DBEAF"}
	($1 == "posix_memalign" || $1 == "aligned_alloc") && $8 != "NULL" {$8 = "0xF00DBEAF"}
	$1 == "free"           {$3 = "0xF00DBEAF"}
	$1 == "realloc"        {$8 = "0xF00DBEAF"}
	$1 == "mmap"           {$12 = "0xF00DBEAF"}
	$1 == "realloc" && $3 != "NULL" {$3 = "0xF00DBEAF"}
	match($0, /^ [^ \t]+/) {$0 = " 0xF00DBEAF" substr($0, RSTART+RLENGTH)}
	{ print }
    ' "$@"
}

skip_info (){
    grep -v '^info ' "$@"
}

skip_foreign_mallocs (){
    lmdbg-grep '!/malloc/ || /[(] (1|2|555|666|777|888) [)]/' "$@"
}

skip_useless_addr (){
    awk 'NF != 1 || $1 != "0xF00DBEAF"' "$@"
}

hide_num (){
    sed 's/num: [0-9][0-9]*/num: MMM/'
}

skip_all (){
    skip_foreign_mallocs "$@" | skip_useless_addr | hide_num
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
    awk -F'\t' -v procfs_exists="$procfs_exists" '
	{ sub(/wrap_/, "") }
	$0 ~ /^[^ ]/ || /prog.[.]c|test3.c/ || (procfs_exists && $2 ~ /lmdbg[.]c/)
    ' "$@"
}

tmpfn1=/tmp/lmdbg.1.$$
tmpfn2=/tmp/lmdbg.2.$$
tmpfn3=/tmp/lmdbg.3.$$
errfn=/tmp/lmdbg.4.$$

trap "rm -rf $tmpfn1 $tmpfn2 $tmpfn3 $errfn" 0 INT QUIT TERM HUP

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
	echo '' > "$errfn"
    fi
}

####################
# completely stupid tests
lmdbg-run -h            | head -1 |
cmp "lmdbg-run -h" \
'lmdbg-run is intended to run your program with
'

lmdbg-sym -h            | head -1 |
cmp "lmdbg-sym -h" \
"lmdbg-sym analyses lmdbg-run's output and converts
"

lmdbg-leaks -h          | head -1 |
cmp "lmdbg-leaks -h" \
"This program analyses lmdbg-run's or lmdbg-sym's output and
"

lmdbg-sysleaks -h       | head -1 |
cmp "lmdbg-sysleaks -h" \
"This program analyses lmdbg-run's output and
"

lmdbg-stat -h | head -1 |
cmp "lmdbg-stat -h" \
'Taking an output of lmdbg-run or other lmdbg-* utilities on input
'

lmdbg-grep -h | head -1 |
cmp "lmdbg-grep -h" \
'Taking an output of lmdbg-stat on input lmdbg-grep outputs global
'

lmdbg-head -h | head -1 |
cmp "lmdbg-head -h" \
'Taking an output of lmdbg on input, lmdbg-head outputs global
'

lmdbg-run -V | head -1 | version2XXX |
cmp "lmdbg-run -V" \
"lmdbg-run XXX
"

lmdbg-sym -V | head -1 | version2XXX |
cmp "lmdbg-sym -V" \
"lmdbg-sym XXX
"

lmdbg-leaks -V | head -1 | version2XXX |
cmp "lmdbg-leaks -V" \
"lmdbg-leaks XXX
"

lmdbg-sysleaks -V | head -1 | version2XXX |
cmp "lmdbg-sysleaks -V" \
"lmdbg-sysleaks XXX
"

lmdbg-stat -V | head -1 | version2XXX |
cmp 'lmdbg-stat -V' \
'lmdbg-stat XXX
'

lmdbg-grep -V | head -1 | version2XXX |
cmp 'lmdbg-grep -V' \
'lmdbg-grep XXX
'

lmdbg-modules -V | head -1 | version2XXX |
cmp "lmdbg-modules -V" \
"lmdbg-modules XXX
"

lmdbg-strip -V | head -1 | version2XXX |
cmp "lmdbg-strip -V" \
"lmdbg-strip XXX
"

lmdbg-head -V | head -1 | version2XXX |
cmp "lmdbg-head -V" \
"lmdbg-head XXX
"

####################
# normal tests

#
execname1=`which prog1 || true`
execname2=`which prog2 || true`
execname3=`which prog3 || true`
execname4=`which prog4 || true`
execname5=`which prog5 || true`
execname6=`which prog6 || true`
execname7=`which prog7 || true`
execname8=`which prog8 || true`
execname9=`which prog9 || true`
execname10=`which prog10 || true`
logname="$OBJDIR"/_log
pidfile="$OBJDIR"/_pid

# lmdbg-run and $#
if lmdbg-run -o "$logname" "$execname1 1 2 3 4" 2>/dev/null; then
    echo FAILED
else
    echo ok
fi |
cmp 'lmdbg-run and $# #1' \
'ok
'

if ! lmdbg-run -o "$logname" "$execname1" '1 1 1' 2 '3 3' 4 2>/dev/null; then
    echo FAILED
fi |
cmp 'lmdbg-run and $# #2' \
'argc=4
'

# lmdbg-run -o with no progname
if lmdbg-run -o "$logname" 2>/dev/null; then
    echo FAILED
else
    echo ok
fi |
cmp 'lmdbg-run -o with no progname' \
'ok
'

# lmdbg-run -o with empty progname
if lmdbg-run -o "$logname" '    ' 2>/dev/null; then
    echo FAILED
else
    echo ok
fi |
cmp 'lmdbg-run -o with empty progname' \
'ok
'

if lmdbg-run -v -o "$logname" "$execname5" 2>&1; then
    echo FAILED
else
    echo $?
fi |
unify_paths |
cmp 'lmdbg-run: test for exit status' \
'Running /path/to/prog5 with LD_PRELOAD=/lmdbg/dir/liblmdbg.so
Done.
17
'

# lmdbg-leaks
cat > "$logname" <<EOF
info section 0x00000000400000 0x00000000401000
info section 0x007f7ff7400000 0x007f7ff751f000
info section 0x007f7ff7c00000 0x007f7ff7c12000
info progname ./hello_SLIST
malloc ( 16384 ) --> 0x7f7ff7b01000 num: 1
 0x7f7ff74f0a8a
malloc ( 10 ) --> 0x7f7ff7b09080 num: 2
 0x7f7ff74dc6e7
calloc ( 1 , 16 ) --> 0x7f7ff7b09090 num: 3
 0x400c68
 0x400d0e
 0x400b13
malloc ( 10 ) --> 0x7f7ff7b090a0 num: 4
 0x7f7ff74dc6e7
calloc ( 1 , 16 ) --> 0x7f7ff7b090b0 num: 5
 0x400c68
 0x400d0e
 0x400b13
malloc ( 11 ) --> 0x7f7ff7b090c0 num: 6
 0x7f7ff74dc6e7
calloc ( 1 , 16 ) --> 0x7f7ff7b090d0 num: 7
 0x400c68
 0x400d0e
 0x400b13
malloc ( 4096 ) --> 0x7f7ff7b0b000 num: 8
 0x7f7ff74f0a8a
free ( 0x7f7ff7b090c0 ) num: 9
 0x400c22
 0x400d33
 0x400b13
free ( 0x7f7ff7b090d0 ) num: 10
 0x400c3f
 0x400d33
 0x400b13
free ( 0x7f7ff7b090a0 ) num: 11
 0x400c22
 0x400d33
 0x400b13
free ( 0x7f7ff7b090b0 ) num: 12
 0x400c3f
 0x400d33
 0x400b13
free ( 0x7f7ff7b09080 ) num: 13
 0x400c22
 0x400d33
 0x400b13
free ( 0x7f7ff7b09090 ) num: 14
 0x400c3f
 0x400d33
 0x400b13
EOF

lmdbg-leaks < "$logname" |
cmp 'lmdbg-leaks real #1' \
'info progname ./hello_SLIST
info section 0x00000000400000 0x00000000401000
info section 0x007f7ff7400000 0x007f7ff751f000
info section 0x007f7ff7c00000 0x007f7ff7c12000
malloc ( 16384 ) --> 0x7f7ff7b01000 num: 1
 0x7f7ff74f0a8a
malloc ( 4096 ) --> 0x7f7ff7b0b000 num: 8
 0x7f7ff74f0a8a
'

cat > "$logname" <<EOF
info progname ./hello_SLIST
info section 0x00000000400000 0x00000000401000
info section 0x007f7ff7400000 0x007f7ff751f000
info section 0x007f7ff7c00000 0x007f7ff7c12000
malloc ( 16384 ) --> 0x7f7ff7b01000 num: 1
 0x7f7ff74f0a8a
malloc ( 10 ) --> 0x7f7ff7b09080 num: 2
 0x7f7ff74dc6e7
malloc ( 16 ) --> 0x7f7ff7b09090 num: 3
 0x400c68
 0x400d0e
 0x400b13
malloc ( 10 ) --> 0x7f7ff7b090a0 num: 4
 0x7f7ff74dc6e7
malloc ( 16 ) --> 0x7f7ff7b090b0 num: 5
 0x400c68
 0x400d0e
 0x400b13
malloc ( 11 ) --> 0x7f7ff7b090c0 num: 6
 0x7f7ff74dc6e7
malloc ( 16 ) --> 0x7f7ff7b090d0 num: 7
 0x400c68
 0x400d0e
 0x400b13
malloc ( 4096 ) --> 0x7f7ff7b0b000 num: 8
 0x7f7ff74f0a8a
free ( 0x7f7ff7b090c0 ) num: 9
 0x400c22
 0x400d33
 0x400b13
free ( 0x7f7ff7b090d0 ) num: 10
 0x400c3f
 0x400d33
 0x400b13
free ( 0x7f7ff7b090a0 ) num: 11
 0x400c22
 0x400d33
 0x400b13
free ( 0x7f7ff7b090b0 ) num: 12
 0x400c3f
 0x400d33
 0x400b13
free ( 0x7f7ff7b09080 ) num: 13
 0x400c22
 0x400d33
 0x400b13
free ( 0x7f7ff7b09090 ) num: 14
 0x400c3f
 0x400d33
 0x400b13
EOF

lmdbg-leaks < "$logname" |
cmp 'lmdbg-leaks real #2' \
'info progname ./hello_SLIST
info section 0x00000000400000 0x00000000401000
info section 0x007f7ff7400000 0x007f7ff751f000
info section 0x007f7ff7c00000 0x007f7ff7c12000
malloc ( 16384 ) --> 0x7f7ff7b01000 num: 1
 0x7f7ff74f0a8a
malloc ( 4096 ) --> 0x7f7ff7b0b000 num: 8
 0x7f7ff74f0a8a
'

# -o
rm -f "$logname"

if echo qwerty | lmdbg-run -o "$logname" grep qwerty > /dev/null 2>&1; then
    echo ok
else
    echo $?
fi |
cmp 'stacktrace(3): test for sigsegv seen on NetBSD/x86_64' \
'ok
'

if grep '^ ' "$logname" 2>&1 > /dev/null; then
    echo ok
else
    echo "grep(1) exit status is $?"
fi |
cmp 'lmdbg-run: non-empty log' \
'ok
'

# -o
if lmdbg-run -o "$logname" "$execname7" 2>/dev/null 1>&2; then
    echo FAILED
else
    echo $?
fi |
cmp 'stacktrace(3): test for foreign sigsegv' \
'139
'

# -o
lmdbg-run -o "$logname" "$execname1"

unify_address "$logname" | skip_info | skip_all | head -5 |
cmp "prog1.c: lmdbg-run -o" \
"malloc ( 555 ) --> 0xF00DBEAF num: MMM
realloc ( NULL , 666 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
free ( 0xF00DBEAF ) num: MMM
"

# lmdbg-run + prog10.c
logname="$OBJDIR"/_log

lmdbg-run -o "$logname" "$execname10" || true

unify_address "$logname" | skip_info |
    skip_all | head -5 |
    cmp "prog10.c: lmdbg-run -o" \
''

#
lmdbg-run -mo "$logname" "$execname10" || true

unify_address "$logname" | skip_info |
    skip_all | head -5 |
    cmp "prog10.c: lmdbg-run -m -o" \
'mmap ( NULL , 40960 , PROT_READ|PROT_WRITE , MAP_ANON ) --> 0xF00DBEAF num: MMM
'

# -n
lmdbg-run -o "$logname" -n "$execname1"

unify_address "$logname" | skip_info | skip_all |
cmp "prog1.c: lmdbg-run -n" \
''

# -T
lmdbg-run -o "$logname" -T1 "$execname1"

unify_address "$logname" | skip_info | skip_all | head -5 |
cmp "prog1.c: lmdbg-run -T" \
"malloc ( 555 ) --> 0xF00DBEAF num: MMM
realloc ( NULL , 666 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
free ( 0xF00DBEAF ) num: MMM
"

# -B
lmdbg-run -o "$logname" -B2 "$execname1"

unify_address "$logname" | skip_info | skip_all | head -5 |
cmp "prog1.c: lmdbg-run -B" \
"malloc ( 555 ) --> 0xF00DBEAF num: MMM
realloc ( NULL , 666 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
free ( 0xF00DBEAF ) num: MMM
"

# -o
lmdbg-run -o "$logname" "$execname1"

unify_address "$logname" | skip_info | skip_all | head -5 |
cmp "prog1.c: lmdbg-run -o" \
"malloc ( 555 ) --> 0xF00DBEAF num: MMM
realloc ( NULL , 666 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
free ( 0xF00DBEAF ) num: MMM
"

# lmdbg-leaks
logname2="$OBJDIR"/_log2
lmdbg-leaks "$logname" > "$logname2"

unify_address "$logname2" | skip_info | skip_all |
cmp "prog1.c: lmdbg-leaks" \
"realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
"

# lmdbg-sym -g
lmdbg-sym -g "$logname" |
unify_address | skip_info | hide_lmdbg_code | hide_line_numbers |
canonize_paths | skip_all | lmdbg-head -n 5 |
cmp "prog1.c: lmdbg-sym" \
"malloc ( 555 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog1.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog1.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog1.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog1.c:NNN	main
free ( 0xF00DBEAF ) num: MMM
 0xF00DBEAF	prog1.c:NNN	main
"

# lmdbg-sym -g
lmdbg-sym -g -P "$execname1" "$logname" |
unify_address | skip_info | hide_lmdbg_code | hide_line_numbers |
canonize_paths | skip_all | lmdbg-head -n 5 |
cmp "prog1.c: lmdbg-sym -g" \
"malloc ( 555 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog1.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog1.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog1.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog1.c:NNN	main
free ( 0xF00DBEAF ) num: MMM
 0xF00DBEAF	prog1.c:NNN	main
"

if addr2line --help >/dev/null 2>&1 && test `uname -s` != SunOS; then
    lmdbg-sym -a -P "$execname1" "$logname" |
    unify_address | skip_info | hide_lmdbg_code | hide_line_numbers |
    canonize_paths | skip_all |  lmdbg-head -n 5 | grep -v '0xF00DBEAF.*prog1' |
    cmp "prog1.c: lmdbg-sym -a" \
"malloc ( 555 ) --> 0xF00DBEAF num: MMM
realloc ( NULL , 666 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
free ( 0xF00DBEAF ) num: MMM
"
fi

# lmdbg-run -f lmdbg-leaks
lmdbg-run -o"$logname" -f lmdbg-leaks "$execname1"

unify_address "$logname" | skip_info | hide_lmdbg_code |
hide_line_numbers |
canonize_paths | skip_all |
cmp "prog1.c: lmdbg-run -f lmdbg-leaks" \
"realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
"

# lmdbg-run -f lmdbg-leaks
lmdbg-run -o"$logname" -f lmdbg-leaks "$execname1"

unify_address "$logname" | skip_info | hide_lmdbg_code |
hide_line_numbers |
canonize_paths | skip_all |
cmp "prog1.c: lmdbg-run -f lmdbg-leaks" \
"realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
"

# prog1.c
logname="$OBJDIR"/_log

# lmdbg-run -o with two leaks
lmdbg-run -o "$logname" -f"lmdbg-sym" "$execname2"

unify_address "$logname" | skip_info | skip_all |
hide_line_numbers |
canonize_paths | skip_all | hide_foreign_code | lmdbg-head -n 4 |
cmp "prog2.c: lmdbg-run -f" \
"malloc ( 555 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog2.c:NNN	main
realloc ( NULL , 666 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog2.c:NNN	main
realloc ( 0xF00DBEAF , 777 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog2.c:NNN	main
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog2.c:NNN	main
"

# lmdbg-leaks with two leaks
logname2="$OBJDIR"/_log2
lmdbg-leaks "$logname" > "$logname2"

unify_paths_inplace "$logname"

unify_paths "$logname2" | skip_info | unify_address | skip_all |
hide_line_numbers | hide_foreign_code | sort |
cmp "prog2.c: lmdbg-run -p again" \
" 0xF00DBEAF	prog2.c:NNN	main
 0xF00DBEAF	prog2.c:NNN	main
malloc ( 555 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
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

unify_address "$logname2" | skip_info | skip_all |
hide_line_numbers |
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

unify_address "$logname2" | skip_info | skip_all |
hide_line_numbers |
canonize_paths |
cmp "prog2.c: lmdbg-sysleaks -c ./lmdbg2.conf -s" ''

# lmdbg-leaks with lmdbg-leak3.conf
lmdbg-sysleaks -c ./lmdbg3.conf -s \
    "$logname" > "$logname2"

unify_address "$logname2" | skip_info | skip_all |
hide_line_numbers |
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

unify_address "$logname2" | skip_info | skip_all |
hide_line_numbers |
cmp "prog2.c: lmdbg-sysleaks -c ./lmdbg3.conf" \
'realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF
 0xF00DBEAF	lmdbg.c:NNN	log_stacktrace
 0xF00DBEAF	lmdbg.c:NNN	realloc
 0xF00DBEAF	/lmdbg/dir/prog2.c:NNN	main
'

# lmdbg!
lmdbg -c ./lmdbg3.conf -o "$logname" "$execname1" || true

unify_paths "$logname" | skip_all |
hide_line_numbers | unify_address | skip_info | hide_foreign_code |
cmp "prog1.c: lmdbg -c ./lmdbg3.conf" \
'realloc ( 0xF00DBEAF , 888 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog1.c:NNN	main
'

# lmdbg!
if false; then
    # disabled because NetBSD-9.0 allocates memory
    # somewhere in libc and does not free it.
lmdbg -v -c ./lmdbg5.conf -o "$logname" "$execname1" 2>"$logname2" || true

cat "$logname2" |
cmp "prog1.c: lmdbg -v -c lmdbg5.conf" \
'No memory leaks detected
'
fi

# lmdbg!
lmdbg -c ./lmdbg6.conf -o "$logname" "$execname2" || true

unify_address "$logname" | skip_info | skip_all |
hide_line_numbers | unify_paths | hide_foreign_code |
cmp "prog1.c: lmdbg -o" \
'malloc ( 555 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog2.c:NNN	main
'

# lmdbg -M allocs!
lmdbg -T2 -M allocs -o "$logname" "$execname6" || true

unify_address "$logname" | skip_all |
hide_line_numbers | unify_paths | hide_foreign_code | grep -E '^[^ ]|main' |
cmp "prog6.c: lmdbg -M allocs #1" \
'info progname /path/to/prog6
info stat total_allocs: 2201
info stat total_free_cnt: 1
info stat total_leaks: 2400
stacktrace peak: 2000 max: 1 allocs: 2000 leaks: 2000
 	prog6.c:NNN	main
stacktrace peak: 400 max: 2 allocs: 200 leaks: 400
 	prog6.c:NNN	main
stacktrace peak: 888 max: 888 allocs: 1
 	prog6.c:NNN	main
'

# lmdbg -M allocs!
lmdbg -T2 -Ma -o "$logname" "$execname6" || true

unify_address "$logname" | skip_all |
hide_line_numbers | unify_paths | hide_foreign_code | grep -E '^[^ ]|main' |
cmp "prog6.c: lmdbg -Ma #2" \
'info progname /path/to/prog6
info stat total_allocs: 2201
info stat total_free_cnt: 1
info stat total_leaks: 2400
stacktrace peak: 2000 max: 1 allocs: 2000 leaks: 2000
 	prog6.c:NNN	main
stacktrace peak: 400 max: 2 allocs: 200 leaks: 400
 	prog6.c:NNN	main
stacktrace peak: 888 max: 888 allocs: 1
 	prog6.c:NNN	main
'

# lmdbg -M peak!
lmdbg -T2 -Mpeak -o "$logname" "$execname6" || true

unify_address "$logname" | skip_all |
hide_line_numbers | unify_paths | hide_foreign_code | grep -E '^[^ ]|main' |
cmp "prog6.c: lmdbg -M peak #1" \
'info progname /path/to/prog6
info stat total_allocs: 2201
info stat total_free_cnt: 1
info stat total_leaks: 2400
stacktrace peak: 2000 max: 1 allocs: 2000 leaks: 2000
 	prog6.c:NNN	main
stacktrace peak: 888 max: 888 allocs: 1
 	prog6.c:NNN	main
stacktrace peak: 400 max: 2 allocs: 200 leaks: 400
 	prog6.c:NNN	main
'

# lmdbg -M p!
lmdbg -T2 -M p -o "$logname" "$execname6" || true

unify_address "$logname" | skip_all |
hide_line_numbers | unify_paths | hide_foreign_code | grep -E '^[^ ]|main' |
cmp "prog6.c: lmdbg -M p #2" \
'info progname /path/to/prog6
info stat total_allocs: 2201
info stat total_free_cnt: 1
info stat total_leaks: 2400
stacktrace peak: 2000 max: 1 allocs: 2000 leaks: 2000
 	prog6.c:NNN	main
stacktrace peak: 888 max: 888 allocs: 1
 	prog6.c:NNN	main
stacktrace peak: 400 max: 2 allocs: 200 leaks: 400
 	prog6.c:NNN	main
'

# lmdbg -M max!
lmdbg -T2 -Mmax -o "$logname" "$execname6" || true

unify_address "$logname" | skip_all |
hide_line_numbers | unify_paths | hide_foreign_code | grep -E '^[^ ]|main' |
cmp "prog6.c: lmdbg -M max #1" \
'info progname /path/to/prog6
info stat total_allocs: 2201
info stat total_free_cnt: 1
info stat total_leaks: 2400
stacktrace peak: 888 max: 888 allocs: 1
 	prog6.c:NNN	main
stacktrace peak: 400 max: 2 allocs: 200 leaks: 400
 	prog6.c:NNN	main
stacktrace peak: 2000 max: 1 allocs: 2000 leaks: 2000
 	prog6.c:NNN	main
'

# lmdbg -M m!
lmdbg -T2 -M m -o "$logname" "$execname6" || true

unify_address "$logname" | skip_all |
hide_line_numbers | unify_paths | hide_foreign_code | grep -E '^[^ ]|main' |
cmp "prog6.c: lmdbg -M m #2" \
'info progname /path/to/prog6
info stat total_allocs: 2201
info stat total_free_cnt: 1
info stat total_leaks: 2400
stacktrace peak: 888 max: 888 allocs: 1
 	prog6.c:NNN	main
stacktrace peak: 400 max: 2 allocs: 200 leaks: 400
 	prog6.c:NNN	main
stacktrace peak: 2000 max: 1 allocs: 2000 leaks: 2000
 	prog6.c:NNN	main
'

# lmdbg -M leaks!
lmdbg -T2 -M leaks -o "$logname" "$execname6" || true

unify_address "$logname" | skip_all |
hide_line_numbers | unify_paths | hide_foreign_code | grep -E '^[^ ]|main' |
cmp "prog6.c: lmdbg -M leaks #1" \
'info progname /path/to/prog6
info stat total_allocs: 2200
info stat total_free_cnt: 0
info stat total_leaks: 2400
stacktrace peak: 2000 max: 1 allocs: 2000 leaks: 2000
 	prog6.c:NNN	main
stacktrace peak: 400 max: 2 allocs: 200 leaks: 400
 	prog6.c:NNN	main
'

# lmdbg -M leaks!
lmdbg -T2 -M l -o "$logname" "$execname6" || true

unify_address "$logname" | skip_all |
hide_line_numbers | unify_paths | hide_foreign_code | grep -E '^[^ ]|main' |
cmp "prog6.c: lmdbg -M l #2" \
'info progname /path/to/prog6
info stat total_allocs: 2200
info stat total_free_cnt: 0
info stat total_leaks: 2400
stacktrace peak: 2000 max: 1 allocs: 2000 leaks: 2000
 	prog6.c:NNN	main
stacktrace peak: 400 max: 2 allocs: 200 leaks: 400
 	prog6.c:NNN	main
'

# lmdbg-run -nN
lmdbg-run -o "$logname" -nN "$pidfile" "$execname8" &
sleep 1
kill -USR1 `cat $pidfile`
wait

unify_address "$logname" | skip_info | skip_all | grep -E ' (555|666) ' |
cmp "prog8.c: lmdbg-run + SIGUSR1" \
"malloc ( 666 ) --> 0xF00DBEAF num: MMM
"

# lmdbg-run -o and shared libraries
lmdbg-run -o "$logname" "$execname3"

unify_address "$logname" | skip_info | skip_all |
    grep -E ' (555|666) ' |
    hide_line_numbers | unify_paths |
cmp "prog3.c: lmdbg-run -o" \
'malloc ( 555 ) --> 0xF00DBEAF num: MMM
malloc ( 666 ) --> 0xF00DBEAF num: MMM
'

# lmdbg-sym -g and shared libraries
lmdbg-sym -g -P "$execname3" "$logname" |
    unify_paths | unify_address | skip_info | hide_lmdbg_code | skip_foreign_mallocs |
    hide_line_numbers | lmdbg-head -n 2 | hide_num | skip_useless_addr |
cmp "prog3.c: lmdbg-sym -g" \
'malloc ( 555 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	test3.c:NNN	allocate_memory
 0xF00DBEAF	prog3.c:NNN	main
malloc ( 666 ) --> 0xF00DBEAF num: MMM
 0xF00DBEAF	prog3.c:NNN	main
'

# lmdbg-run + prog4.c
logname="$OBJDIR"/_log

if test "$with_glibc" = 0; then
    lmdbg-run -o "$logname" "$execname4"

    unify_address "$logname" | skip_info | 
    skip_all | head -5 |
    cmp "prog4.c: lmdbg-run -o" \
'calloc ( 555 , 16 ) --> 0xF00DBEAF num: MMM
calloc ( 5 , 256 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF num: MMM
calloc ( 1 , 10240 ) --> 0xF00DBEAF num: MMM
free ( 0xF00DBEAF ) num: MMM
'

    # lmdbg-leaks + prog4.c
    lmdbg-leaks "$logname" |
    unify_address | skip_info | skip_all | sort |
    cmp "prog4.c: lmdbg-leaks + calloc" \
'calloc ( 1 , 10240 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF num: MMM
'
fi

if test "$with_posix_memalign" = 1; then
    # lmdbg-run + prog5.c
    logname="$OBJDIR"/_log

    lmdbg-run -o "$logname" "$execname5" || true

    unify_address "$logname" | skip_info |
    skip_all | head -5 |
    cmp "prog5.c: lmdbg-run -o" \
'posix_memalign ( 16 , 200 ) --> 0xF00DBEAF num: MMM
posix_memalign ( 8 , 256 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF num: MMM
posix_memalign ( 256 , 10240 ) --> 0xF00DBEAF num: MMM
free ( 0xF00DBEAF ) num: MMM
'

    # lmdbg-leaks + prog5.c
    lmdbg-leaks "$logname" | lmdbg-sym -p |
    unify_paths | hide_line_numbers |
    unify_address | skip_info | skip_all |
    hide_foreign_code | sort |
    cmp "prog5.c: lmdbg-leaks + lmdbg-sym" \
' 0xF00DBEAF	prog5.c:NNN	main
 0xF00DBEAF	prog5.c:NNN	main
posix_memalign ( 256 , 10240 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF num: MMM
'
fi

if test "$with_aligned_alloc" = 1; then
    # lmdbg-run + prog9.c
    logname="$OBJDIR"/_log

    lmdbg-run -o "$logname" "$execname9" || true

    unify_address "$logname" | skip_info |
    skip_all | head -5 |
    cmp "prog9.c: lmdbg-run -o" \
'aligned_alloc ( 16 , 200 ) --> 0xF00DBEAF num: MMM
aligned_alloc ( 8 , 256 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF num: MMM
aligned_alloc ( 256 , 10240 ) --> 0xF00DBEAF num: MMM
free ( 0xF00DBEAF ) num: MMM
'

    # lmdbg-leaks + prog9.c
    lmdbg-leaks "$logname" | lmdbg-sym -p |
    unify_paths | hide_line_numbers |
    unify_address | skip_info | skip_all |
    hide_foreign_code | sort |
    cmp "prog9.c: lmdbg-leaks + lmdbg-sym" \
' 0xF00DBEAF	prog9.c:NNN	main
 0xF00DBEAF	prog9.c:NNN	main
aligned_alloc ( 256 , 10240 ) --> 0xF00DBEAF num: MMM
realloc ( 0xF00DBEAF , 1024 ) --> 0xF00DBEAF num: MMM
'
fi

# lmdbg-m2s: malloc
ctrl2norm (){
    awk '{
	gsub(/\031/, "\\{031}")
	gsub(/\032/, "\\{032}")
	gsub(/\033/, "\\{033}")
	gsub(/\034/, "\\{034}")
	print}' "$@"
}

test_fn="$OBJDIR/_tst"

$LMDBG_M2S_DIR/lmdbg-m2s ./input2.txt | ctrl2norm |
cmp "lmdbg-m2s:" \
'info lalala \{031}
malloc ( 123 ) -> 0x1234 \{031}\{034}0x234\{034}0x456
calloc ( 16 , 124 ) -> 0x1235 \{031}\{034}0x235\{034}0x457\{034}0x678
memalign ( 16 , 123 ) -> 0x1235000 \{031}\{034}0x1\{034}0x2\{034}0x3
aligned_alloc ( 8 , 124 ) -> 0x123E000 \{031}\{034}0x1\{034}0x2\{034}0x8
realloc ( 0x1235000 , 12300 ) -> 0x2236000 \{031}\{034}0x2\{034}0x3\{034}0x4
posix_memalign ( 16 , 123 ) -> 0x3235000 \{031}\{034}0x1\{033}foo\{034}0x2\{033}bar\{032}baz\{034}0x3\{033}foobar
stacktrace peak: 123 max: 234 allocs: 456 \{031}\{034}0x111\{034}0x222\{034}0x333
'

# lmdbg-s2m: malloc
ctrl2norm (){
    awk '{
	gsub(/\\[{]032[}]/, "\032")
	gsub(/\\[{]033[}]/, "\033")
	gsub(/\\[{]034[}]/, "\034")
	print}' "$@"
}

$LMDBG_M2S_DIR/lmdbg-m2s ./input2.txt | $LMDBG_S2M_DIR/lmdbg-s2m > $test_fn.tmp
printf 'lmdbg-s2m:... ' 1>&2
if diff ./input2.txt "$test_fn.tmp" > "$test_fn.tmp2"; then
    echo ok
else
    echo FAILED
    awk '{print "   " $0}' "$test_fn.tmp2"
    ex=1
fi

# lmdbg-stat: malloc
lmdbg-stat ./input3.txt | $LMDBG_M2S_DIR/lmdbg-m2s | sort | $LMDBG_S2M_DIR/lmdbg-s2m |
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

lmdbg-stat ./input1.txt | $LMDBG_M2S_DIR/lmdbg-m2s | sort | $LMDBG_S2M_DIR/lmdbg-s2m | tee "$stat_fn" |
cmp "lmdbg-stat (input1.txt):" \
'info lalala
info stat total_allocs: 14
info stat total_free_cnt: 2
info stat total_leaks: 933
stacktrace peak: 130 max: 130 allocs: 1 leaks: 130
 0x2
 0x3
stacktrace peak: 200 max: 200 allocs: 1
 0x7
stacktrace peak: 223 max: 123 allocs: 2 leaks: 123
 0x1
 0x2
stacktrace peak: 248 max: 248 allocs: 1
 0x2
 0x3
 0x4
stacktrace peak: 300 max: 300 allocs: 1
 0x5
stacktrace peak: 310 max: 180 allocs: 5 leaks: 310
 0x6
stacktrace peak: 370 max: 140 allocs: 3 leaks: 370
 0x3
 0x4
 0x5
'

# lmdbg-grep
lmdbg-grep 'address >= "0x8049600" && address <= "0x8049770"' ./input4.txt |
cmp 'lmdbg-grep + address' \
'info stat total_leaks: 50
info stat total_allocs: 4
info stat total_free_cnt: 2
stacktrace peak: 90 max: 90 allocs: 1
 0xbbbe2bc3	lmdbg.c:101	log_stacktrace
 0xbbbe3498	lmdbg.c:431	malloc
 0x8049700	testme2.c:987	testfunc21
 0x8049634	testme2.c:87	testfunc22
 0x8048788	testme.c:7	main
 0x80485b4
 0x8048517
'

lmdbg-grep 'source ~ /^testme2.c:/' ./input4.txt |
cmp 'lmdbg-grep + source' \
'info stat total_leaks: 50
info stat total_allocs: 4
info stat total_free_cnt: 2
stacktrace peak: 90 max: 90 allocs: 1
 0xbbbe2bc3	lmdbg.c:101	log_stacktrace
 0xbbbe3498	lmdbg.c:431	malloc
 0x8049700	testme2.c:987	testfunc21
 0x8049634	testme2.c:87	testfunc22
 0x8048788	testme.c:7	main
 0x80485b4
 0x8048517
'

lmdbg-grep 'funcname == "testfunc1"' ./input4.txt |
cmp 'lmdbg-grep + funcname' \
'info stat total_leaks: 50
info stat total_allocs: 4
info stat total_free_cnt: 2
stacktrace peak: 120 max: 70 allocs: 3 leaks: 50
 0xbbbe2bc3	lmdbg.c:101	log_stacktrace
 0xbbbe33bd	lmdbg.c:456	realloc
 0x8049900	testme.c:987	testfunc1
 0x8048757	testme.c:9	main
 0x80485b4
 0x8048517
'

lmdbg-grep 'addrline ~ /bar/' ./input2.txt |
cmp 'lmdbg-grep + addrline' \
'info lalala
posix_memalign ( 16 , 123 ) -> 0x3235000
 0x1	foo
 0x2	bar baz
 0x3	foobar
'

lmdbg-grep 'bytes == 123' ./input2.txt |
cmp 'lmdbg-grep + bytes' \
'info lalala
malloc ( 123 ) -> 0x1234
 0x234
 0x456
memalign ( 16 , 123 ) -> 0x1235000
 0x1
 0x2
 0x3
posix_memalign ( 16 , 123 ) -> 0x3235000
 0x1	foo
 0x2	bar baz
 0x3	foobar
'

lmdbg-grep 'bytes == 1984' ./input2.txt |
cmp 'lmdbg-grep + bytes' \
'info lalala
calloc ( 16 , 124 ) -> 0x1235
 0x235
 0x457
 0x678
'

lmdbg-grep 'bytes == 12300' ./input2.txt |
cmp 'lmdbg-grep + bytes' \
'info lalala
realloc ( 0x1235000 , 12300 ) -> 0x2236000
 0x2
 0x3
 0x4
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
aligned_alloc ( 8 , 124 ) -> 0x123E000
 0x1
 0x2
 0x8
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
info stat total_allocs: 14
info stat total_free_cnt: 2
info stat total_leaks: 933
stacktrace peak: 130 max: 130 allocs: 1 leaks: 130
 0x2
 0x3
stacktrace peak: 223 max: 123 allocs: 2 leaks: 123
 0x1
 0x2
stacktrace peak: 310 max: 180 allocs: 5 leaks: 310
 0x6
stacktrace peak: 370 max: 140 allocs: 3 leaks: 370
 0x3
 0x4
 0x5
'

# lmdbg-grep
lmdbg-grep -v 'peak < 200' "$stat_fn" |
cmp 'lmdbg-grep -v + peak' \
'info lalala
info stat total_allocs: 14
info stat total_free_cnt: 2
info stat total_leaks: 933
stacktrace peak: 200 max: 200 allocs: 1
 0x7
stacktrace peak: 223 max: 123 allocs: 2 leaks: 123
 0x1
 0x2
stacktrace peak: 248 max: 248 allocs: 1
 0x2
 0x3
 0x4
stacktrace peak: 300 max: 300 allocs: 1
 0x5
stacktrace peak: 310 max: 180 allocs: 5 leaks: 310
 0x6
stacktrace peak: 370 max: 140 allocs: 3 leaks: 370
 0x3
 0x4
 0x5
'

# lmdbg-sort
lmdbg-sort -f peak < "$stat_fn" |
cmp 'lmdbg-sort -f peak' \
'info lalala
info stat total_allocs: 14
info stat total_free_cnt: 2
info stat total_leaks: 933
stacktrace peak: 370 max: 140 allocs: 3 leaks: 370
 0x3
 0x4
 0x5
stacktrace peak: 310 max: 180 allocs: 5 leaks: 310
 0x6
stacktrace peak: 300 max: 300 allocs: 1
 0x5
stacktrace peak: 248 max: 248 allocs: 1
 0x2
 0x3
 0x4
stacktrace peak: 223 max: 123 allocs: 2 leaks: 123
 0x1
 0x2
stacktrace peak: 200 max: 200 allocs: 1
 0x7
stacktrace peak: 130 max: 130 allocs: 1 leaks: 130
 0x2
 0x3
'

lmdbg-sort -f leaks < "$stat_fn" |
cmp 'lmdbg-sort -f leaks' \
'info lalala
info stat total_allocs: 14
info stat total_free_cnt: 2
info stat total_leaks: 933
stacktrace peak: 370 max: 140 allocs: 3 leaks: 370
 0x3
 0x4
 0x5
stacktrace peak: 310 max: 180 allocs: 5 leaks: 310
 0x6
stacktrace peak: 130 max: 130 allocs: 1 leaks: 130
 0x2
 0x3
stacktrace peak: 223 max: 123 allocs: 2 leaks: 123
 0x1
 0x2
stacktrace peak: 200 max: 200 allocs: 1
 0x7
stacktrace peak: 248 max: 248 allocs: 1
 0x2
 0x3
 0x4
stacktrace peak: 300 max: 300 allocs: 1
 0x5
'

lmdbg-sort -f max < "$stat_fn" |
cmp 'lmdbg-sort -f max' \
'info lalala
info stat total_allocs: 14
info stat total_free_cnt: 2
info stat total_leaks: 933
stacktrace peak: 300 max: 300 allocs: 1
 0x5
stacktrace peak: 248 max: 248 allocs: 1
 0x2
 0x3
 0x4
stacktrace peak: 200 max: 200 allocs: 1
 0x7
stacktrace peak: 310 max: 180 allocs: 5 leaks: 310
 0x6
stacktrace peak: 370 max: 140 allocs: 3 leaks: 370
 0x3
 0x4
 0x5
stacktrace peak: 130 max: 130 allocs: 1 leaks: 130
 0x2
 0x3
stacktrace peak: 223 max: 123 allocs: 2 leaks: 123
 0x1
 0x2
'

lmdbg-sort -f leaks input5.txt |
cmp 'lmdbg-sort -f leaks + no stacktraces'  \
'info progname myprogram
info stat total_allocs: 71087
info stat total_free_cnt: 0
info stat total_leaks: 51220723
stacktrace peak: 29191257 max: 22006166 allocs: 12306 leaks: 29191257 module: mod13
stacktrace peak: 7765763 max: 2471053 allocs: 32998 leaks: 7765763    module: mod4
stacktrace peak: 5008186 max: 2251871   allocs: 1537 leaks: 5008186   module: mod14
stacktrace peak: 4290081 max: 1611674 allocs: 5608  leaks: 4290081    module: mod1
stacktrace peak: 2850474 max: 2849762   allocs: 104  leaks: 2850474   module: mod15
stacktrace peak: 851100  max: 748820  allocs: 12768 leaks: 851100     module: mod3
stacktrace peak: 473047  max: 324561  allocs: 4060  leaks: 473047     module: mod12
stacktrace peak: 466367  max: 389244  allocs: 160   leaks: 466367     module: mod11
stacktrace peak: 179274  max: 179086  allocs: 85    leaks: 179274     module: mod7
stacktrace peak: 74746   max: 51846   allocs: 958   leaks: 74746      module: mod10
stacktrace peak: 55586   max: 50880   allocs: 332   leaks: 55586      module: mod6
stacktrace peak: 8224    max: 8080      allocs: 29   leaks: 8224      module: mod16
stacktrace peak: 3696    max: 3696    allocs: 16    leaks: 3696       module: mod2
stacktrace peak: 2845    max: 1185    allocs: 123   leaks: 2845       module: mod9
stacktrace peak: 68      max: 68      allocs: 1     leaks: 68         module: mod5
stacktrace peak: 8       max: 8       allocs: 1     leaks: 8          module: mod8
'

lmdbg-sort -f num input6.txt |
cmp 'lmdbg-sort -f num'  \
'realloc ( 0x7f7ff7b0cc00 , 888 ) --> 0x7f7ff7b0c800 num: 1
 0x7f7ff7800fc0
 0x7f7ff7801c4b
 0x402a44
 0x400902
realloc ( 0x7f7ff7b0cc00 , 888 ) --> 0x7f7ff7b0c800 num: 3
 0x7f7ff7803fc0
 0x7f7ff7802c4b
 0x400a44
 0x400902
realloc ( 0x7f7ff7b0cc00 , 888 ) --> 0x7f7ff7b0c800 num: 4
 0x7f7ff7805fc0
 0x7f7ff7804c4b
 0x401a44
 0x400902
'

# lmdbg-modules
lmdbg-modules -c lmdbg-modules_config.txt lmdbg-modules_input.txt |
cmp 'lmdbg-modules' \
'stacktrace peak: 450 max: 123 allocs: 2000 leaks: 100 module: module1
 0x1000	module1.c:1000	module1_func1(void*)
stacktrace peak: 430 max: 129 allocs: 2001 leaks: 1000 module: module1
 0x1000	module1.c:1020	module1_func1(void*)
stacktrace peak: 450 max: 423 allocs: 2200 leaks: 200 module: module5
 0x5200	submodule52.c:5000	submodule52_func52(int, int)
 0x5000	module5.c:5000	module5_func5(int, int)
stacktrace peak: 470 max: 421 allocs: 2300 leaks: 300 module: module5
 0x5200	submodule52.c:5100	submodule52_func52(int, int)
 0x5000	module5.c:5000	module5_func5(int, int)
stacktrace peak: 270 max: 221 allocs: 2302 leaks: 302 module: module2
 0x2000	module2.c:2000	module2_func2(const char*)
stacktrace peak: 5270 max: 225 allocs: 2305 leaks: 305 module: submodule53
 0x5300	submodule53.c:5000	submodule53_func53(const char*)
 0x5000	module5.c:5000	module5_func5(const char*)
stacktrace peak: 2702 max: 2212 allocs: 232 leaks: 3022 module: module2
 0x2000	module2.c:2000	module2_func2(const char*)
stacktrace peak: 3703 max: 3312 allocs: 332 leaks: 3033 module: module3
 0x3000	module3.c:3000	module3_func3(void)
stacktrace brbrbr module: module4
 0x4000	module4.c:4000	module4_func4
stacktrace lalala
 0x6000	module6.c:6000	module6_func6
stacktrace bla-bla-bla module: submodule51
 0x5100	module5.c:5000	submodule51_func51
 0x5000	module5.c:5000	module5_func5
'

lmdbg-modules -s -c lmdbg-modules_config.txt lmdbg-modules_input.txt |
lmdbg-sort -f leaks |
cmp 'lmdbg-modules -s' \
'info modulestat peak: 2702 max: 2212 allocs: 2534 leaks: 3324 module: module2
info modulestat peak: 3703 max: 3312 allocs: 332 leaks: 3033 module: module3
info modulestat peak: 450 max: 129 allocs: 4001 leaks: 1100 module: module1
info modulestat peak: 470 max: 423 allocs: 4500 leaks: 500 module: module5
info modulestat peak: 5270 max: 225 allocs: 2305 leaks: 305 module: submodule53
'

# lmdbg-strip
lmdbg-strip -l input4.txt |
cmp 'lmdbg-strip -l' \
'info stat total_leaks: 50
info stat total_allocs: 4
info stat total_free_cnt: 2
stacktrace peak: 120 max: 70 allocs: 3 leaks: 50
 0xbbbe2bc3	lmdbg.c	log_stacktrace
 0xbbbe33bd	lmdbg.c	realloc
 0x8049900	testme.c	testfunc1
 0x8048757	testme.c	main
 0x80485b4
 0x8048517
stacktrace peak: 90 max: 90 allocs: 1
 0xbbbe2bc3	lmdbg.c	log_stacktrace
 0xbbbe3498	lmdbg.c	malloc
 0x8049700	testme2.c	testfunc21
 0x8049634	testme2.c	testfunc22
 0x8048788	testme.c	main
 0x80485b4
 0x8048517
'

lmdbg-strip -r input1.txt |
cmp 'lmdbg-strip -r' \
'info lalala
malloc ( 123 ) --> 0xXYZ
 0x1
 0x2
calloc ( 2 , 124 ) --> 0xXYZ
 0x2
 0x3
 0x4
memalign ( 16 , 120 ) --> 0xXYZ
 0x3
 0x4
 0x5
free ( 0xXYZ )
 0x1
posix_memalign ( 16 , 130 ) --> 0xXYZ
 0x2
 0x3
malloc ( 100 ) --> 0xXYZ
 0x1
 0x2
malloc ( 200 ) --> 0xXYZ
 0x7
realloc ( 0xXYZ , 300 ) --> 0xXYZ
 0x5
free ( 0xXYZ )
 0x1
realloc ( 0xXYZ , 110 ) --> 0xXYZ
 0x6
realloc ( 0xXYZ , 120 ) --> 0xXYZ
 0x6
realloc ( 0xXYZ , 140 ) --> 0xXYZ
 0x6
realloc ( 0xXYZ , 130 ) --> 0xXYZ
 0x6
memalign ( 16 , 110 ) --> 0xXYZ
 0x3
 0x4
 0x5
realloc ( 0xXYZ , 180 ) --> 0xXYZ
 0x6
aligned_alloc ( 8 , 140 ) --> 0xXYZ
 0x3
 0x4
 0x5
'

lmdbg-strip -al input4.txt |
cmp 'lmdbg-strip -al' \
'info stat total_leaks: 50
info stat total_allocs: 4
info stat total_free_cnt: 2
stacktrace peak: 120 max: 70 allocs: 3 leaks: 50
 	lmdbg.c	log_stacktrace
 	lmdbg.c	realloc
 	testme.c	testfunc1
 	testme.c	main
stacktrace peak: 90 max: 90 allocs: 1
 	lmdbg.c	log_stacktrace
 	lmdbg.c	malloc
 	testme2.c	testfunc21
 	testme2.c	testfunc22
 	testme.c	main
'

lmdbg-strip -as input4.txt |
cmp 'lmdbg-strip -as' \
'info stat total_leaks: 50
info stat total_allocs: 4
info stat total_free_cnt: 2
stacktrace peak: 120 max: 70 allocs: 3 leaks: 50
 		log_stacktrace
 		realloc
 		testfunc1
 		main
stacktrace peak: 90 max: 90 allocs: 1
 		log_stacktrace
 		malloc
 		testfunc21
 		testfunc22
 		main
'

lmdbg-strip -n input4.txt |
cmp 'lmdbg-strip -n' \
'info stat total_leaks: 50
info stat total_allocs: 4
info stat total_free_cnt: 2
stacktrace peak: 120 max: 70 allocs: 3 leaks: 50
 0xbbbe2bc3	lmdbg.c:101	log_stacktrace
 0xbbbe33bd	lmdbg.c:456	realloc
 0x8049900	testme.c:987	testfunc1
 0x8048757	testme.c:9	main
 0x80485b4
 0x8048517
stacktrace peak: 90 max: 90 allocs: 1
 0xbbbe2bc3	lmdbg.c:101	log_stacktrace
 0xbbbe3498	lmdbg.c:431	malloc
 0x8049700	testme2.c:987	testfunc21
 0x8049634	testme2.c:87	testfunc22
 0x8048788	testme.c:7	main
 0x80485b4
 0x8048517
'

# lmdbg-strip
lmdbg-head input1.txt |
cmp 'lmdbg-head' \
'info lalala
malloc ( 123 ) --> 0x1234
 0x1
 0x2
calloc ( 2 , 124 ) --> 0x1235
 0x2
 0x3
 0x4
memalign ( 16 , 120 ) --> 0x1236
 0x3
 0x4
 0x5
free ( 0x1235 )
 0x1
posix_memalign ( 16 , 130 ) --> 0x1237
 0x2
 0x3
malloc ( 100 ) --> 0x1238
 0x1
 0x2
malloc ( 200 ) --> 0x1239
 0x7
realloc ( 0x1238 , 300 ) --> 0x123A
 0x5
free ( 0x1239 )
 0x1
realloc ( 0x123A , 110 ) --> 0x123B
 0x6
'

lmdbg-head -n3 input1.txt |
cmp 'lmdbg-head -n3' \
'info lalala
malloc ( 123 ) --> 0x1234
 0x1
 0x2
calloc ( 2 , 124 ) --> 0x1235
 0x2
 0x3
 0x4
memalign ( 16 , 120 ) --> 0x1236
 0x3
 0x4
 0x5
'

#
if test -f "$errfn"; then
    exit 1
else
    exit 0
fi
