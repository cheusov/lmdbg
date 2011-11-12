#include <stdlib.h>

extern int log_enabled;

int main ()
{
	int i;

	malloc (1000);
	for (i=0; i < 2000; ++i)
		malloc (1);
	for (i=0; i < 200; ++i)
		malloc (2);

	return 0;
}
