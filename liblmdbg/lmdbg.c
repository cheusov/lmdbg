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

static int st_skip  = 0;
static int st_count = INT_MAX;

static unsigned alloc_count = 0;

#define POINTER_FORMAT "%p"

static void * (*real_malloc)  (size_t s);
static void * (*real_realloc) (void *p, size_t s);
static void   (*real_free)    (void *p);
static void * (*real_calloc)  (size_t number, size_t s);
#if HAVE_FUNC3_POSIX_MEMALIGN_STDLIB_H
static int (*real_posix_memalign)  (void **memptr, size_t align, size_t size);
#endif
#if HAVE_FUNC2_MEMALIGN_MALLOC_H
static void * (*real_memalign) (size_t align, size_t size);
#endif

static void lmdbg_startup (void);
static void lmdbg_finish (void);

void construct(void) __attribute__((constructor));
void construct(void) { lmdbg_startup(); }

void destruct(void) __attribute__((destructor));
void destruct(void) { lmdbg_finish(); }

#ifdef HAVE_VAR___MALLOC_HOOK_MALLOC_H
#define WRAP(name) wrap_ ## name
#else
#define WRAP(name) name
#endif

static void print_stacktrace (void **buffer, int size)
{
	int i;
	if (!log_fd)
		return;

	for (i = st_skip; i < size && i-st_skip < st_count; ++i) {
		fprintf (log_fd, " " POINTER_FORMAT "\n", buffer [i]);
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

	real_malloc  = dlsym (libc_so, "malloc");
	if (!real_malloc)
		exit (41);

	real_realloc = dlsym (libc_so, "realloc");
	if (!real_realloc)
		exit (42);

	real_free    = dlsym (libc_so, "free");
	if (!real_free)
		exit (43);

	real_calloc  = dlsym (libc_so, "calloc");
	if (!real_calloc)
		exit (44);

#if HAVE_FUNC3_POSIX_MEMALIGN_STDLIB_H
	real_posix_memalign = dlsym (libc_so, "posix_memalign");
	if (!real_posix_memalign)
		exit (45);
#endif

#if HAVE_FUNC2_MEMALIGN_MALLOC_H
	real_memalign    = dlsym (libc_so, "memalign");
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

	if (log_filename){
		log_fd = fopen (log_filename, "w");

		if (!log_fd){
			snprintf (err_msg, sizeof (err_msg),
					  "fopen(\"%s\", \"w\") failed", log_filename);
			perror (err_msg);
			exit (50);
		}
	}
}

static void init_st_range (void)
{
	const char *s_st_skip = getenv ("LMDBG_ST_SKIP");
	const char *s_st_count = getenv ("LMDBG_ST_COUNT");

	if (s_st_skip && s_st_skip [0]){
		st_skip = atoi (s_st_skip);
		if (st_skip < 0)
			st_skip = 0;
	}

	if (s_st_count && s_st_count [0]){
		st_count = atoi (s_st_count);
		if (st_count < 0)
			st_count = INT_MAX;
	}
}

#ifdef HAVE_VAR___MALLOC_HOOK_MALLOC_H
#define EXTRA_ARG , const void *CALLER
#else
#define EXTRA_ARG
#endif

void * WRAP(malloc) (size_t s EXTRA_ARG);
void * WRAP(realloc) (void *p, size_t s EXTRA_ARG);
void WRAP(free) (void *p EXTRA_ARG);
#if HAVE_FUNC2_MEMALIGN_MALLOC_H
void * WRAP(memalign) (size_t align, size_t size EXTRA_ARG);
#endif

/* no WRAP and EXTRA_ARG! for calloc(3) and posix_memalign(3) */
void * calloc (size_t number, size_t s);
#if HAVE_FUNC3_POSIX_MEMALIGN_STDLIB_H
int posix_memalign (void **memptr, size_t align, size_t size);
#endif

#ifdef HAVE_VAR___MALLOC_HOOK_MALLOC_H
static void *(*malloc_hook_orig) (size_t size EXTRA_ARG);
static void *(*realloc_hook_orig) (void *p, size_t s EXTRA_ARG);
static void (*free_hook_orig) (void *p EXTRA_ARG);
#if HAVE_FUNC2_MEMALIGN_MALLOC_H
static void *(*memalign_hook_orig) (size_t align, size_t size EXTRA_ARG);
#endif
#endif

static void enable_logging (void)
{
	log_enabled = 1;

#ifdef HAVE_VAR___MALLOC_HOOK_MALLOC_H
	__malloc_hook   = WRAP(malloc);
	__realloc_hook  = WRAP(realloc);
	__free_hook     = WRAP(free);
#if HAVE_FUNC2_MEMALIGN_MALLOC_H
	__memalign_hook = WRAP(memalign);
#endif
#endif
}

static void disable_logging (void)
{
	log_enabled = 0;

#ifdef HAVE_VAR___MALLOC_HOOK_MALLOC_H
	__malloc_hook   = malloc_hook_orig;
	__realloc_hook  = realloc_hook_orig;
	__free_hook     = free_hook_orig;
#if HAVE_FUNC2_MEMALIGN_MALLOC_H
	__memalign_hook = memalign_hook_orig;
#endif
#endif
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

struct section_t {
	char *module;
	char *addr_beg;
	char *addr_end;
};
static struct section_t sections [1000];
static int sections_count = 0;

void *lmdbg_get_addr (char *point, char *base_addr, const char *module)
{
	int i;

	for (i=0; i < sections_count; ++i){
		if (!strcmp (sections [i].module, module)){
			return sections [i].addr_beg + (point - base_addr);
		}
	}

	/* If we don't find appropriate address range, return
	 an original address
	*/
	return point;
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
	const char *addr_beg=NULL, *addr_end=NULL;
	char *module=NULL;
	char *p;
	size_t len;

	snprintf (map_fn, sizeof (map_fn), "/proc/%li/maps", (long) getpid ());
	fp = fopen (map_fn, "r");

	if (!fp){
		return;
	}

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

		if (!module || *module != '/')
			continue;

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

		sections [sections_count].module = strdup (module);

		++sections_count;

		/* printing */
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
	init_st_range ();
	print_sections_map ();
	print_progname ();
	init_verbose_flag ();

	/*
	fprintf (stderr, "real_malloc=%p\n", real_malloc);
	fprintf (stderr, "real_realloc=%p\n", real_realloc);
	fprintf (stderr, "real_free=%p\n", real_free);
	fprintf (stderr, "real_memalign=%p\n", real_memalign);
	*/

#ifdef HAVE_VAR___MALLOC_HOOK_MALLOC_H
	malloc_hook_orig   = __malloc_hook;
	realloc_hook_orig  = __realloc_hook;
	free_hook_orig     = __free_hook;
#if HAVE_FUNC2_MEMALIGN_MALLOC_H
	memalign_hook_orig = __memalign_hook;
#endif
#endif

	if (log_filename != NULL)
		enable_logging ();
}

static void lmdbg_finish (void)
{
	disable_logging ();
	if (log_fd)
		fclose (log_fd);
	log_fd = NULL;
}

/* replacement functions */
void * WRAP(malloc) (size_t s EXTRA_ARG)
{
	void *p;
	assert (real_malloc);

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		p = (*real_malloc) (s);
		fprintf (log_fd, "malloc ( %u ) --> %p num: %u\n",
				 (unsigned) s, p, alloc_count);

		log_stacktrace ();

		enable_logging ();
		return p;
	}else{
		return (*real_malloc) (s);
	}
}

void * WRAP(realloc) (void *p, size_t s EXTRA_ARG)
{
	void *np;
	assert (real_realloc);

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		np = (*real_realloc) (p, s);
		if (p){
			fprintf (log_fd, "realloc ( %p , %u ) --> %p num: %u\n",
					 p, (unsigned) s, np, alloc_count);
		}else{
			fprintf (log_fd, "realloc ( NULL , %u ) --> %p num: %u\n",
					 (unsigned) s, np, alloc_count);
		}
		log_stacktrace ();

		enable_logging ();
		return np;
	}else{
		return (*real_realloc) (p, s);
	}
}

