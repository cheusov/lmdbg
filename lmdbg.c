/* Lightwight Malloc DeBuGger */



#define _GNU_SOURCE

#include "config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <unistd.h>
#include <fcntl.h>
#include <malloc.h>
#include <assert.h>
#include <execinfo.h>
#include <dlfcn.h>

/* Configuration info */

#define STACK_ADDR_OK(a) ((a) != 0)

typedef unsigned long addr;

#define MAX_TRACEBACK_LEVELS 50

typedef addr TRACEBACK [MAX_TRACEBACK_LEVELS+1];

/* Filename to which we output. */
static const char *logfile_name = NULL;

static FILE *log_fd = NULL;

#define CAST_ASSIGN(d,s) ((d) = ((typeof (d))(s)))

#define POINTER_FORMAT "%#08lx"

/* Symbol control */

#ifdef USE_LIBC_HOOKS
#define WRAPPER_LINKAGE static
#define WRAP(name) wrap_ ## name
#define REAL(name) name
#endif

extern void * REAL(malloc) (size_t s);
WRAPPER_LINKAGE void * WRAP(malloc) (size_t s);

extern void * REAL(realloc) (void *p, size_t s);
WRAPPER_LINKAGE void * WRAP(realloc) (void * p, size_t s);

extern void REAL(free) (void *p);
WRAPPER_LINKAGE void WRAP(free) (void * p);

#if HAVE_MEMALIGN
extern void * REAL(memalign) (size_t align, size_t size);
WRAPPER_LINKAGE void * WRAP(memalign) (size_t align, size_t size);
#endif

/* Declarations */
static void log_flush(void);
static void log_vprintf(const char *fmt, va_list va);
static void log_detail(const char *fmt, ...);
static void generate_traceback(TRACEBACK tb, addr eip);
static void dump_traceback(TRACEBACK tb);
static void do_traceback(addr eip);
static void print_header(void);

/* Number of times we call __lmdbg_maybe_finish. */
#define TRIES_FOR_FINISH 3

void __lmdbg_maybe_startup(void);
void __lmdbg_maybe_finish(void);

static void startup (void);
static void finish (void);

/* Hook to ensure we get linked.  The asm is to avoid underscore
   troubles. */
int __lmdbg_hook_1 asm ("__lmdbg_hook_1") = 0;

/* This file will be linked either first or last, so let's have a shot
   at constructing. */

static void construct(void) __attribute__((constructor));
static void construct(void) { __lmdbg_maybe_startup(); }

static void destruct(void) __attribute__((destructor));
static void destruct(void) { __lmdbg_maybe_finish(); }

/*
 */

#ifdef USE_LIBC_HOOKS
typedef struct {
	void * (*malloc_hook)(size_t s);
	void * (*realloc_hook)(void *p , size_t s );
	void (*free_hook)(void *p );

#if HAVE_MEMALIGN
	void * (*memalign_hook)(size_t al, size_t s );
#endif
} hookset;

static hookset lmdbg_hooks = {
	WRAP(malloc),
	WRAP(realloc),
	WRAP(free),

#if HAVE_MEMALIGN
	WRAP(memalign)
#endif
};

static void set_hooks(hookset *h)
{
	CAST_ASSIGN(__malloc_hook, h->malloc_hook);
	CAST_ASSIGN(__realloc_hook, h->realloc_hook);
	CAST_ASSIGN(__free_hook, h->free_hook);

#if HAVE_MEMALIGN
	CAST_ASSIGN(__memalign_hook, h->memalign_hook);
#endif
}

static void get_hooks(hookset *h)
{
	CAST_ASSIGN(h->malloc_hook, __malloc_hook);
	CAST_ASSIGN(h->realloc_hook, __realloc_hook);
	CAST_ASSIGN(h->free_hook, __free_hook);

#if HAVE_MEMALIGN
	CAST_ASSIGN(h->memalign_hook, __memalign_hook);
#endif
}
#endif

static hookset old_hooks = { NULL, NULL, NULL, NULL };

#define NO_CATCH() do {    \
	set_hooks(&old_hooks); \
} while (0)

#define OK_CATCH() do {     \
	get_hooks(&old_hooks);  \
	set_hooks(&lmdbg_hooks); \
} while (0)

