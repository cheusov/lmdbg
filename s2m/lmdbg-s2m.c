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

static int first = 1;
static int line_num = 0;

static void xputc (int c, FILE *stream)
{
	if (putc (c, stdout) == EOF){
		perror ("putc(3) failed");
		exit (1);
	}
}

static void process_line (char *buf)
{
	char *p;
	char *last_token = NULL;

	if (!buf [0])
		return;

	if (strncmp (buf, "malloc", 6) &&
		strncmp (buf, "calloc", 6) &&
		strncmp (buf, "realloc", 7) &&
		strncmp (buf, "free", 4) &&
		strncmp (buf, "stacktrace", 10) &&
		strncmp (buf, "memalign", 8) &&
		strncmp (buf, "posix_memalign", 14) &&
		strncmp (buf, "stacktrace", 10))
	{
		puts (buf);
		return;
	}

	for (p=buf; *p; ++p){
		if (*p == ' ' && p[1] != 0 && p[1] != ' ')
			last_token = p+1;
	}

	if (!last_token){
		puts (buf);
		return;
	}

	last_token [-1] = 0;
	puts (buf);

	for (p=last_token; *p; ++p){
		if (*p == '\033'){
			*p = '\t';
		}else if (*p == '\032'){
			*p = ' ';
		}else if (*p == '\034'){
			*p = 0;
			xputc (' ', stdout);
			puts (last_token);
			last_token = p+1;
		}
	}
	xputc (' ', stdout);
	puts (last_token);
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

	return 0;
}
