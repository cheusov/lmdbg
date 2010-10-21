#include "stat.h"

#include <Judy.h>

void *stat = NULL;

stat_t **get_stat (int id)
{
	PWord_t ret = (PWord_t) JudyLIns (&stat, (Word_t) id, 0);
	return (stat_t **) ret;
}
