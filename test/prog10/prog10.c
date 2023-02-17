#include <sys/mman.h>
#include <stdlib.h>

#define FINAL_LENGTH (4096 * 10)

int main (int argc, char **argv)
{
	char *p = NULL;
	--argc;
	++argv;
	const char *arg1 = argc ? argv[0] : "";

	if (p = mmap(NULL, FINAL_LENGTH,
				 PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON,
				 -1, 0), p == NULL)
		return 1;

	if (!strchr(arg1, 'n'))
		munmap(p, FINAL_LENGTH);

	return 0;
}
