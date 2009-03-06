
/* Copyright (c) 2003-2009 Aleksey Cheusov <vle@gmx.net>
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

#include <dlfcn.h>

#ifdef __linux__
#include <malloc.h>
#endif

#include "stacktrace.h"

#define MAX_FRAMES_CNT 50

static int log_enabled = 0;

static const char *log_filename = NULL;
static FILE *      log_fd       = NULL;
static int         log_verbose  = 0;

#define POINTER_FORMAT "%p"

static void * (*real_malloc)  (size_t s);
static void * (*real_realloc) (void *p, size_t s);
static void   (*real_free)    (void *p);
#if HAVE_MEMALIGN
static void * (*real_memalign) (size_t align, size_t size);
#endif

static void lmdbg_startup (void);
static void lmdbg_finish (void);

static void construct(void) __attribute__((constructor));
static void construct(void) { lmdbg_startup(); }

static void destruct(void) __attribute__((destructor));
static void destruct(void) { lmdbg_finish(); }

#ifdef __linux__
#define WRAP(name) wrap_ ## name
#else
#define WRAP(name) name
#endif

static void log_stacktrace (void);

static void print_stacktrace (void **buffer, int size)
{
	int i;
	for (i = 0; i < size; ++i) {
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

#if HAVE_MEMALIGN
	real_memalign    = dlsym (libc_so, "memalign");
	if (!real_memalign)
		exit (44);
#endif
}

static void init_verbose_flag ()
{
	const char *v = getenv ("LMDBG_VERBOSE");
	log_verbose = v && v [0];
}

static void init_log (void)
{
	log_filename = getenv ("LMDBG_LOGFILE");

	if (log_verbose)
		fprintf (stderr, "LMDBG_LOGFILE=%s\n", log_filename);

	if (!log_filename || strcmp (log_filename, "-") == 0){
		log_fd = stderr;
	}else{
		log_fd = fopen (log_filename, "w");

		if (!log_fd){
			perror (log_filename);
			exit (50);
		}
	}
}

#ifdef __linux__
#define EXTRA_ARG , const void *CALLER
#else
#define EXTRA_ARG
#endif

void * WRAP(malloc) (size_t s EXTRA_ARG);
void * WRAP(realloc) (void *p, size_t s EXTRA_ARG);
void WRAP(free) (void *p EXTRA_ARG);
#if HAVE_MEMALIGN
void * WRAP(memalign) (size_t align, size_t size EXTRA_ARG);
#endif

#ifdef __linux__
static void *(*malloc_hook_orig) (size_t size EXTRA_ARG);
static void *(*realloc_hook_orig) (void *p, size_t s EXTRA_ARG);
static void (*free_hook_orig) (void *p EXTRA_ARG);
#if HAVE_MEMALIGN
static void *(*memalign_hook_orig) (size_t align, size_t size EXTRA_ARG);
#endif
#endif

static void enable_logging (void)
{
	log_enabled = 1;

#ifdef __linux__
	__malloc_hook   = WRAP(malloc);
	__realloc_hook  = WRAP(realloc);
	__free_hook     = WRAP(free);
#if HAVE_MEMALIGN
	__memalign_hook = WRAP(memalign);
#endif
#endif
}

static void disable_logging (void)
{
	log_enabled = 0;

#ifdef __linux__
	__malloc_hook   = malloc_hook_orig;
	__realloc_hook  = realloc_hook_orig;
	__free_hook     = free_hook_orig;
#if HAVE_MEMALIGN
	__memalign_hook = memalign_hook_orig;
#endif
#endif
}

static void lmdbg_startup (void)
{
	if (real_malloc){
		/* already initialized */
		return;
	}

	init_fun_ptrs ();
	init_verbose_flag ();
	init_log ();

	/*
	fprintf (stderr, "real_malloc=%p\n", real_malloc);
	fprintf (stderr, "real_realloc=%p\n", real_realloc);
	fprintf (stderr, "real_free=%p\n", real_free);
	fprintf (stderr, "real_memalign=%p\n", real_memalign);
	*/

#ifdef __linux__
	malloc_hook_orig   = __malloc_hook;
	realloc_hook_orig  = __realloc_hook;
	free_hook_orig     = __free_hook;
#if HAVE_MEMALIGN
	memalign_hook_orig = __memalign_hook;
#endif
#endif

	if (log_filename != NULL)
		enable_logging ();
}

static void lmdbg_finish (void)
{
	disable_logging ();
	fclose (log_fd);
}

/* replacement functions */
void * WRAP(malloc) (size_t s EXTRA_ARG)
{
	assert (real_malloc);

	if (log_enabled){
		disable_logging ();

		void *p = (*real_malloc) (s);
		fprintf (log_fd, "malloc ( %u ) --> %p\n", (unsigned) s, p);
		log_stacktrace ();

		enable_logging ();
		return p;
	}else{
		return (*real_malloc) (s);
	}
}

void * WRAP(realloc) (void *p, size_t s EXTRA_ARG)
{
	assert (real_realloc);

	if (log_enabled){
		disable_logging ();

		void *np = (*real_realloc) (p, s);
		if (p){
			fprintf (log_fd, "realloc ( %p , %u ) --> %p\n",
					 p, (unsigned) s, np);
		}else{
			fprintf (log_fd, "realloc ( NULL , %u ) --> %p\n",
					 (unsigned) s, np);
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

		(*real_free) (p);
		fprintf (log_fd, "free ( %p )\n", p);
		log_stacktrace ();

		enable_logging ();
	}else{
		(*real_free) (p);
	}
}

#if HAVE_MEMALIGN
void * WRAP(memalign) (size_t align, size_t size EXTRA_ARG)
{
	assert (real_memalign);

	if (log_enabled){
		disable_logging ();

		void *p = (*real_memalign) (align, size);
		fprintf (log_fd, "memalign ( %u , %u ) --> %p\n",
				 (unsigned) align, (unsigned) size, p);
		log_stacktrace ();

		enable_logging ();
		return p;
	}else{
		return (*real_memalign) (align, size);
	}
}
#endif
