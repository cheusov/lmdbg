#ifndef _ST_HASH_H_
#define _ST_HASH_H_

/* initialize st_hash object */
void * st_hash_create (void);
/* inserts st/st_size to the hash and returns a unique [1..+inf) identifier */
int st_hash_insert (void *h, void **st, int st_size);
/* returns an [1..+inf) identifier of st/st_size or -1 if absent */
int st_hash_getid (const void *h, void **st, int st_size);
/* returns maximum id */
int st_hash_getmaxid (const void *h);
/* destroys st_hash object */
void st_hash_destroy (void *h);

#endif // _ST_HASH_H_