/* HACK HACK HACK HACK HACK HACK HACK */
/* We want `startup' to be run before any constructors, and `finish'
   after all destructors and `atexit' functions.  The order depends in
   part on link order.  Therefore we call these from all possible
   places, and get the first or last as appropriate. */

void __lmdbg_maybe_startup(void)
{
	static int have_run = 0;
	if (!have_run){
		have_run = 1;
		atexit(__lmdbg_maybe_finish);
		startup();
    }else{
		return;
	}
}

void __lmdbg_maybe_finish(void)
{
	static int tries = 0;
	if (++tries == TRIES_FOR_FINISH) /* This is the last try */
		finish();
	else
		return;
}

static void startup (void)
{
	static int initted = 0;

	if (initted){
		fprintf(stderr, "Initted multiple times! Can't happen\n");
		return;
	}
	initted = 1;

	logfile_name = getenv ("LMDBG_LOGFILE");
	fprintf (stderr, "LMDBG_LOGFILE=%s\n", logfile_name);

	if (!logfile_name || strcmp (logfile_name, "-") == 0){
		log_fd = stderr;
	}else{
		log_fd = fopen (logfile_name, "w");

		fflush (stderr);

		if (!log_fd){
			perror(logfile_name);
			return;
		}
	}

	print_header();

	OK_CATCH ();
}

static void finish(void)
{
	NO_CATCH();
	log_flush();
	if (log_fd)
		fclose (log_fd);
}

static void 
generate_any_traceback (
	TRACEBACK tb,
	addr start_eip,
	addr start_ebp, 
	int eip_on_stack) 
{ 
/* Wow.  Here be lots of ugly typecasts. */ 
	addr ebp; 
	addr last_ebp; 
	addr eip; 
	size_t i; 

	if (eip_on_stack){ 
		last_ebp = 0; 
		ebp = start_ebp; 
		eip = 0;  /* In case we abort immediately */ 
/* The last test really needs to be done only once, but this 
   is cleaner */ 
		while (ebp > last_ebp && STACK_ADDR_OK(ebp)){ 
			eip = *((addr *)ebp + 1); 
			last_ebp = ebp; 
			ebp = *(addr *)ebp; 
			if (eip == start_eip) 
				break; 
		}
		if (eip != start_eip){ 
/* We broke out because the frame address went wrong, or maybe 
   we reached the top.  Assume start_eip is right, but don't 
   go any farther than that. */ 
			tb[0] = start_eip; 
			tb[1] = 0; 
			return; 
		} 
	}else{ 
		eip = start_eip; 
		ebp = start_ebp; 
	} 
 
	i = 0; 
	last_ebp = 0; 
	tb[i++] = eip; /* Log the first one */ 
 
/* The last test really needs to be done only once, but this 
   is cleaner */ 
	while (
		i < MAX_TRACEBACK_LEVELS - 1 &&
		ebp > last_ebp &&
		STACK_ADDR_OK(ebp))
	{
		tb[i++] = *((addr *)ebp + 1); 
		last_ebp = ebp; 
		ebp = *(addr *)ebp; 
	} 
	tb[i] = 0; 
}

static void
dump_traceback(TRACEBACK tb)
{
	size_t i;
	int count;

//	count = backtrace ((void **)tb, MAX_TRACEBACK_LEVELS);
	count = MAX_TRACEBACK_LEVELS;

	for (i = 0; i < count && tb [i]; ++i) {
		log_detail(" " POINTER_FORMAT "\n", tb[i]);
	}
}

 /* The standard case, where we want a traceback of our callers */
static void 
generate_traceback(TRACEBACK tb, addr eip)
{ 
	generate_any_traceback(tb, eip, (addr)__builtin_frame_address(0), 1); 
} 

static void
do_traceback(addr eip)
{
	TRACEBACK buf;
	memset (&buf, 0, sizeof (buf));
	generate_traceback(buf, eip);
	dump_traceback(buf);
}

/* Logging */

static void
log_flush(void)
{
	if (log_fd)
		fflush (log_fd);
}

static void
log_vprintf(const char *fmt, va_list va)
{
   if (log_fd)
      vfprintf (log_fd, fmt, va);
}

