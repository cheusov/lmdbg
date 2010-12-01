#include "st_hash.h"

#include <stdlib.h>
#include <stdio.h>
#include <Judy.h>

typedef struct {
	int count;
	Pvoid_t hash;
} st_hash_real_t;

void * st_hash_create (void)
{
	st_hash_real_t *p = malloc (sizeof (st_hash_real_t));
	if (!p){
		perror ("malloc(3) failed");
		exit (1);
	}

	p->count = 0;
	p->hash  = NULL;

	return p;
}

int st_hash_insert (void *h, void **st, int st_size)
{
	st_hash_real_t *p = (st_hash_real_t *) h;
	PWord_t ret = (PWord_t) JudyHSIns (
		&p->hash, (void *) st, st_size * sizeof (st [0]), 0);
	if (*ret == 0)
		*ret = ++p->count;
	return *ret;
}

int st_hash_getid (const void *h, void **st, int st_size)
{
	/* not implemented yet */
	abort ();
}

int st_hash_getmaxid (const void * h)
{
	const st_hash_real_t *p = (const st_hash_real_t *) h;
	return p->count;
}

void st_hash_destroy (void *h)
{
	st_hash_real_t *p = (st_hash_real_t *) h;
	JudyHSFreeArray (&p->hash, 0);
	free (h);
}
