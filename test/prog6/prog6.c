#include <stdlib.h>

int main ()
{
	int i;
	void *p1 = malloc (888);

	for (i=0; i < 2000; ++i)
		malloc (1);
	for (i=0; i < 200; ++i)
		malloc (2);

	free (p1);

	return 0;
}
