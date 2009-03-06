/*
 * Copyright (c) 2007-2008 Aleksey Cheusov <vle@gmx.net>
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

#if HAVE_EXECINFO_H
#include <execinfo.h>
/* GNU libc ? */
int stacktrace (void **buffer, int size)
{
	return backtrace (buffer, size);
}

#else
/* !HAVE_EXECINFO_H (probably NetBSD/FreeBSD/Solaris etc.) */

#include <string.h>
#include <signal.h>
#include <setjmp.h>

static struct sigaction sigsegv_orig_handler;
static struct sigaction  sigbus_orig_handler;

static jmp_buf jmpbuf;

static void handler_sigfatal (int dummy)
{
	longjmp (jmpbuf,1);
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

static void restore_sigfatal_handlers (void)
{
	sigaction (SIGSEGV, &sigsegv_orig_handler, NULL);
	sigaction (SIGBUS,  &sigbus_orig_handler, NULL);
}

#define one_traceback(x)					   \
		if (x >= size) break;                  \
		tb [x] = __builtin_return_address (x); \
		frame  = __builtin_frame_address (x); \
		if (!tb [x] || !frame){\
			tb [x] = 0; \
			break;\
		}

int stacktrace (void **tb, int size)
{
	unsigned i  = 0;
	void* frame = NULL;

	for (i=0; i < size; ++i){
		tb [i] = 0;
	}

	set_sigfatal_handlers ();

	if (!setjmp (jmpbuf)){
		while (1){
			one_traceback(0);
			one_traceback(1);
			one_traceback(2);
			one_traceback(3);
			one_traceback(4);
			one_traceback(5);
			one_traceback(6);
			one_traceback(7);
			one_traceback(8);
			one_traceback(9);
			one_traceback(10);
			one_traceback(11);
			one_traceback(12);
			one_traceback(13);
			one_traceback(14);
			one_traceback(15);
			one_traceback(16);
			one_traceback(17);
			one_traceback(18);
			one_traceback(19);
			one_traceback(20);
			one_traceback(21);
			one_traceback(22);
			one_traceback(23);
			one_traceback(24);
			one_traceback(25);
			one_traceback(26);
			one_traceback(27);
			one_traceback(28);
			one_traceback(29);
			one_traceback(30);
			one_traceback(31);
			one_traceback(32);
			one_traceback(33);
			one_traceback(34);
			one_traceback(35);
			one_traceback(36);
			one_traceback(37);
			one_traceback(38);
			one_traceback(39);
		}

		longjmp (jmpbuf, 2);
	}

	restore_sigfatal_handlers ();

	for (i=0; i < size; ++i){
		if (!tb [i])
			return i;
	}
	return size;
}
#endif /* HAVE_EXECINFO_H */
