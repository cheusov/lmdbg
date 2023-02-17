/*
  Copyright (c) 2003-2009 Aleksey Cheusov <vle@gmx.net>

  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <assert.h>

#include <Judy.h>

#include "st_hash.h"
#include "stat.h"

static int line_num = 0;

static void *hash = NULL;

static void xputc (int c, FILE *stream)
{
	if (putc (c, stdout) == EOF){
		perror ("putc(3) failed");
		exit (1);
	}
}

static void **stacktrace    = NULL;
static int  stacktrace_len = 0;
static int  stacktrace_max = 0;

typedef enum {
	ft_malloc=10,
	ft_realloc,
	ft_memalign,
	ft_posix_memalign,
	ft_aligned_alloc,
	ft_free
} func_t;

typedef struct {
	func_t type;
	size_t bytes;
	void *oldaddr;
	void *addr;
} operation_t;

static operation_t op;

static int total_allocs_cnt = 0;
static int total_free_cnt = 0;
static size_t total_allocated = 0;

typedef struct {
	size_t allocated;
	int stacktrace_id;
} ptrdata_t;

static Pvoid_t ptr2data = NULL;

static void ptr2data_destroy (void)
{
	Word_t idx = 0;
	stat_t ** ptr = (stat_t **) JudyLFirst (ptr2data, &idx, NULL);
	if (!ptr)
		return;

	do {
		if (*ptr)
			free (*ptr);

		ptr = (stat_t **) JudyLNext (ptr2data, &idx, NULL);
	} while (ptr != NULL);

	JudyLFreeArray (&ptr2data, NULL);
}

static void **stacktrace_dup (void **st, int st_len)
{
	void **p = malloc (st_len * sizeof (st [0]));
	memcpy (p, st, st_len * sizeof (st [0]));
	return p;
}

static void process_stacktrace (void)
{
	int id;
	int old_maxid;
	int new = 0;
	ptrdata_t **ptrdata;
	stat_t **stat_cell_p = NULL;
	stat_t *stat_cell = NULL;

	if (!stacktrace_len)
		return;

	switch (op.type){
		case ft_malloc:
		case ft_realloc:
		case ft_memalign:
		case ft_posix_memalign:
		case ft_aligned_alloc:
			old_maxid = st_hash_getmaxid (hash);
			id = st_hash_insert (hash, stacktrace, stacktrace_len);

			new = id > old_maxid;
//			if (new){
//				statistics = (stat_t*) realloc (
//					statistics,
//					sizeof (statistics [0]) * (id + 1));
//				memset (&statistics [id],0, sizeof (statistics [0]));
//			}

			stat_cell_p = get_stat (id);
			if (!*stat_cell_p){
				*stat_cell_p = malloc (sizeof (stat_t));
				memset (*stat_cell_p, 0, sizeof (stat_t));
			}
			stat_cell = *stat_cell_p;
			stat_cell->allocated += op.bytes;
			if (stat_cell->allocated > stat_cell->peak_allocated)
				stat_cell->peak_allocated = stat_cell->allocated;
			if (op.bytes > stat_cell->max_allocated)
				stat_cell->max_allocated = op.bytes;
			++stat_cell->allocs_cnt;
			if (new){
				stat_cell->stacktrace
					= stacktrace_dup (stacktrace, stacktrace_len);
				stat_cell->stacktrace_len = stacktrace_len;
			}
			++total_allocs_cnt;
			total_allocated += op.bytes;

			/* pointer to associated data */
			ptrdata = (ptrdata_t **) JudyLIns (&ptr2data, (Word_t) op.addr, 0);
			assert (ptrdata);
			*ptrdata = (ptrdata_t *) malloc (sizeof (ptrdata_t));
			(*ptrdata)->allocated = op.bytes;
			(*ptrdata)->stacktrace_id = id;
			break;
		case ft_free:
			break;
		default:
			abort ();
	}

	switch (op.type){
		case ft_malloc:
		case ft_memalign:
		case ft_posix_memalign:
		case ft_aligned_alloc:
			break;
		case ft_realloc:
			if (op.oldaddr){
				ptrdata = (ptrdata_t **) JudyLGet (
					ptr2data, (Word_t) op.oldaddr, 0);

				if (ptrdata){
					total_allocated -= (*ptrdata)->allocated;
					stat_cell_p = get_stat ((*ptrdata)->stacktrace_id);
					stat_cell = *stat_cell_p;
					stat_cell->allocated -= (*ptrdata)->allocated;

					free (*ptrdata);
					JudyLDel (&ptr2data, (Word_t) op.oldaddr, 0);
				}
			}
			break;
		case ft_free:
			if (op.oldaddr){
				ptrdata = (ptrdata_t **) JudyLGet (
					ptr2data, (Word_t) op.oldaddr, 0);

				if (ptrdata){
					total_allocated -= (*ptrdata)->allocated;
					stat_cell_p = get_stat ((*ptrdata)->stacktrace_id);
					stat_cell = *stat_cell_p;
					stat_cell->allocated -= (*ptrdata)->allocated;

					++total_free_cnt;

					free (*ptrdata);
					JudyLDel (&ptr2data, (Word_t) op.oldaddr, 0);
				}
			}
			break;
		default:
			abort ();
	}

	/* reinit */
	stacktrace_len = 0;
}

