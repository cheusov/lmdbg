#!/bin/sh

set -e

unify_paths (){
    cat "$@"
}

runtest (){
    prog=$1
    shift

    echo '--------------------------------------------------'
    echo "------- args: $@" | unify_paths
    "$OBJDIR"/"$prog" "$@" 2>&1 | unify_paths
}

####################

unify_text (){
    num=$1
    shift

    awk -v num="$num" 'NR == num {$0="XXX"} {print}' "$@"
}

runtest lmdbg-run --help        | head -3 | unify_text 3
runtest lmdbg-sym --help        | head -3 | unify_text 3
runtest lmdbg-check --help      | head -3 | unify_text 3
runtest lmdbg-leak-check --help | head -3 | unify_text 3

runtest lmdbg-run -h            | head -3 | unify_text 3
runtest lmdbg-sym -h            | head -3 | unify_text 3
runtest lmdbg-check -h          | head -3 | unify_text 3
runtest lmdbg-leak-check -h     | head -3 | unify_text 3
