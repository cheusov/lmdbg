/*
 * Copyright (c) 2007-2013 Aleksey Cheusov <vle@gmx.net>
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

#include "stacktrace.h"

#ifdef EXTERNAL_BACKTRACE
#include <execinfo.h>
/* GNU libc ? */
int stacktrace (void **buffer, int size)
{
	int ret = backtrace (buffer, size);
	int i;

	for (i=0; i < ret; ++i){
		if (!buffer [i])
			return i;
	}

	return ret;
}

#else
/* !HAVE_HEADER_EXECINFO_H (probably NetBSD/FreeBSD/Solaris etc.) */

/*
  stacktrace(3) implementation:
    - gcc's __builtin_frame_address and __builtin_return_address builtins are used.
	- in order to prevent sigsegv caused by stacktrace(3) seen on some
      systems, sigsegv and some other signals are ignored if they
      happen from inside stacktrace(3). If they happen outside
      stacktrace(3), they are handled by original handlers.
*/

#include <string.h>
#include <signal.h>
#include <setjmp.h>
#include <unistd.h>

static struct sigaction sigsegv_orig_handler;
static struct sigaction  sigbus_orig_handler;

static jmp_buf jmpbuf;

static int signals_already_set = 0;
static int inside_stacktrace   = 0;

static void restore_sigfatal_handlers (void)
{
	sigaction (SIGSEGV, &sigsegv_orig_handler, NULL);
	sigaction (SIGBUS,  &sigbus_orig_handler, NULL);
}

static void handler_sigfatal (int sig)
{
	if (inside_stacktrace){
		longjmp (jmpbuf,1);
	}else{
		restore_sigfatal_handlers ();
		kill (getpid (), sig);
	}
}

static void set_sigfatal_handlers (void)
{
	struct sigaction sa;

	sa.sa_handler = handler_sigfatal;
	sigemptyset (&sa.sa_mask);
	sa.sa_flags = 0;

	sigaction (SIGSEGV, &sa, &sigsegv_orig_handler);
	sigaction (SIGBUS,  &sa,  &sigbus_orig_handler);
}

#define one_return_address(x) \
 if (x == size) return size; \
 if (!__builtin_frame_address (x)) return x; \
 tb [x] = __builtin_return_address (x); \
 if (!tb [x]) return x; \
 ret = x;

int stacktrace (void **tb, int size)
{
	int ret = 0;

	inside_stacktrace = 1;

	if (!signals_already_set){
		set_sigfatal_handlers ();
		signals_already_set = 1;
	}

	if (!setjmp (jmpbuf)){
		one_return_address(0);
		one_return_address(1);
		one_return_address(2);
		one_return_address(3);
		one_return_address(4);
		one_return_address(5);
		one_return_address(6);
		one_return_address(7);
		one_return_address(8);
		one_return_address(9);
		one_return_address(10);
		one_return_address(11);
		one_return_address(12);
		one_return_address(13);
		one_return_address(14);
		one_return_address(15);
		one_return_address(16);
		one_return_address(17);
		one_return_address(18);
		one_return_address(19);
		one_return_address(20);
		one_return_address(21);
		one_return_address(22);
		one_return_address(23);
		one_return_address(24);
		one_return_address(25);
		one_return_address(26);
		one_return_address(27);
		one_return_address(28);
		one_return_address(29);
		one_return_address(30);
		one_return_address(31);
		one_return_address(32);
		one_return_address(33);
		one_return_address(34);
		one_return_address(35);
		one_return_address(36);
		one_return_address(37);
		one_return_address(38);
		one_return_address(39);

		longjmp (jmpbuf, 2);
	}

	inside_stacktrace = 0;

	return ret+1;
}

#endif /* HAVE_HEADER_EXECINFO_H */
