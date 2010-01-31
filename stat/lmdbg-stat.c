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

static int first = 1;
static int line_num = 0;

static Pvoid_t hash = NULL;

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
	ft_free
} func_t;

typedef struct {
	func_t type;
	size_t bytes;
	void *oldaddr;
	void *addr;
} operation_t;

static operation_t op;

static int stacktrace_count = 0;

typedef struct {
	void **stacktrace;
	int stacktrace_len;
	int allocs_cnt;
	size_t allocated;
	size_t max_allocated;
	size_t peak_allocated;
} stat_t;

static stat_t *statistics;

static int total_allocs_cnt = 0;
static int total_free_cnt = 0;
static size_t total_allocated = 0;

typedef struct {
	size_t allocated;
	int stacktrace_id;
} ptrdata_t;

static Pvoid_t ptr2data = NULL;

static void **stacktrace_dup (void **st, int st_len)
{
	void **p = malloc (st_len * sizeof (st [0]));
	memcpy (p, st, st_len * sizeof (st [0]));
	return p;
}

static void process_stacktrace (void)
{
	int i=0;
	PWord_t ret;
	int id;
	int new = 0;
	ptrdata_t *ptrdata;

//	printf ("stacktrace_len=%i\n", stacktrace_len);

	if (!stacktrace_len)
		return;

//	printf ("type = %i\n", op.type);
//	printf ("bytes = %u\n", (unsigned) op.bytes);
//	printf ("oldaddr = %p\n", op.oldaddr);
//	printf ("addr = %p\n", op.addr);

//	for (i=0; i < stacktrace_len; ++i){
//		printf ("  addr [%i]=%p\n", i, stacktrace [i]);
//	}

	switch (op.type){
		case ft_malloc:
		case ft_realloc:
		case ft_memalign:
		case ft_posix_memalign:
			ret = (PWord_t) JudyHSIns (&hash, stacktrace, stacktrace_len * sizeof (stacktrace [0]), 0);
			if (*ret == 0){
				new = 1;
				*ret = ++stacktrace_count;
			}
			id = *ret;

			if (new){
				statistics = (stat_t*) realloc (
					statistics,
					sizeof (statistics [0]) * (stacktrace_count+1));
				memset (&statistics [id],0, sizeof (statistics [0]));
			}

			statistics [id].allocated += op.bytes;
			if (statistics [id].allocated > statistics [id].peak_allocated)
				statistics [id].peak_allocated = statistics [id].allocated;
			if (op.bytes > statistics [id].max_allocated)
				statistics [id].max_allocated = op.bytes;
			++statistics [id].allocs_cnt;
			if (new){
				statistics [id].stacktrace
					= stacktrace_dup (stacktrace, stacktrace_len);
				statistics [id].stacktrace_len = stacktrace_len;
			}
			++total_allocs_cnt;
			total_allocated += op.bytes;
			ret = (PWord_t) JudyLIns (&ptr2data, (Word_t) op.addr, 0);
			*ret = (Word_t) malloc (sizeof (ptrdata_t));
			ptrdata = (ptrdata_t*) *ret;
			ptrdata->allocated = op.bytes;
			ptrdata->stacktrace_id = id;
			break;
	}

	switch (op.type){
		case ft_malloc:
		case ft_memalign:
		case ft_posix_memalign:
			break;
		case ft_realloc:
			if (op.oldaddr){
				ptrdata = *(ptrdata_t **) JudyLGet (ptr2data, (Word_t) op.oldaddr, 0);
				total_allocated -= ptrdata->allocated;
				statistics [ptrdata->stacktrace_id].allocated -= ptrdata->allocated;
			}
			break;
		case ft_free:
			ptrdata = *(ptrdata_t **) JudyLGet (ptr2data, (Word_t) op.oldaddr, 0);
			total_allocated -= ptrdata->allocated;
			++total_free_cnt;
			statistics [ptrdata->stacktrace_id].allocated -= ptrdata->allocated;
			ptrdata->allocated = 0;
			break;
		default:
			abort ();
	}

//	printf ("stacktrace_count=%i\n", stacktrace_count);

	/* reinit */
	stacktrace_len = 0;
}

void print_results (void)
{
	int i, j;
	printf ("info stat total_allocs: %i\n", total_allocs_cnt);
	printf ("info stat total_free_cnt: %i\n", total_free_cnt);
	printf ("info stat total_leaks: %lu\n", total_allocated);

	for (i=1; i <= stacktrace_count; ++i){
		printf ("stacktrace peak: %lu max: %lu allocs: %i",
				(unsigned long) statistics [i].peak_allocated,
				(unsigned long) statistics [i].max_allocated,
				(unsigned long) statistics [i].allocs_cnt);
		if (statistics [i].allocated){
			printf (" leaks: %lu", statistics [i].allocated);
		}
		printf ("\n");
		for (j=0; j < statistics [i].stacktrace_len; ++j){
			printf (" %p\n", statistics [i].stacktrace [j]);
		}
	}
}

static void * s2p (const char *s)
{
	void *addr;
	int ret = 0;

	ret = sscanf (s, "%p", &addr);
	if (ret != 1){
		perror ("Bad address:");
		exit (1);
	}

	return addr;
}

static int s2i (const char *s)
{
	int val;
	int ret = 0;

	ret = sscanf (s, "%i", &val);
	if (ret != 1){
		perror ("Bad integer:");
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
	int i;

	size_t bytes;

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
			 !strcmp (tokens [0], "posix_memalign")) &&
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
		if (len > 0 && buffer [len-1] == '\n')
			buffer [len-1] = 0;

		++line_num;
		process_line (buffer);
	}

	if (ferror (in)){
		perror ("fgets(3) failed");
		exit (1);
	}

	process_stacktrace ();
}

int main (int argc, char **argv)
{
	int i;
	FILE *fd;

	--argc, ++argv;

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

	return 0;
}
