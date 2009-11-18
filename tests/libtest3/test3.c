#include <stdlib.h>

char *allocate_memory (size_t count);

char *allocate_memory (size_t count)
{
	return malloc (count);
}