static void
log_detail(const char *fmt, ...)
{
	va_list vl;
	va_start(vl, fmt);
	log_vprintf(fmt, vl);
	va_end(vl);
}

/* Generate a traceback and store it in `tb'.  If `eip_on_stack' is 1,
   `start_ebp' is a frame pointer somewhere below the caller at `start_eip'.
   Otherwise, `start_eip' is not on the stack; the traceback will start
   with it and continue with the function whose frame pointer is `start_ebp'.
*/

/* Standard GCC stack frame looks like:
   ...
   Return address
   Saved EBP  <-- EBP points here
   Local vars...
*/

/* Bother.  There isn't really any good way to find out the limits
   of the stack.  Guess we just have to trust the luser to have
   compiled without -fomit-frame-pointer and not scrogged the stack... */
#define STACK_ADDR_OK(a) ((a) != 0)

WRAPPER_LINKAGE 
void *
WRAP(malloc)(size_t n )
{
	addr adr;
	void *p;

	NO_CATCH();
	p = REAL(malloc)(n);
	OK_CATCH();

	log_detail ("malloc ( %u ) -> %p\n", n, p);

	adr = (addr) __builtin_return_address (0);
	do_traceback (adr);

	return p;
}

#if HAVE_MEMALIGN
static void *
WRAP(memalign)(size_t alignment, size_t nbytes)
{
	addr adr;
	void *p;

	NO_CATCH();
	p = REAL(memalign)(alignment, nbytes);
	OK_CATCH ();

	log_detail ("memalign ( %u , %u ) --> %p\n", alignment, nbytes, p);

	adr = (addr) __builtin_return_address (0);
	do_traceback (adr);

	return p;
}
#endif

WRAPPER_LINKAGE
void
WRAP(free) (void *p )
{
	addr adr;

	NO_CATCH();
	REAL(free)(p);
	OK_CATCH ();

	log_detail ("free ( %p )\n", p);

	adr = (addr) __builtin_return_address (0);
	do_traceback (adr);
}

WRAPPER_LINKAGE
void *
WRAP(realloc)(void *p, size_t s)
{
	addr adr;
	void *np;

	NO_CATCH();
	np = REAL(realloc)(p, s);
	OK_CATCH();

	if (p)
		log_detail ("realloc ( %p , %u ) --> %p\n", p, s, np);
	else
		log_detail ("realloc ( NULL , %u ) --> %p\n", s, np);

	adr = (addr) __builtin_return_address (0);
	do_traceback (adr);

	return np;
}

static void print_header(void)
{
}

int lmdbg_dlopen_add_libs (void)
{
	char *add_libs = getenv ("LMDBG_ADD_LIBS");
	char buf [4000];
	char *p;
	char *library = NULL;
	char *s_flags    = NULL;
	int flags = 0;
	int ret = 0;
	int exit_flag = 0;

	NO_CATCH();

	if (add_libs && add_libs [0] && strlen (add_libs) < 4000){
		strcpy (buf, add_libs);
		for (p = buf; 1; ++p){
			exit_flag = !*p;

			switch (*p){
				case ':':
					*p = 0;
					s_flags = p + 1;
					break;
				case ',':
				case '\0':
					*p = 0;

					if (library && s_flags){

						if (!strcmp (s_flags, "RTLD_LAZY")){
							flags = RTLD_LAZY;
						}else if (!strcmp (s_flags, "RTLD_GLOBAL")){
							flags = RTLD_GLOBAL;
						}else if (!strcmp (s_flags, "RTLD_NOW")){
							flags = RTLD_NOW;
						}else{
							/* this should not happen */
							return 7;
						}
						fprintf (stderr, "dlopen(\"%s\", %i)...", library, flags);
						if (dlopen (library, flags)){
							fprintf (stderr, "done\n");
							++ret;
						}else{
							fprintf (stderr, "failed\n");
						}
					}

					library = p + 1;
					s_flags = NULL;
					break;
				default:
			}

			if (exit_flag)
				break;
		}
	}

	OK_CATCH ();
	fprintf (stderr, "successfully loaded: %i librarries\n", ret);
	return 0;
}