void WRAP(free) (void *p EXTRA_ARG)
{
	assert (real_free);

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		(*real_free) (p);
		fprintf (log_fd, "free ( %p ) num: %u\n", p, alloc_count);
		log_stacktrace ();

		enable_logging ();
	}else{
		(*real_free) (p);
	}
}

void * calloc (size_t number, size_t size)
{
	void *p;
	assert (real_calloc);

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		p = (*real_calloc) (number, size);
		fprintf (log_fd, "calloc ( %u , %u ) --> %p num: %u\n",
				 (unsigned) number, (unsigned) size, p, alloc_count);
		log_stacktrace ();

		enable_logging ();
		return p;
	}else{
		return (*real_calloc) (number, size);
	}
}

#if HAVE_FUNC3_POSIX_MEMALIGN_STDLIB_H
int posix_memalign (void **memptr, size_t align, size_t size)
{
	int ret;
	assert (real_posix_memalign);

	if (log_enabled){
		disable_logging ();

		++alloc_count;

		ret = (*real_posix_memalign) (memptr, align, size);
		fprintf (log_fd, "posix_memalign ( %u , %u ) --> %p num: %u\n",
				 (unsigned) align, (unsigned) size, *memptr,
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
void * WRAP(memalign) (size_t align, size_t size EXTRA_ARG)
{
	void *p;
	assert (real_memalign);

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
