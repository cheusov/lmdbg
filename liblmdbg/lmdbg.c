/*
 * Copyright (c) 2003-2009 Aleksey Cheusov <vle@gmx.net>
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>
#include <assert.h>
#include <limits.h>
#include <signal.h>

#include <dlfcn.h>

#if HAVE_FUNC2_MEMALIGN_MALLOC_H
#include <malloc.h>
#endif

#include "stacktrace.h"

#define MAX_FRAMES_CNT 50

int log_enabled = 0;
void print_pid (void);
void *lmdbg_get_addr (char *point, char *base_addr, const char *module);

static const char *log_filename = NULL;
static FILE *      log_fd       = NULL;
static int         log_verbose  = 0;

static int st_skip_top    = 0;
static int st_skip_bottom = 0;
static int st_count = INT_MAX;

static int enabling_timeout = 0;

static unsigned alloc_count = 0;

#define POINTER_FORMAT "%p"

typedef void* (*malloc_t) (size_t);
typedef void* (*realloc_t) (void *, size_t);
typedef void (*free_t)    (void *);
typedef void* (*calloc_t)  (size_t, size_t);
typedef int  (*posix_memalign_t)  (void **, size_t, size_t);
typedef void* (*memalign_t) (size_t, size_t);

static malloc_t  real_malloc;
static realloc_t real_realloc;
static free_t    real_free;
static calloc_t  real_calloc;
#if HAVE_FUNC3_POSIX_MEMALIGN_STDLIB_H
static posix_memalign_t real_posix_memalign;
#endif
#if HAVE_FUNC2_MEMALIGN_MALLOC_H
static memalign_t real_memalign;
#endif

static void lmdbg_startup (void);
static void lmdbg_finish (void);

void construct(void) __attribute__((constructor));
void construct(void) { lmdbg_startup(); }

void destruct(void) __attribute__((destructor));
void destruct(void) { lmdbg_finish(); }

struct section_t {
	char *module;
	char *addr_beg;
	char *addr_end;
};
static struct section_t sections [1000];
static int sections_count = 0;

static void enable_logging (void);

static void handler_sigusr1 (int dummy)
{
	enable_logging ();
}

static void set_sigusr1_handler (void)
{
	struct sigaction sa;

	sa.sa_handler = handler_sigusr1;
	sigemptyset (&sa.sa_mask);
	sa.sa_flags = SA_RESTART;

	sigaction (SIGUSR1, &sa, NULL);
}

static int is_addr_valid (char *addr)
{
	int i;

	if (!sections_count)
		return 1;

	for (i=0; i < sections_count; ++i){
		if (addr >= sections [i].addr_beg && addr < sections [i].addr_end)
			return 1;
	}

	return 0;
}

static void print_stacktrace (void **buffer, int size)
{
	int i;
	int top, bottom;
	void *addr;
	if (!log_fd)
		return;

	if (st_skip_top + st_skip_bottom >= size){
		top = bottom = 0;
	}else{
		top    = st_skip_top;
		bottom = st_skip_bottom;
	}

	for (i = top; i < size - bottom && i-top < st_count; ++i){
		addr = buffer [i];
		if (!is_addr_valid (addr)){
/*			fprintf (stderr, "bad address: " POINTER_FORMAT "\n", addr); */
			continue;
		}

		assert (addr);
		fprintf (log_fd, " " POINTER_FORMAT "\n", addr);
	}
}

static void log_stacktrace (void)
{
	void * buf [MAX_FRAMES_CNT];
	int cnt;

	cnt = stacktrace (buf, MAX_FRAMES_CNT);
	print_stacktrace (buf, cnt);
}

#if defined(RTLD_LAZY)
#define DL_FLAGS RTLD_LAZY
#elif defined(DL_LAZY)
#define DL_FLAGS DL_LAZY
#endif

