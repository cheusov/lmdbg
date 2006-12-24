/* This code is derived from yamd */

/*
  Yet Another Malloc Debugger

  This file and the rest of YAMD is copyright (C) 1999 by Nate Eldredge.
  There is no warranty whatever; I disclaim responsibility for any
  damage caused.  Released under the GNU General Public License (see the
  file COPYING).
*/

#if !defined(__i386__)
#error Can be compiled on x86 only!
#endif

typedef unsigned long addr;

#define MAX_TRACEBACK_LEVELS 50

typedef addr TRACEBACK [MAX_TRACEBACK_LEVELS+1];

#define STACK_ADDR_OK(x) ((x) != 0)

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

#ifdef USE_GCC_BUILTINS
#define one_traceback(x) \
		tb [x] = (addr)__builtin_return_address (x); \
		frame  = (addr)__builtin_frame_address (x); \
		if (!tb [x] || !frame || (frame > last_frame && last_frame)){\
			tb [x] = 0; \
			return;\
		};\
		last_frame = frame;
#endif

static void generate_traceback(TRACEBACK tb, addr eip)
{ 
#ifndef USE_GCC_BUILTINS
	generate_any_traceback(tb, eip, (addr)__builtin_frame_address(0), 1); 
#else
	unsigned i = 0;
	addr frame      = 0;
	addr last_frame = 0;

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
#endif
} 
