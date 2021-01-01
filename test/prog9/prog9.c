#include <stdlib.h>

int main (int argc, char **argv)
{
	void *p1 = NULL;
	void *p2 = NULL;
	void *p3 = NULL;
	void *p4 = NULL;

	if (p1 = aligned_alloc(16, 200), p1 == NULL)
		return 1;
	if (p2 = aligned_alloc(8, 256), p2 == NULL)
		return 1;
	p3 = realloc (p1, 1024);
	if (p4 = aligned_alloc(256, 10240), p4 == NULL)
		return 1;
	free (p2);

	return 17;
}