static void print_results (void)
{
	int i, j;
	int st_count;
	stat_t *stat_cell;
	char buf [200];

	printf ("info stat total_allocs: %i\n", total_allocs_cnt);
	printf ("info stat total_free_cnt: %i\n", total_free_cnt);
	printf ("info stat total_leaks: %lu\n", (unsigned long) total_allocated);

	st_count = st_hash_getmaxid (hash);
	for (i=1; i <= st_count; ++i){
		stat_cell = *get_stat (i);

		printf ("stacktrace peak: %lu max: %lu allocs: %i",
				(unsigned long) stat_cell->peak_allocated,
				(unsigned long) stat_cell->max_allocated,
				                stat_cell->allocs_cnt);
		if (stat_cell->allocated){
			printf (" leaks: %lu", (unsigned long) stat_cell->allocated);
		}
		printf ("\n");
		for (j=0; j < stat_cell->stacktrace_len; ++j){
			buf [0] = 0;
			snprintf (buf, sizeof (buf), "%p", stat_cell->stacktrace [j]);
			if (buf [0] != '0' || buf [1] != 'x'){
				/* Under Solaris %p doesn't print 0x prefix for address */
				printf (" 0x%s\n", buf);
			}else{
				printf (" %s\n", buf);
			}
		}
	}
}

static void * s2p (const char *s)
{
	void *addr = NULL;
	int ret = 0;

	if (strcmp (s, "NULL")){
		ret = sscanf (s, "%p", &addr);
		if (!addr){
			/* Under Solaris %p doesn't accept 0x prefix for address */
			if (s[0] != '0' || s[1] != 'x')
				goto err;

			ret = sscanf (s+2, "%p", &addr);
		}
		if (ret != 1){
		err:
			fprintf (stderr, "Line #%d, bad address: %s\n", line_num, s);
			exit (1);
		}
	}

	return addr;
}

static int s2i (const char *s)
{
	int val;
	int ret = 0;

	ret = sscanf (s, "%i", &val);
	if (ret != 1){
		fprintf (stderr, "Bad integer: %s\n", s);
		exit (1);
	}

	return val;
}

