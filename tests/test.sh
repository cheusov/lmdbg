#!/bin/sh

export LC_ALL=C

set -e

export LMDBG_LIBDYN="$OBJDIR"/.libs/liblmdbg.so
export PATH=$OBJDIR:$PATH

unify_paths (){
    cat "$@"
}

runtest (){
    prog=$1
    shift

    echo '--------------------------------------------------'
    echo "------- args: $prog $@" | unify_paths
    "$OBJDIR"/"$prog" "$@" 2>&1 | unify_paths
}

####################

unify_text (){
    num=$1
    shift

    awk -v num="$num" 'NR == num {$0="XXX"} {print}' "$@"
}

unify_address (){
    sed 's,0x[0-9a-fA-F][0-9a-fA-F]*,0xF00DBEAF,g' "$@"
}

hide_lmdbg_code (){
    awk '/^ 0x/ && !/main/ {$0 = " " $1} {print}' "$@"
}

hide_foreign_code (){
    awk '/^ .*[.][cS]/ && !/test.[.]c/ {$0 = " ??:NNN"} {print}' "$@"
}

hide_line_numbers (){
    sed 's,:[0-9][0-9]*,:NNN,' "$@"
}

canonize_paths (){
    awk '/^ / {sub(/[^ \t]*\//, "")} {print}' "$@"
}

####################
# stupid tests
runtest lmdbg-run --help        | head -3 | unify_text 3
runtest lmdbg-sym --help        | head -3 | unify_text 3
runtest lmdbg-leaks --help      | head -3 | unify_text 3
runtest lmdbg-sysleaks --help   | head -3 | unify_text 3

runtest lmdbg-run -h            | head -3 | unify_text 3
runtest lmdbg-sym -h            | head -3 | unify_text 3
runtest lmdbg-leaks -h          | head -3 | unify_text 3
runtest lmdbg-sysleaks -h       | head -3 | unify_text 3

runtest lmdbg-run --version        | head -3 | unify_text 3
runtest lmdbg-sym --version        | head -3 | unify_text 3
runtest lmdbg-leaks --version      | head -3 | unify_text 3
runtest lmdbg-sysleaks --version   | head -3 | unify_text 3

runtest lmdbg-run -V               | head -3 | unify_text 3
runtest lmdbg-sym -V               | head -3 | unify_text 3
runtest lmdbg-leaks -V             | head -3 | unify_text 3
runtest lmdbg-sysleaks -V          | head -3 | unify_text 3

####################
# real tests

# test1.c
execname="$OBJDIR"/_test1
srcname="$SRCDIR"/tests/test1.c
logname="$OBJDIR"/_log

"$CC" -O0 -g -o "$execname" "$srcname"

# -o
runtest lmdbg-run -o "$logname" "$execname"

grep malloc  "$logname" | unify_address
grep realloc "$logname" | unify_address
grep free    "$logname" | unify_address
# --log
runtest lmdbg-run --log "$logname" "$execname"

grep malloc  "$logname" | unify_address
grep realloc "$logname" | unify_address
grep free    "$logname" | unify_address

# lmdbg-leaks
logname2="$OBJDIR"/_log2
runtest lmdbg-leaks "$logname" > "$logname2"

grep -- --- "$logname2"

grep malloc  "$logname2" | unify_address
grep realloc "$logname2" | unify_address
grep free    "$logname2" | unify_address

# lmdbg-sym --with-gdb
runtest lmdbg-sym --with-gdb "$execname" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers | canonize_paths

# lmdbg-sym -g
runtest lmdbg-sym -g "$execname" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers | canonize_paths

# lmdbg-sym -a
runtest lmdbg-sym -a "$execname" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers |
hide_foreign_code | canonize_paths

# lmdbg-run --pipe lmdbg-leaks
runtest lmdbg-run -o "$logname" --pipe "$OBJDIR"/lmdbg-leaks "$execname"

grep malloc  "$logname" | unify_address
grep realloc "$logname" | unify_address
grep free    "$logname" | unify_address

# lmdbg-run -p lmdbg-leaks
runtest lmdbg-run -o "$logname" -p "$OBJDIR"/lmdbg-leaks "$execname"

grep malloc  "$logname" | unify_address
grep realloc "$logname" | unify_address
grep free    "$logname" | unify_address

# test1.c
execname="$OBJDIR"/_test2
srcname="$SRCDIR"/tests/test2.c
logname="$OBJDIR"/_log

"$CC" -O0 -g -o "$execname" "$srcname"

# lmdbg-run -o with two leaks
runtest lmdbg-run -o "$logname" -p "lmdbg-sym $execname" "$execname"

grep ^malloc  "$logname" | unify_address
grep ^realloc "$logname" | unify_address
grep ^free    "$logname" | unify_address

# lmdbg-leaks with two leaks
logname2="$OBJDIR"/_log2
runtest lmdbg-leaks "$logname" > "$logname2"

grep -- --- "$logname2"

grep ^malloc  "$logname2" | unify_address
grep ^realloc "$logname2" | unify_address
grep ^free    "$logname2" | unify_address

# lmdbg-leaks with lmdbg-leak1.conf
runtest lmdbg-sysleaks -c ./lmdbg-check1.conf -s \
    "$logname" > "$logname2"

grep -- --- "$logname2"

grep ^malloc  "$logname2" | unify_address
grep ^realloc "$logname2" | unify_address
grep ^free    "$logname2" | unify_address

# lmdbg-leaks with lmdbg-leak2.conf
runtest lmdbg-sysleaks -c ./lmdbg-check2.conf -s \
    "$logname" > "$logname2"

grep -- --- "$logname2"

grep ^malloc  "$logname2" | unify_address
grep ^realloc "$logname2" | unify_address
grep ^free    "$logname2" | unify_address

# lmdbg-leaks with lmdbg-leak3.conf
runtest lmdbg-sysleaks -c ./lmdbg-check3.conf -s \
    "$logname" > "$logname2"

grep -- --- "$logname2"

grep ^malloc  "$logname2" | unify_address
grep ^realloc "$logname2" | unify_address
grep ^free    "$logname2" | unify_address
