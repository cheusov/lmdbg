#include <unistd.h>
#include <stdlib.h>

int main ()
{
	void *p;

	p = malloc (555);
	sleep (3);
	p = malloc (666);

	return 0;
}
