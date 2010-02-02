#!/usr/bin/env runawk

#use "power_getopt.awk"
#use "heapsort.awk"
#use "exitnow.awk"

#.begin-str help
# usage: lmdbg-sort [OPTIONS] [files...]
# OPTIONS:
#  -h|--help                display this help
#  =f <field>               sorting key,
#                           valid values are: allocs, max, peak, max.
#                           This option is mandatory!
#.end-str

BEGIN {
	field = getarg("f")
	if (!field){
		print_help()
		exitnow(12)
	}
 
	field = field ":"
 
	count = 1
}

/^info / {
	print $0
	next
}

{
	for (i=1; i <= NF; ++i){
		if ($i == field){
			input [count] = $0
			weights [count] = $(i+1)
			++count
			break
		}
	}
}

END {
	heapsort(weights, remap, 1, count)
	for (i=count; i >= 1; --i){
		print input [remap [i]]
	}
}
