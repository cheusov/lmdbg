#include <unistd.h>
#include <stdlib.h>

int main ()
{
	void *p;

	p = malloc (500);
	sleep (3);
	p = malloc (600);

	return 0;
}
