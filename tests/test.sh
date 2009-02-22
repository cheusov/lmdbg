#!/bin/sh

export LC_ALL=C

set -e

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
    grep -v '[[:space:]]lmdbg[.]c' "$@"
}

hide_line_numbers (){
    sed 's,:[0-9][0-9]*,:NNN,' "$@"
}

####################
# stupid tests
runtest lmdbg-run --help        | head -3 | unify_text 3
runtest lmdbg-sym --help        | head -3 | unify_text 3
runtest lmdbg-check --help      | head -3 | unify_text 3
runtest lmdbg-leak-check --help | head -3 | unify_text 3

runtest lmdbg-run -h            | head -3 | unify_text 3
runtest lmdbg-sym -h            | head -3 | unify_text 3
runtest lmdbg-check -h          | head -3 | unify_text 3
runtest lmdbg-leak-check -h     | head -3 | unify_text 3

runtest lmdbg-run --version        | head -3 | unify_text 3
runtest lmdbg-sym --version        | head -3 | unify_text 3
runtest lmdbg-check --version      | head -3 | unify_text 3
runtest lmdbg-leak-check --version | head -3 | unify_text 3

runtest lmdbg-run -V               | head -3 | unify_text 3
runtest lmdbg-sym -V               | head -3 | unify_text 3
runtest lmdbg-check -V             | head -3 | unify_text 3
runtest lmdbg-leak-check -V        | head -3 | unify_text 3

####################
# real tests

# lmdbg-run
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

# lmdbg-check
logname2="$OBJDIR"/_log2
runtest lmdbg-check "$logname" > "$logname2"

grep -- --- "$logname2"

grep malloc  "$logname2" | unify_address
grep realloc "$logname2" | unify_address
grep free    "$logname2" | unify_address

# lmdbg-sym --with-gdb
runtest lmdbg-sym --with-gdb "$execname" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers

# lmdbg-sym -g
runtest lmdbg-sym -g "$execname" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers

# lmdbg-sym -a
runtest lmdbg-sym -a "$execname" "$logname" |
unify_address | hide_lmdbg_code | hide_line_numbers
