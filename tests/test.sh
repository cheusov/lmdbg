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

# real tests
execname="$OBJDIR"/_test1
srcname="$SRCDIR"/tests/test1.c
logname="$OBJDIR"/_log

"$CC" -O0 -g -o "$execname" "$srcname"
runtest lmdbg-run -o "$logname" "$execname"

grep malloc  "$logname" | unify_address
grep realloc "$logname" | unify_address
grep free    "$logname" | unify_address
