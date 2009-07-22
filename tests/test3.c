#include <stdlib.h>

char *allocate_memory (size_t count);

int main ()
{
	void *p1 = NULL;
	void *p2 = NULL;

	p1 = allocate_memory (555);
	p2 = malloc (666);

	return 0;
}