static void init_fun_ptrs (void)
{
	void *libc_so = NULL;

#if defined(RTLD_NEXT)
	libc_so = RTLD_NEXT;
#else
	libc_so = dlopen ("/lib/libc.so", DL_FLAGS);
#endif

	if (!libc_so)
		exit (40);

	real_malloc = (malloc_t) dlsym (libc_so, "__libc_malloc");
	if (!real_malloc)
		real_malloc  = (malloc_t) dlsym (libc_so, "malloc");
	if (!real_malloc)
		exit (41);

	real_realloc = (realloc_t) dlsym (libc_so, "__libc_realloc");
	if (!real_realloc)
		real_realloc = (realloc_t) dlsym (libc_so, "realloc");
	if (!real_realloc)
		exit (42);

	real_free    = (free_t) dlsym (libc_so, "__libc_free");
	if (!real_free)
		real_free    = (free_t) dlsym (libc_so, "free");
	if (!real_free)
		exit (43);

	real_calloc  = (calloc_t) dlsym (libc_so, "__libc_calloc");
	if (!real_calloc)
		real_calloc  = (calloc_t) dlsym (libc_so, "calloc");
	if (!real_calloc)
		exit (44);

#if HAVE_FUNC3_POSIX_MEMALIGN_STDLIB_H
	real_posix_memalign = (posix_memalign_t) dlsym (libc_so, "__libc_posix_memalign");
	if (!real_posix_memalign)
		real_posix_memalign = (posix_memalign_t) dlsym (libc_so, "posix_memalign");
	if (!real_posix_memalign)
		exit (45);
#endif

#if HAVE_FUNC2_MEMALIGN_MALLOC_H
	real_memalign    = (memalign_t) dlsym (libc_so, "__libc_memalign");
	if (!real_memalign)
		real_memalign    = (memalign_t) dlsym (libc_so, "memalign");
	if (!real_memalign)
		exit (46);
#endif
}

static void init_verbose_flag (void)
{
	const char *v = getenv ("LMDBG_VERBOSE");
	log_verbose = v && v [0];
}

static void init_log (void)
{
	char err_msg [200];

	log_filename = getenv ("LMDBG_LOGFILE");

	if (log_verbose)
		fprintf (stderr, "LMDBG_LOGFILE=%s\n", log_filename);

	if (log_filename && log_filename [0]){
		log_fd = fopen (log_filename, "w");

		if (!log_fd){
			snprintf (err_msg, sizeof (err_msg),
					  "fopen(\"%s\", \"w\") failed", log_filename);
			perror (err_msg);
			exit (50);
		}
	}
}

static void init_pid (void)
{
	char err_msg [200];
	FILE *pid_fd = NULL;

	const char *pid_filename = getenv ("LMDBG_PIDFILE");

	if (log_verbose)
		fprintf (stderr, "LMDBG_PIDFILE=%s\n", pid_filename);

	if (pid_filename && pid_filename [0]){
		pid_fd = fopen (pid_filename, "w");

		if (!pid_fd){
			snprintf (err_msg, sizeof (err_msg),
					  "fopen(\"%s\", \"w\") failed", pid_filename);
			perror (err_msg);
			exit (51);
		}

		fprintf (pid_fd, "%ld\n", (long int) getpid ());

		if (fclose (pid_fd)){
			snprintf (err_msg, sizeof (err_msg),
					  "write to \"%s\" failed", pid_filename);
			perror (err_msg);
			exit (52);
		}
	}
}

static void init_st_range (void)
{
	const char *s_st_skip_top    = getenv ("LMDBG_ST_SKIP_TOP");
	const char *s_st_skip_bottom = getenv ("LMDBG_ST_SKIP_BOTTOM");
	const char *s_st_count       = getenv ("LMDBG_ST_COUNT");

	if (s_st_skip_top && s_st_skip_top [0]){
		st_skip_top = atoi (s_st_skip_top);
		if (st_skip_top < 0)
			st_skip_top = 0;
	}

	if (s_st_skip_bottom && s_st_skip_bottom [0]){
		st_skip_bottom = atoi (s_st_skip_bottom);
		if (st_skip_bottom < 0)
			st_skip_bottom = 0;
	}

	if (s_st_count && s_st_count [0]){
		st_count = atoi (s_st_count);
		if (st_count <= 0)
			st_count = INT_MAX;
	}
}

static void init_enabling_timeout (void)
{
	const char *s = getenv ("LMDBG_TIMEOUT");
	if (!s || !*s)
		enabling_timeout = 0;
	else
		enabling_timeout = atoi(s);
}

static void enable_logging (void)
{
	if (!log_fd)
		return;

	log_enabled = 1;
}

static void disable_logging (void)
{
	log_enabled = 0;
}

