#include <stdlib.h>

int main ()
{
	void *p1 = NULL;
	void *p2 = NULL;
	void *p3 = NULL;
	void *p4 = NULL;

	if (posix_memalign (&p1, 16, 200))
		return 1;
	if (posix_memalign (&p2, 8, 256))
		return 1;
	p3 = realloc (p1, 1024);
	if (posix_memalign (&p4, 256, 10240))
		return 1;
	free (p2);

	return 0;
}
