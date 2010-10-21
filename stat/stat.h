#ifndef _STAT_H_
#define _STAT_H_

#include <string.h>

typedef struct {
	void **stacktrace;
	int stacktrace_len;
	int allocs_cnt;
	size_t allocated;
	size_t max_allocated;
	size_t peak_allocated;
} stat_t;

extern stat_t **get_stat (int id);
extern void *stat;

#endif // _STAT_H_