void print_pid (void)
{
	FILE *pid_fd;
	const char *pid_filename = getenv ("LMDBG_PIDFILE");
	if (!pid_filename)
		return;

	pid_fd = fopen (pid_filename, "w");
	if (!pid_fd)
		return;

	fprintf (pid_fd, "%li\n", (long) getpid ());
	fclose (pid_fd);
}

void *lmdbg_get_addr (char *point, char *base_addr, const char *module)
{
	int i;

	for (i=0; i < sections_count; ++i){
		if (sections [i].module [0] == '/' && !strcmp (sections [i].module, module)){
			return sections [i].addr_beg + (point - base_addr);
		}
	}

	for (i=0; i < sections_count; ++i){
/*		fprintf (stderr, "%p in [%p, %p]\n",
				 point, sections [i].addr_beg, sections [i].addr_end);
*/

		if (point >= sections [i].addr_beg && point < sections [i].addr_end){
			return point;
		}
	}

	return NULL;
}

static void print_progname (void)
{
	const char *progname = getenv ("LMDBG_PROGNAME");
	if (!progname || !progname [0])
		return;

	if (!log_fd)
		return;

	fprintf (log_fd, "info progname %s\n", progname);
}

static void print_sections_map (void)
{
	char map_fn [PATH_MAX];
	FILE *fp;
	char buf [LINE_MAX];
	void *lmdbg_addr=NULL;
	const char *addr_beg=NULL, *addr_end=NULL;
	const char *module=NULL;
	char *p;
	size_t len;

	snprintf (map_fn, sizeof (map_fn), "/proc/%li/maps", (long) getpid ());
	fp = fopen (map_fn, "r");

	if (!fp)
		return;

	if (stacktrace (&lmdbg_addr, 1) != 1)
		return;

	while (fgets (buf, sizeof (buf), fp)){
		/* buf content has the following format 
		   bbbd1000-bbbd9000 rw-p 000d7000 00:18 116162   /lib/libc.so.12.163
		*/
		len = strlen (buf);
		if (buf [len-1] == '\n')
			buf [len-1] = 0;

		/* obtaining addresses */
		addr_beg = buf;
		for (p=buf; *p; ++p){
			if (*p == ' ')
				break;
			if (*p == '-'){
				*p = 0;
				addr_end = p + 1;
			}
		}
		if (!*p || !addr_end){
			/* badly formatted line? */
			continue;
		}

		*p++ = '\0';

		/* We need only executable sections (code) */
		if (*p != 'r')
			continue; /* not readable? */
		if (p[1] != '-')
			continue; /* bad input */
		if (p[2] != 'x')
			continue; /* not executable */

		/* obtaining library name */
		for (; *p; ++p){
			if (*p == ' ')
				module = p+1;
		}

		if (!module)
			module = "";

		/* fill in sections array */
		if (1 != sscanf (addr_beg, POINTER_FORMAT,
						 &sections [sections_count].addr_beg))
		{
			abort ();
		}
		if (1 != sscanf (addr_end, POINTER_FORMAT,
						 &sections [sections_count].addr_end))
		{
			abort ();
		}

		/* ignore addresses from lmdbg.c */
		if (lmdbg_addr >= (void *) sections [sections_count].addr_beg &&
			lmdbg_addr <  (void *) sections [sections_count].addr_end)
		{
			continue;
		}

		sections [sections_count].module = strdup (module);

		++sections_count;

		/* printing */
		if (addr_beg [0] == '0' && addr_beg [1] == 'x')
			addr_beg += 2;
		if (addr_end [0] == '0' && addr_end [1] == 'x')
			addr_end += 2;

		if (log_fd)
			fprintf (log_fd, "info section 0x%s 0x%s %s\n",
					 addr_beg, addr_end, module);
	}

	fclose (fp);
}

static void lmdbg_startup (void)
{
	if (real_malloc){
		/* already initialized */
		return;
	}

	init_fun_ptrs ();
	init_log ();
	init_pid ();
	init_st_range ();
	print_sections_map ();
	print_progname ();
	init_verbose_flag ();
	init_enabling_timeout ();

	if (log_filename != NULL && enabling_timeout == 0)
		enable_logging ();
	else if (enabling_timeout == -1)
		set_sigusr1_handler ();
}

static void lmdbg_finish (void)
{
	disable_logging ();
	if (log_fd)
		fclose (log_fd);
	log_fd = NULL;
}

