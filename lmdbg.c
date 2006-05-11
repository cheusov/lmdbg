/* Lightwight Malloc DeBuGger */

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>
#include <malloc.h>
#include <assert.h>

#include <dlfcn.h>

static int log_enabled = 0;

static const char *log_filename = NULL;
static FILE *      log_fd       = NULL;
static int         log_verbose  = 0;

#define POINTER_FORMAT "%#08lx"

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

#include "stacktrace.c"

static void generate_traceback(TRACEBACK tb, addr eip);
static void do_traceback(addr eip);

static void print_traceback(TRACEBACK tb)
{
	size_t i;
	int count;

//	count = backtrace ((void **)tb, MAX_TRACEBACK_LEVELS);

	for (i = 0; i < MAX_TRACEBACK_LEVELS && tb [i]; ++i) {
		fprintf (log_fd, " " POINTER_FORMAT "\n", tb[i]);
	}
}

static void do_traceback(addr eip)
{
	TRACEBACK buf;
	memset (&buf, 0, sizeof (buf));
	generate_traceback(buf, eip);
	print_traceback(buf);
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

static void lmdbg_startup (void)
{
	if (real_malloc){
		/* already initialized */
		return;
	}

	init_fun_ptrs ();
	init_verbose_flag ();
	init_log ();

	log_enabled = 1;
}

static void lmdbg_finish (void)
{
	log_enabled = 0;
	fclose (log_fd);
}

/* replacement functions */
void * malloc (size_t s)
{
	if (log_enabled){
		void *p = (*real_malloc) (s);

		log_enabled = 0;
		fprintf (log_fd, "malloc ( %ul ) -> %p\n", (unsigned long) s, p);
		do_traceback ((addr) __builtin_return_address (0));
		log_enabled = 1;

		return p;
	}else{
		return (*real_malloc) (s);
	}
}

void * realloc (void *p, size_t s)
{
	if (log_enabled){
		void *np = (*real_realloc) (p, s);
		log_enabled = 0;

		if (p){
			fprintf (log_fd, "realloc ( %p , %ul ) --> %p\n",
					 p, (unsigned long) s, np);
		}else{
			fprintf (log_fd, "realloc ( NULL , %ul ) --> %p\n",
					 (unsigned long) s, np);
		}
		do_traceback ((addr) __builtin_return_address (0));

		log_enabled = 1;
		return np;
	}else{
		return (*real_realloc) (p, s);
	}
}

void free (void *p)
{
	if (log_enabled){
		(*real_free) (p);

		log_enabled = 0;
		fprintf (log_fd, "free ( %p )\n", p);
		do_traceback ((addr) __builtin_return_address (0));

		log_enabled = 1;
	}else{
		(*real_free) (p);
	}
}

#if HAVE_MEMALIGN
void * memalign (size_t align, size_t size)
{
	if (log_enabled){
		void *p = (*real_memalign) (align, size);

		log_enabled = 0;
		fprintf (log_fd, "memalign ( %ul , %ul ) --> %p\n",
				 (unsigned long) align, (unsigned long) size, p);
		do_traceback ((addr) __builtin_return_address (0));
		log_enabled = 1;

		return p;
	}else{
		return (*real_memalign) (align, size);
	}
}
#endif
