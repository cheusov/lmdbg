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

#define MAX_TRACEBACK_LEVELS 50

typedef void* traceback_t [MAX_TRACEBACK_LEVELS];

#define one_traceback(x) \
		tb [x] = __builtin_return_address (x); \
		frame  = __builtin_frame_address (x); \
		if (!tb [x] || !frame){\
			tb [x] = 0; \
			break;\
		};\
		last_frame = frame;

static void generate_traceback (traceback_t tb)
{ 
	unsigned i = 0;
	void* frame      = NULL;
	void* last_frame = NULL;

	for (i=0; i < MAX_TRACEBACK_LEVELS; ++i){
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
			break;
		}

		longjmp (jmpbuf, 2);
	}

	restore_sigfatal_handlers ();
}
