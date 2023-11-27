#include <sys/mman.h>
#include <stdlib.h>
#include <string.h>

#define PAGE_SIZE 12288
#define FINAL_LENGTH (PAGE_SIZE * 10)

int main (int argc, char **argv)
{
	char *p = NULL;
	unsigned i;
	--argc;
	++argv;
	const char *arg1 = argc ? argv[0] : "";

	if (p = mmap(NULL, FINAL_LENGTH,
				 PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON,
				 -1, 0), p == NULL)
		return 1;

	if (strchr(arg1, 't')){
		for (i = 0; i < 3; ++i){
			mmap(NULL, PAGE_SIZE, PROT_READ|PROT_WRITE,
				 MAP_PRIVATE|MAP_ANON, -1, 0);
		}
	}

	if (!strchr(arg1, 'n'))
		munmap(p, FINAL_LENGTH);

	return 0;
}
