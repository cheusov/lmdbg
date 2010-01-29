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
	ft_malloc,
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

static void process_stacktrace (void)
{
	int i=0;
	PWord_t ret;

	printf ("stacktrace_len=%i\n", stacktrace_len);

	if (!stacktrace_len)
		return;

//	printf ("type = %i\n", op.type);
//	printf ("bytes = %u\n", (unsigned) op.bytes);
//	printf ("oldaddr = %p\n", op.oldaddr);
//	printf ("addr = %p\n", op.addr);

//	for (i=0; i < stacktrace_len; ++i){
//		printf ("  addr [%i]=%p\n", i, stacktrace [i]);
//	}

	ret = (PWord_t) JudyHSIns (&hash, stacktrace, stacktrace_len * sizeof (stacktrace [0]), 0);
	if (*ret == 0){
		*ret = ++stacktrace_count;
	}

	printf ("stacktrace_count=%i\n", stacktrace_count);

	/* reinit */
	stacktrace_len = 0;
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
		/* malloc/calloc/realloc/free/... */
//		printf ("lalala=%s\n", buf);
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
			!strcmp (tokens [4], "->"))
		{
			op.type    = ft_malloc;
			op.bytes   = (size_t) s2i (tokens [2]);
			op.oldaddr = NULL;
			op.addr    = s2p (tokens [5]);
		}

		if (token_count >= 8 &&
			!strcmp (tokens [0], "calloc") &&
			!strcmp (tokens [1], "(") &&
			!strcmp (tokens [3], ",") &&
			!strcmp (tokens [5], ")") &&
			!strcmp (tokens [6], "->"))
		{
			op.type    = ft_malloc;
			op.bytes   = (size_t) (s2i (tokens [2]) * s2i (tokens [4]));
			op.oldaddr = NULL;
			op.addr    = s2p (tokens [7]);
		}

		if (token_count >= 8 &&
			!strcmp (tokens [0], "realloc") &&
			!strcmp (tokens [1], "(") &&
			!strcmp (tokens [3], ",") &&
			!strcmp (tokens [5], ")") &&
			!strcmp (tokens [6], "->"))
		{
			op.type    = ft_realloc;
			op.bytes   = (size_t) s2i (tokens [4]);
			op.oldaddr = s2p (tokens [2]);
			op.addr    = s2p (tokens [7]);
		}

		if (token_count >= 8 &&
			(!strcmp (tokens [0], "memalign") ||
			 !strcmp (tokens [0], "posix_memalign")) &&
			!strcmp (tokens [1], "(") &&
			!strcmp (tokens [3], ",") &&
			!strcmp (tokens [5], ")") &&
			!strcmp (tokens [6], "->"))
		{
			op.type    = ft_memalign;
			op.bytes   = (size_t) s2i (tokens [4]);
			op.oldaddr = NULL;
			op.addr    = s2p (tokens [7]);
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
		}

		process_stacktrace ();
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

	if (line_num >= 1)
		xputc ('\n', stdout);

	return 0;
}
