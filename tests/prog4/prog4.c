#include <stdlib.h>

int main (int argc, char **argv)
{
	void *p1 = NULL;
	void *p2 = NULL;
	void *p3 = NULL;
	void *p4 = NULL;

	p1 = calloc (555, 16);
	p2 = calloc (5, 256);
	p3 = realloc (p1, 1024);
	p4 = calloc (1, 10240);
	free (p2);

	return 0;
}
