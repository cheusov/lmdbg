#include "stat.h"

#include <Judy.h>

static void *stat = NULL;

stat_t **get_stat (int id)
{
	PWord_t ret = (PWord_t) JudyLIns (&stat, (Word_t) id, 0);
	return (stat_t **) ret;
}

void destroy_stats (void)
{
	Word_t idx = 0;
	stat_t ** ptr = (stat_t **) JudyLFirst (stat, &idx, NULL);
	if (!ptr)
		return;

	do {
		if (*ptr){
			free ((*ptr)->stacktrace);
			free (*ptr);
		}

		ptr = (stat_t **) JudyLNext (stat, &idx, NULL);
	} while (ptr != NULL);
	JudyLFreeArray (&stat, NULL);
}