static void process_line (char *buf)
{
	void *addr;
	char *p, *last_p;
	char * tokens [10];
	int token_count = 0;

	char orig_buf [20480];

	snprintf (orig_buf, sizeof (orig_buf), "%s", buf);

	if (!buf [0])
		return;

	if (buf [0] == ' '){
		/* address with leading space character */
		addr = s2p (buf + 1);

		++stacktrace_len;
		if (stacktrace_len > stacktrace_max){
			stacktrace_max = stacktrace_len;
			stacktrace = realloc (stacktrace,
								  stacktrace_max * sizeof (void *));
		}
		stacktrace [stacktrace_len-1] = addr;
	}else{
		process_stacktrace ();

		/* malloc/calloc/realloc/free/... */
		for (p=buf; *p; ++p){
			if (*p == ' ' || *p == '\t')
				*p = 0;
		}
		last_p = p;

		for (p=buf; p <= last_p; ++p){
			if (*p && (p == buf || p [-1] == 0)){
				tokens [token_count++] = p;
				if (token_count == sizeof (tokens)/sizeof (tokens [0])){
					/* too much tokens, ignore the rest */
					break;
				}
			}
		}

		if (token_count >= 5 &&
			!strcmp (tokens [0], "malloc") &&
			!strcmp (tokens [1], "(") &&
			!strcmp (tokens [3], ")") &&
			!strcmp (tokens [4], "-->"))
		{
			op.type    = ft_malloc;
			op.bytes   = (size_t) s2i (tokens [2]);
			op.oldaddr = NULL;
			op.addr    = s2p (tokens [5]);
			return;
		}

		if (token_count >= 8 &&
			!strcmp (tokens [0], "calloc") &&
			!strcmp (tokens [1], "(") &&
			!strcmp (tokens [3], ",") &&
			!strcmp (tokens [5], ")") &&
			!strcmp (tokens [6], "-->"))
		{
			op.type    = ft_malloc;
			op.bytes   = (size_t) (s2i (tokens [2]) * s2i (tokens [4]));
			op.oldaddr = NULL;
			op.addr    = s2p (tokens [7]);
			return;
		}

		if (token_count >= 8 &&
			!strcmp (tokens [0], "realloc") &&
			!strcmp (tokens [1], "(") &&
			!strcmp (tokens [3], ",") &&
			!strcmp (tokens [5], ")") &&
			!strcmp (tokens [6], "-->"))
		{
			op.type    = ft_realloc;
			op.bytes   = (size_t) s2i (tokens [4]);
			op.oldaddr = s2p (tokens [2]);
			op.addr    = s2p (tokens [7]);
			return;
		}

		if (token_count >= 8 &&
			(!strcmp (tokens [0], "memalign") ||
			 !strcmp (tokens [0], "posix_memalign") ||
			 !strcmp (tokens [0], "aligned_alloc")) &&
			!strcmp (tokens [1], "(") &&
			!strcmp (tokens [3], ",") &&
			!strcmp (tokens [5], ")") &&
			!strcmp (tokens [6], "-->"))
		{
			op.type    = ft_memalign;
			op.bytes   = (size_t) s2i (tokens [4]);
			op.oldaddr = NULL;
			op.addr    = s2p (tokens [7]);
			return;
		}

		if (token_count >= 4 &&
			!strcmp (tokens [0], "free") &&
			!strcmp (tokens [1], "(") &&
			!strcmp (tokens [3], ")"))
		{
			op.type    = ft_free;
			op.bytes   = 0;
			op.oldaddr = s2p (tokens [2]);
			op.addr    = NULL;
			return;
		}

		if (token_count >= 1 && !strcmp (tokens [0], "info")){
			puts (orig_buf);
			return;
		}

		fprintf (stderr, "bad input line: %s\n", orig_buf);
	}
}

static void process_stream (FILE *in)
{
	char buffer [10000];
	size_t len;
	while (fgets (buffer, sizeof (buffer), in)){
		len = strlen (buffer);
		if (len > 0 && buffer [len-1] == '\n'){
			buffer [len-1] = 0;
		}else{
			/* ignore incomplete badly formatted lines,
			   they may appear due to program crash */
			break;
		}

		++line_num;
		process_line (buffer);
	}

	if (ferror (in)){
		perror ("fgets(3) failed");
		exit (1);
	}

	process_stacktrace ();

	if (stacktrace)
		free (stacktrace);
	stacktrace = NULL;
}

extern char *optarg;
extern int optind;

static void show_version (void)
{
	printf ("lmdbg-stat " VERSION "\n");
	exit (0);
}

static void show_help (void)
{
	printf ("\
Taking an output of lmdbg-run or other lmdbg-* utilities on input\n\
lmdbg-stat outputs a total and per-stacktrace statistical information\n\
about memory alocations.\n\
\n\
usage: lmdbg-stat [OPTIONS] [files...]\n\
OPTIONS:\n\
  -h          display this screen\n\
  -V          display version\n\
");
}

int main (int argc, char **argv)
{
	int i;
	FILE *fd;
	int opt;

	while (opt = getopt (argc, argv, "hV"), opt != -1){
		switch (opt) {
			case 'h':
				show_help ();
				exit (0);
				break;
			case 'V':
				show_version ();
				exit (0);
				break;
			case '?':
			default:
				show_help ();
				exit (1);
		}
	}

	argc -= optind;
	argv += optind;

	hash = st_hash_create ();

	if (!argc){
		process_stream (stdin);
	}else{
		for (i=0; i < argc; ++i){
			fd = fopen (argv [i], "r");
			if (!fd){
				perror ("fopen(3) failed");
				exit (1);
			}

			process_stream (fd);
			fclose (fd);
		}
	}

	print_results ();

	if (line_num >= 1)
		xputc ('\n', stdout);

	st_hash_destroy (hash);
	destroy_stats ();
	ptr2data_destroy ();

	return 0;
}
