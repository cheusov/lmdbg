#include <stdlib.h>

int main ()
{
	void *p1 = NULL;
	void *p2 = NULL;

	p1 = malloc (555);
	p2 = realloc (p2, 666);
	p2 = realloc (p2, 777);
	p2 = realloc (p2, 888);

	free (p1);

	return 0;
}