/* replacement functions */
void * malloc (size_t s)
{
	void *p;
	
	if (!real_malloc){
		/* for glibc, normally real_malloc should be already initialized */
		init_fun_ptrs ();
	}

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		p = real_malloc (s);
		if (p)
			fprintf (log_fd, "malloc ( %u ) --> %p num: %u\n",
					 (unsigned) s, p, alloc_count);
		else
			fprintf (log_fd, "malloc ( %u ) --> NULL num: %u\n",
					 (unsigned) s, alloc_count);

		log_stacktrace ();

		enable_logging ();

		return p;
	}else{
		return real_malloc (s);
	}
}

void * realloc (void *p, size_t s)
{
	void *np;
	char np_buf [100];
	const char *np_ptr = "NULL";

	if (!real_malloc){
		/* for glibc, normally real_malloc should be already initialized */
		init_fun_ptrs ();
	}

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		np = (*real_realloc) (p, s);
		if (np){
			snprintf (np_buf, sizeof (np_buf), "%p", np);
			np_ptr = np_buf;
		}

		if (p){
			fprintf (log_fd, "realloc ( %p , %u ) --> %s num: %u\n",
					 p, (unsigned) s, np_ptr, alloc_count);
		}else{
			fprintf (log_fd, "realloc ( NULL , %u ) --> %s num: %u\n",
					 (unsigned) s, np_ptr, alloc_count);
		}

		log_stacktrace ();

		enable_logging ();
		return np;
	}else{
		return (*real_realloc) (p, s);
	}
}

void free (void *p)
{
	if (!real_malloc){
		/* for glibc, normally real_malloc should be already initialized */
		init_fun_ptrs ();
	}

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		(*real_free) (p);
		if (p)
			fprintf (log_fd, "free ( %p ) num: %u\n", p, alloc_count);
		else
			fprintf (log_fd, "free ( NULL ) num: %u\n", alloc_count);

		log_stacktrace ();

		enable_logging ();
	}else{
		(*real_free) (p);
	}
}

#ifndef __GLIBC__
/* On glibc-based systems lmdbg doesn't work with calloc */
void * calloc (size_t number, size_t size)
{
	void *p;

	if (!real_malloc){
		/* for glibc, normally real_malloc should be already initialized */
		init_fun_ptrs ();
	}

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		p = (*real_calloc) (number, size);
		if (p)
			fprintf (log_fd, "calloc ( %u , %u ) --> %p num: %u\n",
					 (unsigned) number, (unsigned) size, p, alloc_count);
		else
			fprintf (log_fd, "calloc ( %u , %u ) --> NULL num: %u\n",
					 (unsigned) number, (unsigned) size, alloc_count);

		log_stacktrace ();

		enable_logging ();
		return p;
	}else{
		return (*real_calloc) (number, size);
	}
}
#endif

#if HAVE_FUNC3_POSIX_MEMALIGN_STDLIB_H
int posix_memalign (void **memptr, size_t align, size_t size)
{
	int ret;

	if (!real_malloc){
		/* for glibc, normally real_malloc should be already initialized */
		init_fun_ptrs ();
	}

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		ret = (*real_posix_memalign) (memptr, align, size);
		if (!ret)
			fprintf (log_fd, "posix_memalign ( %u , %u ) --> %p num: %u\n",
					 (unsigned) align, (unsigned) size, *memptr,
					 alloc_count);
		else
			fprintf (log_fd, "posix_memalign ( %u , %u ) --> NULL num: %u\n",
					 (unsigned) align, (unsigned) size,
					 alloc_count);

		log_stacktrace ();

		enable_logging ();
		return ret;
	}else{
		return (*real_posix_memalign) (memptr, align, size);
	}
}
#endif

#if HAVE_FUNC2_MEMALIGN_MALLOC_H
void * memalign (size_t align, size_t size)
{
	void *p;

	if (!real_malloc){
		/* for glibc, normally real_malloc should be already initialized */
		init_fun_ptrs ();
	}

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		p = (*real_memalign) (align, size);
		fprintf (log_fd, "memalign ( %u , %u ) --> %p num: %u\n",
				 (unsigned) align, (unsigned) size, p, alloc_count);
		log_stacktrace ();

		enable_logging ();
		return p;
	}else{
		return (*real_memalign) (align, size);
	}
}
#endif
