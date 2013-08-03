#include <stdlib.h>
#include <assert.h>

int main ()
{
	void *p1 = NULL;

	p1 = malloc (500);

	*(int *) NULL = 100500;

	return 0;
}
